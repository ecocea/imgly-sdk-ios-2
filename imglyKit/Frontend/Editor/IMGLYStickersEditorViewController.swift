//
//  IMGLYStickersEditorViewController.swift
//  imglyKit
//
//  Created by Sascha Schwabbauer on 10/04/15.
//  Copyright (c) 2015 9elements GmbH. All rights reserved.
//

import UIKit
import Gifu

let StickersCollectionViewCellSize = CGSize(width: 90, height: 90)
let StickersCollectionViewCellReuseIdentifier = "StickersCollectionViewCell"

open class IMGLYStickersEditorViewController: IMGLYSubEditorViewController {

    // MARK: - Properties
    
    open var stickersDataSource = IMGLYStickersDataSource()
    open fileprivate(set) lazy var stickersClipView: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        return view
        }()
    
    open fileprivate(set) lazy var stickerSelectorContainerView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: blurEffect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentView.layer.borderColor = UIColor.white.cgColor
        view.contentView.layer.borderWidth = 1.5
        return view
    }()
    
    open fileprivate(set) lazy var titleContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 36.0/255, green: 36.0/255, blue: 36.0/255, alpha: 1.0)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        view.addSubview(closeButton)
        let views: [String : AnyObject] = ["titleLabel" : titleLabel,
                                           "closeButton" : closeButton]
        let metrics: [String : AnyObject] = [
            "btnHeight" : 35 as AnyObject
        ]
       
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[titleLabel]-|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[titleLabel]-|", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "[closeButton(==btnHeight)]-|", options: [], metrics: metrics, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[closeButton]-|", options: [], metrics: metrics, views: views))
        return view
    }()
    
    open fileprivate(set) lazy var titleLabel: UILabel = {
        let label = UILabel()
        let bundle = Bundle(for: type(of: self))
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.textColor = UIColor.white
        label.text = NSLocalizedString("stickers-editor.title", tableName: nil, bundle: bundle, value: "", comment: "")
        return label
        }()
    
    open fileprivate(set) lazy var closeButton: UIButton = {
        let bundle = Bundle(for: type(of: self))
        let button = UIButton()
        button.contentHorizontalAlignment = .center
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(IMGLYStickersEditorViewController.closeBtn(_:)), for: .touchUpInside)
        return button
        }()
 
    
    fileprivate var draggedView: UIView?
    fileprivate var tempStickerCopy = [CIFilter]()
    
    // MARK: - SubEditorViewController
    
    open override func tappedDone(_ sender: UIBarButtonItem?) {
        var addedStickers = false
        
        for view in stickersClipView.subviews {
            if let view = view as? IMGLYGIFImageView {
                if let image = view.image {
                    let stickerFilter = IMGLYInstanceFactory.stickerFilter()
                    let sticker = view.sticker
                    sticker?.resultImage = image
                    stickerFilter.sticker = sticker
                    let center = CGPoint(x: view.center.x / stickersClipView.frame.size.width,
                                         y: view.center.y / stickersClipView.frame.size.height)
                    
                    var size = initialSizeForStickerImage(image)
                    size.width = size.width / stickersClipView.bounds.size.width
                    size.height = size.height / stickersClipView.bounds.size.height
                    stickerFilter.center = center
                    stickerFilter.scale = size.width
                    stickerFilter.transform = view.transform
                    fixedFilterStack.stickerFilters.append(stickerFilter)
                    addedStickers = true
                }
            }
        }
        
        if addedStickers {
            updatePreviewImageWithCompletion {
                self.stickersClipView.removeFromSuperview()
                super.tappedDone(sender)
            }
        } else {
            super.tappedDone(sender)
        }
    }
    
    // MARK: - Helpers
    
    fileprivate func initialSizeForStickerImage(_ image: UIImage) -> CGSize {
        let initialMaxStickerSize = stickersClipView.bounds.width * 0.3
        let widthRatio = initialMaxStickerSize / image.size.width
        let heightRatio = initialMaxStickerSize / image.size.height
        let scale = min(widthRatio, heightRatio)
        
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }
    
    // MARK: - UIViewController
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        let bundle = Bundle(for: type(of: self))
        navigationItem.title = NSLocalizedString("stickers-editor.title", tableName: nil, bundle: bundle, value: "", comment: "")
        
        configureStickersClipView()
        configureGestureRecognizers()
        configureStickersCollectionView()
        backupStickers()
        fixedFilterStack.stickerFilters.removeAll()
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        rerenderPreviewWithoutStickers()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        stickersClipView.frame = view.convert(previewImageView.visibleImageFrame, from: previewImageView)
    }
    
    // MARK: - Configuration
    
    fileprivate func configureStickersCollectionView() {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.itemSize = StickersCollectionViewCellSize
        flowLayout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = 10
        
        let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: flowLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = stickersDataSource
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.register(IMGLYStickerCollectionViewCell.self, forCellWithReuseIdentifier: StickersCollectionViewCellReuseIdentifier)
        view.addSubview(stickerSelectorContainerView)
        stickerSelectorContainerView.contentView.addSubview(collectionView)
        stickerSelectorContainerView.contentView.addSubview(titleContainerView)
        
        let views: [String : AnyObject] = ["collectionView" : collectionView,
                                           "stickerSelectorContainerView" : stickerSelectorContainerView,
                                           "titleContainerView" : titleContainerView]
        
        let metrics: [String : AnyObject] = [
            "margin" : 40 as AnyObject,
            "titleHeight" : 35 as AnyObject,
        ]
        
        stickerSelectorContainerView.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[collectionView]|", options: [], metrics: metrics, views: views))
        stickerSelectorContainerView.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[titleContainerView]|", options: [], metrics: metrics, views: views))
        stickerSelectorContainerView.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[collectionView]-[titleContainerView(==titleHeight)]|", options: [], metrics: metrics, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-(==margin)-[stickerSelectorContainerView]-(==margin)-|", options: [], metrics: metrics, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(==margin)-[stickerSelectorContainerView]-(==margin)-|", options: [], metrics: metrics, views: views))
    }
    
    fileprivate func configureStickersClipView() {
        view.addSubview(stickersClipView)
    }
    
    fileprivate func configureGestureRecognizers() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(IMGLYStickersEditorViewController.panned(_:)))
        panGestureRecognizer.minimumNumberOfTouches = 1
        panGestureRecognizer.maximumNumberOfTouches = 1
        stickersClipView.addGestureRecognizer(panGestureRecognizer)
        
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(IMGLYStickersEditorViewController.pinched(_:)))
        pinchGestureRecognizer.delegate = self
        stickersClipView.addGestureRecognizer(pinchGestureRecognizer)
        
        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(IMGLYStickersEditorViewController.rotated(_:)))
        rotationGestureRecognizer.delegate = self
        stickersClipView.addGestureRecognizer(rotationGestureRecognizer)
    }
    
    // MARK: - Gesture Handling
    
    @objc fileprivate func panned(_ recognizer: UIPanGestureRecognizer) {
        let location = recognizer.location(in: stickersClipView)
        let translation = recognizer.translation(in: stickersClipView)
        
        switch recognizer.state {
        case .began:
            draggedView = stickersClipView.hitTest(location, with: nil) as? UIImageView
            if let draggedView = draggedView {
                stickersClipView.bringSubviewToFront(draggedView)
            }
        case .changed:
            if let draggedView = draggedView {
                draggedView.center = CGPoint(x: draggedView.center.x + translation.x, y: draggedView.center.y + translation.y)
            }
            
            recognizer.setTranslation(CGPoint.zero, in: stickersClipView)
        case .cancelled, .ended:
            draggedView = nil
        default:
            break
        }
    }
    
    @objc fileprivate func pinched(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.numberOfTouches == 2 {
            let point1 = recognizer.location(ofTouch: 0, in: stickersClipView)
            let point2 = recognizer.location(ofTouch: 1, in: stickersClipView)
            let midpoint = CGPoint(x:(point1.x + point2.x) / 2, y: (point1.y + point2.y) / 2)
            let scale = recognizer.scale
            
            switch recognizer.state {
            case .began:
                if draggedView == nil {
                    draggedView = stickersClipView.hitTest(midpoint, with: nil) as? UIImageView
                }
                
                if let draggedView = draggedView {
                    stickersClipView.bringSubviewToFront(draggedView)
                }
            case .changed:
                if let draggedView = draggedView {
                    draggedView.transform = draggedView.transform.scaledBy(x: scale, y: scale)
                }
                
                recognizer.scale = 1
            case .cancelled, .ended:
                draggedView = nil
            default:
                break
            }
        }
    }
    
    @objc fileprivate func rotated(_ recognizer: UIRotationGestureRecognizer) {
        if recognizer.numberOfTouches == 2 {
            let point1 = recognizer.location(ofTouch: 0, in: stickersClipView)
            let point2 = recognizer.location(ofTouch: 1, in: stickersClipView)
            let midpoint = CGPoint(x:(point1.x + point2.x) / 2, y: (point1.y + point2.y) / 2)
            let rotation = recognizer.rotation
            
            switch recognizer.state {
            case .began:
                if draggedView == nil {
                    draggedView = stickersClipView.hitTest(midpoint, with: nil) as? UIImageView
                }
                
                if let draggedView = draggedView {
                    stickersClipView.bringSubviewToFront(draggedView)
                }
            case .changed:
                if let draggedView = draggedView {
                    draggedView.transform = draggedView.transform.rotated(by: rotation)
                }
                
                recognizer.rotation = 0
            case .cancelled, .ended:
                draggedView = nil
            default:
                break
            }
        }
    }
    
    @objc open func closeBtn(_ sender: UIButton?) {
        stickerSelectorContainerView.removeFromSuperview()
    }
    
    // MARK: - sticker object restore
    
    fileprivate func rerenderPreviewWithoutStickers() {
        updatePreviewImageWithCompletion { () -> (Void) in
            self.addStickerImagesFromStickerFilters(self.tempStickerCopy)
        }
    }
    
    fileprivate func addStickerImagesFromStickerFilters(_ stickerFilters: [CIFilter]) {
        for element in stickerFilters {
            guard let stickerFilter = element as? IMGLYStickerFilter, let sticker = stickerFilter.sticker else {
                return
            }
       
            let imageView = createImageView(sticker: sticker)
            imageView.isUserInteractionEnabled = true
            
            let size = stickerFilter.absolutStickerSizeForImageSize(stickersClipView.bounds.size)
            imageView.frame.size = size
            
            let center = CGPoint(x: stickerFilter.center.x * stickersClipView.frame.size.width,
                                 y: stickerFilter.center.y * stickersClipView.frame.size.height)
            imageView.center = center
            imageView.transform = stickerFilter.transform
            stickersClipView.addSubview(imageView)
        }
    }
    
    fileprivate func backupStickers() {
        tempStickerCopy = fixedFilterStack.stickerFilters
    }
}

extension IMGLYStickersEditorViewController: UICollectionViewDelegate {
    // add selected sticker
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let sticker = stickersDataSource.stickers[indexPath.row]
        
        let imageView = createImageView(sticker: sticker)
        imageView.frame.size = initialSizeForStickerImage(imageView.image ?? UIImage())
        imageView.isUserInteractionEnabled = true
        imageView.center = CGPoint(x: stickersClipView.bounds.midX, y: stickersClipView.bounds.midY)
        stickersClipView.addSubview(imageView)
        imageView.transform = CGAffineTransform(scaleX: 0, y: 0)
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0, options: [], animations: { () -> Void in
            imageView.transform = CGAffineTransform.identity
            }, completion: nil)
    }
    
    private func createImageView(sticker: IMGLYSticker) -> IMGLYGIFImageView {
        if let image = sticker.image {
            let imageView = IMGLYGIFImageView(image: image)
            imageView.sticker = sticker
            return imageView
        } else if let dataGif = sticker.dataGif {
            let imageView = IMGLYGIFImageView()
            imageView.prepareForAnimation(withGIFData: dataGif)
            imageView.startAnimatingGIF()
            imageView.sticker = sticker
            return imageView
        }
        return  IMGLYGIFImageView()
    }
}

extension IMGLYStickersEditorViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIRotationGestureRecognizer) || (gestureRecognizer is UIRotationGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer) {
            return true
        }
        
        return false
    }
}
