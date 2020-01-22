//
//  Highlight.swift
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

@objc(ChartHighlight)
open class Highlight: NSObject
{
    /// the x-value of the highlighted value
    fileprivate var _x = Double.nan
    
    /// the y-value of the highlighted value
    fileprivate var _y = Double.nan
    
    /// the x-pixel of the highlight
    private var _xPx = CGFloat.nan
    
    /// the y-pixel of the highlight
    private var _yPx = CGFloat.nan
    
    /// the index of the data object - in case it refers to more than one
    @objc open var dataIndex = Int(-1)
    
    /// the index of the dataset the highlighted value is in
    fileprivate var _dataSetIndex = Int(0)
    
    /// index which value of a stacked bar entry is highlighted
    /// 
    /// **default**: -1
    fileprivate var _stackIndex = Int(-1)
    
    /// the axis the highlighted value belongs to
    private var _axis: YAxis.AxisDependency = YAxis.AxisDependency.left
    
    /// the x-position (pixels) on which this highlight object was last drawn
    @objc open var drawX: CGFloat = 0.0
    
    /// the y-position (pixels) on which this highlight object was last drawn
    @objc open var drawY: CGFloat = 0.0
    
    public override init()
    {
        super.init()
    }
    
    /// - Parameters:
    ///   - x: the x-value of the highlighted value
    ///   - y: the y-value of the highlighted value
    ///   - xPx: the x-pixel of the highlighted value
    ///   - yPx: the y-pixel of the highlighted value
    ///   - dataIndex: the index of the Data the highlighted value belongs to
    ///   - dataSetIndex: the index of the DataSet the highlighted value belongs to
    ///   - stackIndex: references which value of a stacked-bar entry has been selected
    ///   - axis: the axis the highlighted value belongs to
    @objc public init(
        x: Double, y: Double,
        xPx: CGFloat, yPx: CGFloat,
        dataIndex: Int,
        dataSetIndex: Int,
        stackIndex: Int,
        axis: YAxis.AxisDependency)
    {
        super.init()
        
        _x = x
        _y = y
        _xPx = xPx
        _yPx = yPx
        self.dataIndex = dataIndex
        _dataSetIndex = dataSetIndex
        _stackIndex = stackIndex
        _axis = axis
    }
    
    /// - Parameters:
    ///   - x: the x-value of the highlighted value
    ///   - y: the y-value of the highlighted value
    ///   - xPx: the x-pixel of the highlighted value
    ///   - yPx: the y-pixel of the highlighted value
    ///   - dataSetIndex: the index of the DataSet the highlighted value belongs to
    ///   - stackIndex: references which value of a stacked-bar entry has been selected
    ///   - axis: the axis the highlighted value belongs to
    @objc public convenience init(
        x: Double, y: Double,
        xPx: CGFloat, yPx: CGFloat,
        dataSetIndex: Int,
        stackIndex: Int,
        axis: YAxis.AxisDependency)
    {
        self.init(x: x, y: y, xPx: xPx, yPx: yPx,
                  dataIndex: 0,
                  dataSetIndex: dataSetIndex,
                  stackIndex: stackIndex,
                  axis: axis)
    }
    
    /// - Parameters:
    ///   - x: the x-value of the highlighted value
    ///   - y: the y-value of the highlighted value
    ///   - xPx: the x-pixel of the highlighted value
    ///   - yPx: the y-pixel of the highlighted value
    ///   - dataIndex: the index of the Data the highlighted value belongs to
    ///   - dataSetIndex: the index of the DataSet the highlighted value belongs to
    ///   - stackIndex: references which value of a stacked-bar entry has been selected
    ///   - axis: the axis the highlighted value belongs to
    @objc public init(
        x: Double, y: Double,
        xPx: CGFloat, yPx: CGFloat,
        dataSetIndex: Int,
        axis: YAxis.AxisDependency)
    {
        super.init()
        
        _x = x
        _y = y
        _xPx = xPx
        _yPx = yPx
        _dataSetIndex = dataSetIndex
        _axis = axis
    }
    
    /// - Parameters:
    ///   - x: the x-value of the highlighted value
    ///   - y: the y-value of the highlighted value
    ///   - dataSetIndex: the index of the DataSet the highlighted value belongs to
    ///   - dataIndex: The data index to search in (only used in CombinedChartView currently)
    @objc public init(x: Double, y: Double, dataSetIndex: Int, dataIndex: Int = -1)
    {
        _x = x
        _y = y
        _dataSetIndex = dataSetIndex
        self.dataIndex = dataIndex
    }
    
    /// - Parameters:
    ///   - x: the x-value of the highlighted value
    ///   - dataSetIndex: the index of the DataSet the highlighted value belongs to
    ///   - stackIndex: references which value of a stacked-bar entry has been selected
    @objc public convenience init(x: Double, dataSetIndex: Int, stackIndex: Int)
    {
        self.init(x: x, y: Double.nan, dataSetIndex: dataSetIndex)
        _stackIndex = stackIndex
    }
    
    @objc open var x: Double { return _x }
    @objc open var y: Double { return _y }
    @objc open var xPx: CGFloat { return _xPx }
    @objc open var yPx: CGFloat { return _yPx }
    @objc open var dataSetIndex: Int { return _dataSetIndex }
    @objc open var stackIndex: Int { return _stackIndex }
    @objc open var axis: YAxis.AxisDependency { return _axis }
    
    @objc open var isStacked: Bool { return _stackIndex >= 0 }
    
    /// Sets the x- and y-position (pixels) where this highlight was last drawn.
    @objc open func setDraw(x: CGFloat, y: CGFloat)
    {
        self.drawX = x
        self.drawY = y
    }
    
    /// Sets the x- and y-position (pixels) where this highlight was last drawn.
    @objc open func setDraw(pt: CGPoint)
    {
        self.drawX = pt.x
        self.drawY = pt.y
    }

    // MARK: NSObject
    
    open override var description: String
    {
        return "Highlight, x: \(_x), y: \(_y), dataIndex (combined charts): \(dataIndex), dataSetIndex: \(_dataSetIndex), stackIndex (only stacked barentry): \(_stackIndex)"
    }
}


// MARK: Equatable
extension Highlight /*: Equatable*/ {
    open override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? Highlight else { return false }

        if self === object
        {
            return true
        }

        return _x == object._x
            && _y == object._y
            && dataIndex == object.dataIndex
            && _dataSetIndex == object._dataSetIndex
            && _stackIndex == object._stackIndex
    }
}
