//
//  ChartDataSet.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 23/2/15.

//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import UIKit

public class ChartDataSet: NSObject
{
    public var colors = [UIColor]()
    internal var _yVals: [ChartDataEntry]!
    internal var _yMax = Double(0.0)
    internal var _yMin = Double(0.0)
    internal var _yValueSum = Double(0.0)
    
    /// the last start value used for calcMinMax
    internal var _lastStart: Int = 0
    
    /// the last end value used for calcMinMax
    internal var _lastEnd: Int = 0
    
    public var label: String? = "DataSet"
    public var visible = true
    public var drawValuesEnabled = true
    
    /// the color used for the value-text
    public var valueTextColor: UIColor = UIColor.blackColor()
    
    /// the font for the value-text labels
    public var valueFont: UIFont = UIFont.systemFontOfSize(7.0)
    
    /// the formatter used to customly format the values
    public var valueFormatter: NSNumberFormatter?
    
    /// the axis this DataSet should be plotted against.
    public var axisDependency = ChartYAxis.AxisDependency.Left

    public var yVals: [ChartDataEntry] { return _yVals }
    public var yValueSum: Double { return _yValueSum }
    public var yMin: Double { return _yMin }
    public var yMax: Double { return _yMax }
    
    /// if true, value highlighting is enabled
    public var highlightEnabled = true
    
    /// - returns: true if value highlighting is enabled for this dataset
    public var isHighlightEnabled: Bool { return highlightEnabled }
    
    public override required init()
    {
        super.init()
    }
    
    public init(yVals: [ChartDataEntry]?, label: String?)
    {
        super.init()
        
        self.label = label
        _yVals = yVals == nil ? [ChartDataEntry]() : yVals
        
        // default color
        colors.append(UIColor(red: 140.0/255.0, green: 234.0/255.0, blue: 255.0/255.0, alpha: 1.0))
        
        self.calcMinMax(start: _lastStart, end: _lastEnd)
        self.calcYValueSum()
    }
    
    public convenience init(yVals: [ChartDataEntry]?)
    {
        self.init(yVals: yVals, label: "DataSet")
    }
    
    /// Use this method to tell the data set that the underlying data has changed
    public func notifyDataSetChanged()
    {
        calcMinMax(start: _lastStart, end: _lastEnd)
        calcYValueSum()
    }
    
    internal func calcMinMax(start start : Int, end: Int)
    {
        let yValCount = _yVals.count
        
        if yValCount == 0
        {
            return
        }
        
        var endValue : Int
        
        if end == 0 || end >= yValCount
        {
            endValue = yValCount - 1
        }
        else
        {
            endValue = end
        }
        
        _lastStart = start
        _lastEnd = endValue
        
        _yMin = DBL_MAX
        _yMax = -DBL_MAX
        
        for (var i = start; i <= endValue; i++)
        {
            let e = _yVals[i]
            
            if (!e.value.isNaN)
            {
                if (e.value < _yMin)
                {
                    _yMin = e.value
                }
                if (e.value > _yMax)
                {
                    _yMax = e.value
                }
            }
        }
        
        if (_yMin == DBL_MAX)
        {
            _yMin = 0.0
            _yMax = 0.0
        }
    }
    
    private func calcYValueSum()
    {
        _yValueSum = 0
        
        for var i = 0; i < _yVals.count; i++
        {
            _yValueSum += fabs(_yVals[i].value)
        }
    }
    
    /// - returns: the average value across all entries in this DataSet.
    public var average: Double
    {
        return yValueSum / Double(valueCount)
    }
    
    public var entryCount: Int { return _yVals!.count; }
    
    public func yValForXIndex(x: Int) -> Double
    {
        let e = self.entryForXIndex(x)
        
        if (e !== nil && e!.xIndex == x) { return e!.value }
        else { return Double.NaN }
    }
    
    /// - returns: the first Entry object found at the given xIndex with binary search.
    /// If the no Entry at the specifed x-index is found, this method returns the Entry at the closest x-index. 
    /// nil if no Entry object at that index.
    public func entryForXIndex(x: Int) -> ChartDataEntry?
    {
        let index = self.entryIndex(xIndex: x)
        if (index > -1)
        {
            return _yVals[index]
        }
        return nil
    }
    
    public func entriesForXIndex(x: Int) -> [ChartDataEntry]
    {
        var entries = [ChartDataEntry]()
        
        var low = 0
        var high = _yVals.count - 1
        
        while (low <= high)
        {
            var m = Int((high + low) / 2)
            var entry = _yVals[m]
            
            if (x == entry.xIndex)
            {
                while (m > 0 && _yVals[m - 1].xIndex == x)
                {
                    m--
                }
                
                high = _yVals.count
                for (; m < high; m++)
                {
                    entry = _yVals[m]
                    if (entry.xIndex == x)
                    {
                        entries.append(entry)
                    }
                    else
                    {
                        break
                    }
                }
            }
            
            if (x > _yVals[m].xIndex)
            {
                low = m + 1
            }
            else
            {
                high = m - 1
            }
        }
        
        return entries
    }
    
    public func entryIndex(xIndex x: Int) -> Int
    {
        var low = 0
        var high = _yVals.count - 1
        var closest = -1
        
        while (low <= high)
        {
            var m = (high + low) / 2
            let entry = _yVals[m]
            
            if (x == entry.xIndex)
            {
                while (m > 0 && _yVals[m - 1].xIndex == x)
                {
                    m--
                }
                
                return m
            }
            
            if (x > entry.xIndex)
            {
                low = m + 1
            }
            else
            {
                high = m - 1
            }
            
            closest = m
        }
        
        return closest
    }
    
    public func entryIndex(entry e: ChartDataEntry, isEqual: Bool) -> Int
    {
        if (isEqual)
        {
            for (var i = 0; i < _yVals.count; i++)
            {
                if (_yVals[i].isEqual(e))
                {
                    return i
                }
            }
        }
        else
        {
            for (var i = 0; i < _yVals.count; i++)
            {
                if (_yVals[i] === e)
                {
                    return i
                }
            }
        }
        
        return -1
    }
    
    /// - returns: the number of entries this DataSet holds.
    public var valueCount: Int { return _yVals.count; }
    
    /// Adds an Entry to the DataSet dynamically.
    /// Entries are added to the end of the list.
    /// This will also recalculate the current minimum and maximum values of the DataSet and the value-sum.
    /// - parameter e: the entry to add
    public func addEntry(e: ChartDataEntry)
    {
        let val = e.value
        
        if (_yVals == nil)
        {
            _yVals = [ChartDataEntry]()
        }
        
        if (_yVals.count == 0)
        {
            _yMax = val
            _yMin = val
        }
        else
        {
            if (_yMax < val)
            {
                _yMax = val
            }
            if (_yMin > val)
            {
                _yMin = val
            }
        }
        
        _yValueSum += val
        
        _yVals.append(e)
    }
    
    /// Adds an Entry to the DataSet dynamically.
    /// Entries are added to their appropriate index respective to it's x-index.
    /// This will also recalculate the current minimum and maximum values of the DataSet and the value-sum.
    /// - parameter e: the entry to add
    public func addEntryOrdered(e: ChartDataEntry)
    {
        let val = e.value
        
        if (_yVals == nil)
        {
            _yVals = [ChartDataEntry]()
        }
        
        if (_yVals.count == 0)
        {
            _yMax = val
            _yMin = val
        }
        else
        {
            if (_yMax < val)
            {
                _yMax = val
            }
            if (_yMin > val)
            {
                _yMin = val
            }
        }
        
        _yValueSum += val
        
        if _yVals.last?.xIndex > e.xIndex
        {
            var closestIndex = entryIndex(xIndex: e.xIndex)
            if _yVals[closestIndex].xIndex < e.xIndex
            {
                closestIndex++
            }
            _yVals.insert(e, atIndex: closestIndex)
            return;
        }
        
        _yVals.append(e)
    }
    
    public func removeEntry(entry: ChartDataEntry) -> Bool
    {
        var removed = false
        
        for (var i = 0; i < _yVals.count; i++)
        {
            if (_yVals[i] === entry)
            {
                _yVals.removeAtIndex(i)
                removed = true
                break
            }
        }
        
        if (removed)
        {
            _yValueSum -= entry.value
            calcMinMax(start: _lastStart, end: _lastEnd)
        }
        
        return removed
    }
    
    public func removeEntry(xIndex xIndex: Int) -> Bool
    {
        let index = self.entryIndex(xIndex: xIndex)
        if (index > -1)
        {
            let e = _yVals.removeAtIndex(index)
            
            _yValueSum -= e.value
            calcMinMax(start: _lastStart, end: _lastEnd)
            
            return true
        }
        
        return false
    }
    
    /// Removes the first Entry (at index 0) of this DataSet from the entries array.
    ///
    /// - returns: true if successful, false if not.
    public func removeFirst() -> Bool
    {
        let entry: ChartDataEntry? = _yVals.isEmpty ? nil : _yVals.removeFirst()
        
        let removed = entry != nil
        
        if (removed)
        {
            
            let val = entry!.value
            _yValueSum -= val
            
            calcMinMax(start: _lastStart, end: _lastEnd)
        }
        
        return removed;
    }
    
    /// Removes the last Entry (at index size-1) of this DataSet from the entries array.
    ///
    /// - returns: true if successful, false if not.
    public func removeLast() -> Bool
    {
        let entry: ChartDataEntry? = _yVals.isEmpty ? nil : _yVals.removeLast()
        
        let removed = entry != nil
        
        if (removed)
        {
            
            let val = entry!.value
            _yValueSum -= val
            
            calcMinMax(start: _lastStart, end: _lastEnd)
        }
        
        return removed;
    }
    
    public func resetColors()
    {
        colors.removeAll(keepCapacity: false)
    }
    
    public func addColor(color: UIColor)
    {
        colors.append(color)
    }
    
    public func setColor(color: UIColor)
    {
        colors.removeAll(keepCapacity: false)
        colors.append(color)
    }
    
    public func colorAt(var index: Int) -> UIColor
    {
        if (index < 0)
        {
            index = 0
        }
        return colors[index % colors.count]
    }
    
    public var isVisible: Bool
    {
        return visible
    }
    
    public var isDrawValuesEnabled: Bool
    {
        return drawValuesEnabled
    }
    
    /// Checks if this DataSet contains the specified Entry.
    /// - returns: true if contains the entry, false if not.
    public func contains(e: ChartDataEntry) -> Bool
    {
        for entry in _yVals
        {
            if (entry.isEqual(e))
            {
                return true
            }
        }
        
        return false
    }
    
    /// Removes all values from this DataSet and recalculates min and max value.
    public func clear()
    {
        _yVals.removeAll(keepCapacity: true)
        _lastStart = 0
        _lastEnd = 0
        notifyDataSetChanged()
    }

    // MARK: NSObject
    
    public override var description: String
    {
        return String(format: "ChartDataSet, label: %@, %i entries", arguments: [self.label ?? "", _yVals.count])
    }
    
    public override var debugDescription: String
    {
        var desc = description + ":"
        
        for (var i = 0; i < _yVals.count; i++)
        {
            desc += "\n" + _yVals[i].description
        }
        
        return desc
    }
    
    // MARK: NSCopying
    
    public func copyWithZone(zone: NSZone) -> AnyObject
    {
        let copy = self.dynamicType.init()
        
        copy.colors = colors
        copy._yVals = _yVals
        copy._yMax = _yMax
        copy._yMin = _yMin
        copy._yValueSum = _yValueSum
        copy._lastStart = _lastStart
        copy._lastEnd = _lastEnd
        copy.label = label
        
        return copy
    }
}


