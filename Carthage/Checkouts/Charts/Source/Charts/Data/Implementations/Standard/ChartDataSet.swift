//
//  ChartDataSet.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation

/// Determines how to round DataSet index values for `ChartDataSet.entryIndex(x, rounding)` when an exact x-value is not found.
@objc
public enum ChartDataSetRounding: Int
{
    case up = 0
    case down = 1
    case closest = 2
}

/// The DataSet class represents one group or type of entries (Entry) in the Chart that belong together.
/// It is designed to logically separate different groups of values inside the Chart (e.g. the values for a specific line in the LineChart, or the values of a specific group of bars in the BarChart).
open class ChartDataSet: ChartBaseDataSet
{
    public required init()
    {
        entries = []

        super.init()
    }
    
    public override init(label: String?)
    {
        entries = []

        super.init(label: label)
    }
    
    @objc public init(entries: [ChartDataEntry]?, label: String?)
    {
        self.entries = entries ?? []

        super.init(label: label)

        self.calcMinMax()
    }
    
    @objc public convenience init(entries: [ChartDataEntry]?)
    {
        self.init(entries: entries, label: "DataSet")
    }
    
    // MARK: - Data functions and accessors

    /// - Note: Calls `notifyDataSetChanged()` after setting a new value.
    /// - Returns: The array of y-values that this DataSet represents.
    /// the entries that this dataset represents / holds together
    @available(*, unavailable, renamed: "entries")
    @objc
    open var values: [ChartDataEntry] { return entries }

    @objc
    open private(set) var entries: [ChartDataEntry]

    /// Used to replace all entries of a data set while retaining styling properties.
    /// This is a separate method from a setter on `entries` to encourage usage
    /// of `Collection` conformances.
    ///
    /// - Parameter entries: new entries to replace existing entries in the dataset
    @objc
    public func replaceEntries(_ entries: [ChartDataEntry]) {
        self.entries = entries
        notifyDataSetChanged()
    }

    /// maximum y-value in the value array
    internal var _yMax: Double = -Double.greatestFiniteMagnitude
    
    /// minimum y-value in the value array
    internal var _yMin: Double = Double.greatestFiniteMagnitude
    
    /// maximum x-value in the value array
    internal var _xMax: Double = -Double.greatestFiniteMagnitude
    
    /// minimum x-value in the value array
    internal var _xMin: Double = Double.greatestFiniteMagnitude
    
    open override func calcMinMax()
    {
        _yMax = -Double.greatestFiniteMagnitude
        _yMin = Double.greatestFiniteMagnitude
        _xMax = -Double.greatestFiniteMagnitude
        _xMin = Double.greatestFiniteMagnitude

        guard !isEmpty else { return }

        forEach(calcMinMax)
    }
    
    open override func calcMinMaxY(fromX: Double, toX: Double)
    {
        _yMax = -Double.greatestFiniteMagnitude
        _yMin = Double.greatestFiniteMagnitude

        guard !isEmpty else { return }
        
        let indexFrom = entryIndex(x: fromX, closestToY: Double.nan, rounding: .down)
        let indexTo = entryIndex(x: toX, closestToY: Double.nan, rounding: .up)
        
        guard !(indexTo < indexFrom) else { return }
        // only recalculate y
        self[indexFrom...indexTo].forEach(calcMinMaxY)
    }
    
    @objc open func calcMinMaxX(entry e: ChartDataEntry)
    {
        if e.x < _xMin
        {
            _xMin = e.x
        }
        if e.x > _xMax
        {
            _xMax = e.x
        }
    }
    
    @objc open func calcMinMaxY(entry e: ChartDataEntry)
    {
        if e.y < _yMin
        {
            _yMin = e.y
        }
        if e.y > _yMax
        {
            _yMax = e.y
        }
    }
    
    /// Updates the min and max x and y value of this DataSet based on the given Entry.
    ///
    /// - Parameters:
    ///   - e:
    internal func calcMinMax(entry e: ChartDataEntry)
    {
        calcMinMaxX(entry: e)
        calcMinMaxY(entry: e)
    }
    
    /// The minimum y-value this DataSet holds
    open override var yMin: Double { return _yMin }
    
    /// The maximum y-value this DataSet holds
    open override var yMax: Double { return _yMax }
    
    /// The minimum x-value this DataSet holds
    open override var xMin: Double { return _xMin }
    
    /// The maximum x-value this DataSet holds
    open override var xMax: Double { return _xMax }
    
    /// The number of y-values this DataSet represents
    @available(*, deprecated, message: "Use `count` instead")
    open override var entryCount: Int { return count }
    
    /// - Throws: out of bounds
    /// if `i` is out of bounds, it may throw an out-of-bounds exception
    /// - Returns: The entry object found at the given index (not x-value!)
    @available(*, deprecated, message: "Use `subscript(index:)` instead.")
    open override func entryForIndex(_ i: Int) -> ChartDataEntry?
    {
        guard i >= startIndex, i < endIndex else {
            return nil
        }
        return self[i]
    }
    
    /// - Parameters:
    ///   - xValue: the x-value
    ///   - closestToY: If there are multiple y-values for the specified x-value,
    ///   - rounding: determine whether to round up/down/closest if there is no Entry matching the provided x-value
    /// - Returns: The first Entry object found at the given x-value with binary search.
    /// If the no Entry at the specified x-value is found, this method returns the Entry at the closest x-value according to the rounding.
    /// nil if no Entry object at that x-value.
    open override func entryForXValue(
        _ xValue: Double,
        closestToY yValue: Double,
        rounding: ChartDataSetRounding) -> ChartDataEntry?
    {
        let index = entryIndex(x: xValue, closestToY: yValue, rounding: rounding)
        if index > -1
        {
            return self[index]
        }
        return nil
    }
    
    /// - Parameters:
    ///   - xValue: the x-value
    ///   - closestToY: If there are multiple y-values for the specified x-value,
    /// - Returns: The first Entry object found at the given x-value with binary search.
    /// If the no Entry at the specified x-value is found, this method returns the Entry at the closest x-value.
    /// nil if no Entry object at that x-value.
    open override func entryForXValue(
        _ xValue: Double,
        closestToY yValue: Double) -> ChartDataEntry?
    {
        return entryForXValue(xValue, closestToY: yValue, rounding: .closest)
    }
    
    /// - Returns: All Entry objects found at the given xIndex with binary search.
    /// An empty array if no Entry object at that index.
    open override func entriesForXValue(_ xValue: Double) -> [ChartDataEntry]
    {
        var entries = [ChartDataEntry]()
        
        var low = startIndex
        var high = endIndex - 1
        
        while low <= high
        {
            var m = (high + low) / 2
            var entry = self[m]
            
            // if we have a match
            if xValue == entry.x
            {
                while m > 0 && self[m - 1].x == xValue
                {
                    m -= 1
                }
                
                high = endIndex
                
                // loop over all "equal" entries
                while m < high
                {
                    entry = self[m]
                    if entry.x == xValue
                    {
                        entries.append(entry)
                    }
                    else
                    {
                        break
                    }
                    
                    m += 1
                }
                
                break
            }
            else
            {
                if xValue > entry.x
                {
                    low = m + 1
                }
                else
                {
                    high = m - 1
                }
            }
        }
        
        return entries
    }
    
    /// - Parameters:
    ///   - xValue: x-value of the entry to search for
    ///   - closestToY: If there are multiple y-values for the specified x-value,
    ///   - rounding: Rounding method if exact value was not found
    /// - Returns: The array-index of the specified entry.
    /// If the no Entry at the specified x-value is found, this method returns the index of the Entry at the closest x-value according to the rounding.
    open override func entryIndex(
        x xValue: Double,
        closestToY yValue: Double,
        rounding: ChartDataSetRounding) -> Int
    {
        var low = startIndex
        var high = endIndex - 1
        var closest = high
        
        while low < high
        {
            let m = (low + high) / 2
            
            let d1 = self[m].x - xValue
            let d2 = self[m + 1].x - xValue
            let ad1 = abs(d1), ad2 = abs(d2)
            
            if ad2 < ad1
            {
                // [m + 1] is closer to xValue
                // Search in an higher place
                low = m + 1
            }
            else if ad1 < ad2
            {
                // [m] is closer to xValue
                // Search in a lower place
                high = m
            }
            else
            {
                // We have multiple sequential x-value with same distance
                
                if d1 >= 0.0
                {
                    // Search in a lower place
                    high = m
                }
                else if d1 < 0.0
                {
                    // Search in an higher place
                    low = m + 1
                }
            }
            
            closest = high
        }
        
        if closest != -1
        {
            let closestXValue = self[closest].x
            
            if rounding == .up
            {
                // If rounding up, and found x-value is lower than specified x, and we can go upper...
                if closestXValue < xValue && closest < endIndex - 1
                {
                    closest += 1
                }
            }
            else if rounding == .down
            {
                // If rounding down, and found x-value is upper than specified x, and we can go lower...
                if closestXValue > xValue && closest > 0
                {
                    closest -= 1
                }
            }
            
            // Search by closest to y-value
            if !yValue.isNaN
            {
                while closest > 0 && self[closest - 1].x == closestXValue
                {
                    closest -= 1
                }
                
                var closestYValue = self[closest].y
                var closestYIndex = closest
                
                while true
                {
                    closest += 1
                    if closest >= endIndex { break }
                    
                    let value = self[closest]
                    
                    if value.x != closestXValue { break }
                    if abs(value.y - yValue) <= abs(closestYValue - yValue)
                    {
                        closestYValue = yValue
                        closestYIndex = closest
                    }
                }
                
                closest = closestYIndex
            }
        }
        
        return closest
    }
    
    /// - Parameters:
    ///   - e: the entry to search for
    /// - Returns: The array-index of the specified entry
    @available(*, deprecated, message: "Use `firstIndex(of:)` or `lastIndex(of:)`")
    open override func entryIndex(entry e: ChartDataEntry) -> Int
    {
        return firstIndex(of: e) ?? -1
    }
    
    /// Adds an Entry to the DataSet dynamically.
    /// Entries are added to the end of the list.
    /// This will also recalculate the current minimum and maximum values of the DataSet and the value-sum.
    ///
    /// - Parameters:
    ///   - e: the entry to add
    /// - Returns: True
    @available(*, deprecated, message: "Use `append(_:)` instead")
    open override func addEntry(_ e: ChartDataEntry) -> Bool
    {
        append(e)
        return true
    }
    
    /// Adds an Entry to the DataSet dynamically.
    /// Entries are added to their appropriate index respective to it's x-index.
    /// This will also recalculate the current minimum and maximum values of the DataSet and the value-sum.
    ///
    /// - Parameters:
    ///   - e: the entry to add
    /// - Returns: True
    open override func addEntryOrdered(_ e: ChartDataEntry) -> Bool
    {
        calcMinMax(entry: e)
        
        if let last = last, last.x > e.x
        {
            var closestIndex = entryIndex(x: e.x, closestToY: e.y, rounding: .up)
            while self[closestIndex].x < e.x
            {
                closestIndex += 1
            }
            entries.insert(e, at: closestIndex)
        }
        else
        {
            append(e)
        }
        
        return true
    }
    
    @available(*, renamed: "remove(_:)")
    open override func removeEntry(_ entry: ChartDataEntry) -> Bool
    {
        return remove(entry)
    }

    /// Removes an Entry from the DataSet dynamically.
    /// This will also recalculate the current minimum and maximum values of the DataSet and the value-sum.
    ///
    /// - Parameters:
    ///   - entry: the entry to remove
    /// - Returns: `true` if the entry was removed successfully, else if the entry does not exist
    open func remove(_ entry: ChartDataEntry) -> Bool
    {
        guard let index = firstIndex(of: entry) else { return false }
        _ = remove(at: index)
        return true
    }

    /// Removes the first Entry (at index 0) of this DataSet from the entries array.
    ///
    /// - Returns: `true` if successful, `false` if not.
    @available(*, deprecated, message: "Use `func removeFirst() -> ChartDataEntry` instead.")
    open override func removeFirst() -> Bool
    {
        let entry: ChartDataEntry? = isEmpty ? nil : removeFirst()
        return entry != nil
    }
    
    /// Removes the last Entry (at index size-1) of this DataSet from the entries array.
    ///
    /// - Returns: `true` if successful, `false` if not.
    @available(*, deprecated, message: "Use `func removeLast() -> ChartDataEntry` instead.")
    open override func removeLast() -> Bool
    {
        let entry: ChartDataEntry? = isEmpty ? nil : removeLast()
        return entry != nil
    }

    /// Removes all values from this DataSet and recalculates min and max value.
    @available(*, deprecated, message: "Use `removeAll(keepingCapacity:)` instead.")
    open override func clear()
    {
        removeAll(keepingCapacity: true)
    }
    
    // MARK: - Data functions and accessors

    // MARK: - NSCopying
    
    open override func copy(with zone: NSZone? = nil) -> Any
    {
        let copy = super.copy(with: zone) as! ChartDataSet
        
        copy.entries = entries
        copy._yMax = _yMax
        copy._yMin = _yMin
        copy._xMax = _xMax
        copy._xMin = _xMin

        return copy
    }
}

// MARK: MutableCollection
extension ChartDataSet: MutableCollection {
    public typealias Index = Int
    public typealias Element = ChartDataEntry

    public var startIndex: Index {
        return entries.startIndex
    }

    public var endIndex: Index {
        return entries.endIndex
    }

    public func index(after: Index) -> Index {
        return entries.index(after: after)
    }

    @objc
    public subscript(position: Index) -> Element {
        get {
            // This is intentionally not a safe subscript to mirror
            // the behaviour of the built in Swift Collection Types
            return entries[position]
        }
        set {
            calcMinMax(entry: newValue)
            entries[position] = newValue
        }
    }
}

// MARK: RandomAccessCollection
extension ChartDataSet: RandomAccessCollection {
    public func index(before: Index) -> Index {
        return entries.index(before: before)
    }
}

// MARK: RangeReplaceableCollection
extension ChartDataSet: RangeReplaceableCollection {
    public func append(_ newElement: Element) {
        calcMinMax(entry: newElement)
        entries.append(newElement)
    }

    public func remove(at position: Index) -> Element {
        let element = entries.remove(at: position)
        notifyDataSetChanged()
        return element
    }

    public func removeFirst() -> Element {
        let element = entries.removeFirst()
        notifyDataSetChanged()
        return element
    }

    public func removeFirst(_ n: Int) {
        entries.removeFirst(n)
        notifyDataSetChanged()
    }

    public func removeLast() -> Element {
        let element = entries.removeLast()
        notifyDataSetChanged()
        return element
    }

    public func removeLast(_ n: Int) {
        entries.removeLast(n)
        notifyDataSetChanged()
    }

    public func removeSubrange<R>(_ bounds: R) where R : RangeExpression, Index == R.Bound {
        entries.removeSubrange(bounds)
        notifyDataSetChanged()
    }

    @objc
    public func removeAll(keepingCapacity keepCapacity: Bool) {
        entries.removeAll(keepingCapacity: keepCapacity)
        notifyDataSetChanged()
    }
}
