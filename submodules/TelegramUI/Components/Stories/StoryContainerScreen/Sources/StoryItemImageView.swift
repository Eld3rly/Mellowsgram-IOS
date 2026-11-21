import Foundation
import UIKit
import AccountContext
import TelegramCore
import SwiftSignalKit
import ComponentFlow
import TinyThumbnail
import ImageBlur
import MediaResources
import Display
import TelegramPresentationData
import UIKitRuntimeUtils

final class StoryItemImageView: UIView {
    private let contentView: UIImageView
    
    private var currentMedia: EngineMedia?
    private var disposable: Disposable?
    private var fetchDisposable: Disposable?
    private var mellowsgramScreenshotProtectionObserver: NSObjectProtocol?
    private var isCaptureProtected = false
    
    private(set) var isContentLoaded: Bool = false
    var didLoadContents: (() -> Void)?
    
    override init(frame: CGRect) {
        self.contentView = UIImageView()
        self.contentView.contentMode = .scaleAspectFill
        
        super.init(frame: frame)

        self.mellowsgramScreenshotProtectionObserver = NotificationCenter.default.addObserver(forName: Notification.Name("MellowsgramScreenshotProtectionDidChange"), object: nil, queue: .main, using: { [weak self] _ in
            guard let self else {
                return
            }
            setLayerDisableScreenshots(self.contentView.layer, self.isCaptureProtected)
            self.backgroundColor = self.isCaptureProtected && getMellowsgramScreenshotProtectionEnabled() ? UIColor(rgb: 0x181818) : nil
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable?.dispose()
        if let observer = self.mellowsgramScreenshotProtectionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func updateImage(image: UIImage, isCaptureProtected: Bool = false) {
        self.contentView.image = image
        setLayerDisableScreenshots(self.contentView.layer, isCaptureProtected)

        if self.contentView.layer.superlayer !== self.layer {
            self.layer.addSublayer(self.contentView.layer)
        }
    }
    
    func update(context: AccountContext, strings: PresentationStrings, peer: EnginePeer, storyId: Int32, media: EngineMedia, size: CGSize, isCaptureProtected: Bool, attemptSynchronous: Bool, transition: ComponentTransition) {
        // The global Mellowsgram setting decides whether the upstream capture
        // protection request is honoured. Keep the parameter for the upstream
        // story renderer, but do not add a separate overlay of our own.
        _ = strings
        self.isCaptureProtected = isCaptureProtected
        self.backgroundColor = isCaptureProtected && getMellowsgramScreenshotProtectionEnabled() ? UIColor(rgb: 0x181818) : nil
        
        var dimensions: CGSize?
        
        let isMediaUpdated: Bool
        if let currentMedia = self.currentMedia {
            isMediaUpdated = !currentMedia._asMedia().isSemanticallyEqual(to: media._asMedia())
        } else {
            isMediaUpdated = true
        }
        
        switch media {
        case let .image(image):
            if let representation = largestImageRepresentation(image.representations) {
                dimensions = representation.dimensions.cgSize
                
                if isMediaUpdated {
                    if attemptSynchronous, let path = context.engine.resources.completedResourcePath(id: EngineMediaResource.Id(representation.resource.id), pathExtension: nil) {
                        if #available(iOS 15.0, *) {
                            if let image = UIImage(contentsOfFile: path)?.preparingForDisplay() {
                                self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                            }
                        } else {
                            if let image = UIImage(contentsOfFile: path)?.precomposed() {
                                self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                            }
                        }
                        self.isContentLoaded = true
                        self.didLoadContents?()
                    } else {
                        if let thumbnailData = image.immediateThumbnailData.flatMap(decodeTinyThumbnail), let thumbnailImage = UIImage(data: thumbnailData) {
                            if let image = blurredImage(thumbnailImage, radius: 10.0, iterations: 3) {
                                self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                            }
                        }
                        
                        if let peerReference = PeerReference(peer) {
                            self.fetchDisposable = context.engine.resources.fetch(reference: .media(media: .story(peer: peerReference, id: storyId, media: media._asMedia()), resource: representation.resource), userLocation: .peer(peer.id), userContentType: .story, ranges: nil).start()
                        }
                        self.disposable = (context.engine.resources.data(resource: EngineMediaResource(representation.resource))
                        |> map { result -> UIImage? in
                            if result.isComplete {
                                if #available(iOS 15.0, *) {
                                    if let image = UIImage(contentsOfFile: result.path)?.preparingForDisplay() {
                                        return image
                                    } else {
                                        return nil
                                    }
                                } else {
                                    if let image = UIImage(contentsOfFile: result.path)?.precomposed() {
                                        return image
                                    } else {
                                        return nil
                                    }
                                }
                            } else {
                                return nil
                            }
                        }
                        |> deliverOnMainQueue).start(next: { [weak self] image in
                            guard let self else {
                                return
                            }
                            if let image {
                                self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                                self.isContentLoaded = true
                                self.didLoadContents?()
                            }
                        })
                    }
                }
            }
        case let .file(file):
            dimensions = file.dimensions?.cgSize
            
            if isMediaUpdated {
                let cachedPath = context.engine.resources.cachedRepresentationCompletePath(id: EngineMediaResource.Id(file.resource.id), representation: CachedVideoFirstFrameRepresentation())
                
                if attemptSynchronous, FileManager.default.fileExists(atPath: cachedPath) {
                    if #available(iOS 15.0, *) {
                        if let image = UIImage(contentsOfFile: cachedPath)?.preparingForDisplay() {
                            self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                        }
                    } else {
                        if let image = UIImage(contentsOfFile: cachedPath)?.precomposed() {
                            self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                        }
                    }
                    self.isContentLoaded = true
                    self.didLoadContents?()
                } else {
                    if let thumbnailData = file.immediateThumbnailData.flatMap(decodeTinyThumbnail), let thumbnailImage = UIImage(data: thumbnailData) {
                        if let image = blurredImage(thumbnailImage, radius: 10.0, iterations: 3) {
                            self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                        }
                    }
                    
                    let fullSize = context.engine.resources.cachedRepresentation(resource: EngineMediaResource(file.resource), representation: CachedVideoFirstFrameRepresentation(), complete: true, fetch: true, attemptSynchronously: false)
                    var previewSize: Signal<EngineMediaResource.ResourceData?, NoError> = .single(nil)
                    if let representation = file.previewRepresentations.first {
                        previewSize = context.engine.resources.data(resource: EngineMediaResource(representation.resource))
                        |> map(Optional.init)
                    }
                    
                    self.disposable = (combineLatest(
                        fullSize,
                        previewSize
                    )
                    |> map { result, previewResult -> UIImage? in
                        if result.isComplete {
                            if #available(iOS 15.0, *) {
                                if let image = UIImage(contentsOfFile: result.path)?.preparingForDisplay() {
                                    return image
                                } else {
                                    return nil
                                }
                            } else {
                                if let image = UIImage(contentsOfFile: result.path)?.precomposed() {
                                    return image
                                } else {
                                    return nil
                                }
                            }
                        } else if let previewResult, previewResult.isComplete {
                            if #available(iOS 15.0, *) {
                                if let image = UIImage(contentsOfFile: previewResult.path)?.preparingForDisplay() {
                                    return image
                                } else {
                                    return nil
                                }
                            } else {
                                if let image = UIImage(contentsOfFile: previewResult.path)?.precomposed() {
                                    return image
                                } else {
                                    return nil
                                }
                            }
                        } else {
                            return nil
                        }
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] image in
                        guard let self else {
                            return
                        }
                        if let image {
                            self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                            self.isContentLoaded = true
                            self.didLoadContents?()
                        }
                    })
                }
            }
        case .liveStream:
            dimensions = CGSize(width: 128.0, height: 128.0)
            if isMediaUpdated, let thumbnailData = peer.smallProfileImage?.immediateThumbnailData {
                if let thumbnailData = decodeTinyThumbnail(data: thumbnailData), let thumbnailImage = UIImage(data: thumbnailData) {
                    if let image = blurredImage(thumbnailImage, radius: 10.0, iterations: 3) {
                        self.updateImage(image: image, isCaptureProtected: isCaptureProtected)
                    }
                }
            }
        default:
            break
        }
        self.currentMedia = media
        
        if let dimensions {
            let filledSize = dimensions.aspectFilled(size)
            let contentFrame = CGRect(origin: CGPoint(x: floor((size.width - filledSize.width) * 0.5), y: floor((size.height - filledSize.height) * 0.5)), size: filledSize)
            
            transition.setFrame(view: self.contentView, frame: contentFrame)
        }
    }
}
