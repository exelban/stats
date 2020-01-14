//
//  ChartData.swift
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

public class ChartData: NSObject
{
    internal var _yMax = Double(0.0)
    internal var _yMin = Double(0.0)
    internal var _leftAxisMax = Double(0.0)
    internal var _leftAxisMin = Double(0.0)
    internal var _rightAxisMax = Double(0.0)
    internal var _rightAxisMin = Double(0.0)
    private var _yValueSum = Double(0.0)
    private var _yValCount = Int(0)
    
    /// the last start value used for calcMinMax
    internal var _lastStart: Int = 0
    
    /// the last end value used for calcMinMax
    internal var _lastEnd: Int = 0
    
    /// the average length (in characters) across all x-value strings
    private var _xValAverageLength = Double(0.0)
    
    internal var _xVals: [String?]!
    internal var _dataSets: [ChartDataSet]!
    
    public override init()
    {
        super.init()
        
        _xVals = [String?]()
        _dataSets = [ChartDataSet]()
    }
    
    public init(xVals: [String?]?, dataSets: [ChartDataSet]?)
    {
        super.init()
        
        _xVals = xVals == nil ? [String?]() : xVals
        _dataSets = dataSets == nil ? [ChartDataSet]() : dataSets
        
        self.initialize(_dataSets)
    }
    
    public init(xVals: [NSObject]?, dataSets: [ChartDataSet]?)
    {
        super.init()
        
        _xVals = xVals == nil ? [String?]() : ChartUtils.bridgedObjCGetStringArray(objc: xVals!)
        _dataSets = dataSets == nil ? [ChartDataSet]() : dataSets
        
        self.initialize(_dataSets)
    }
    
    public convenience init(xVals: [String?]?)
    {
        self.init(xVals: xVals, dataSets: [ChartDataSet]())
    }
    
    public convenience init(xVals: [NSObject]?)
    {
        self.init(xVals: xVals, dataSets: [ChartDataSet]())
    }
    
    public convenience init(xVals: [String?]?, dataSet: ChartDataSet?)
    {
        self.init(xVals: xVals, dataSets: dataSet === nil ? nil : [dataSet!])
    }
    
    public convenience init(xVals: [NSObject]?, dataSet: ChartDataSet?)
    {
        self.init(xVals: xVals, dataSets: dataSet === nil ? nil : [dataSet!])
    }
    
    internal func initialize(dataSets: [ChartDataSet])
    {
        checkIsLegal(dataSets)
        
        calcMinMax(start: _lastStart, end: _lastEnd)
        calcYValueSum()
        calcYValueCount()
        
        calcXValAverageLength()
    }
    
    // calculates the average length (in characters) across all x-value strings
    internal func calcXValAverageLength()
    {
        if (_xVals.count == 0)
        {
            _xValAverageLength = 1
            return
        }
        
        var sum = 1
        
        for (var i = 0; i < _xVals.count; i++)
        {
            sum += _xVals[i] == nil ? 0 : (_xVals[i]!).characters.count
        }
        
        _xValAverageLength = Double(sum) / Double(_xVals.count)
    }
    
    // Checks if the combination of x-values array and DataSet array is legal or not.
    // :param: dataSets
    internal func checkIsLegal(dataSets: [ChartDataSet]!)
    {
        if (dataSets == nil)
        {
            return
        }
        
        if self is ScatterChartData
        { // In scatter chart it makes sense to have more than one y-value value for an x-index
            return
        }
        
        for (var i = 0; i < dataSets.count; i++)
        {
            if (dataSets[i].yVals.count > _xVals.count)
            {
                print("One or more of the DataSet Entry arrays are longer than the x-values array of this Data object.", terminator: "\n")
                return
            }
        }
    }
    
    public func notifyDataChanged()
    {
        initialize(_dataSets)
    }
    
    /// calc minimum and maximum y value over all datasets
    internal func calcMinMax(start start: Int, end: Int)
    {
        
        if (_dataSets == nil || _dataSets.count < 1)
        {
            _yMax = 0.0
            _yMin = 0.0
        }
        else
        {
            _lastStart = start
            _lastEnd = end
            
            _yMin = DBL_MAX
            _yMax = -DBL_MAX
            
            for (var i = 0; i < _dataSets.count; i++)
            {
                _dataSets[i].calcMinMax(start: start, end: end)
                
                if (_dataSets[i].yMin < _yMin)
                {
                    _yMin = _dataSets[i].yMin
                }
                
                if (_dataSets[i].yMax > _yMax)
                {
                    _yMax = _dataSets[i].yMax
                }
            }
            
            if (_yMin == DBL_MAX)
            {
                _yMin = 0.0
                _yMax = 0.0
            }
            
            // left axis
            let firstLeft = getFirstLeft()

            if (firstLeft !== nil)
            {
                _leftAxisMax = firstLeft!.yMax
                _leftAxisMin = firstLeft!.yMin

                for dataSet in _dataSets
                {
                    if (dataSet.axisDependency == .Left)
                    {
                        if (dataSet.yMin < _leftAxisMin)
                        {
                            _leftAxisMin = dataSet.yMin
                        }

                        if (dataSet.yMax > _leftAxisMax)
                        {
                            _leftAxisMax = dataSet.yMax
                        }
                    }
                }
            }

            // right axis
            let firstRight = getFirstRight()

            if (firstRight !== nil)
            {
                _rightAxisMax = firstRight!.yMax
                _rightAxisMin = firstRight!.yMin
                
                for dataSet in _dataSets
                {
                    if (dataSet.axisDependency == .Right)
                    {
                        if (dataSet.yMin < _rightAxisMin)
                        {
                            _rightAxisMin = dataSet.yMin
                        }

                        if (dataSet.yMax > _rightAxisMax)
                        {
                            _rightAxisMax = dataSet.yMax
                        }
                    }
                }
            }

            // in case there is only one axis, adjust the second axis
            handleEmptyAxis(firstLeft, firstRight: firstRight)
        }
    }
    
    /// calculates the sum of all y-values in all datasets
    internal func calcYValueSum()
    {
        _yValueSum = 0
        
        if (_dataSets == nil)
        {
            return
        }
        
        for (var i = 0; i < _dataSets.count; i++)
        {
            _yValueSum += fabs(_dataSets[i].yValueSum)
        }
    }
    
    /// Calculates the total number of y-values across all ChartDataSets the ChartData represents.
    internal func calcYValueCount()
    {
        _yValCount = 0
        
        if (_dataSets == nil)
        {
            return
        }
        
        var count = 0
        
        for (var i = 0; i < _dataSets.count; i++)
        {
            count += _dataSets[i].entryCount
        }
        
        _yValCount = count
    }
    
    /// - returns: the number of LineDataSets this object contains
    public var dataSetCount: Int
    {
        if (_dataSets == nil)
        {
            return 0
        }
        return _dataSets.count
    }
    
    /// - returns: the average value across all entries in this Data object (all entries from the DataSets this data object holds)
    public var average: Double
    {
        return yValueSum / Double(yValCount)
    }
    
    /// - returns: the smallest y-value the data object contains.
    public var yMin: Double
    {
        return _yMin
    }
    
    public func getYMin() -> Double
    {
        return _yMin
    }
    
    public func getYMin(axis: ChartYAxis.AxisDependency) -> Double
    {
        if (axis == .Left)
        {
            return _leftAxisMin
        }
        else
        {
            return _rightAxisMin
        }
    }
    
    /// - returns: the greatest y-value the data object contains.
    public var yMax: Double
    {
        return _yMax
    }
    
    public func getYMax() -> Double
    {
        return _yMax
    }
    
    public func getYMax(axis: ChartYAxis.AxisDependency) -> Double
    {
        if (axis == .Left)
        {
            return _leftAxisMax
        }
        else
        {
            return _rightAxisMax
        }
    }
    
    /// - returns: the average length (in characters) across all values in the x-vals array
    public var xValAverageLength: Double
    {
        return _xValAverageLength
    }
    
    /// - returns: the total y-value sum across all DataSet objects the this object represents.
    public var yValueSum: Double
    {
        return _yValueSum
    }
    
    /// - returns: the total number of y-values across all DataSet objects the this object represents.
    public var yValCount: Int
    {
        return _yValCount
    }
    
    /// - returns: the x-values the chart represents
    public var xVals: [String?]
    {
        return _xVals
    }
    
    ///Adds a new x-value to the chart data.
    public func addXValue(xVal: String?)
    {
        _xVals.append(xVal)
    }
    
    /// Removes the x-value at the specified index.
    public func removeXValue(index: Int)
    {
        _xVals.removeAtIndex(index)
    }
    
    /// - returns: the array of ChartDataSets this object holds.
    public var dataSets: [ChartDataSet]
    {
        get
        {
            return _dataSets
        }
        set
        {
            _dataSets = newValue
        }
    }
    
    /// Retrieve the index of a ChartDataSet with a specific label from the ChartData. Search can be case sensitive or not.
    /// 
    /// **IMPORTANT: This method does calculations at runtime, do not over-use in performance critical situations.**
    ///
    /// - parameter dataSets: the DataSet array to search
    /// - parameter type:
    /// - parameter ignorecase: if true, the search is not case-sensitive
    /// - returns: the index of the DataSet Object with the given label. Sensitive or not.
    internal func getDataSetIndexByLabel(label: String, ignorecase: Bool) -> Int
    {
        if (ignorecase)
        {
            for (var i = 0; i < dataSets.count; i++)
            {
                if (dataSets[i].label == nil)
                {
                    continue
                }
                if (label.caseInsensitiveCompare(dataSets[i].label!) == NSComparisonResult.OrderedSame)
                {
                    return i
                }
            }
        }
        else
        {
            for (var i = 0; i < dataSets.count; i++)
            {
                if (label == dataSets[i].label)
                {
                    return i
                }
            }
        }
        
        return -1
    }
    
    /// - returns: the total number of x-values this ChartData object represents (the size of the x-values array)
    public var xValCount: Int
    {
        return _xVals.count
    }
    
    /// - returns: the labels of all DataSets as a string array.
    internal func dataSetLabels() -> [String]
    {
        var types = [String]()
        
        for (var i = 0; i < _dataSets.count; i++)
        {
            if (dataSets[i].label == nil)
            {
                continue
            }
            
            types[i] = _dataSets[i].label!
        }
        
        return types
    }
    
    /// Get the Entry for a corresponding highlight object
    ///
    /// - parameter highlight:
    /// - returns: the entry that is highlighted
    public func getEntryForHighlight(highlight: ChartHighlight) -> ChartDataEntry?
    {
        if highlight.dataSetIndex >= dataSets.count
        {
            return nil
        }
        else
        {
            return _dataSets[highlight.dataSetIndex].entryForXIndex(highlight.xIndex)
        }
    }
    
    /// **IMPORTANT: This method does calculations at runtime. Use with care in performance critical situations.**
    ///
    /// - parameter label:
    /// - parameter ignorecase:
    /// - returns: the DataSet Object with the given label. Sensitive or not.
    public func getDataSetByLabel(label: String, ignorecase: Bool) -> ChartDataSet?
    {
        let index = getDataSetIndexByLabel(label, ignorecase: ignorecase)
        
        if (index < 0 || index >= _dataSets.count)
        {
            return nil
        }
        else
        {
            return _dataSets[index]
        }
    }
    
    public func getDataSetByIndex(index: Int) -> ChartDataSet!
    {
        if (_dataSets == nil || index < 0 || index >= _dataSets.count)
        {
            return nil
        }
        
        return _dataSets[index]
    }
    
    public func addDataSet(d: ChartDataSet!)
    {
        if (_dataSets == nil)
        {
            return
        }
        
        _yValCount += d.entryCount
        _yValueSum += d.yValueSum
        
        if (_dataSets.count == 0)
        {
            _yMax = d.yMax
            _yMin = d.yMin
            
            if (d.axisDependency == .Left)
            {
                _leftAxisMax = d.yMax
                _leftAxisMin = d.yMin
            }
            else
            {
                _rightAxisMax = d.yMax
                _rightAxisMin = d.yMin
            }
        }
        else
        {
            if (_yMax < d.yMax)
            {
                _yMax = d.yMax
            }
            if (_yMin > d.yMin)
            {
                _yMin = d.yMin
            }
            
            if (d.axisDependency == .Left)
            {
                if (_leftAxisMax < d.yMax)
                {
                    _leftAxisMax = d.yMax
                }
                if (_leftAxisMin > d.yMin)
                {
                    _leftAxisMin = d.yMin
                }
            }
            else
            {
                if (_rightAxisMax < d.yMax)
                {
                    _rightAxisMax = d.yMax
                }
                if (_rightAxisMin > d.yMin)
                {
                    _rightAxisMin = d.yMin
                }
            }
        }
        
        _dataSets.append(d)
        
        handleEmptyAxis(getFirstLeft(), firstRight: getFirstRight())
    }
    
    public func handleEmptyAxis(firstLeft: ChartDataSet?, firstRight: ChartDataSet?)
    {
        // in case there is only one axis, adjust the second axis
        if (firstLeft === nil)
        {
            _leftAxisMax = _rightAxisMax
            _leftAxisMin = _rightAxisMin
        }
        else if (firstRight === nil)
        {
            _rightAxisMax = _leftAxisMax
            _rightAxisMin = _leftAxisMin
        }
    }
    
    /// Removes the given DataSet from this data object.
    /// Also recalculates all minimum and maximum values.
    ///
    /// - returns: true if a DataSet was removed, false if no DataSet could be removed.
    public func removeDataSet(dataSet: ChartDataSet!) -> Bool
    {
        if (_dataSets == nil || dataSet === nil)
        {
            return false
        }
        
        for (var i = 0; i < _dataSets.count; i++)
        {
            if (_dataSets[i] === dataSet)
            {
                return removeDataSetByIndex(i)
            }
        }
        
        return false
    }
    
    /// Removes the DataSet at the given index in the DataSet array from the data object. 
    /// Also recalculates all minimum and maximum values. 
    ///
    /// - returns: true if a DataSet was removed, false if no DataSet could be removed.
    public func removeDataSetByIndex(index: Int) -> Bool
    {
        if (_dataSets == nil || index >= _dataSets.count || index < 0)
        {
            return false
        }
        
        let d = _dataSets.removeAtIndex(index)
        _yValCount -= d.entryCount
        _yValueSum -= d.yValueSum
        
        calcMinMax(start: _lastStart, end: _lastEnd)
        
        return true
    }
    
    /// Adds an Entry to the DataSet at the specified index. Entries are added to the end of the list.
    public func addEntry(e: ChartDataEntry, dataSetIndex: Int)
    {
        if (_dataSets != nil && _dataSets.count > dataSetIndex && dataSetIndex >= 0)
        {
            let val = e.value
            let set = _dataSets[dataSetIndex]
            
            if (_yValCount == 0)
            {
                _yMin = val
                _yMax = val
                
                if (set.axisDependency == .Left)
                {
                    _leftAxisMax = e.value
                    _leftAxisMin = e.value
                }
                else
                {
                    _rightAxisMax = e.value
                    _rightAxisMin = e.value
                }
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
                
                if (set.axisDependency == .Left)
                {
                    if (_leftAxisMax < e.value)
                    {
                        _leftAxisMax = e.value
                    }
                    if (_leftAxisMin > e.value)
                    {
                        _leftAxisMin = e.value
                    }
                }
                else
                {
                    if (_rightAxisMax < e.value)
                    {
                        _rightAxisMax = e.value
                    }
                    if (_rightAxisMin > e.value)
                    {
                        _rightAxisMin = e.value
                    }
                }
            }
            
            _yValCount += 1
            _yValueSum += val
            
            handleEmptyAxis(getFirstLeft(), firstRight: getFirstRight())
            
            set.addEntry(e)
        }
        else
        {
            print("ChartData.addEntry() - dataSetIndex our of range.", terminator: "\n")
        }
    }
    
    /// Removes the given Entry object from the DataSet at the specified index.
    public func removeEntry(entry: ChartDataEntry!, dataSetIndex: Int) -> Bool
    {
        // entry null, outofbounds
        if (entry === nil || dataSetIndex >= _dataSets.count)
        {
            return false
        }
        
        // remove the entry from the dataset
        let removed = _dataSets[dataSetIndex].removeEntry(xIndex: entry.xIndex)
        
        if (removed)
        {
            let val = entry.value
            
            _yValCount -= 1
            _yValueSum -= val
            
            calcMinMax(start: _lastStart, end: _lastEnd)
        }
        
        return removed
    }
    
    /// Removes the Entry object at the given xIndex from the ChartDataSet at the
    /// specified index. 
    /// - returns: true if an entry was removed, false if no Entry was found that meets the specified requirements.
    public func removeEntryByXIndex(xIndex: Int, dataSetIndex: Int) -> Bool
    {
        if (dataSetIndex >= _dataSets.count)
        {
            return false
        }
        
        let entry = _dataSets[dataSetIndex].entryForXIndex(xIndex)
        
        if (entry?.xIndex != xIndex)
        {
            return false
        }
        
        return removeEntry(entry, dataSetIndex: dataSetIndex)
    }
    
    /// - returns: the DataSet that contains the provided Entry, or null, if no DataSet contains this entry.
    public func getDataSetForEntry(e: ChartDataEntry!) -> ChartDataSet?
    {
        if (e == nil)
        {
            return nil
        }
        
        for (var i = 0; i < _dataSets.count; i++)
        {
            let set = _dataSets[i]
            
            for (var j = 0; j < set.entryCount; j++)
            {
                if (e === set.entryForXIndex(e.xIndex))
                {
                    return set
                }
            }
        }
        
        return nil
    }
    
    /// - returns: the index of the provided DataSet inside the DataSets array of this data object. -1 if the DataSet was not found.
    public func indexOfDataSet(dataSet: ChartDataSet) -> Int
    {
        for (var i = 0; i < _dataSets.count; i++)
        {
            if (_dataSets[i] === dataSet)
            {
                return i
            }
        }
        
        return -1
    }
    
    /// - returns: the first DataSet from the datasets-array that has it's dependency on the left axis. Returns null if no DataSet with left dependency could be found.
    public func getFirstLeft() -> ChartDataSet?
    {
        for dataSet in _dataSets
        {
            if (dataSet.axisDependency == .Left)
            {
                return dataSet
            }
        }
        
        return nil
    }
    
    /// - returns: the first DataSet from the datasets-array that has it's dependency on the right axis. Returns null if no DataSet with right dependency could be found.
    public func getFirstRight() -> ChartDataSet?
    {
        for dataSet in _dataSets
        {
            if (dataSet.axisDependency == .Right)
            {
                return dataSet
            }
        }
        
        return nil
    }
    
    /// - returns: all colors used across all DataSet objects this object represents.
    public func getColors() -> [UIColor]?
    {
        if (_dataSets == nil)
        {
            return nil
        }
        
        var clrcnt = 0
        
        for (var i = 0; i < _dataSets.count; i++)
        {
            clrcnt += _dataSets[i].colors.count
        }
        
        var colors = [UIColor]()
        
        for (var i = 0; i < _dataSets.count; i++)
        {
            let clrs = _dataSets[i].colors
            
            for clr in clrs
            {
                colors.append(clr)
            }
        }
        
        return colors
    }
    
    /// Generates an x-values array filled with numbers in range specified by the parameters. Can be used for convenience.
    public func generateXVals(from: Int, to: Int) -> [String]
    {
        var xvals = [String]()
        
        for (var i = from; i < to; i++)
        {
            xvals.append(String(i))
        }
        
        return xvals
    }
    
    /// Sets a custom ValueFormatter for all DataSets this data object contains.
    public func setValueFormatter(formatter: NSNumberFormatter!)
    {
        for set in dataSets
        {
            set.valueFormatter = formatter
        }
    }
    
    /// Sets the color of the value-text (color in which the value-labels are drawn) for all DataSets this data object contains.
    public func setValueTextColor(color: UIColor!)
    {
        for set in dataSets
        {
            set.valueTextColor = color ?? set.valueTextColor
        }
    }
    
    /// Sets the font for all value-labels for all DataSets this data object contains.
    public func setValueFont(font: UIFont!)
    {
        for set in dataSets
        {
            set.valueFont = font ?? set.valueFont
        }
    }
    
    /// Enables / disables drawing values (value-text) for all DataSets this data object contains.
    public func setDrawValues(enabled: Bool)
    {
        for set in dataSets
        {
            set.drawValuesEnabled = enabled
        }
    }
    
    /// Enables / disables highlighting values for all DataSets this data object contains.
    public var highlightEnabled: Bool
    {
        get
        {
            for set in dataSets
            {
                if (!set.highlightEnabled)
                {
                    return false
                }
            }
            
            return true
        }
        set
        {
            for set in dataSets
            {
                set.highlightEnabled = newValue
            }
        }
    }
    
    /// if true, value highlightning is enabled
    public var isHighlightEnabled: Bool { return highlightEnabled }
    
    /// Clears this data object from all DataSets and removes all Entries.
    /// Don't forget to invalidate the chart after this.
    public func clearValues()
    {
        dataSets.removeAll(keepCapacity: false)
        notifyDataChanged()
    }
    
    /// Checks if this data object contains the specified Entry. 
    /// - returns: true if so, false if not.
    public func contains(entry entry: ChartDataEntry) -> Bool
    {
        for set in dataSets
        {
            if (set.contains(entry))
            {
                return true
            }
        }
        
        return false
    }
    
    /// Checks if this data object contains the specified DataSet. 
    /// - returns: true if so, false if not.
    public func contains(dataSet dataSet: ChartDataSet) -> Bool
    {
        for set in dataSets
        {
            if (set.isEqual(dataSet))
            {
                return true
            }
        }
        
        return false
    }
    
    /// MARK: - ObjC compatibility
    
    /// - returns: the average length (in characters) across all values in the x-vals array
    public var xValsObjc: [NSObject] { return ChartUtils.bridgedObjCGetStringArray(swift: _xVals); }
}
