//
//  ViewPortHandler.swift
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

/// Class that contains information about the charts current viewport settings, including offsets, scale & translation levels, ...
@objc(ChartViewPortHandler)
open class ViewPortHandler: NSObject
{
    /// matrix used for touch events
    private var _touchMatrix = CGAffineTransform.identity
    
    /// this rectangle defines the area in which graph values can be drawn
    private var _contentRect = CGRect()
    
    private var _chartWidth = CGFloat(0.0)
    private var _chartHeight = CGFloat(0.0)
    
    /// minimum scale value on the y-axis
    private var _minScaleY = CGFloat(1.0)
    
    /// maximum scale value on the y-axis
    private var _maxScaleY = CGFloat.greatestFiniteMagnitude
    
    /// minimum scale value on the x-axis
    private var _minScaleX = CGFloat(1.0)
    
    /// maximum scale value on the x-axis
    private var _maxScaleX = CGFloat.greatestFiniteMagnitude
    
    /// contains the current scale factor of the x-axis
    private var _scaleX = CGFloat(1.0)
    
    /// contains the current scale factor of the y-axis
    private var _scaleY = CGFloat(1.0)
    
    /// current translation (drag distance) on the x-axis
    private var _transX = CGFloat(0.0)
    
    /// current translation (drag distance) on the y-axis
    private var _transY = CGFloat(0.0)
    
    /// offset that allows the chart to be dragged over its bounds on the x-axis
    private var _transOffsetX = CGFloat(0.0)
    
    /// offset that allows the chart to be dragged over its bounds on the x-axis
    private var _transOffsetY = CGFloat(0.0)
    
    /// Constructor - don't forget calling setChartDimens(...)
    @objc public init(width: CGFloat, height: CGFloat)
    {
        super.init()
        
        setChartDimens(width: width, height: height)
    }
    
    @objc open func setChartDimens(width: CGFloat, height: CGFloat)
    {
        let offsetLeft = self.offsetLeft
        let offsetTop = self.offsetTop
        let offsetRight = self.offsetRight
        let offsetBottom = self.offsetBottom
        
        _chartHeight = height
        _chartWidth = width
        
        restrainViewPort(offsetLeft: offsetLeft, offsetTop: offsetTop, offsetRight: offsetRight, offsetBottom: offsetBottom)
    }
    
    @objc open var hasChartDimens: Bool
    {
        if _chartHeight > 0.0 && _chartWidth > 0.0
        {
            return true
        }
        else
        {
            return false
        }
    }

    @objc open func restrainViewPort(offsetLeft: CGFloat, offsetTop: CGFloat, offsetRight: CGFloat, offsetBottom: CGFloat)
    {
        _contentRect.origin.x = offsetLeft
        _contentRect.origin.y = offsetTop
        _contentRect.size.width = _chartWidth - offsetLeft - offsetRight
        _contentRect.size.height = _chartHeight - offsetBottom - offsetTop
    }
    
    @objc open var offsetLeft: CGFloat
    {
        return _contentRect.origin.x
    }
    
    @objc open var offsetRight: CGFloat
    {
        return _chartWidth - _contentRect.size.width - _contentRect.origin.x
    }
    
    @objc open var offsetTop: CGFloat
    {
        return _contentRect.origin.y
    }
    
    @objc open var offsetBottom: CGFloat
    {
        return _chartHeight - _contentRect.size.height - _contentRect.origin.y
    }
    
    @objc open var contentTop: CGFloat
    {
        return _contentRect.origin.y
    }
    
    @objc open var contentLeft: CGFloat
    {
        return _contentRect.origin.x
    }
    
    @objc open var contentRight: CGFloat
    {
        return _contentRect.origin.x + _contentRect.size.width
    }
    
    @objc open var contentBottom: CGFloat
    {
        return _contentRect.origin.y + _contentRect.size.height
    }
    
    @objc open var contentWidth: CGFloat
    {
        return _contentRect.size.width
    }
    
    @objc open var contentHeight: CGFloat
    {
        return _contentRect.size.height
    }
    
    @objc open var contentRect: CGRect
    {
        return _contentRect
    }
    
    @objc open var contentCenter: CGPoint
    {
        return CGPoint(x: _contentRect.origin.x + _contentRect.size.width / 2.0, y: _contentRect.origin.y + _contentRect.size.height / 2.0)
    }
    
    @objc open var chartHeight: CGFloat
    { 
        return _chartHeight
    }
    
    @objc open var chartWidth: CGFloat
    { 
        return _chartWidth
    }

    // MARK: - Scaling/Panning etc.
    
    /// Zooms by the specified zoom factors.
    @objc open func zoom(scaleX: CGFloat, scaleY: CGFloat) -> CGAffineTransform
    {
        return _touchMatrix.scaledBy(x: scaleX, y: scaleY)
    }
    
    /// Zooms around the specified center
    @objc open func zoom(scaleX: CGFloat, scaleY: CGFloat, x: CGFloat, y: CGFloat) -> CGAffineTransform
    {
        var matrix = _touchMatrix.translatedBy(x: x, y: y)
        matrix = matrix.scaledBy(x: scaleX, y: scaleY)
        matrix = matrix.translatedBy(x: -x, y: -y)
        return matrix
    }
    
    /// Zooms in by 1.4, x and y are the coordinates (in pixels) of the zoom center.
    @objc open func zoomIn(x: CGFloat, y: CGFloat) -> CGAffineTransform
    {
        return zoom(scaleX: 1.4, scaleY: 1.4, x: x, y: y)
    }
    
    /// Zooms out by 0.7, x and y are the coordinates (in pixels) of the zoom center.
    @objc open func zoomOut(x: CGFloat, y: CGFloat) -> CGAffineTransform
    {
        return zoom(scaleX: 0.7, scaleY: 0.7, x: x, y: y)
    }
    
    /// Zooms out to original size.
    @objc open func resetZoom() -> CGAffineTransform
    {
        return zoom(scaleX: 1.0, scaleY: 1.0, x: 0.0, y: 0.0)
    }
    
    /// Sets the scale factor to the specified values.
    @objc open func setZoom(scaleX: CGFloat, scaleY: CGFloat) -> CGAffineTransform
    {
        var matrix = _touchMatrix
        matrix.a = scaleX
        matrix.d = scaleY
        return matrix
    }
    
    /// Sets the scale factor to the specified values. x and y is pivot.
    @objc open func setZoom(scaleX: CGFloat, scaleY: CGFloat, x: CGFloat, y: CGFloat) -> CGAffineTransform
    {
        var matrix = _touchMatrix
        matrix.a = 1.0
        matrix.d = 1.0
        matrix = matrix.translatedBy(x: x, y: y)
        matrix = matrix.scaledBy(x: scaleX, y: scaleY)
        matrix = matrix.translatedBy(x: -x, y: -y)
        return matrix
    }
    
    /// Resets all zooming and dragging and makes the chart fit exactly it's bounds.
    @objc open func fitScreen() -> CGAffineTransform
    {
        _minScaleX = 1.0
        _minScaleY = 1.0

        return CGAffineTransform.identity
    }
    
    /// Translates to the specified point.
    @objc open func translate(pt: CGPoint) -> CGAffineTransform
    {
        let translateX = pt.x - offsetLeft
        let translateY = pt.y - offsetTop
        
        let matrix = _touchMatrix.concatenating(CGAffineTransform(translationX: -translateX, y: -translateY))
        
        return matrix
    }
    
    /// Centers the viewport around the specified position (x-index and y-value) in the chart.
    /// Centering the viewport outside the bounds of the chart is not possible.
    /// Makes most sense in combination with the setScaleMinima(...) method.
    @objc open func centerViewPort(pt: CGPoint, chart: ChartViewBase)
    {
        let translateX = pt.x - offsetLeft
        let translateY = pt.y - offsetTop
        
        let matrix = _touchMatrix.concatenating(CGAffineTransform(translationX: -translateX, y: -translateY))
        refresh(newMatrix: matrix, chart: chart, invalidate: true)
    }
    
    /// call this method to refresh the graph with a given matrix
    @objc @discardableResult open func refresh(newMatrix: CGAffineTransform, chart: ChartViewBase, invalidate: Bool) -> CGAffineTransform
    {
        _touchMatrix = newMatrix
        
        // make sure scale and translation are within their bounds
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
        
        chart.setNeedsDisplay()
        
        return _touchMatrix
    }
    
    /// limits the maximum scale and X translation of the given matrix
    private func limitTransAndScale(matrix: inout CGAffineTransform, content: CGRect?)
    {
        // min scale-x is 1
        _scaleX = min(max(_minScaleX, matrix.a), _maxScaleX)
        
        // min scale-y is 1
        _scaleY = min(max(_minScaleY,  matrix.d), _maxScaleY)
        
        
        var width: CGFloat = 0.0
        var height: CGFloat = 0.0
        
        if content != nil
        {
            width = content!.width
            height = content!.height
        }
        
        let maxTransX = -width * (_scaleX - 1.0)
        _transX = min(max(matrix.tx, maxTransX - _transOffsetX), _transOffsetX)
        
        let maxTransY = height * (_scaleY - 1.0)
        _transY = max(min(matrix.ty, maxTransY + _transOffsetY), -_transOffsetY)
        
        matrix.tx = _transX
        matrix.a = _scaleX
        matrix.ty = _transY
        matrix.d = _scaleY
    }
    
    /// Sets the minimum scale factor for the x-axis
    @objc open func setMinimumScaleX(_ xScale: CGFloat)
    {
        var newValue = xScale
        
        if newValue < 1.0
        {
            newValue = 1.0
        }
        
        _minScaleX = newValue
        
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
    }
    
    /// Sets the maximum scale factor for the x-axis
    @objc open func setMaximumScaleX(_ xScale: CGFloat)
    {
        var newValue = xScale
        
        if newValue == 0.0
        {
            newValue = CGFloat.greatestFiniteMagnitude
        }
        
        _maxScaleX = newValue
        
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
    }
    
    /// Sets the minimum and maximum scale factors for the x-axis
    @objc open func setMinMaxScaleX(minScaleX: CGFloat, maxScaleX: CGFloat)
    {
        var newMin = minScaleX
        var newMax = maxScaleX
        
        if newMin < 1.0
        {
            newMin = 1.0
        }
        if newMax == 0.0
        {
            newMax = CGFloat.greatestFiniteMagnitude
        }
        
        _minScaleX = newMin
        _maxScaleX = maxScaleX
        
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
    }
    
    /// Sets the minimum scale factor for the y-axis
    @objc open func setMinimumScaleY(_ yScale: CGFloat)
    {
        var newValue = yScale
        
        if newValue < 1.0
        {
            newValue = 1.0
        }
        
        _minScaleY = newValue
        
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
    }
    
    /// Sets the maximum scale factor for the y-axis
    @objc open func setMaximumScaleY(_ yScale: CGFloat)
    {
        var newValue = yScale
        
        if newValue == 0.0
        {
            newValue = CGFloat.greatestFiniteMagnitude
        }
        
        _maxScaleY = newValue
        
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
    }
    
    @objc open func setMinMaxScaleY(minScaleY: CGFloat, maxScaleY: CGFloat)
    {
        var minScaleY = minScaleY, maxScaleY = maxScaleY
        
        if minScaleY < 1.0
        {
            minScaleY = 1.0
        }
        
        if maxScaleY == 0.0
        {
            maxScaleY = CGFloat.greatestFiniteMagnitude
        }
        
        _minScaleY = minScaleY
        _maxScaleY = maxScaleY
        
        limitTransAndScale(matrix: &_touchMatrix, content: _contentRect)
    }

    @objc open var touchMatrix: CGAffineTransform
    {
        return _touchMatrix
    }
    
    // MARK: - Boundaries Check
    
    @objc open func isInBoundsX(_ x: CGFloat) -> Bool
    {
        return isInBoundsLeft(x) && isInBoundsRight(x)
    }
    
    @objc open func isInBoundsY(_ y: CGFloat) -> Bool
    {
        return isInBoundsTop(y) && isInBoundsBottom(y)
    }
    
    @objc open func isInBounds(x: CGFloat, y: CGFloat) -> Bool
    {
        return isInBoundsX(x) && isInBoundsY(y)
    }
    
    @objc open func isInBoundsLeft(_ x: CGFloat) -> Bool
    {
        return _contentRect.origin.x <= x + 1.0
    }
    
    @objc open func isInBoundsRight(_ x: CGFloat) -> Bool
    {
        let x = floor(x * 100.0) / 100.0
        return (_contentRect.origin.x + _contentRect.size.width) >= x - 1.0
    }
    
    @objc open func isInBoundsTop(_ y: CGFloat) -> Bool
    {
        return _contentRect.origin.y <= y
    }
    
    @objc open func isInBoundsBottom(_ y: CGFloat) -> Bool
    {
        let normalizedY = floor(y * 100.0) / 100.0
        return (_contentRect.origin.y + _contentRect.size.height) >= normalizedY
    }
    
    /// The current x-scale factor
    @objc open var scaleX: CGFloat
    {
        return _scaleX
    }
    
    /// The current y-scale factor
    @objc open var scaleY: CGFloat
    {
        return _scaleY
    }
    
    /// The minimum x-scale factor
    @objc open var minScaleX: CGFloat
    {
        return _minScaleX
    }
    
    /// The minimum y-scale factor
    @objc open var minScaleY: CGFloat
    {
        return _minScaleY
    }
    
    /// The minimum x-scale factor
    @objc open var maxScaleX: CGFloat
    {
        return _maxScaleX
    }
    
    /// The minimum y-scale factor
    @objc open var maxScaleY: CGFloat
    {
        return _maxScaleY
    }
    
    /// The translation (drag / pan) distance on the x-axis
    @objc open var transX: CGFloat
    {
        return _transX
    }
    
    /// The translation (drag / pan) distance on the y-axis
    @objc open var transY: CGFloat
    {
        return _transY
    }
    
    /// if the chart is fully zoomed out, return true
    @objc open var isFullyZoomedOut: Bool
    {
        return isFullyZoomedOutX && isFullyZoomedOutY
    }
    
    /// `true` if the chart is fully zoomed out on it's y-axis (vertical).
    @objc open var isFullyZoomedOutY: Bool
    {
        return !(_scaleY > _minScaleY || _minScaleY > 1.0)
    }
    
    /// `true` if the chart is fully zoomed out on it's x-axis (horizontal).
    @objc open var isFullyZoomedOutX: Bool
    {
        return !(_scaleX > _minScaleX || _minScaleX > 1.0)
    }
    
    /// Set an offset in pixels that allows the user to drag the chart over it's bounds on the x-axis.
    @objc open func setDragOffsetX(_ offset: CGFloat)
    {
        _transOffsetX = offset
    }
    
    /// Set an offset in pixels that allows the user to drag the chart over it's bounds on the y-axis.
    @objc open func setDragOffsetY(_ offset: CGFloat)
    {
        _transOffsetY = offset
    }
    
    /// `true` if both drag offsets (x and y) are zero or smaller.
    @objc open var hasNoDragOffset: Bool
    {
        return _transOffsetX <= 0.0 && _transOffsetY <= 0.0
    }
    
    /// `true` if the chart is not yet fully zoomed out on the x-axis
    @objc open var canZoomOutMoreX: Bool
    {
        return _scaleX > _minScaleX
    }
    
    /// `true` if the chart is not yet fully zoomed in on the x-axis
    @objc open var canZoomInMoreX: Bool
    {
        return _scaleX < _maxScaleX
    }
    
    /// `true` if the chart is not yet fully zoomed out on the y-axis
    @objc open var canZoomOutMoreY: Bool
    {
        return _scaleY > _minScaleY
    }
    
    /// `true` if the chart is not yet fully zoomed in on the y-axis
    @objc open var canZoomInMoreY: Bool
    {
        return _scaleY < _maxScaleY
    }
}
