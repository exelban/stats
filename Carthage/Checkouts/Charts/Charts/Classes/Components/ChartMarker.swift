//
//  ChartMarker.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 3/3/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import UIKit

public class ChartMarker: ChartComponentBase
{
    /// The marker image to render
    public var image: UIImage?
    
    /// Use this to return the desired offset you wish the MarkerView to have on the x-axis.
    public var offset: CGPoint = CGPoint()
    
    /// The marker's size
    public var size: CGSize
    {
        get
        {
            return image!.size
        }
    }
    
    public override init()
    {
        super.init()
    }
    
    /// Draws the ChartMarker on the given position on the given context
    public func draw(context context: CGContext?, point: CGPoint)
    {
        let offset = self.offset
        let size = self.size
        
        let rect = CGRect(x: point.x + offset.x, y: point.y + offset.y, width: size.width, height: size.height)
        
        UIGraphicsPushContext(context)
        image!.drawInRect(rect)
        UIGraphicsPopContext()
    }
    
    /// This method enables a custom ChartMarker to update it's content everytime the MarkerView is redrawn according to the data entry it points to.
    ///
    /// - parameter highlight: the highlight object contains information about the highlighted value such as it's dataset-index, the selected range or stack-index (only stacked bar entries).
    public func refreshContent(entry entry: ChartDataEntry, highlight: ChartHighlight)
    {
        // Do nothing here...
    }
}