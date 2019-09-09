//
//  Transformer.swift
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

/// Transformer class that contains all matrices and is responsible for transforming values into pixels on the screen and backwards.
@objc(ChartTransformer)
open class Transformer: NSObject
{
    /// matrix to map the values to the screen pixels
    internal var _matrixValueToPx = CGAffineTransform.identity

    /// matrix for handling the different offsets of the chart
    internal var _matrixOffset = CGAffineTransform.identity

    internal var _viewPortHandler: ViewPortHandler

    @objc public init(viewPortHandler: ViewPortHandler)
    {
        _viewPortHandler = viewPortHandler
    }

    /// Prepares the matrix that transforms values to pixels. Calculates the scale factors from the charts size and offsets.
    @objc open func prepareMatrixValuePx(chartXMin: Double, deltaX: CGFloat, deltaY: CGFloat, chartYMin: Double)
    {
        var scaleX = (_viewPortHandler.contentWidth / deltaX)
        var scaleY = (_viewPortHandler.contentHeight / deltaY)
        
        if CGFloat.infinity == scaleX
        {
            scaleX = 0.0
        }
        if CGFloat.infinity == scaleY
        {
            scaleY = 0.0
        }

        // setup all matrices
        _matrixValueToPx = CGAffineTransform.identity
        _matrixValueToPx = _matrixValueToPx.scaledBy(x: scaleX, y: -scaleY)
        _matrixValueToPx = _matrixValueToPx.translatedBy(x: CGFloat(-chartXMin), y: CGFloat(-chartYMin))
    }

    /// Prepares the matrix that contains all offsets.
    @objc open func prepareMatrixOffset(inverted: Bool)
    {
        if !inverted
        {
            _matrixOffset = CGAffineTransform(translationX: _viewPortHandler.offsetLeft, y: _viewPortHandler.chartHeight - _viewPortHandler.offsetBottom)
        }
        else
        {
            _matrixOffset = CGAffineTransform(scaleX: 1.0, y: -1.0)
            _matrixOffset = _matrixOffset.translatedBy(x: _viewPortHandler.offsetLeft, y: -_viewPortHandler.offsetTop)
        }
    }

    /// Transform an array of points with all matrices.
    // VERY IMPORTANT: Keep matrix order "value-touch-offset" when transforming.
    open func pointValuesToPixel(_ points: inout [CGPoint])
    {
        let trans = valueToPixelMatrix
        points = points.map { $0.applying(trans) }
    }
    
    open func pointValueToPixel(_ point: inout CGPoint)
    {
        point = point.applying(valueToPixelMatrix)
    }
    
    @objc open func pixelForValues(x: Double, y: Double) -> CGPoint
    {
        return CGPoint(x: x, y: y).applying(valueToPixelMatrix)
    }
    
    /// Transform a rectangle with all matrices.
    open func rectValueToPixel(_ r: inout CGRect)
    {
        r = r.applying(valueToPixelMatrix)
    }
    
    /// Transform a rectangle with all matrices with potential animation phases.
    open func rectValueToPixel(_ r: inout CGRect, phaseY: Double)
    {
        // multiply the height of the rect with the phase
        var bottom = r.origin.y + r.size.height
        bottom *= CGFloat(phaseY)
        let top = r.origin.y * CGFloat(phaseY)
        r.size.height = bottom - top
        r.origin.y = top

        r = r.applying(valueToPixelMatrix)
    }
    
    /// Transform a rectangle with all matrices.
    open func rectValueToPixelHorizontal(_ r: inout CGRect)
    {
        r = r.applying(valueToPixelMatrix)
    }
    
    /// Transform a rectangle with all matrices with potential animation phases.
    open func rectValueToPixelHorizontal(_ r: inout CGRect, phaseY: Double)
    {
        // multiply the height of the rect with the phase
        let left = r.origin.x * CGFloat(phaseY)
        let right = (r.origin.x + r.size.width) * CGFloat(phaseY)
        r.size.width = right - left
        r.origin.x = left
        
        r = r.applying(valueToPixelMatrix)
    }

    /// transforms multiple rects with all matrices
    open func rectValuesToPixel(_ rects: inout [CGRect])
    {
        let trans = valueToPixelMatrix
        rects = rects.map { $0.applying(trans) }
    }
    
    /// Transforms the given array of touch points (pixels) into values on the chart.
    open func pixelsToValues(_ pixels: inout [CGPoint])
    {
        let trans = pixelToValueMatrix
        pixels = pixels.map { $0.applying(trans) }
    }
    
    /// Transforms the given touch point (pixels) into a value on the chart.
    open func pixelToValues(_ pixel: inout CGPoint)
    {
        pixel = pixel.applying(pixelToValueMatrix)
    }
    
    /// - Returns: The x and y values in the chart at the given touch point
    /// (encapsulated in a CGPoint). This method transforms pixel coordinates to
    /// coordinates / values in the chart.
    @objc open func valueForTouchPoint(_ point: CGPoint) -> CGPoint
    {
        return point.applying(pixelToValueMatrix)
    }
    
    /// - Returns: The x and y values in the chart at the given touch point
    /// (x/y). This method transforms pixel coordinates to
    /// coordinates / values in the chart.
    @objc open func valueForTouchPoint(x: CGFloat, y: CGFloat) -> CGPoint
    {
        return CGPoint(x: x, y: y).applying(pixelToValueMatrix)
    }
    
    @objc open var valueToPixelMatrix: CGAffineTransform
    {
        return
            _matrixValueToPx.concatenating(_viewPortHandler.touchMatrix
                ).concatenating(_matrixOffset
        )
    }
    
    @objc open var pixelToValueMatrix: CGAffineTransform
    {
        return valueToPixelMatrix.inverted()
    }
}
