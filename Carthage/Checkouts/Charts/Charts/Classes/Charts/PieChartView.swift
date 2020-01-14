//
//  PieChartView.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 4/3/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import UIKit

/// View that represents a pie chart. Draws cake like slices.
public class PieChartView: PieRadarChartViewBase
{
    /// rect object that represents the bounds of the piechart, needed for drawing the circle
    private var _circleBox = CGRect()
    
    /// array that holds the width of each pie-slice in degrees
    private var _drawAngles = [CGFloat]()
    
    /// array that holds the absolute angle in degrees of each slice
    private var _absoluteAngles = [CGFloat]()

    public override init(frame: CGRect)
    {
        super.init(frame: frame)
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    internal override func initialize()
    {
        super.initialize()
        
        renderer = PieChartRenderer(chart: self, animator: _animator, viewPortHandler: _viewPortHandler)
    }
    
    public override func drawRect(rect: CGRect)
    {
        super.drawRect(rect)
        
        if (_dataNotSet)
        {
            return
        }
        
        let context = UIGraphicsGetCurrentContext()
        
        renderer!.drawData(context: context)
        
        if (valuesToHighlight())
        {
            renderer!.drawHighlighted(context: context, indices: _indicesToHightlight)
        }
        
        renderer!.drawExtras(context: context)
        
        renderer!.drawValues(context: context)
        
        _legendRenderer.renderLegend(context: context)
        
        drawDescription(context: context)
        
        drawMarkers(context: context)
    }
    
    internal override func calculateOffsets()
    {
        super.calculateOffsets()
        
        // prevent nullpointer when no data set
        if (_dataNotSet)
        {
            return
        }
        
        let radius = diameter / 2.0
        
        let c = centerOffsets
        
        let dataSets = data?.dataSets as? [PieChartDataSet]
        
        let maxShift = dataSets?.reduce(0.0, combine: { shift, dataSet in
            return dataSet.selectionShift > shift ? dataSet.selectionShift : shift
        }) ?? 0.0
        
        // create the circle box that will contain the pie-chart (the bounds of the pie-chart)
        _circleBox.origin.x = (c.x - radius) + (maxShift / 2.0)
        _circleBox.origin.y = (c.y - radius) + (maxShift / 2.0)
        _circleBox.size.width = diameter - maxShift
        _circleBox.size.height = diameter - maxShift
    }
    
    internal override func calcMinMax()
    {
        super.calcMinMax()
        
        calcAngles()
    }
    
    public override func getMarkerPosition(entry e: ChartDataEntry, highlight: ChartHighlight) -> CGPoint
    {
        let center = self.centerCircleBox
        var r = self.radius
        
        var off = r / 10.0 * 3.6
        
        if self.isDrawHoleEnabled
        {
            off = (r - (r * self.holeRadiusPercent)) / 2.0
        }
        
        r -= off // offset to keep things inside the chart
        
        let rotationAngle = self.rotationAngle
        
        let i = e.xIndex
        
        // offset needed to center the drawn text in the slice
        let offset = drawAngles[i] / 2.0
        
        // calculate the text position
        let x: CGFloat = (r * cos(((rotationAngle + absoluteAngles[i] - offset) * _animator.phaseY) * ChartUtils.Math.FDEG2RAD) + center.x)
        let y: CGFloat = (r * sin(((rotationAngle + absoluteAngles[i] - offset) * _animator.phaseY) * ChartUtils.Math.FDEG2RAD) + center.y)
        
        return CGPoint(x: x, y: y)
    }
    
    /// calculates the needed angles for the chart slices
    private func calcAngles()
    {
        _drawAngles = [CGFloat]()
        _absoluteAngles = [CGFloat]()
        
        _drawAngles.reserveCapacity(_data.yValCount)
        _absoluteAngles.reserveCapacity(_data.yValCount)
        
        var dataSets = _data.dataSets

        var cnt = 0

        for (var i = 0; i < _data.dataSetCount; i++)
        {
            let set = dataSets[i]
            var entries = set.yVals

            for (var j = 0; j < entries.count; j++)
            {
                _drawAngles.append(calcAngle(abs(entries[j].value)))

                if (cnt == 0)
                {
                    _absoluteAngles.append(_drawAngles[cnt])
                }
                else
                {
                    _absoluteAngles.append(_absoluteAngles[cnt - 1] + _drawAngles[cnt])
                }

                cnt++
            }
        }
    }
    
    /// checks if the given index in the given DataSet is set for highlighting or not
    public func needsHighlight(xIndex xIndex: Int, dataSetIndex: Int) -> Bool
    {
        // no highlight
        if (!valuesToHighlight() || dataSetIndex < 0)
        {
            return false
        }
        
        for (var i = 0; i < _indicesToHightlight.count; i++)
        {
            // check if the xvalue for the given dataset needs highlight
            if (_indicesToHightlight[i].xIndex == xIndex
                && _indicesToHightlight[i].dataSetIndex == dataSetIndex)
            {
                return true
            }
        }
        
        return false
    }
    
    /// calculates the needed angle for a given value
    private func calcAngle(value: Double) -> CGFloat
    {
        return CGFloat(value) / CGFloat(_data.yValueSum) * 360.0
    }
    
    public override func indexForAngle(angle: CGFloat) -> Int
    {
        // take the current angle of the chart into consideration
        let a = ChartUtils.normalizedAngleFromAngle(angle - self.rotationAngle)
        for (var i = 0; i < _absoluteAngles.count; i++)
        {
            if (_absoluteAngles[i] > a)
            {
                return i
            }
        }
        
        return -1; // return -1 if no index found
    }
    
    /// - returns: the index of the DataSet this x-index belongs to.
    public func dataSetIndexForIndex(xIndex: Int) -> Int
    {
        var dataSets = _data.dataSets
        
        for (var i = 0; i < dataSets.count; i++)
        {
            if (dataSets[i].entryForXIndex(xIndex) !== nil)
            {
                return i
            }
        }
        
        return -1
    }
    
    /// - returns: an integer array of all the different angles the chart slices
    /// have the angles in the returned array determine how much space (of 360°)
    /// each slice takes
    public var drawAngles: [CGFloat]
    {
        return _drawAngles
    }

    /// - returns: the absolute angles of the different chart slices (where the
    /// slices end)
    public var absoluteAngles: [CGFloat]
    {
        return _absoluteAngles
    }
    
    /// Sets the color for the hole that is drawn in the center of the PieChart (if enabled).
    /// 
    /// *Note: Use holeTransparent with holeColor = nil to make the hole transparent.*
    public var holeColor: UIColor?
    {
        get
        {
            return (renderer as! PieChartRenderer).holeColor!
        }
        set
        {
            (renderer as! PieChartRenderer).holeColor = newValue
            setNeedsDisplay()
        }
    }
    
    /// Set the hole in the center of the PieChart transparent
    public var holeTransparent: Bool
    {
        get
        {
            return (renderer as! PieChartRenderer).holeTransparent
        }
        set
        {
            (renderer as! PieChartRenderer).holeTransparent = newValue
            setNeedsDisplay()
        }
    }
    
    /// - returns: true if the hole in the center of the PieChart is transparent, false if not.
    public var isHoleTransparent: Bool 
    {
        return (renderer as! PieChartRenderer).holeTransparent
    }
    
    /// true if the hole in the center of the pie-chart is set to be visible, false if not
    public var drawHoleEnabled: Bool
    {
        get
        {
            return (renderer as! PieChartRenderer).drawHoleEnabled
        }
        set
        {
            (renderer as! PieChartRenderer).drawHoleEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// - returns: true if the hole in the center of the pie-chart is set to be visible, false if not
    public var isDrawHoleEnabled: Bool
    {
        get
        {
            return (renderer as! PieChartRenderer).drawHoleEnabled
        }
    }
    
    /// the text that is displayed in the center of the pie-chart. By default, the text is "Total value + sum of all values"
    public var centerText: String!
    {
        get
        {
            return (renderer as! PieChartRenderer).centerText
        }
        set
        {
            (renderer as! PieChartRenderer).centerText = newValue
            setNeedsDisplay()
        }
    }
    
    /// true if drawing the center text is enabled
    public var drawCenterTextEnabled: Bool
    {
        get
        {
            return (renderer as! PieChartRenderer).drawCenterTextEnabled
        }
        set
        {
            (renderer as! PieChartRenderer).drawCenterTextEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// - returns: true if drawing the center text is enabled
    public var isDrawCenterTextEnabled: Bool
    {
        get
        {
            return (renderer as! PieChartRenderer).drawCenterTextEnabled
        }
    }
    
    internal override var requiredLegendOffset: CGFloat
    {
        return _legend.font.pointSize * 2.0
    }
    
    internal override var requiredBaseOffset: CGFloat
    {
        return 0.0
    }
    
    public override var radius: CGFloat
    {
        return _circleBox.width / 2.0
    }
    
    /// - returns: the circlebox, the boundingbox of the pie-chart slices
    public var circleBox: CGRect
    {
        return _circleBox
    }
    
    /// - returns: the center of the circlebox
    public var centerCircleBox: CGPoint
    {
        return CGPoint(x: _circleBox.midX, y: _circleBox.midY)
    }
    
    /// Sets the font of the center text of the piechart.
    public var centerTextFont: UIFont
    {
        get
        {
            return (renderer as! PieChartRenderer).centerTextFont
        }
        set
        {
            (renderer as! PieChartRenderer).centerTextFont = newValue
            setNeedsDisplay()
        }
    }
    
    /// Sets the color of the center text of the piechart.
    public var centerTextColor: UIColor
    {
        get
        {
            return (renderer as! PieChartRenderer).centerTextColor
        }
        set
        {
            (renderer as! PieChartRenderer).centerTextColor = newValue
            setNeedsDisplay()
        }
    }
    
    /// the radius of the hole in the center of the piechart in percent of the maximum radius (max = the radius of the whole chart)
    /// 
    /// **default**: 0.5 (50%) (half the pie)
    public var holeRadiusPercent: CGFloat
    {
        get
        {
            return (renderer as! PieChartRenderer).holeRadiusPercent
        }
        set
        {
            (renderer as! PieChartRenderer).holeRadiusPercent = newValue
            setNeedsDisplay()
        }
    }
    
    /// the radius of the transparent circle that is drawn next to the hole in the piechart in percent of the maximum radius (max = the radius of the whole chart)
    /// 
    /// **default**: 0.55 (55%) -> means 5% larger than the center-hole by default
    public var transparentCircleRadiusPercent: CGFloat
    {
        get
        {
            return (renderer as! PieChartRenderer).transparentCircleRadiusPercent
        }
        set
        {
            (renderer as! PieChartRenderer).transparentCircleRadiusPercent = newValue
            setNeedsDisplay()
        }
    }
    
    /// set this to true to draw the x-value text into the pie slices
    public var drawSliceTextEnabled: Bool
    {
        get
        {
            return (renderer as! PieChartRenderer).drawXLabelsEnabled
        }
        set
        {
            (renderer as! PieChartRenderer).drawXLabelsEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// - returns: true if drawing x-values is enabled, false if not
    public var isDrawSliceTextEnabled: Bool
    {
        get
        {
            return (renderer as! PieChartRenderer).drawXLabelsEnabled
        }
    }
    
    /// If this is enabled, values inside the PieChart are drawn in percent and not with their original value. Values provided for the ValueFormatter to format are then provided in percent.
    public var usePercentValuesEnabled: Bool
    {
        get
        {
            return (renderer as! PieChartRenderer).usePercentValuesEnabled
        }
        set
        {
            (renderer as! PieChartRenderer).usePercentValuesEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// - returns: true if drawing x-values is enabled, false if not
    public var isUsePercentValuesEnabled: Bool
    {
        get
        {
            return (renderer as! PieChartRenderer).usePercentValuesEnabled
        }
    }
    
    
    /// the line break mode for center text.
    /// note that different line break modes give different performance results - Clipping being the fastest, WordWrapping being the slowst.
    public var centerTextLineBreakMode: NSLineBreakMode
    {
        get
        {
            return (renderer as! PieChartRenderer).centerTextLineBreakMode
        }
        set
        {
            (renderer as! PieChartRenderer).centerTextLineBreakMode = newValue
            setNeedsDisplay()
        }
    }
    
    /// the rectangular radius of the bounding box for the center text, as a percentage of the pie hole
    public var centerTextRadiusPercent: CGFloat
    {
        get
        {
            return (renderer as! PieChartRenderer).centerTextRadiusPercent
        }
        set
        {
            (renderer as! PieChartRenderer).centerTextRadiusPercent = newValue
            setNeedsDisplay()
        }
    }
}