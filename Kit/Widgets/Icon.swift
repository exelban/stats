//
//  Icon.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 05/10/2026.
//  Using Swift 6.0.
//  Running on macOS 27.0.
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class IconWidget: WidgetWrapper {
    private let fanAnimation: Bool
    private var animationState: Bool = false
    private var value: Bool = false
    private let imageView: NSImageView = NSImageView(frame: .zero)
    
    public init(title: String, config: NSDictionary, icon: NSImage?, preview: Bool = false) {
        self.fanAnimation = config["Fan animation"] as? Bool ?? false
        
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = icon?.withSymbolConfiguration(configuration) ?? icon
        let width = ceil(image?.size.width ?? 16)
        
        super.init(.icon, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: width + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.imageView.frame = self.bounds
        self.imageView.autoresizingMask = [.width, .height]
        self.imageView.image = image
        self.imageView.symbolConfiguration = configuration
        self.imageView.contentTintColor = .textColor
        self.imageView.imageScaling = .scaleNone
        self.imageView.imageAlignment = .alignCenter
        self.addSubview(self.imageView)
        
        if !preview && self.fanAnimation {
            self.animationState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_animation", defaultValue: self.animationState)
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setValue(_ value: Bool) {
        DispatchQueue.main.async(execute: {
            self.value = value
            self.updateAnimation()
        })
    }
    
    @objc private func updateAnimation() {
        guard self.animationState, self.value, self.window?.isVisible == true else {
            self.imageView.layer?.removeAnimation(forKey: "rotation")
            return
        }
        
        self.imageView.wantsLayer = true
        guard let layer = self.imageView.layer, layer.animation(forKey: "rotation") == nil else { return }
        let x = layer.bounds.width * (0.5 - layer.anchorPoint.x)
        let y = layer.bounds.height * (0.5 - layer.anchorPoint.y)
        
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = (0...60).map { frame in
            var transform = CATransform3DMakeTranslation(x, y, 0)
            transform = CATransform3DRotate(transform, CGFloat(frame) * 2 * .pi / 60, 0, 0, 1)
            transform = CATransform3DTranslate(transform, -x, -y, 0)
            return NSValue(caTransform3D: transform)
        }
        animation.duration = 1.5
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        layer.add(animation, forKey: "rotation")
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView {
        guard self.fanAnimation else { return NSView() }
        let view = SettingsContainerView()
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Animate icon"), component: switchView(
                action: #selector(self.toggleAnimation),
                state: self.animationState
            ))
        ]))
        
        return view
    }
    
    @objc private func toggleAnimation(_ sender: NSControl) {
        self.animationState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_animation", value: self.animationState)
        self.updateAnimation()
    }
}
