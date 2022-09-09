import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import TelegramNotices
import ChatListSearchItemHeader
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AppBundle
import Postbox

enum TestTaskAccountBotCommand {
    case settings
    case help
    case privacy
}

enum TestTaskAccountParticipantsSection {
    case members
    case admins
    case banned
    case memberRequests
}

enum TestTaskAccountMemberAction {
    case promote
    case restrict
    case remove
}

enum TestTaskAccountContextSubject {
    case bio
    case phone(String)
    case link
}

enum TestTaskAccountSettingsSection {
    case avatar
    case edit
    case proxy
    case savedMessages
    case recentCalls
    case devices
    case chatFolders
    case notificationsAndSounds
    case privacyAndSecurity
    case dataAndStorage
    case appearance
    case language
    case stickers
    case premium
    case passport
    case watch
    case support
    case faq
    case tips
    case phoneNumber
    case username
    case addAccount
    case logout
    case rememberPassword
}

final class TestTaskAccountInteraction {
    let openChat: () -> Void
    let openUsername: (String) -> Void
    let openPhone: (String) -> Void
    let editingOpenNotificationSettings: () -> Void
    let editingOpenSoundSettings: () -> Void
    let editingToggleShowMessageText: (Bool) -> Void
    let requestDeleteContact: () -> Void
    let openAddContact: () -> Void
    let updateBlocked: (Bool) -> Void
    let openReport: (Bool) -> Void
    let openShareBot: () -> Void
    let openAddBotToGroup: () -> Void
    let performBotCommand: (TestTaskAccountBotCommand) -> Void
    let editingOpenPublicLinkSetup: () -> Void
    let editingOpenInviteLinksSetup: () -> Void
    let editingOpenDiscussionGroupSetup: () -> Void
    let editingToggleMessageSignatures: (Bool) -> Void
    let openParticipantsSection: (TestTaskAccountParticipantsSection) -> Void
    let editingOpenPreHistorySetup: () -> Void
    let editingOpenAutoremoveMesages: () -> Void
    let openPermissions: () -> Void
    let editingOpenStickerPackSetup: () -> Void
    let openLocation: () -> Void
    let editingOpenSetupLocation: () -> Void
    let openTestTaskAccount: (Peer, Bool) -> Void
    let performMemberAction: (PeerInfoMember, TestTaskAccountMemberAction) -> Void
    let openTestTaskAccountContextMenu: (TestTaskAccountContextSubject, ASDisplayNode) -> Void
    let performBioLinkAction: (TextLinkItemActionType, TextLinkItem) -> Void
    let requestLayout: (Bool) -> Void
    let openEncryptionKey: () -> Void
    let openSettings: (TestTaskAccountSettingsSection) -> Void
    let openPaymentMethod: () -> Void
    let switchToAccount: (AccountRecordId) -> Void
    let logoutAccount: (AccountRecordId) -> Void
    let accountContextMenu: (AccountRecordId, ASDisplayNode, ContextGesture?) -> Void
    let updateBio: (String) -> Void
    let openDeletePeer: () -> Void
    let openFaq: (String?) -> Void
    let openAddMember: () -> Void
    let openQrCode: () -> Void
    let editingOpenReactionsSetup: () -> Void
    let dismissInput: () -> Void
    
    init(
        openUsername: @escaping (String) -> Void,
        openPhone: @escaping (String) -> Void,
        editingOpenNotificationSettings: @escaping () -> Void,
        editingOpenSoundSettings: @escaping () -> Void,
        editingToggleShowMessageText: @escaping (Bool) -> Void,
        requestDeleteContact: @escaping () -> Void,
        openChat: @escaping () -> Void,
        openAddContact: @escaping () -> Void,
        updateBlocked: @escaping (Bool) -> Void,
        openReport: @escaping (Bool) -> Void,
        openShareBot: @escaping () -> Void,
        openAddBotToGroup: @escaping () -> Void,
        performBotCommand: @escaping (TestTaskAccountBotCommand) -> Void,
        editingOpenPublicLinkSetup: @escaping () -> Void,
        editingOpenInviteLinksSetup: @escaping () -> Void,
        editingOpenDiscussionGroupSetup: @escaping () -> Void,
        editingToggleMessageSignatures: @escaping (Bool) -> Void,
        openParticipantsSection: @escaping (TestTaskAccountParticipantsSection) -> Void,
        editingOpenPreHistorySetup: @escaping () -> Void,
        editingOpenAutoremoveMesages: @escaping () -> Void,
        openPermissions: @escaping () -> Void,
        editingOpenStickerPackSetup: @escaping () -> Void,
        openLocation: @escaping () -> Void,
        editingOpenSetupLocation: @escaping () -> Void,
        openTestTaskAccount: @escaping (Peer, Bool) -> Void,
        performMemberAction: @escaping (PeerInfoMember, TestTaskAccountMemberAction) -> Void,
        openTestTaskAccountContextMenu: @escaping (TestTaskAccountContextSubject, ASDisplayNode) -> Void,
        performBioLinkAction: @escaping (TextLinkItemActionType, TextLinkItem) -> Void,
        requestLayout: @escaping (Bool) -> Void,
        openEncryptionKey: @escaping () -> Void,
        openSettings: @escaping (TestTaskAccountSettingsSection) -> Void,
        openPaymentMethod: @escaping () -> Void,
        switchToAccount: @escaping (AccountRecordId) -> Void,
        logoutAccount: @escaping (AccountRecordId) -> Void,
        accountContextMenu: @escaping (AccountRecordId, ASDisplayNode, ContextGesture?) -> Void,
        updateBio: @escaping (String) -> Void,
        openDeletePeer: @escaping () -> Void,
        openFaq: @escaping (String?) -> Void,
        openAddMember: @escaping () -> Void,
        openQrCode: @escaping () -> Void,
        editingOpenReactionsSetup: @escaping () -> Void,
        dismissInput: @escaping () -> Void
    ) {
        self.openUsername = openUsername
        self.openPhone = openPhone
        self.editingOpenNotificationSettings = editingOpenNotificationSettings
        self.editingOpenSoundSettings = editingOpenSoundSettings
        self.editingToggleShowMessageText = editingToggleShowMessageText
        self.requestDeleteContact = requestDeleteContact
        self.openChat = openChat
        self.openAddContact = openAddContact
        self.updateBlocked = updateBlocked
        self.openReport = openReport
        self.openShareBot = openShareBot
        self.openAddBotToGroup = openAddBotToGroup
        self.performBotCommand = performBotCommand
        self.editingOpenPublicLinkSetup = editingOpenPublicLinkSetup
        self.editingOpenInviteLinksSetup = editingOpenInviteLinksSetup
        self.editingOpenDiscussionGroupSetup = editingOpenDiscussionGroupSetup
        self.editingToggleMessageSignatures = editingToggleMessageSignatures
        self.openParticipantsSection = openParticipantsSection
        self.editingOpenPreHistorySetup = editingOpenPreHistorySetup
        self.editingOpenAutoremoveMesages = editingOpenAutoremoveMesages
        self.openPermissions = openPermissions
        self.editingOpenStickerPackSetup = editingOpenStickerPackSetup
        self.openLocation = openLocation
        self.editingOpenSetupLocation = editingOpenSetupLocation
        self.openTestTaskAccount = openTestTaskAccount
        self.performMemberAction = performMemberAction
        self.openTestTaskAccountContextMenu = openTestTaskAccountContextMenu
        self.performBioLinkAction = performBioLinkAction
        self.requestLayout = requestLayout
        self.openEncryptionKey = openEncryptionKey
        self.openSettings = openSettings
        self.openPaymentMethod = openPaymentMethod
        self.switchToAccount = switchToAccount
        self.logoutAccount = logoutAccount
        self.accountContextMenu = accountContextMenu
        self.updateBio = updateBio
        self.openDeletePeer = openDeletePeer
        self.openFaq = openFaq
        self.openAddMember = openAddMember
        self.openQrCode = openQrCode
        self.editingOpenReactionsSetup = editingOpenReactionsSetup
        self.dismissInput = dismissInput
    }
}
