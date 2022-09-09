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

final class TestTaskAccountNavigationTransitionNode: ASDisplayNode, CustomNavigationTransitionNode {
    private let screenNode: TestTaskAccountScreenNode
    private let presentationData: PresentationData

    private var topNavigationBar: NavigationBar?
    private var bottomNavigationBar: NavigationBar?
    private var reverseFraction: Bool = false
    
    private let headerNode: PeerInfoHeaderNode
    
    private var previousBackButtonArrow: ASDisplayNode?
    private var previousBackButton: ASDisplayNode?
    private var currentBackButtonArrow: ASDisplayNode?
    private var previousBackButtonBadge: ASDisplayNode?
    private var currentBackButton: ASDisplayNode?
    
    private var previousTitleNode: (ASDisplayNode, ASDisplayNode)?
    private var previousStatusNode: (ASDisplayNode, ASDisplayNode)?
    
    private var didSetup: Bool = false
    
    init(screenNode: TestTaskAccountScreenNode, presentationData: PresentationData, headerNode: PeerInfoHeaderNode) {
        self.screenNode = screenNode
        self.presentationData = presentationData
        self.headerNode = headerNode
        
        super.init()
        
        self.addSubnode(headerNode)
    }
    
    func setup(topNavigationBar: NavigationBar, bottomNavigationBar: NavigationBar) {
        if let _ = bottomNavigationBar.userInfo as? PeerInfoNavigationSourceTag {
            self.topNavigationBar = topNavigationBar
            self.bottomNavigationBar = bottomNavigationBar
        } else {
            self.topNavigationBar = bottomNavigationBar
            self.bottomNavigationBar = topNavigationBar
            self.reverseFraction = true
        }
        
        topNavigationBar.isHidden = true
        bottomNavigationBar.isHidden = true
        
        if let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar {
            self.addSubnode(bottomNavigationBar.additionalContentNode)

            if let previousBackButtonArrow = bottomNavigationBar.makeTransitionBackArrowNode(accentColor: self.presentationData.theme.rootController.navigationBar.accentTextColor) {
                self.previousBackButtonArrow = previousBackButtonArrow
                self.addSubnode(previousBackButtonArrow)
            }
            if let previousBackButton = bottomNavigationBar.makeTransitionBackButtonNode(accentColor: self.presentationData.theme.rootController.navigationBar.accentTextColor) {
                self.previousBackButton = previousBackButton
                self.addSubnode(previousBackButton)
            }
            if self.screenNode.headerNode.isAvatarExpanded, let currentBackButtonArrow = topNavigationBar.makeTransitionBackArrowNode(accentColor: self.screenNode.headerNode.isAvatarExpanded ? .white : self.presentationData.theme.rootController.navigationBar.accentTextColor) {
                self.currentBackButtonArrow = currentBackButtonArrow
                self.addSubnode(currentBackButtonArrow)
            }
            if let previousBackButtonBadge = bottomNavigationBar.makeTransitionBadgeNode() {
                self.previousBackButtonBadge = previousBackButtonBadge
                self.addSubnode(previousBackButtonBadge)
            }
            if let currentBackButton = topNavigationBar.makeTransitionBackButtonNode(accentColor: self.screenNode.headerNode.isAvatarExpanded ? .white : self.presentationData.theme.rootController.navigationBar.accentTextColor) {
                self.currentBackButton = currentBackButton
                self.addSubnode(currentBackButton)
            }
            if let previousTitleView = bottomNavigationBar.titleView as? ChatTitleView {
                let previousTitleNode = previousTitleView.titleNode.makeCopy()
                let previousTitleContainerNode = ASDisplayNode()
                previousTitleContainerNode.addSubnode(previousTitleNode)
                previousTitleNode.frame = previousTitleNode.frame.offsetBy(dx: -previousTitleNode.frame.width / 2.0, dy: -previousTitleNode.frame.height / 2.0)
                self.previousTitleNode = (previousTitleContainerNode, previousTitleNode)
                self.addSubnode(previousTitleContainerNode)
                
                let previousStatusNode = previousTitleView.activityNode.makeCopy()
                let previousStatusContainerNode = ASDisplayNode()
                previousStatusContainerNode.addSubnode(previousStatusNode)
                previousStatusNode.frame = previousStatusNode.frame.offsetBy(dx: -previousStatusNode.frame.width / 2.0, dy: -previousStatusNode.frame.height / 2.0)
                self.previousStatusNode = (previousStatusContainerNode, previousStatusNode)
                self.addSubnode(previousStatusContainerNode)
            }
        }
    }
    
    func update(containerSize: CGSize, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar else {
            return
        }
        
        let fraction = self.reverseFraction ? (1.0 - fraction) : fraction
        
        if let previousBackButtonArrow = self.previousBackButtonArrow {
            let previousBackButtonArrowFrame = bottomNavigationBar.backButtonArrow.view.convert(bottomNavigationBar.backButtonArrow.view.bounds, to: bottomNavigationBar.view)
            previousBackButtonArrow.frame = previousBackButtonArrowFrame
        }
        
        if let previousBackButton = self.previousBackButton {
            let previousBackButtonFrame = bottomNavigationBar.backButtonNode.view.convert(bottomNavigationBar.backButtonNode.view.bounds, to: bottomNavigationBar.view)
            previousBackButton.frame = previousBackButtonFrame
            transition.updateAlpha(node: previousBackButton, alpha: fraction)
        }
        
        if let currentBackButtonArrow = self.currentBackButtonArrow {
            let currentBackButtonArrowFrame = topNavigationBar.backButtonArrow.view.convert(topNavigationBar.backButtonArrow.view.bounds, to: topNavigationBar.view)
            currentBackButtonArrow.frame = currentBackButtonArrowFrame
            
            transition.updateAlpha(node: currentBackButtonArrow, alpha: 1.0 - fraction)
            if let previousBackButtonArrow = self.previousBackButtonArrow {
                transition.updateAlpha(node: previousBackButtonArrow, alpha: fraction)
            }
        }
        
        if let previousBackButtonBadge = self.previousBackButtonBadge {
            let previousBackButtonBadgeFrame = bottomNavigationBar.badgeNode.view.convert(bottomNavigationBar.badgeNode.view.bounds, to: bottomNavigationBar.view)
            previousBackButtonBadge.frame = previousBackButtonBadgeFrame
            
            transition.updateAlpha(node: previousBackButtonBadge, alpha: fraction)
        }
        
        if let currentBackButton = self.currentBackButton {
            transition.updateAlpha(node: currentBackButton, alpha: (1.0 - fraction))
        }
        
        if let previousTitleView = bottomNavigationBar.titleView as? ChatTitleView, let _ = (bottomNavigationBar.rightButtonNode.singleCustomNode as? ChatAvatarNavigationNode)?.avatarNode, let (previousTitleContainerNode, previousTitleNode) = self.previousTitleNode, let (previousStatusContainerNode, previousStatusNode) = self.previousStatusNode {
            let previousTitleFrame = previousTitleView.titleNode.view.convert(previousTitleView.titleNode.bounds, to: bottomNavigationBar.view)
            let previousStatusFrame = previousTitleView.activityNode.view.convert(previousTitleView.activityNode.bounds, to: bottomNavigationBar.view)
            
            self.headerNode.navigationTransition = PeerInfoHeaderNavigationTransition(sourceNavigationBar: bottomNavigationBar, sourceTitleView: previousTitleView, sourceTitleFrame: previousTitleFrame, sourceSubtitleFrame: previousStatusFrame, fraction: fraction)
            var topHeight = topNavigationBar.backgroundNode.bounds.height
            
            if let (layout, _) = self.screenNode.validLayout {
                let sectionInset: CGFloat
                if layout.size.width >= 375.0 {
                    sectionInset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
                } else {
                    sectionInset = 0.0
                }
                let headerInset = sectionInset
                
                topHeight = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: headerInset, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: topNavigationBar.bounds.height, isModalOverlay: layout.isModalOverlay, isMediaOnly: false, contentOffset: 0.0, paneContainerY: 0.0, presentationData: self.presentationData, peer: self.screenNode.data?.peer, cachedData: self.screenNode.data?.cachedData, notificationSettings: self.screenNode.data?.notificationSettings, statusData: self.screenNode.data?.status, panelStatusData: (nil, nil, nil), isSecretChat: self.screenNode.peerId.namespace == Namespaces.Peer.SecretChat, isContact: self.screenNode.data?.isContact ?? false, isSettings: self.screenNode.isSettings, state: self.screenNode.state, metrics: layout.metrics, transition: transition, additive: false)
            }
            
            let titleScale = (fraction * previousTitleNode.bounds.height + (1.0 - fraction) * self.headerNode.titleNodeRawContainer.bounds.height) / previousTitleNode.bounds.height
            let subtitleScale = max(0.01, min(10.0, (fraction * previousStatusNode.bounds.height + (1.0 - fraction) * self.headerNode.subtitleNodeRawContainer.bounds.height) / previousStatusNode.bounds.height))
            
            transition.updateFrame(node: previousTitleContainerNode, frame: CGRect(origin: self.headerNode.titleNodeRawContainer.frame.center, size: CGSize()))
            transition.updateFrame(node: previousTitleNode, frame: CGRect(origin: CGPoint(x: -previousTitleFrame.width / 2.0, y: -previousTitleFrame.height / 2.0), size: previousTitleFrame.size))
            transition.updateFrame(node: previousStatusContainerNode, frame: CGRect(origin: self.headerNode.subtitleNodeRawContainer.frame.center, size: CGSize()))
            transition.updateFrame(node: previousStatusNode, frame: CGRect(origin: CGPoint(x: -previousStatusFrame.size.width / 2.0, y: -previousStatusFrame.size.height / 2.0), size: previousStatusFrame.size))
            
            transition.updateSublayerTransformScale(node: previousTitleContainerNode, scale: titleScale)
            transition.updateSublayerTransformScale(node: previousStatusContainerNode, scale: subtitleScale)
            
            transition.updateAlpha(node: self.headerNode.titleNode, alpha: (1.0 - fraction))
            transition.updateAlpha(node: previousTitleNode, alpha: fraction)
            transition.updateAlpha(node: self.headerNode.subtitleNode, alpha: (1.0 - fraction))
            transition.updateAlpha(node: previousStatusNode, alpha: fraction)
            
            transition.updateAlpha(node: self.headerNode.navigationButtonContainer, alpha: (1.0 - fraction))

            if case .animated = transition, (bottomNavigationBar.additionalContentNode.alpha.isZero || bottomNavigationBar.additionalContentNode.alpha == 1.0) {
                bottomNavigationBar.additionalContentNode.alpha = fraction
                if fraction.isZero {
                    bottomNavigationBar.additionalContentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                } else {
                    transition.updateAlpha(node: bottomNavigationBar.additionalContentNode, alpha: fraction)
                }
            } else {
                transition.updateAlpha(node: bottomNavigationBar.additionalContentNode, alpha: fraction)
            }

            let bottomHeight = bottomNavigationBar.backgroundNode.bounds.height

            transition.updateSublayerTransformOffset(layer: bottomNavigationBar.additionalContentNode.layer, offset: CGPoint(x: 0.0, y: (1.0 - fraction) * (topHeight - bottomHeight)))
        }
    }
    
    func restore() {
        guard let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar else {
            return
        }

        topNavigationBar.additionalContentNode.alpha = 1.0
        ContainedViewLayoutTransition.immediate.updateSublayerTransformOffset(layer: topNavigationBar.additionalContentNode.layer, offset: CGPoint())
        topNavigationBar.reattachAdditionalContentNode()

        bottomNavigationBar.additionalContentNode.alpha = 1.0
        ContainedViewLayoutTransition.immediate.updateSublayerTransformOffset(layer: bottomNavigationBar.additionalContentNode.layer, offset: CGPoint())
        bottomNavigationBar.reattachAdditionalContentNode()
        
        topNavigationBar.isHidden = false
        bottomNavigationBar.isHidden = false
        self.headerNode.navigationTransition = nil
        self.screenNode.insertSubnode(self.headerNode, aboveSubnode: self.screenNode.scrollNode)
    }
}
