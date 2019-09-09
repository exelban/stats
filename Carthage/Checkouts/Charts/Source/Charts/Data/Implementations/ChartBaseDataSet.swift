//
//  BaseDataSet.swift
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


open class ChartBaseDataSet: NSObject, IChartDataSet, NSCopying
{
    public required override init()
    {
        super.init()
        
        // default color
        colors.append(NSUIColor(red: 140.0/255.0, green: 234.0/255.0, blue: 255.0/255.0, alpha: 1.0))
        valueColors.append(NSUIColor.black)
    }
    
    @objc public init(label: String?)
    {
        super.init()
        
        // default color
        colors.append(NSUIColor(red: 140.0/255.0, green: 234.0/255.0, blue: 255.0/255.0, alpha: 1.0))
        valueColors.append(NSUIColor.black)
        
        self.label = label
    }
    
    // MARK: - Data functions and accessors
    
    /// Use this method to tell the data set that the underlying data has changed
    open func notifyDataSetChanged()
    {
        calcMinMax()
    }
    
    open func calcMinMax()
    {
        fatalError("calcMinMax is not implemented in ChartBaseDataSet")
    }
    
    open func calcMinMaxY(fromX: Double, toX: Double)
    {
        fatalError("calcMinMaxY(fromX:, toX:) is not implemented in ChartBaseDataSet")
    }
    
    open var yMin: Double
    {
        fatalError("yMin is not implemented in ChartBaseDataSet")
    }
    
    open var yMax: Double
    {
        fatalError("yMax is not implemented in ChartBaseDataSet")
    }
    
    open var xMin: Double
    {
        fatalError("xMin is not implemented in ChartBaseDataSet")
    }
    
    open var xMax: Double
    {
        fatalError("xMax is not implemented in ChartBaseDataSet")
    }
    
    open var entryCount: Int
    {
        fatalError("entryCount is not implemented in ChartBaseDataSet")
    }
        
    open func entryForIndex(_ i: Int) -> ChartDataEntry?
    {
        fatalError("entryForIndex is not implemented in ChartBaseDataSet")
    }
    
    open func entryForXValue(
        _ x: Double,
        closestToY y: Double,
        rounding: ChartDataSetRounding) -> ChartDataEntry?
    {
        fatalError("entryForXValue(x, closestToY, rounding) is not implemented in ChartBaseDataSet")
    }
    
    open func entryForXValue(
        _ x: Double,
        closestToY y: Double) -> ChartDataEntry?
    {
        fatalError("entryForXValue(x, closestToY) is not implemented in ChartBaseDataSet")
    }
    
    open func entriesForXValue(_ x: Double) -> [ChartDataEntry]
    {
        fatalError("entriesForXValue is not implemented in ChartBaseDataSet")
    }
    
    open func entryIndex(
        x xValue: Double,
        closestToY y: Double,
        rounding: ChartDataSetRounding) -> Int
    {
        fatalError("entryIndex(x, closestToY, rounding) is not implemented in ChartBaseDataSet")
    }
    
    open func entryIndex(entry e: ChartDataEntry) -> Int
    {
        fatalError("entryIndex(entry) is not implemented in ChartBaseDataSet")
    }
    
    open func addEntry(_ e: ChartDataEntry) -> Bool
    {
        fatalError("addEntry is not implemented in ChartBaseDataSet")
    }
    
    open func addEntryOrdered(_ e: ChartDataEntry) -> Bool
    {
        fatalError("addEntryOrdered is not implemented in ChartBaseDataSet")
    }
    
    @discardableResult open func removeEntry(_ entry: ChartDataEntry) -> Bool
    {
        fatalError("removeEntry is not implemented in ChartBaseDataSet")
    }
    
    @discardableResult open func removeEntry(index: Int) -> Bool
    {
        if let entry = entryForIndex(index)
        {
            return removeEntry(entry)
        }
        return false
    }
    
    @discardableResult open func removeEntry(x: Double) -> Bool
    {
        if let entry = entryForXValue(x, closestToY: Double.nan)
        {
            return removeEntry(entry)
        }
        return false
    }
    
    @discardableResult open func removeFirst() -> Bool
    {
        if entryCount > 0
        {
            if let entry = entryForIndex(0)
            {
                return removeEntry(entry)
            }
        }
        return false
    }
    
    @discardableResult open func removeLast() -> Bool
    {
        if entryCount > 0
        {
            if let entry = entryForIndex(entryCount - 1)
            {
                return removeEntry(entry)
            }
        }
        return false
    }
    
    open func contains(_ e: ChartDataEntry) -> Bool
    {
        fatalError("removeEntry is not implemented in ChartBaseDataSet")
    }
    
    open func clear()
    {
        fatalError("clear is not implemented in ChartBaseDataSet")
    }
    
    // MARK: - Styling functions and accessors
    
    /// All the colors that are used for this DataSet.
    /// Colors are reused as soon as the number of Entries the DataSet represents is higher than the size of the colors array.
    open var colors = [NSUIColor]()
    
    /// List representing all colors that are used for drawing the actual values for this DataSet
    open var valueColors = [NSUIColor]()

    /// The label string that describes the DataSet.
    open var label: String? = "DataSet"
    
    /// The axis this DataSet should be plotted against.
    open var axisDependency = YAxis.AxisDependency.left
    
    /// - Returns: The color at the given index of the DataSet's color array.
    /// This prevents out-of-bounds by performing a modulus on the color index, so colours will repeat themselves.
    open func color(atIndex index: Int) -> NSUIColor
    {
        var index = index
        if index < 0
        {
            index = 0
        }
        return colors[index % colors.count]
    }
    
    /// Resets all colors of this DataSet and recreates the colors array.
    open func resetColors()
    {
        colors.removeAll(keepingCapacity: false)
    }
    
    /// Adds a new color to the colors array of the DataSet.
    ///
    /// - Parameters:
    ///   - color: the color to add
    open func addColor(_ color: NSUIColor)
    {
        colors.append(color)
    }
    
    /// Sets the one and **only** color that should be used for this DataSet.
    /// Internally, this recreates the colors array and adds the specified color.
    ///
    /// - Parameters:
    ///   - color: the color to set
    open func setColor(_ color: NSUIColor)
    {
        colors.removeAll(keepingCapacity: false)
        colors.append(color)
    }
    
    /// Sets colors to a single color a specific alpha value.
    ///
    /// - Parameters:
    ///   - color: the color to set
    ///   - alpha: alpha to apply to the set `color`
    @objc open func setColor(_ color: NSUIColor, alpha: CGFloat)
    {
        setColor(color.withAlphaComponent(alpha))
    }
    
    /// Sets colors with a specific alpha value.
    ///
    /// - Parameters:
    ///   - colors: the colors to set
    ///   - alpha: alpha to apply to the set `colors`
    @objc open func setColors(_ colors: [NSUIColor], alpha: CGFloat)
    {
        self.colors = colors.map { $0.withAlphaComponent(alpha) }
    }
    
    /// Sets colors with a specific alpha value.
    ///
    /// - Parameters:
    ///   - colors: the colors to set
    ///   - alpha: alpha to apply to the set `colors`
    open func setColors(_ colors: NSUIColor...)
    {
        self.colors = colors
    }
    
    /// if true, value highlighting is enabled
    open var highlightEnabled = true
    
    /// `true` if value highlighting is enabled for this dataset
    open var isHighlightEnabled: Bool { return highlightEnabled }
    
    /// Custom formatter that is used instead of the auto-formatter if set
    internal var _valueFormatter: IValueFormatter?
    
    /// Custom formatter that is used instead of the auto-formatter if set
    open var valueFormatter: IValueFormatter?
    {
        get
        {
            if needsFormatter
            {
                return ChartUtils.defaultValueFormatter()
            }
            
            return _valueFormatter
        }
        set
        {
            if newValue == nil { return }
            
            _valueFormatter = newValue
        }
    }
    
    open var needsFormatter: Bool
    {
        return _valueFormatter == nil
    }
    
    /// Sets/get a single color for value text.
    /// Setting the color clears the colors array and adds a single color.
    /// Getting will return the first color in the array.
    open var valueTextColor: NSUIColor
    {
        get
        {
            return valueColors[0]
        }
        set
        {
            valueColors.removeAll(keepingCapacity: false)
            valueColors.append(newValue)
        }
    }
    
    /// - Returns: The color at the specified index that is used for drawing the values inside the chart. Uses modulus internally.
    open func valueTextColorAt(_ index: Int) -> NSUIColor
    {
        var index = index
        if index < 0
        {
            index = 0
        }
        return valueColors[index % valueColors.count]
    }
    
    /// the font for the value-text labels
    open var valueFont: NSUIFont = NSUIFont.systemFont(ofSize: 7.0)
    
    /// The form to draw for this dataset in the legend.
    open var form = Legend.Form.default
    
    /// The form size to draw for this dataset in the legend.
    ///
    /// Return `NaN` to use the default legend form size.
    open var formSize: CGFloat = CGFloat.nan
    
    /// The line width for drawing the form of this dataset in the legend
    ///
    /// Return `NaN` to use the default legend form line width.
    open var formLineWidth: CGFloat = CGFloat.nan
    
    /// Line dash configuration for legend shapes that consist of lines.
    ///
    /// This is how much (in pixels) into the dash pattern are we starting from.
    open var formLineDashPhase: CGFloat = 0.0
    
    /// Line dash configuration for legend shapes that consist of lines.
    ///
    /// This is the actual dash pattern.
    /// I.e. [2, 3] will paint [--   --   ]
    /// [1, 3, 4, 2] will paint [-   ----  -   ----  ]
    open var formLineDashLengths: [CGFloat]? = nil
    
    /// Set this to true to draw y-values on the chart.
    ///
    /// - Note: For bar and line charts: if `maxVisibleCount` is reached, no values will be drawn even if this is enabled.
    open var drawValuesEnabled = true
    
    /// `true` if y-value drawing is enabled, `false` ifnot
    open var isDrawValuesEnabled: Bool
    {
        return drawValuesEnabled
    }

    /// Set this to true to draw y-icons on the chart.
    ///
    /// - Note: For bar and line charts: if `maxVisibleCount` is reached, no icons will be drawn even if this is enabled.
    open var drawIconsEnabled = true
    
    /// Returns true if y-icon drawing is enabled, false if not
    open var isDrawIconsEnabled: Bool
    {
        return drawIconsEnabled
    }
    
    /// Offset of icons drawn on the chart.  
    ///
    /// For all charts except Pie and Radar it will be ordinary (x offset, y offset).
    ///
    /// For Pie and Radar chart it will be (y offset, distance from center offset); so if you want icon to be rendered under value, you should increase X component of CGPoint, and if you want icon to be rendered closet to center, you should decrease height component of CGPoint.
    open var iconsOffset = CGPoint(x: 0, y: 0)
    
    /// Set the visibility of this DataSet. If not visible, the DataSet will not be drawn to the chart upon refreshing it.
    open var visible = true
    
    /// `true` if this DataSet is visible inside the chart, or `false` ifit is currently hidden.
    open var isVisible: Bool
    {
        return visible
    }
    
    // MARK: - NSObject
    
    open override var description: String
    {
        return String(format: "%@, label: %@, %i entries", arguments: [NSStringFromClass(type(of: self)), self.label ?? "", self.entryCount])
    }
    
    open override var debugDescription: String
    {
        return (0..<entryCount).reduce(description + ":") {
            $0 + "\n" + (self.entryForIndex($1)?.description ?? "")
        }
    }
    
    // MARK: - NSCopying
    
    open func copy(with zone: NSZone? = nil) -> Any 
    {
        let copy = type(of: self).init()
        
        copy.colors = colors
        copy.valueColors = valueColors
        copy.label = label
        copy.axisDependency = axisDependency
        copy.highlightEnabled = highlightEnabled
        copy._valueFormatter = _valueFormatter
        copy.valueFont = valueFont
        copy.form = form
        copy.formSize = formSize
        copy.formLineWidth = formLineWidth
        copy.formLineDashPhase = formLineDashPhase
        copy.formLineDashLengths = formLineDashLengths
        copy.drawValuesEnabled = drawValuesEnabled
        copy.drawValuesEnabled = drawValuesEnabled
        copy.iconsOffset = iconsOffset
        copy.visible = visible
        
        return copy
    }
}
