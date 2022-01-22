import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import StickerResources
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ContextUI
import SoftwareVideo

public final class StickerPreviewPeekContent: PeekControllerContent {
    let account: Account
    public let item: ImportStickerPack.Sticker
    let menu: [ContextMenuItem]
    
    public init(account: Account, item: ImportStickerPack.Sticker, menu: [ContextMenuItem]) {
        self.account = account
        self.item = item
        self.menu = menu
    }
    
    public func presentation() -> PeekControllerContentPresentation {
        return .freeform
    }
    
    public func menuActivation() -> PeerControllerMenuActivation {
        return .press
    }
    
    public func menuItems() -> [ContextMenuItem] {
        return self.menu
    }
    
    public func node() -> PeekControllerContentNode & ASDisplayNode {
        return StickerPreviewPeekContentNode(account: self.account, item: self.item)
    }
    
    public func topAccessoryNode() -> ASDisplayNode? {
        return nil
    }
    
    public func isEqual(to: PeekControllerContent) -> Bool {
        if let to = to as? StickerPreviewPeekContent {
            return self.item === to.item
        } else {
            return false
        }
    }
}

private final class StickerPreviewPeekContentNode: ASDisplayNode, PeekControllerContentNode {
    private let account: Account
    private let item: ImportStickerPack.Sticker
    
    private var textNode: ASTextNode
    private var imageNode: ASImageNode
    private var animationNode: AnimatedStickerNode?
    private var videoNode: VideoStickerNode?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    init(account: Account, item: ImportStickerPack.Sticker) {
        self.account = account
        self.item = item
        
        self.textNode = ASTextNode()
        self.imageNode = ASImageNode()
        self.imageNode.displaysAsynchronously = false
        switch item.content {
            case let .image(data):
                self.imageNode.image = UIImage(data: data)
            case .animation:
                let animationNode = AnimatedStickerNode()
                self.animationNode = animationNode
                let dimensions = PixelDimensions(width: 512, height: 512)
                let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 400.0, height: 400.0))
                if let resource = item.resource {
                    self.animationNode?.setup(source: AnimatedStickerResourceSource(account: account, resource: resource), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), mode: .direct(cachePathPrefix: nil))
                }
                self.animationNode?.visibility = true
            case .video:
                let videoNode = VideoStickerNode()
                self.videoNode = videoNode
                
                if let resource = item.resource as? TelegramMediaResource {
                    let dummyFile = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 1), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/webm", size: resource.size ?? 1, attributes: [.Video(duration: 1, size: PixelDimensions(width: 100, height: 100), flags: [])])
                    
                    videoNode.update(account: account, fileReference: .standalone(media: dummyFile))
                }
                videoNode.update(isPlaying: true)
        }
        if case let .image(data) = item.content, let image = UIImage(data: data) {
            self.imageNode.image = image
        }
        self.textNode.attributedText = NSAttributedString(string: item.emojis.joined(separator: " "), font: Font.regular(32.0), textColor: .black)
                
        super.init()
        
        self.isUserInteractionEnabled = false
        
        if let videoNode = self.videoNode {
            self.addSubnode(videoNode)
        } else if let animationNode = self.animationNode {
            self.addSubnode(animationNode)
        } else {
            self.addSubnode(self.imageNode)
        }
        
        self.addSubnode(self.textNode)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let boundingSize = CGSize(width: 180.0, height: 180.0).fitted(size)
        let imageFrame = CGRect(origin: CGPoint(), size: boundingSize)
            
        let textSpacing: CGFloat = 10.0
        let textSize = self.textNode.measure(CGSize(width: 100.0, height: 100.0))
        self.textNode.frame = CGRect(origin: CGPoint(x: floor((imageFrame.size.width - textSize.width) / 2.0), y: -textSize.height - textSpacing), size: textSize)
        
        self.imageNode.frame = imageFrame
        
        if let videoNode = self.videoNode {
            videoNode.frame = imageFrame
            videoNode.updateLayout(size: imageFrame.size)
        } else if let animationNode = self.animationNode {
            animationNode.frame = imageFrame
            animationNode.updateLayout(size: imageFrame.size)
        }
        return boundingSize
    }
}
