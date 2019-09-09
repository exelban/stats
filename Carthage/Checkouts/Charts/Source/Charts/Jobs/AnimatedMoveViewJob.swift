//
//  AnimatedMoveViewJob.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

open class AnimatedMoveViewJob: AnimatedViewPortJob
{
    internal override func animationUpdate()
    {
        guard
            let viewPortHandler = viewPortHandler,
            let transformer = transformer,
            let view = view
            else { return }
        
        var pt = CGPoint(
            x: xOrigin + (CGFloat(xValue) - xOrigin) * phase,
            y: yOrigin + (CGFloat(yValue) - yOrigin) * phase
        )
        
        transformer.pointValueToPixel(&pt)
        viewPortHandler.centerViewPort(pt: pt, chart: view)
    }
}
