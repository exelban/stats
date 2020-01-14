//
//  ChartViewPortHandler.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 27/2/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import CoreGraphics

public class ChartViewPortHandler: NSObject
{
    /// matrix used for touch events
    private var _touchMatrix = CGAffineTransformIdentity
    
    /// this rectangle defines the area in which graph values can be drawn
    private var _contentRect = CGRect()
    
    private var _chartWidth = CGFloat(0.0)
    private var _chartHeight = CGFloat(0.0)
    
    /// minimum scale value on the y-axis
    private var _minScaleY = CGFloat(1.0)
    
    /// maximum scale value on the y-axis
    private var _maxScaleY = CGFloat.max
    
    /// minimum scale value on the x-axis
    private var _minScaleX = CGFloat(1.0)
    
    /// maximum scale value on the x-axis
    private var _maxScaleX = CGFloat.max
    
    /// contains the current scale factor of the x-axis
    private var _scaleX = CGFloat(1.0)
    
    /// contains the current scale factor of the y-axis
    private var _scaleY = CGFloat(1.0)
    
    private var _transX = CGFloat(0.0)
    private var _transY = CGFloat(0.0)
    
    /// offset that allows the chart to be dragged over its bounds on the x-axis
    private var _transOffsetX = CGFloat(0.0)
    
    /// offset that allows the chart to be dragged over its bounds on the x-axis
    private var _transOffsetY = CGFloat(0.0)
    
    public override init()
    {
    }
    
    public init(width: CGFloat, height: CGFloat)
    {
        super.init()
        
        setChartDimens(width: width, height: height)
    }
    
    public func setChartDimens(width width: CGFloat, height: CGFloat)
    {
        let offsetLeft = self.offsetLeft
        let offsetTop = self.offsetTop
        let offsetRight = self.offsetRight
        let offsetBottom = self.offsetBottom
        
        _chartHeight = height
        _chartWidth = width
        
        restrainViewPort(offsetLeft: offsetLeft, offsetTop: offsetTop, offsetRight: offsetRight, offsetBottom: offsetBottom)
    }
    
    public var hasChartDimens: Bool
    {
        if (_chartHeight > 0.0 && _chartWidth > 0.0)
        {
            return true
        }
        else
        {
            return false
        }
    }

    public func restrainViewPort(offsetLeft offsetLeft: CGFloat, offsetTop: CGFloat, offsetRight: CGFloat, offsetBottom: CGFloat)
    {
        _contentRect.origin.x = offsetLeft
        _contentRect.origin.y = offsetTop
        _contentRect.size.width = _chartWidth - offsetLeft - offsetRight
        _contentRect.size.height = _chartHeight - offsetBottom - offsetTop
    }
    
    public var offsetLeft: CGFloat
    {
        return _contentRect.origin.x
    }
    
    public var offsetRight: CGFloat
    {
        return _chartWidth - _contentRect.size.width - _contentRect.origin.x
    }
    
    public var offsetTop: CGFloat
    {
        return _contentRect.origin.y
    }
    
    public var offsetBottom: CGFloat
    {
        return _chartHeight - _contentRect.size.height - _contentRect.origin.y
    }
    
    public var contentTop: CGFloat
    {
        return _contentRect.origin.y
    }
    
    public var contentLeft: CGFloat
    {
        return _contentRect.origin.x
    }
    
    public var contentRight: CGFloat
    {
        return _contentRect.origin.x + _contentRect.size.width
    }
    
    public var contentBottom: CGFloat
    {
        return _contentRect.origin.y + _contentRect.size.height
    }
    
    public var contentWidth: CGFloat
    {
        return _contentRect.size.width
    }
    
    public var contentHeight: CGFloat
    {
        return _contentRect.size.height
    }
    
    public var contentRect: CGRect { return _contentRect; }
    
    public var contentCenter: CGPoint
    {
        return CGPoint(x: _contentRect.origin.x + _contentRect.size.width / 2.0, y: _contentRect.origin.y + _contentRect.size.height / 2.0)
    }
    
    public var chartHeight: CGFloat { return _chartHeight; }
    
    public var chartWidth: CGFloat { return _chartWidth; }

    // MARK: - Scaling/Panning etc.
    
    /// Zooms around the specified center
    public func zoom(scaleX scaleX: CGFloat, scaleY: CGFloat, x: CGFloat, y: CGFloat) -> CGAffineTransform
    {
        var matrix = CGAffineTransformTranslate(_touchMatrix, x, y)
        matrix = CGAffineTransformScale(matrix, scaleX, scaleY)
        matrix = CGAffineTransformTranslate(matrix, -x, -y)
        return matrix
    }
    
    /// Zooms in by 1.4, x and y are the coordinates (in pixels) of the zoom center.
    public func zoomIn(x x: CGFloat, y: CGFloat) -> CGAffineTransform
    {
        return zoom(scaleX: 1.4, scaleY: 1.4, x: x, y: y)
    }
    
    /// Zooms out by 0.7, x and y are the coordinates (in pixels) of the zoom center.
    public func zoomOut(x x: CGFloat, y: CGFloat) -> CGAffineTransform
    {
        return zoom(scaleX: 0.7, scaleY: 0.7, x: x, y: y)
    }
    
    /// Resets all zooming and dragging and makes the chart fit exactly it's bounds.
    public func fitScreen() -> CGAffineTransform
    {
        _minScaleX = 1.0
        _minScaleY = 1.0

        return CGAffineTransformIdentity
    }
    
    /// Centers the viewport around the specified position (x-index and y-value) in the chart.
    public func centerViewPort(pt pt: CGPoint, chart: ChartViewBase)
    {
        let translateX = pt.x - offsetLeft
        let translateY = pt.y - offsetTop
        
        let matrix = CGAffineTransformConcat(_touchMatrix, CGAffineTransformMakeTranslation(-translateX, -translateY))
        
        refresh(newMatrix: matrix, chart: chart, invalidate: true)
    }
    
    /// call this method to refresh the graph with a given matrix
    public func refresh(newMatrix newMatrix: CGAffineTransform, chart: ChartViewBase, invalidate: Bool) -> CGAffineTransform
    {
        _touchMatrix = newMatrix
        
        // make sure scale and translation are within their bounds
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
        
        chart.setNeedsDisplay()
        
        return _touchMatrix
    }
    
    /// limits the maximum scale and X translation of the given matrix
    private func limitTransAndScale(inout matrix matrix: CGAffineTransform, content: CGRect?)
    {
        // min scale-x is 1, max is the max CGFloat
        _scaleX = min(max(_minScaleX, matrix.a), _maxScaleX)
        
        // min scale-y is 1
        _scaleY = min(max(_minScaleY,  matrix.d), _maxScaleY)
        
        
        var width: CGFloat = 0.0
        var height: CGFloat = 0.0
        
        if (content != nil)
        {
            width = content!.width
            height = content!.height
        }
        
        let maxTransX = -width * (_scaleX - 1.0)
        let newTransX = min(max(matrix.tx, maxTransX - _transOffsetX), _transOffsetX)
        _transX = newTransX;
        
        let maxTransY = height * (_scaleY - 1.0)
        let newTransY = max(min(matrix.ty, maxTransY + _transOffsetY), -_transOffsetY)
        _transY = newTransY;
        
        matrix.tx = _transX
        matrix.a = _scaleX
        matrix.ty = _transY
        matrix.d = _scaleY
    }
    
    public func setMinimumScaleX(xScale: CGFloat)
    {
        var newValue = xScale
        
        if (newValue < 1.0)
        {
            newValue = 1.0
        }
        
        _minScaleX = newValue
        
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
    }
    
    public func setMaximumScaleX(xScale: CGFloat)
    {
        _maxScaleX = xScale
        
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
    }
    
    public func setMinMaxScaleX(minScaleX minScaleX: CGFloat, maxScaleX: CGFloat)
    {
        var newMin = minScaleX
        
        if (newMin < 1.0)
        {
            newMin = 1.0
        }
        
        _minScaleX = newMin
        _maxScaleX = maxScaleX
        
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
    }
    
    
    public func setMaximumScaleY(yScale: CGFloat)
    {
        _maxScaleY = yScale;
        
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
    }
    
    public func setMinimumScaleY(yScale: CGFloat)
    {
        var newValue = yScale
        
        if (newValue < 1.0)
        {
            newValue = 1.0
        }
        
        _minScaleY = newValue
        
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
    }
    
    public var touchMatrix: CGAffineTransform
    {
        return _touchMatrix
    }
    
    // MARK: - Boundaries Check
    
    public func isInBoundsX(x: CGFloat) -> Bool
    {
        if (isInBoundsLeft(x) && isInBoundsRight(x))
        {
            return true
        }
        else
        {
            return false
        }
    }
    
    public func isInBoundsY(y: CGFloat) -> Bool
    {
        if (isInBoundsTop(y) && isInBoundsBottom(y))
        {
            return true
        }
        else
        {
            return false
        }
    }
    
    public func isInBounds(x x: CGFloat, y: CGFloat) -> Bool
    {
        if (isInBoundsX(x) && isInBoundsY(y))
        {
            return true
        }
        else
        {
            return false
        }
    }
    
    public func isInBoundsLeft(x: CGFloat) -> Bool
    {
        return _contentRect.origin.x <= x ? true : false
    }
    
    public func isInBoundsRight(x: CGFloat) -> Bool
    {
        let normalizedX = CGFloat(Int(x * 100.0)) / 100.0
        return (_contentRect.origin.x + _contentRect.size.width) >= normalizedX ? true : false
    }
    
    public func isInBoundsTop(y: CGFloat) -> Bool
    {
        return _contentRect.origin.y <= y ? true : false
    }
    
    public func isInBoundsBottom(y: CGFloat) -> Bool
    {
        let normalizedY = CGFloat(Int(y * 100.0)) / 100.0
        return (_contentRect.origin.y + _contentRect.size.height) >= normalizedY ? true : false
    }
    
    /// - returns: the current x-scale factor
    public var scaleX: CGFloat
    {
        return _scaleX
    }
    
    /// - returns: the current y-scale factor
    public var scaleY: CGFloat
    {
        return _scaleY
    }
    
    public var transX: CGFloat
    {
        return _transX
    }
    
    public var transY: CGFloat
    {
        return _transY
    }
    
    /// if the chart is fully zoomed out, return true
    public var isFullyZoomedOut: Bool
    {
        if (isFullyZoomedOutX && isFullyZoomedOutY)
        {
            return true
        }
        else
        {
            return false
        }
    }
    
    /// - returns: true if the chart is fully zoomed out on it's y-axis (vertical).
    public var isFullyZoomedOutY: Bool
    {
        if (_scaleY > _minScaleY || _minScaleY > 1.0)
        {
            return false
        }
        else
        {
            return true
        }
    }
    
    /// - returns: true if the chart is fully zoomed out on it's x-axis (horizontal).
    public var isFullyZoomedOutX: Bool
    {
        if (_scaleX > _minScaleX || _minScaleX > 1.0)
        {
            return false
        }
        else
        {
            return true
        }
    }
    
    /// Set an offset in pixels that allows the user to drag the chart over it's bounds on the x-axis.
    public func setDragOffsetX(offset: CGFloat)
    {
        _transOffsetX = offset
    }
    
    /// Set an offset in pixels that allows the user to drag the chart over it's bounds on the y-axis.
    public func setDragOffsetY(offset: CGFloat)
    {
        _transOffsetY = offset
    }
    
    /// - returns: true if both drag offsets (x and y) are zero or smaller.
    public var hasNoDragOffset: Bool
    {
        return _transOffsetX <= 0.0 && _transOffsetY <= 0.0 ? true : false
    }
    
    public var canZoomOutMoreX: Bool
    {
        return (_scaleX > _minScaleX)
    }
    
    public var canZoomInMoreX: Bool
    {
        return (_scaleX < _maxScaleX)
    }
}