//
//  TransformerHorizontalBarChart.swift
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

@objc(ChartTransformerHorizontalBarChart)
open class TransformerHorizontalBarChart: Transformer
{
    /// Prepares the matrix that contains all offsets.
    open override func prepareMatrixOffset(inverted: Bool)
    {
        if !inverted
        {
            _matrixOffset = CGAffineTransform(translationX: _viewPortHandler.offsetLeft, y: _viewPortHandler.chartHeight - _viewPortHandler.offsetBottom)
        }
        else
        {
            _matrixOffset = CGAffineTransform(scaleX: -1.0, y: 1.0)
            _matrixOffset = _matrixOffset.translatedBy(x: -(_viewPortHandler.chartWidth - _viewPortHandler.offsetRight),
                y: _viewPortHandler.chartHeight - _viewPortHandler.offsetBottom)
        }
    }
}
