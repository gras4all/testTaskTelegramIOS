import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import TelegramStringFormatting
import PhoneNumberFormat
import AppBundle
import PresentationDataUtils
import NotificationMuteSettingsUI
import NotificationSoundSelectionUI
import OverlayStatusController
import ShareController
import PhotoResources
import PeerAvatarGalleryUI
import TelegramIntents
import PeerInfoUI
import SearchBarNode
import SearchUI
import ContextUI
import OpenInExternalAppUI
import SafariServices
import GalleryUI
import LegacyUI
import MapResourceToAvatarSizes
import LegacyComponents
import WebSearchUI
import LocationResources
import LocationUI
import Geocoding
import TextFormat
import StatisticsUI
import StickerResources
import SettingsUI
import ChatListUI
import CallListUI
import AccountUtils
import PassportUI
import AuthTransferUI
import DeviceAccess
import LegacyMediaPickerUI
import TelegramNotices
import SaveToCameraRoll
import PeerInfoUI
import ListMessageItem
import GalleryData
import ChatInterfaceState
import TelegramVoip
import InviteLinksUI
import UndoUI
import MediaResources
import HashtagSearchUI
import ActionSheetPeerItem
import TelegramCallsUI
import PeerInfoAvatarListNode
import PasswordSetupUI
import CalendarMessageScreen
import TooltipUI
import QrCodeUI
import TranslateUI
import ChatPresentationInterfaceState
import CreateExternalMediaStreamScreen
import PaymentMethodUI
import PremiumUI
import InstantPageCache

// MARK: - TestTaskAccountScreenImpl
public final class TestTaskAccountScreenImpl: ViewController, PeerInfoScreen, KeyShortcutResponder {
    private let context: AccountContext
    let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private let peerId: PeerId
    private let avatarInitiallyExpanded: Bool
    private let isOpenedFromChat: Bool
    private let nearbyPeerDistance: Int32?
    private var callMessages: [Message]
    private let isSettings: Bool
    private let hintGroupInCommon: PeerId?
    private weak var requestsContext: PeerInvitationImportersContext?
    
    var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let cachedDataPromise = Promise<CachedPeerData?>()
    
    private let accountsAndPeers = Promise<((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)])>()
    private var accountsAndPeersValue: ((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)])?
    private var accountsAndPeersDisposable: Disposable?
    
    private let activeSessionsContextAndCount = Promise<(ActiveSessionsContext, Int, WebSessionsContext)?>(nil)

    private var tabBarItemDisposable: Disposable?

    var controllerNode: TestTaskAccountScreenNode {
        return self.displayNode as! TestTaskAccountScreenNode
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    override public var customNavigationData: CustomViewControllerNavigationData? {
        get {
            if !self.isSettings {
                return ChatControllerNavigationData(peerId: self.peerId)
            } else {
                return nil
            }
        }
    }
    
    private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, peerId: PeerId, avatarInitiallyExpanded: Bool, isOpenedFromChat: Bool, nearbyPeerDistance: Int32?, callMessages: [Message], isSettings: Bool = false, hintGroupInCommon: PeerId? = nil, requestsContext: PeerInvitationImportersContext? = nil) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.peerId = peerId
        self.avatarInitiallyExpanded = avatarInitiallyExpanded
        self.isOpenedFromChat = isOpenedFromChat
        self.nearbyPeerDistance = nearbyPeerDistance
        self.callMessages = callMessages
        self.isSettings = isSettings
        self.hintGroupInCommon = hintGroupInCommon
        self.requestsContext = requestsContext
        
        self.presentationData = updatedPresentationData?.0 ?? context.sharedContext.currentPresentationData.with { $0 }
        
        let baseNavigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
        super.init(navigationBarPresentationData: NavigationBarPresentationData(
            theme: NavigationBarTheme(
                buttonColor: avatarInitiallyExpanded ? .white : baseNavigationBarPresentationData.theme.buttonColor,
                disabledButtonColor: baseNavigationBarPresentationData.theme.disabledButtonColor,
                primaryTextColor: baseNavigationBarPresentationData.theme.primaryTextColor,
                backgroundColor: .clear,
                enableBackgroundBlur: false,
                separatorColor: .clear,
                badgeBackgroundColor: baseNavigationBarPresentationData.theme.badgeBackgroundColor,
                badgeStrokeColor: baseNavigationBarPresentationData.theme.badgeStrokeColor,
                badgeTextColor: baseNavigationBarPresentationData.theme.badgeTextColor
        ), strings: baseNavigationBarPresentationData.strings))
                
        if isSettings {
            let activeSessionsContextAndCountSignal = deferred { () -> Signal<(ActiveSessionsContext, Int, WebSessionsContext)?, NoError> in
                let activeSessionsContext = context.engine.privacy.activeSessions()
                let webSessionsContext = context.engine.privacy.webSessions()
                let otherSessionCount = activeSessionsContext.state
                |> map { state -> Int in
                    return state.sessions.filter({ !$0.isCurrent }).count
                }
                |> distinctUntilChanged
                return otherSessionCount
                |> map { value in
                    return (activeSessionsContext, value, webSessionsContext)
                }
            }
            self.activeSessionsContextAndCount.set(activeSessionsContextAndCountSignal)
            
            self.accountsAndPeers.set(activeAccountsAndPeers(context: context))
            self.accountsAndPeersDisposable = (self.accountsAndPeers.get()
            |> deliverOnMainQueue).start(next: { [weak self] value in
                self?.accountsAndPeersValue = value
            })
            
            self.tabBarItemContextActionType = .always
            
            let notificationsFromAllAccounts = self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
            |> map { sharedData -> Bool in
                let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) ?? InAppNotificationSettings.defaultSettings
                return settings.displayNotificationsFromAllAccounts
            }
            |> distinctUntilChanged
            
            let accountTabBarAvatarBadge: Signal<Int32, NoError> = combineLatest(notificationsFromAllAccounts, self.accountsAndPeers.get())
            |> map { notificationsFromAllAccounts, primaryAndOther -> Int32 in
                if !notificationsFromAllAccounts {
                    return 0
                }
                let (primary, other) = primaryAndOther
                if let _ = primary, !other.isEmpty {
                    return other.reduce(into: 0, { (result, next) in
                        result += next.2
                    })
                } else {
                    return 0
                }
            }
            |> distinctUntilChanged
            
            let accountTabBarAvatar: Signal<(UIImage, UIImage)?, NoError> = combineLatest(self.accountsAndPeers.get(), context.sharedContext.presentationData)
            |> map { primaryAndOther, presentationData -> (Account, EnginePeer, PresentationTheme)? in
                if let primary = primaryAndOther.0, !primaryAndOther.1.isEmpty {
                    return (primary.0.account, primary.1, presentationData.theme)
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged(isEqual: { $0?.0 === $1?.0 && $0?.1 == $1?.1 && $0?.2 === $1?.2 })
            |> mapToSignal { primary -> Signal<(UIImage, UIImage)?, NoError> in
                if let primary = primary {
                    let size = CGSize(width: 31.0, height: 31.0)
                    let inset: CGFloat = 3.0
                    if let signal = peerAvatarImage(account: primary.0, peerReference: PeerReference(primary.1._asPeer()), authorOfMessage: nil, representation: primary.1.profileImageRepresentations.first, displayDimensions: size, inset: 3.0, emptyColor: nil, synchronousLoad: false) {
                        return signal
                        |> map { imageVersions -> (UIImage, UIImage)? in
                            if let image = imageVersions?.0 {
                                return (image.withRenderingMode(.alwaysOriginal), image.withRenderingMode(.alwaysOriginal))
                            } else {
                                return nil
                            }
                        }
                    } else {
                        return Signal { subscriber in
                            let avatarFont = avatarPlaceholderFont(size: 13.0)
                            var displayLetters = primary.1.displayLetters
                            if displayLetters.count == 2 && displayLetters[0].isSingleEmoji && displayLetters[1].isSingleEmoji {
                                displayLetters = [displayLetters[0]]
                            }
                            let image = generateImage(size, rotatedContext: { size, context in
                                context.clear(CGRect(origin: CGPoint(), size: size))
                                context.translateBy(x: inset, y: inset)
                                
                                drawPeerAvatarLetters(context: context, size: CGSize(width: size.width - inset * 2.0, height: size.height - inset * 2.0), font: avatarFont, letters: displayLetters, peerId: primary.1.id)
                            })?.withRenderingMode(.alwaysOriginal)
                            if let image = image {
                                subscriber.putNext((image, image))
                            } else {
                                subscriber.putNext(nil)
                            }
                            subscriber.putCompletion()
                            return EmptyDisposable
                        }
                        |> runOn(.concurrentDefaultQueue())
                    }
                } else {
                    return .single(nil)
                }
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if let lhs = lhs, let rhs = rhs {
                    if lhs.0 !== rhs.0 || lhs.1 !== rhs.1 {
                        return false
                    } else {
                        return true
                    }
                } else if (lhs == nil) != (rhs == nil) {
                    return false
                }
                return true
            })
            
            let notificationsAuthorizationStatus = Promise<AccessType>(.allowed)
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                notificationsAuthorizationStatus.set(
                    .single(.allowed)
                    |> then(DeviceAccess.authorizationStatus(applicationInForeground: context.sharedContext.applicationBindings.applicationInForeground, subject: .notifications)
                    )
                )
            }
            
            let notificationsWarningSuppressed = Promise<Bool>(true)
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                notificationsWarningSuppressed.set(
                    .single(true)
                    |> then(context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.permissionWarningKey(permission: .notifications)!)
                        |> map { noticeView -> Bool in
                            let timestamp = noticeView.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                            if let timestamp = timestamp, timestamp > 0 {
                                return true
                            } else {
                                return false
                            }
                        }
                    )
                )
            }
            
            let icon: UIImage?
            if useSpecialTabBarIcons() {
                icon = UIImage(bundleImageName: "Chat List/Tabs/Holiday/IconSettings")
            } else {
                icon = UIImage(bundleImageName: "Chat List/Tabs/IconSettings")
            }
            
            let tabBarItem: Signal<(String, UIImage?, UIImage?, String?, Bool, Bool), NoError> = combineLatest(queue: .mainQueue(), self.context.sharedContext.presentationData, notificationsAuthorizationStatus.get(), notificationsWarningSuppressed.get(), getServerProvidedSuggestions(account: self.context.account), accountTabBarAvatar, accountTabBarAvatarBadge)
            |> map { presentationData, notificationsAuthorizationStatus, notificationsWarningSuppressed, suggestions, accountTabBarAvatar, accountTabBarAvatarBadge -> (String, UIImage?, UIImage?, String?, Bool, Bool) in
                let notificationsWarning = shouldDisplayNotificationsPermissionWarning(status: notificationsAuthorizationStatus, suppressed:  notificationsWarningSuppressed)
                let phoneNumberWarning = suggestions.contains(.validatePhoneNumber)
                let passwordWarning = suggestions.contains(.validatePassword)
                var otherAccountsBadge: String?
                if accountTabBarAvatarBadge > 0 {
                    otherAccountsBadge = compactNumericCountString(Int(accountTabBarAvatarBadge), decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                }
                return (presentationData.strings.Settings_Title, accountTabBarAvatar?.0 ?? icon, accountTabBarAvatar?.1 ?? icon, notificationsWarning || phoneNumberWarning || passwordWarning ? "!" : otherAccountsBadge, accountTabBarAvatar != nil, presentationData.reduceMotion)
            }
            
            self.tabBarItemDisposable = (tabBarItem |> deliverOnMainQueue).start(next: { [weak self] title, image, selectedImage, badgeValue, isAvatar, reduceMotion in
                if let strongSelf = self {
                    strongSelf.tabBarItem.title = title
                    strongSelf.tabBarItem.image = image
                    strongSelf.tabBarItem.selectedImage = selectedImage
                    strongSelf.tabBarItem.animationName = isAvatar || reduceMotion ? nil : "TabSettings"
                    strongSelf.tabBarItem.ringSelection = isAvatar
                    strongSelf.tabBarItem.badgeValue = badgeValue
                }
            })
            
            self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        }
                
        self.navigationBar?.makeCustomTransitionNode = { [weak self] other, isInteractive in
            guard let strongSelf = self else {
                return nil
            }
            if strongSelf.navigationItem.leftBarButtonItem != nil {
                return nil
            }
            if other.item?.leftBarButtonItem != nil {
                return nil
            }
            if strongSelf.controllerNode.scrollNode.view.contentOffset.y > .ulpOfOne {
                return nil
            }
            if isInteractive && strongSelf.controllerNode.headerNode.isAvatarExpanded {
                return nil
            }
            if other.contentNode != nil {
                return nil
            }
            if let allowsCustomTransition = other.allowsCustomTransition, !allowsCustomTransition() {
                return nil
            }
            if let tag = other.userInfo as? PeerInfoNavigationSourceTag, tag.peerId == peerId {
                return TestTaskAccountNavigationTransitionNode(screenNode: strongSelf.controllerNode, presentationData: strongSelf.presentationData, headerNode: strongSelf.controllerNode.headerNode)
            }
            return nil
        }
        
        self.setStatusBarStyle(avatarInitiallyExpanded ? .White : self.presentationData.theme.rootController.statusBarStyle.style, animated: false)
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToTop()
        }
        
        let presentationDataSignal: Signal<PresentationData, NoError>
        if let updatedPresentationData = updatedPresentationData {
            presentationDataSignal = updatedPresentationData.signal
        } else if self.peerId != self.context.account.peerId {
            let themeEmoticon: Signal<String?, NoError> = self.cachedDataPromise.get()
            |> map { cachedData -> String? in
                if let cachedData = cachedData as? CachedUserData {
                    return cachedData.themeEmoticon
                } else if let cachedData = cachedData as? CachedGroupData {
                    return cachedData.themeEmoticon
                } else if let cachedData = cachedData as? CachedChannelData {
                    return cachedData.themeEmoticon
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged
            
            presentationDataSignal = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, context.engine.themes.getChatThemes(accountManager: context.sharedContext.accountManager, onlyCached: false), themeEmoticon)
            |> map { presentationData, chatThemes, themeEmoticon -> PresentationData in
                var presentationData = presentationData
                if let themeEmoticon = themeEmoticon, let theme = chatThemes.first(where: { $0.emoticon == themeEmoticon }) {
                    if let theme = makePresentationTheme(cloudTheme: theme, dark: presentationData.theme.overallDarkAppearance) {
                        presentationData = presentationData.withUpdated(theme: theme)
                        presentationData = presentationData.withUpdated(chatWallpaper: theme.chat.defaultWallpaper)
                    }
                }
                return presentationData
            }
        } else {
            presentationDataSignal = context.sharedContext.presentationData
        }
        
        self.presentationDataDisposable = (presentationDataSignal
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.controllerNode.updatePresentationData(strongSelf.presentationData)
                    
                    if strongSelf.navigationItem.backBarButtonItem != nil {
                        strongSelf.navigationItem.backBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
                    }
                }
            }
        })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.accountsAndPeersDisposable?.dispose()
        self.tabBarItemDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = TestTaskAccountScreenNode(controller: self, context: self.context, peerId: self.peerId, avatarInitiallyExpanded: self.avatarInitiallyExpanded, isOpenedFromChat: self.isOpenedFromChat, nearbyPeerDistance: self.nearbyPeerDistance, callMessages: self.callMessages, isSettings: self.isSettings, hintGroupInCommon: self.hintGroupInCommon, requestsContext: requestsContext)
        self.controllerNode.accountsAndPeers.set(self.accountsAndPeers.get() |> map { $0.1 })
        self.controllerNode.activeSessionsContextAndCount.set(self.activeSessionsContextAndCount.get())
        self.cachedDataPromise.set(self.controllerNode.cachedDataPromise.get())
        self._ready.set(self.controllerNode.ready.get())
        
        super.displayNodeDidLoad()
    }
    
    var movingInHierarchy = false
    public override func willMove(toParent viewController: UIViewController?) {
        super.willMove(toParent: parent)
        
        if self.isSettings, viewController == nil, let tabBarController = self.parent as? TabBarController {
            self.movingInHierarchy = true
            tabBarController.updateBackgroundAlpha(1.0, transition: .immediate)
        }
    }
    
    public override func didMove(toParent viewController: UIViewController?) {
        super.didMove(toParent: viewController)
        
        if self.isSettings {
            if viewController == nil {
                self.movingInHierarchy = false
                Queue.mainQueue().after(0.1) {
                    self.controllerNode.resetHeaderExpansion()
                }
            } else {
                self.controllerNode.updateNavigation(transition: .immediate, additive: false)
            }
        }
    }
    
    private func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController, !controller.keepOnParentDismissal {
                controller.dismissWithCommitAction()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController, !controller.keepOnParentDismissal {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }
    
    override public func present(_ controller: ViewController, in context: PresentationContextType, with arguments: Any? = nil, blockInteraction: Bool = false, completion: @escaping () -> Void = {}) {
        self.dismissAllTooltips()
        
        super.present(controller, in: context, with: arguments, blockInteraction: blockInteraction, completion: completion)
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var chatNavigationStack: [PeerId] = []
        if !self.isSettings, let summary = self.customNavigationDataSummary as? ChatControllerNavigationDataSummary {
            chatNavigationStack.removeAll()
            chatNavigationStack = summary.peerIds.filter({ $0 != peerId })
        }
        
        if !chatNavigationStack.isEmpty {
            self.navigationBar?.backButtonNode.isGestureEnabled = true
            self.navigationBar?.backButtonNode.activated = { [weak self] gesture, _ in
                guard let strongSelf = self else {
                    gesture.cancel()
                    return
                }
                
                let _ = (strongSelf.context.engine.data.get(EngineDataList(
                    chatNavigationStack.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                ))
                |> deliverOnMainQueue).start(next: { peerList in
                    guard let strongSelf = self, let backButtonNode = strongSelf.navigationBar?.backButtonNode else {
                        return
                    }
                    let peers = peerList.compactMap { $0 }
                    
                    let avatarSize = CGSize(width: 28.0, height: 28.0)
                    
                    var items: [ContextMenuItem] = []
                    for peer in peers {
                        items.append(.action(ContextMenuActionItem(text: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), icon: { _ in return nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: strongSelf.context.account, peer: peer, size: avatarSize)), action: { _, f in
                            f(.default)
                            
                            guard let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController else {
                                return
                            }

                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peer.id), animated: true, completion: { _ in
                            }))
                        })))
                    }
                    let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .reference(ChatControllerContextReferenceContentSource(controller: strongSelf, sourceView: backButtonNode.view, insets: UIEdgeInsets(), contentInsets: UIEdgeInsets(top: 0.0, left: -15.0, bottom: 0.0, right: -15.0))), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                    strongSelf.presentInGlobalOverlay(contextController)
                })
                
            }
        }
        
 
        
        
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight = self.isSettings ? (self.navigationBar?.frame.height ?? 0.0) : self.navigationLayout(layout: layout).navigationFrame.maxY
        self.validLayout = (layout, navigationHeight)
        
        self.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition)
    }
    
    override public func tabBarItemContextAction(sourceNode: ContextExtractedContentContainingNode, gesture: ContextGesture) {
        guard let (maybePrimary, other) = self.accountsAndPeersValue, let primary = maybePrimary else {
            return
        }
        
        let strings = self.presentationData.strings
        
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: strings.Settings_AddAccount, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] _, f in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.openSettings(section: .addAccount)
            f(.dismissWithoutContent)
        })))
        
        
        let avatarSize = CGSize(width: 28.0, height: 28.0)
        
        items.append(.action(ContextMenuActionItem(text: primary.1.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder), icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: primary.0.account, peer: primary.1, size: avatarSize)), action: { _, f in
            f(.default)
        })))
        
        if !other.isEmpty {
            items.append(.separator)
        }
        
        for account in other {
            let id = account.0.account.id
            items.append(.action(ContextMenuActionItem(text: account.1.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder), badge: account.2 != 0 ? ContextMenuActionBadge(value: "\(account.2)", color: .accent) : nil, icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: account.0.account, peer: account.1, size: avatarSize)), action: { [weak self] _, f in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.controllerNode.switchToAccount(id: id)
                f(.dismissWithoutContent)
            })))
        }
        
        let controller = ContextController(account: primary.0.account, presentationData: self.presentationData, source: .extracted(SettingsTabBarContextExtractedContentSource(controller: self, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
        self.context.sharedContext.mainWindow?.presentInGlobalOverlay(controller)
    }
    
    public var keyShortcuts: [KeyShortcut] {
        if self.isSettings {
            return [
                KeyShortcut(
                    input: "0",
                    modifiers: [.command],
                    action: { [weak self] in
                        self?.controllerNode.openSettings(section: .savedMessages)
                    }
                )
            ]
        } else {
            return [
                KeyShortcut(
                    input: "W",
                    modifiers: [.command],
                    action: { [weak self] in
                        self?.dismiss(animated: true, completion: nil)
                    }
                ),
                KeyShortcut(
                    input: UIKeyCommand.inputEscape,
                    modifiers: [],
                    action: { [weak self] in
                        self?.dismiss(animated: true, completion: nil)
                    }
                )
            ]
        }
    }
}

//MARK: - Private classes
private final class SettingsTabBarContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = true
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let centerActionsHorizontally: Bool = true
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

//MARK: - Private methods
private func getUserPeer(engine: TelegramEngine, peerId: EnginePeer.Id) -> Signal<EnginePeer?, NoError> {
    return engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    |> mapToSignal { peer -> Signal<EnginePeer?, NoError> in
        guard let peer = peer else {
            return .single(nil)
        }
        if case let .secretChat(secretChat) = peer {
            return engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: secretChat.regularPeerId))
        } else {
            return .single(peer)
        }
    }
}




