//
//  DataApproximator.swift
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

@objc(ChartDataApproximator)
open class DataApproximator: NSObject
{
    /// uses the douglas peuker algorithm to reduce the given arraylist of entries
    @objc open class func reduceWithDouglasPeuker(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint]
    {
        // if a shape has 2 or less points it cannot be reduced
        if tolerance <= 0 || points.count < 3
        {
            return points
        }
        
        var keep = [Bool](repeating: false, count: points.count)
        
        // first and last always stay
        keep[0] = true
        keep[points.count - 1] = true
        
        // first and last entry are entry point to recursion
        reduceWithDouglasPeuker(points: points,
                                tolerance: tolerance,
                                start: 0,
                                end: points.count - 1,
                                keep: &keep)
        
        // create a new array with series, only take the kept ones
        return zip(keep, points).compactMap { $0 ? nil : $1 }
    }

    /// apply the Douglas-Peucker-Reduction to an array of `CGPoint`s with a given tolerance
    ///
    /// - Parameters:
    ///   - points:
    ///   - tolerance:
    ///   - start:
    ///   - end:
    open class func reduceWithDouglasPeuker(
        points: [CGPoint],
        tolerance: CGFloat,
        start: Int,
        end: Int,
        keep: inout [Bool])
    {
        if end <= start + 1
        {
            // recursion finished
            return
        }
        
        var greatestIndex = Int(0)
        var greatestDistance = CGFloat(0.0)
        
        let line = Line(pt1: points[start], pt2: points[end])
        
        for i in start + 1 ..< end
        {
            let distance = line.distance(toPoint: points[i])
            
            if distance > greatestDistance
            {
                greatestDistance = distance
                greatestIndex = i
            }
        }
        
        if greatestDistance > tolerance
        {
            // keep max dist point
            keep[greatestIndex] = true
            
            // recursive call
            reduceWithDouglasPeuker(points: points, tolerance: tolerance, start: start, end: greatestIndex, keep: &keep)
            reduceWithDouglasPeuker(points: points, tolerance: tolerance, start: greatestIndex, end: end, keep: &keep)
        } // else don't keep the point...
    }
    
    private class Line
    {
        var sxey: CGFloat
        var exsy: CGFloat
        
        var dx: CGFloat
        var dy: CGFloat
        
        var length: CGFloat
        
        init(pt1: CGPoint, pt2: CGPoint)
        {
            dx = pt1.x - pt2.x
            dy = pt1.y - pt2.y
            sxey = pt1.x * pt2.y
            exsy = pt2.x * pt1.y
            length = sqrt(dx * dx + dy * dy)
        }
        
        func distance(toPoint pt: CGPoint) -> CGFloat
        {
            return abs(dy * pt.x - dx * pt.y + sxey - exsy) / length
        }
    }
}
