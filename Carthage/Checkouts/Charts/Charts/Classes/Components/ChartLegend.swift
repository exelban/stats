//
//  ChartLegend.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 24/2/15.

//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import UIKit

public class ChartLegend: ChartComponentBase
{
    @objc
    public enum ChartLegendPosition: Int
    {
        case RightOfChart
        case RightOfChartCenter
        case RightOfChartInside
        case LeftOfChart
        case LeftOfChartCenter
        case LeftOfChartInside
        case BelowChartLeft
        case BelowChartRight
        case BelowChartCenter
        case AboveChartLeft
        case AboveChartRight
        case AboveChartCenter
        case PiechartCenter
    }
    
    @objc
    public enum ChartLegendForm: Int
    {
        case Square
        case Circle
        case Line
    }
    
    @objc
    public enum ChartLegendDirection: Int
    {
        case LeftToRight
        case RightToLeft
    }

    /// the legend colors array, each color is for the form drawn at the same index
    public var colors = [UIColor?]()
    
    // the legend text array. a nil label will start a group.
    public var labels = [String?]()
    
    internal var _extraColors = [UIColor?]()
    internal var _extraLabels = [String?]()
    
    /// colors that will be appended to the end of the colors array after calculating the legend.
    public var extraColors: [UIColor?] { return _extraColors; }
    
    /// labels that will be appended to the end of the labels array after calculating the legend. a nil label will start a group.
    public var extraLabels: [String?] { return _extraLabels; }
    
    /// Are the legend labels/colors a custom value or auto calculated? If false, then it's auto, if true, then custom.
    /// 
    /// **default**: false (automatic legend)
    private var _isLegendCustom = false

    public var position = ChartLegendPosition.BelowChartLeft
    public var direction = ChartLegendDirection.LeftToRight

    public var font: UIFont = UIFont.systemFontOfSize(10.0)
    public var textColor = UIColor.blackColor()

    public var form = ChartLegendForm.Square
    public var formSize = CGFloat(8.0)
    public var formLineWidth = CGFloat(1.5)
    
    public var xEntrySpace = CGFloat(6.0)
    public var yEntrySpace = CGFloat(0.0)
    public var formToTextSpace = CGFloat(5.0)
    public var stackSpace = CGFloat(3.0)
    
    /// Sets the x offset fo the legend.
    /// Higher offset means the legend as a whole will be placed further away from the left/right.
    /// Positive value will move the legend to the right when LTR, and to the left when RTL.
    public var xOffset = CGFloat(5.0)
    
    /// Sets the y offset fo the legend.
    /// Higher offset means the legend as a whole will be placed further away from the top.
    public var yOffset = CGFloat(7.0)
    
    public var calculatedLabelSizes = [CGSize]()
    public var calculatedLabelBreakPoints = [Bool]()
    public var calculatedLineSizes = [CGSize]()
    
    public override init()
    {
        super.init()
    }
    
    public init(colors: [UIColor?], labels: [String?])
    {
        super.init()
        
        self.colors = colors
        self.labels = labels
    }
    
    public init(colors: [NSObject], labels: [NSObject])
    {
        super.init()
        
        self.colorsObjc = colors
        self.labelsObjc = labels
    }
    
    public func getMaximumEntrySize(font: UIFont) -> CGSize
    {
        var maxW = CGFloat(0.0)
        var maxH = CGFloat(0.0)
        
        var labels = self.labels
        for (var i = 0; i < labels.count; i++)
        {
            if (labels[i] == nil)
            {
                continue
            }
            
            let size = (labels[i] as NSString!).sizeWithAttributes([NSFontAttributeName: font])
            
            if (size.width > maxW)
            {
                maxW = size.width
            }
            if (size.height > maxH)
            {
                maxH = size.height
            }
        }
        
        return CGSize(
            width: maxW + formSize + formToTextSpace,
            height: maxH
        )
    }
    
    public func getLabel(index: Int) -> String?
    {
        return labels[index]
    }
    
    public func getFullSize(labelFont: UIFont) -> CGSize
    {
        var width = CGFloat(0.0)
        var height = CGFloat(0.0)
        
        var labels = self.labels
        for (var i = 0, count = labels.count; i < count; i++)
        {
            if (labels[i] != nil)
            {
                // make a step to the left
                if (colors[i] != nil)
                {
                    width += formSize + formToTextSpace
                }
                
                let size = (labels[i] as NSString!).sizeWithAttributes([NSFontAttributeName: labelFont])
                
                width += size.width
                height += size.height
                
                if (i < count - 1)
                {
                    width += xEntrySpace
                    height += yEntrySpace
                }
            }
            else
            {
                width += formSize + stackSpace
                
                if (i < count - 1)
                {
                    width += stackSpace
                }
            }
        }
        
        return CGSize(width: width, height: height)
    }

    public var neededWidth = CGFloat(0.0)
    public var neededHeight = CGFloat(0.0)
    public var textWidthMax = CGFloat(0.0)
    public var textHeightMax = CGFloat(0.0)
    
    /// flag that indicates if word wrapping is enabled
    /// this is currently supported only for: `BelowChartLeft`, `BelowChartRight`, `BelowChartCenter`.
    /// note that word wrapping a legend takes a toll on performance.
    /// you may want to set maxSizePercent when word wrapping, to set the point where the text wraps.
    /// 
    /// **default**: false
    public var wordWrapEnabled = false
    
    /// if this is set, then word wrapping the legend is enabled.
    public var isWordWrapEnabled: Bool { return wordWrapEnabled }

    /// The maximum relative size out of the whole chart view in percent.
    /// If the legend is to the right/left of the chart, then this affects the width of the legend.
    /// If the legend is to the top/bottom of the chart, then this affects the height of the legend.
    /// If the legend is the center of the piechart, then this defines the size of the rectangular bounds out of the size of the "hole".
    /// 
    /// **default**: 0.95 (95%)
    public var maxSizePercent: CGFloat = 0.95
    
    public func calculateDimensions(labelFont labelFont: UIFont, viewPortHandler: ChartViewPortHandler)
    {
        if (position == .RightOfChart
            || position == .RightOfChartCenter
            || position == .LeftOfChart
            || position == .LeftOfChartCenter
            || position == .PiechartCenter)
        {
            let maxEntrySize = getMaximumEntrySize(labelFont)
            let fullSize = getFullSize(labelFont)
            
            neededWidth = maxEntrySize.width
            neededHeight = fullSize.height
            textWidthMax = maxEntrySize.width
            textHeightMax = maxEntrySize.height
        }
        else if (position == .BelowChartLeft
            || position == .BelowChartRight
            || position == .BelowChartCenter
            || position == .AboveChartLeft
            || position == .AboveChartRight
            || position == .AboveChartCenter)
        {
            var labels = self.labels
            var colors = self.colors
            let labelCount = labels.count
            
            let labelLineHeight = labelFont.lineHeight
            let formSize = self.formSize
            let formToTextSpace = self.formToTextSpace
            let xEntrySpace = self.xEntrySpace
            let stackSpace = self.stackSpace
            let wordWrapEnabled = self.wordWrapEnabled
            
            let contentWidth: CGFloat = viewPortHandler.contentWidth
            
            // Prepare arrays for calculated layout
            if (calculatedLabelSizes.count != labelCount)
            {
                calculatedLabelSizes = [CGSize](count: labelCount, repeatedValue: CGSize())
            }
            
            if (calculatedLabelBreakPoints.count != labelCount)
            {
                calculatedLabelBreakPoints = [Bool](count: labelCount, repeatedValue: false)
            }
            
            calculatedLineSizes.removeAll(keepCapacity: true)
            
            // Start calculating layout
            
            let labelAttrs = [NSFontAttributeName: labelFont]
            var maxLineWidth: CGFloat = 0.0
            var currentLineWidth: CGFloat = 0.0
            var requiredWidth: CGFloat = 0.0
            var stackedStartIndex: Int = -1
            
            for (var i = 0; i < labelCount; i++)
            {
                let drawingForm = colors[i] != nil
                
                calculatedLabelBreakPoints[i] = false
                
                if (stackedStartIndex == -1)
                {
                    // we are not stacking, so required width is for this label only
                    requiredWidth = 0.0
                }
                else
                {
                    // add the spacing appropriate for stacked labels/forms
                    requiredWidth += stackSpace
                }
                
                // grouped forms have null labels
                if (labels[i] != nil)
                {
                    calculatedLabelSizes[i] = (labels[i] as NSString!).sizeWithAttributes(labelAttrs)
                    requiredWidth += drawingForm ? formToTextSpace + formSize : 0.0
                    requiredWidth += calculatedLabelSizes[i].width
                }
                else
                {
                    calculatedLabelSizes[i] = CGSize()
                    requiredWidth += drawingForm ? formSize : 0.0
                    
                    if (stackedStartIndex == -1)
                    {
                        // mark this index as we might want to break here later
                        stackedStartIndex = i
                    }
                }
                
                if (labels[i] != nil || i == labelCount - 1)
                {
                    let requiredSpacing = currentLineWidth == 0.0 ? 0.0 : xEntrySpace
                    
                    if (!wordWrapEnabled || // No word wrapping, it must fit.
                        currentLineWidth == 0.0 || // The line is empty, it must fit.
                        (contentWidth - currentLineWidth >= requiredSpacing + requiredWidth)) // It simply fits
                    {
                        // Expand current line
                        currentLineWidth += requiredSpacing + requiredWidth
                    }
                    else
                    { // It doesn't fit, we need to wrap a line
                        
                        // Add current line size to array
                        calculatedLineSizes.append(CGSize(width: currentLineWidth, height: labelLineHeight))
                        maxLineWidth = max(maxLineWidth, currentLineWidth)
                        
                        // Start a new line
                        calculatedLabelBreakPoints[stackedStartIndex > -1 ? stackedStartIndex : i] = true
                        currentLineWidth = requiredWidth
                    }
                    
                    if (i == labelCount - 1)
                    { // Add last line size to array
                        calculatedLineSizes.append(CGSize(width: currentLineWidth, height: labelLineHeight))
                        maxLineWidth = max(maxLineWidth, currentLineWidth)
                    }
                }
                
                stackedStartIndex = labels[i] != nil ? -1 : stackedStartIndex
            }
            
            let maxEntrySize = getMaximumEntrySize(labelFont)
            
            textWidthMax = maxEntrySize.width
            textHeightMax = maxEntrySize.height
            neededWidth = maxLineWidth
            neededHeight = labelLineHeight * CGFloat(calculatedLineSizes.count) +
                yEntrySpace * CGFloat(calculatedLineSizes.count == 0 ? 0 : (calculatedLineSizes.count - 1))
        }
        else
        {
            let maxEntrySize = getMaximumEntrySize(labelFont)
            let fullSize = getFullSize(labelFont)
            
            /* RightOfChartInside, LeftOfChartInside */
            neededWidth = fullSize.width
            neededHeight = maxEntrySize.height
            textWidthMax = maxEntrySize.width
            textHeightMax = maxEntrySize.height
        }
    }
    
    /// MARK: - Custom legend
    
    /// colors and labels that will be appended to the end of the auto calculated colors and labels after calculating the legend.
    /// (if the legend has already been calculated, you will need to call notifyDataSetChanged() to let the changes take effect)
    public func setExtra(colors colors: [UIColor?], labels: [String?])
    {
        self._extraLabels = labels
        self._extraColors = colors
    }
    
    /// Sets a custom legend's labels and colors arrays.
    /// The colors count should match the labels count.
    /// * Each color is for the form drawn at the same index.
    /// * A nil label will start a group.
    /// * A nil color will avoid drawing a form, and a clearColor will leave a space for the form.
    /// This will disable the feature that automatically calculates the legend labels and colors from the datasets.
    /// Call `resetCustom(...)` to re-enable automatic calculation (and then `notifyDataSetChanged()` is needed).
    public func setCustom(colors colors: [UIColor?], labels: [String?])
    {
        self.labels = labels
        self.colors = colors
        _isLegendCustom = true
    }
    
    /// Calling this will disable the custom legend labels (set by `setLegend(...)`). Instead, the labels will again be calculated automatically (after `notifyDataSetChanged()` is called).
    public func resetCustom()
    {
        _isLegendCustom = false
    }
    
    /// **default**: false (automatic legend)
    /// - returns: true if a custom legend labels and colors has been set
    public var isLegendCustom: Bool
    {
        return _isLegendCustom
    }
    
    /// MARK: - ObjC compatibility
    
    /// colors that will be appended to the end of the colors array after calculating the legend.
    public var extraColorsObjc: [NSObject] { return ChartUtils.bridgedObjCGetUIColorArray(swift: _extraColors); }
    
    /// labels that will be appended to the end of the labels array after calculating the legend. a nil label will start a group.
    public var extraLabelsObjc: [NSObject] { return ChartUtils.bridgedObjCGetStringArray(swift: _extraLabels); }
    
    /// the legend colors array, each color is for the form drawn at the same index
    /// (ObjC bridging functions, as Swift 1.2 does not bridge optionals in array to `NSNull`s)
    public var colorsObjc: [NSObject]
    {
        get { return ChartUtils.bridgedObjCGetUIColorArray(swift: colors); }
        set { self.colors = ChartUtils.bridgedObjCGetUIColorArray(objc: newValue); }
    }
    
    // the legend text array. a nil label will start a group.
    /// (ObjC bridging functions, as Swift 1.2 does not bridge optionals in array to `NSNull`s)
    public var labelsObjc: [NSObject]
    {
        get { return ChartUtils.bridgedObjCGetStringArray(swift: labels); }
        set { self.labels = ChartUtils.bridgedObjCGetStringArray(objc: newValue); }
    }
    
    /// colors and labels that will be appended to the end of the auto calculated colors and labels after calculating the legend.
    /// (if the legend has already been calculated, you will need to call `notifyDataSetChanged()` to let the changes take effect)
    public func setExtra(colors colors: [NSObject], labels: [NSObject])
    {
        if (colors.count != labels.count)
        {
            fatalError("ChartLegend:setExtra() - colors array and labels array need to be of same size")
        }
        
        self._extraLabels = ChartUtils.bridgedObjCGetStringArray(objc: labels)
        self._extraColors = ChartUtils.bridgedObjCGetUIColorArray(objc: colors)
    }
    
    /// Sets a custom legend's labels and colors arrays.
    /// The colors count should match the labels count.
    /// * Each color is for the form drawn at the same index.
    /// * A nil label will start a group.
    /// * A nil color will avoid drawing a form, and a clearColor will leave a space for the form.
    /// This will disable the feature that automatically calculates the legend labels and colors from the datasets.
    /// Call `resetLegendToAuto(...)` to re-enable automatic calculation, and then if needed - call `notifyDataSetChanged()` on the chart to make it refresh the data.
    public func setCustom(colors colors: [NSObject], labels: [NSObject])
    {
        if (colors.count != labels.count)
        {
            fatalError("ChartLegend:setCustom() - colors array and labels array need to be of same size")
        }
        
        self.labelsObjc = labels
        self.colorsObjc = colors
        _isLegendCustom = true
    }
}
