//
//  PieChartView.swift
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

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(Cocoa)
import Cocoa
#endif

/// View that represents a pie chart. Draws cake like slices.
open class PieChartView: PieRadarChartViewBase
{
    /// rect object that represents the bounds of the piechart, needed for drawing the circle
    private var _circleBox = CGRect()
    
    /// flag indicating if entry labels should be drawn or not
    private var _drawEntryLabelsEnabled = true
    
    /// array that holds the width of each pie-slice in degrees
    private var _drawAngles = [CGFloat]()
    
    /// array that holds the absolute angle in degrees of each slice
    private var _absoluteAngles = [CGFloat]()
    
    /// if true, the hole inside the chart will be drawn
    private var _drawHoleEnabled = true
    
    private var _holeColor: NSUIColor? = NSUIColor.white
    
    /// Sets the color the entry labels are drawn with.
    private var _entryLabelColor: NSUIColor? = NSUIColor.white
    
    /// Sets the font the entry labels are drawn with.
    private var _entryLabelFont: NSUIFont? = NSUIFont(name: "HelveticaNeue", size: 13.0)
    
    /// if true, the hole will see-through to the inner tips of the slices
    private var _drawSlicesUnderHoleEnabled = false
    
    /// if true, the values inside the piechart are drawn as percent values
    private var _usePercentValuesEnabled = false
    
    /// variable for the text that is drawn in the center of the pie-chart
    private var _centerAttributedText: NSAttributedString?
    
    /// the offset on the x- and y-axis the center text has in dp.
    private var _centerTextOffset: CGPoint = CGPoint()
    
    /// indicates the size of the hole in the center of the piechart
    ///
    /// **default**: `0.5`
    private var _holeRadiusPercent = CGFloat(0.5)
    
    private var _transparentCircleColor: NSUIColor? = NSUIColor(white: 1.0, alpha: 105.0/255.0)
    
    /// the radius of the transparent circle next to the chart-hole in the center
    private var _transparentCircleRadiusPercent = CGFloat(0.55)
    
    /// if enabled, centertext is drawn
    private var _drawCenterTextEnabled = true
    
    private var _centerTextRadiusPercent: CGFloat = 1.0
    
    /// maximum angle for this pie
    private var _maxAngle: CGFloat = 360.0

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
        _xAxis = nil
        
        self.highlighter = PieHighlighter(chart: self)
    }
    
    open override func draw(_ rect: CGRect)
    {
        super.draw(rect)
        
        if _data === nil
        {
            return
        }
        
        let optionalContext = NSUIGraphicsGetCurrentContext()
        guard let context = optionalContext, let renderer = renderer else
        {
            return
        }
        
        renderer.drawData(context: context)
        
        if (valuesToHighlight())
        {
            renderer.drawHighlighted(context: context, indices: _indicesToHighlight)
        }
        
        renderer.drawExtras(context: context)
        
        renderer.drawValues(context: context)
        
        legendRenderer.renderLegend(context: context)
        
        drawDescription(context: context)
        
        drawMarkers(context: context)
    }
    
    internal override func calculateOffsets()
    {
        super.calculateOffsets()
        
        // prevent nullpointer when no data set
        if _data === nil
        {
            return
        }
        
        let radius = diameter / 2.0
        
        let c = self.centerOffsets
        
        let shift = (data as? PieChartData)?.dataSet?.selectionShift ?? 0.0
        
        // create the circle box that will contain the pie-chart (the bounds of the pie-chart)
        _circleBox.origin.x = (c.x - radius) + shift
        _circleBox.origin.y = (c.y - radius) + shift
        _circleBox.size.width = diameter - shift * 2.0
        _circleBox.size.height = diameter - shift * 2.0
    }
    
    internal override func calcMinMax()
    {
        calcAngles()
    }
    
    open override func getMarkerPosition(highlight: Highlight) -> CGPoint
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
        
        let entryIndex = Int(highlight.x)
        
        // offset needed to center the drawn text in the slice
        let offset = drawAngles[entryIndex] / 2.0
        
        // calculate the text position
        let x: CGFloat = (r * cos(((rotationAngle + absoluteAngles[entryIndex] - offset) * CGFloat(_animator.phaseY)).DEG2RAD) + center.x)
        let y: CGFloat = (r * sin(((rotationAngle + absoluteAngles[entryIndex] - offset) * CGFloat(_animator.phaseY)).DEG2RAD) + center.y)
        
        return CGPoint(x: x, y: y)
    }
    
    /// calculates the needed angles for the chart slices
    private func calcAngles()
    {
        _drawAngles = [CGFloat]()
        _absoluteAngles = [CGFloat]()
        
        guard let data = _data else { return }

        let entryCount = data.entryCount
        
        _drawAngles.reserveCapacity(entryCount)
        _absoluteAngles.reserveCapacity(entryCount)
        
        let yValueSum = (_data as! PieChartData).yValueSum

        var cnt = 0

        for set in data.dataSets
        {
            for j in 0 ..< set.entryCount
            {
                guard let e = set.entryForIndex(j) else { continue }
                
                _drawAngles.append(calcAngle(value: abs(e.y), yValueSum: yValueSum))

                if cnt == 0
                {
                    _absoluteAngles.append(_drawAngles[cnt])
                }
                else
                {
                    _absoluteAngles.append(_absoluteAngles[cnt - 1] + _drawAngles[cnt])
                }

                cnt += 1
            }
        }
    }
    
    /// Checks if the given index is set to be highlighted.
    @objc open func needsHighlight(index: Int) -> Bool
    {
        return _indicesToHighlight.contains { Int($0.x) == index }
    }
    
    /// calculates the needed angle for a given value
    private func calcAngle(_ value: Double) -> CGFloat
    {
        return calcAngle(value: value, yValueSum: (_data as! PieChartData).yValueSum)
    }
    
    /// calculates the needed angle for a given value
    private func calcAngle(value: Double, yValueSum: Double) -> CGFloat
    {
        return CGFloat(value) / CGFloat(yValueSum) * _maxAngle
    }
    
    /// This will throw an exception, PieChart has no XAxis object.
    open override var xAxis: XAxis
    {
        fatalError("PieChart has no XAxis")
    }

    open override func indexForAngle(_ angle: CGFloat) -> Int
    {
        // TODO: Return nil instead of -1
        // take the current angle of the chart into consideration
        let a = (angle - self.rotationAngle).normalizedAngle
        return _absoluteAngles.firstIndex { $0 > a } ?? -1
    }
    
    /// - Returns: The index of the DataSet this x-index belongs to.
    @objc open func dataSetIndexForIndex(_ xValue: Double) -> Int
    {
        // TODO: Return nil instead of -1
        return _data?.dataSets.firstIndex {
            $0.entryForXValue(xValue, closestToY: .nan) != nil
        } ?? -1
    }
    
    /// - Returns: An integer array of all the different angles the chart slices
    /// have the angles in the returned array determine how much space (of 360°)
    /// each slice takes
    @objc open var drawAngles: [CGFloat]
    {
        return _drawAngles
    }

    /// - Returns: The absolute angles of the different chart slices (where the
    /// slices end)
    @objc open var absoluteAngles: [CGFloat]
    {
        return _absoluteAngles
    }
    
    /// The color for the hole that is drawn in the center of the PieChart (if enabled).
    /// 
    /// - Note: Use holeTransparent with holeColor = nil to make the hole transparent.*
    @objc open var holeColor: NSUIColor?
    {
        get
        {
            return _holeColor
        }
        set
        {
            _holeColor = newValue
            setNeedsDisplay()
        }
    }
    
    /// if true, the hole will see-through to the inner tips of the slices
    ///
    /// **default**: `false`
    @objc open var drawSlicesUnderHoleEnabled: Bool
    {
        get
        {
            return _drawSlicesUnderHoleEnabled
        }
        set
        {
            _drawSlicesUnderHoleEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// `true` if the inner tips of the slices are visible behind the hole, `false` if not.
    @objc open var isDrawSlicesUnderHoleEnabled: Bool
    {
        return drawSlicesUnderHoleEnabled
    }
    
    /// `true` if the hole in the center of the pie-chart is set to be visible, `false` ifnot
    @objc open var drawHoleEnabled: Bool
    {
        get
        {
            return _drawHoleEnabled
        }
        set
        {
            _drawHoleEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// `true` if the hole in the center of the pie-chart is set to be visible, `false` ifnot
    @objc open var isDrawHoleEnabled: Bool
    {
        get
        {
            return drawHoleEnabled
        }
    }
    
    /// the text that is displayed in the center of the pie-chart
    @objc open var centerText: String?
    {
        get
        {
            return self.centerAttributedText?.string
        }
        set
        {
            var attrString: NSMutableAttributedString?
            if newValue == nil
            {
                attrString = nil
            }
            else
            {
                let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                paragraphStyle.lineBreakMode = .byTruncatingTail
                paragraphStyle.alignment = .center
                
                attrString = NSMutableAttributedString(string: newValue!)
                attrString?.setAttributes([
                    .foregroundColor: NSUIColor.black,
                    .font: NSUIFont.systemFont(ofSize: 12.0),
                    .paragraphStyle: paragraphStyle
                    ], range: NSMakeRange(0, attrString!.length))
            }
            self.centerAttributedText = attrString
        }
    }
    
    /// the text that is displayed in the center of the pie-chart
    @objc open var centerAttributedText: NSAttributedString?
    {
        get
        {
            return _centerAttributedText
        }
        set
        {
            _centerAttributedText = newValue
            setNeedsDisplay()
        }
    }
    
    /// Sets the offset the center text should have from it's original position in dp. Default x = 0, y = 0
    @objc open var centerTextOffset: CGPoint
    {
        get
        {
            return _centerTextOffset
        }
        set
        {
            _centerTextOffset = newValue
            setNeedsDisplay()
        }
    }
    
    /// `true` if drawing the center text is enabled
    @objc open var drawCenterTextEnabled: Bool
    {
        get
        {
            return _drawCenterTextEnabled
        }
        set
        {
            _drawCenterTextEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// `true` if drawing the center text is enabled
    @objc open var isDrawCenterTextEnabled: Bool
    {
        get
        {
            return drawCenterTextEnabled
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
    
    open override var radius: CGFloat
    {
        return _circleBox.width / 2.0
    }
    
    /// The circlebox, the boundingbox of the pie-chart slices
    @objc open var circleBox: CGRect
    {
        return _circleBox
    }
    
    /// The center of the circlebox
    @objc open var centerCircleBox: CGPoint
    {
        return CGPoint(x: _circleBox.midX, y: _circleBox.midY)
    }
    
    /// the radius of the hole in the center of the piechart in percent of the maximum radius (max = the radius of the whole chart)
    /// 
    /// **default**: 0.5 (50%) (half the pie)
    @objc open var holeRadiusPercent: CGFloat
    {
        get
        {
            return _holeRadiusPercent
        }
        set
        {
            _holeRadiusPercent = newValue
            setNeedsDisplay()
        }
    }
    
    /// The color that the transparent-circle should have.
    ///
    /// **default**: `nil`
    @objc open var transparentCircleColor: NSUIColor?
    {
        get
        {
            return _transparentCircleColor
        }
        set
        {
            _transparentCircleColor = newValue
            setNeedsDisplay()
        }
    }
    
    /// the radius of the transparent circle that is drawn next to the hole in the piechart in percent of the maximum radius (max = the radius of the whole chart)
    /// 
    /// **default**: 0.55 (55%) -> means 5% larger than the center-hole by default
    @objc open var transparentCircleRadiusPercent: CGFloat
    {
        get
        {
            return _transparentCircleRadiusPercent
        }
        set
        {
            _transparentCircleRadiusPercent = newValue
            setNeedsDisplay()
        }
    }
        
    /// The color the entry labels are drawn with.
    @objc open var entryLabelColor: NSUIColor?
    {
        get { return _entryLabelColor }
        set
        {
            _entryLabelColor = newValue
            setNeedsDisplay()
        }
    }
    
    /// The font the entry labels are drawn with.
    @objc open var entryLabelFont: NSUIFont?
    {
        get { return _entryLabelFont }
        set
        {
            _entryLabelFont = newValue
            setNeedsDisplay()
        }
    }
    
    /// Set this to true to draw the enrty labels into the pie slices
    @objc open var drawEntryLabelsEnabled: Bool
    {
        get
        {
            return _drawEntryLabelsEnabled
        }
        set
        {
            _drawEntryLabelsEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// `true` if drawing entry labels is enabled, `false` ifnot
    @objc open var isDrawEntryLabelsEnabled: Bool
    {
        get
        {
            return drawEntryLabelsEnabled
        }
    }
    
    /// If this is enabled, values inside the PieChart are drawn in percent and not with their original value. Values provided for the ValueFormatter to format are then provided in percent.
    @objc open var usePercentValuesEnabled: Bool
    {
        get
        {
            return _usePercentValuesEnabled
        }
        set
        {
            _usePercentValuesEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// `true` if drawing x-values is enabled, `false` ifnot
    @objc open var isUsePercentValuesEnabled: Bool
    {
        get
        {
            return usePercentValuesEnabled
        }
    }
    
    /// the rectangular radius of the bounding box for the center text, as a percentage of the pie hole
    @objc open var centerTextRadiusPercent: CGFloat
    {
        get
        {
            return _centerTextRadiusPercent
        }
        set
        {
            _centerTextRadiusPercent = newValue
            setNeedsDisplay()
        }
    }
    
    /// The max angle that is used for calculating the pie-circle.
    /// 360 means it's a full pie-chart, 180 results in a half-pie-chart.
    /// **default**: 360.0
    @objc open var maxAngle: CGFloat
    {
        get
        {
            return _maxAngle
        }
        set
        {
            _maxAngle = newValue
            
            if _maxAngle > 360.0
            {
                _maxAngle = 360.0
            }
            
            if _maxAngle < 90.0
            {
                _maxAngle = 90.0
            }
        }
    }
}
