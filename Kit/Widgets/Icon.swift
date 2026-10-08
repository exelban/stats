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
    public init(title: String, icon: NSImage?, preview: Bool = false) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = icon?.withSymbolConfiguration(configuration) ?? icon
        let width = ceil(image?.size.width ?? 16)
        
        super.init(.icon, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: width + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        let imageView = NSImageView(frame: self.bounds)
        imageView.autoresizingMask = [.width, .height]
        imageView.image = image
        imageView.symbolConfiguration = configuration
        imageView.contentTintColor = .textColor
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        self.addSubview(imageView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
