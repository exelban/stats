//
//  DataApproximator+N.swift
//  Charts
//
//  Created by M Ivaniushchenko on 9/6/17.
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation

extension CGPoint {
    fileprivate func distanceToLine(from linePoint1: CGPoint, to linePoint2: CGPoint) -> CGFloat {
        let dx = linePoint2.x - linePoint1.x
        let dy = linePoint2.y - linePoint1.y
        
        let dividend = abs(dy * self.x - dx * self.y - linePoint1.x * linePoint2.y + linePoint2.x * linePoint1.y)
        let divisor = sqrt(dx * dx + dy * dy)
        
        return dividend / divisor
    }
}

private struct LineAlt {
    let start: Int
    let end: Int
    
    var distance: CGFloat = 0
    var index: Int = 0
    
    init(start: Int, end: Int, points: [CGPoint]) {
        self.start = start
        self.end = end
        
        let startPoint = points[start]
        let endPoint = points[end]
        
        guard (end > start + 1) else {
            return
        }
        
        for i in start + 1 ..< end {
            let currentPoint = points[i]
            
            let distance = currentPoint.distanceToLine(from: startPoint, to: endPoint)
            
            if distance > self.distance {
                self.index = i
                self.distance = distance
            }
        }
    }
}

extension LineAlt: Comparable {
    static func ==(lhs: LineAlt, rhs: LineAlt) -> Bool {
        return (lhs.start == rhs.start) && (lhs.end == rhs.end) && (lhs.index == rhs.index)
    }
    
    static func <(lhs: LineAlt, rhs: LineAlt) -> Bool {
        return lhs.distance < rhs.distance
    }
}


extension DataApproximator {
    /// uses the douglas peuker algorithm to reduce the given arraylist of entries to given number of points
    /// More algorithm details here - http://psimpl.sourceforge.net/douglas-peucker.html
    @objc open class func reduceWithDouglasPeukerN(_ points: [CGPoint], resultCount: Int) -> [CGPoint]
    {
        // if a shape has 2 or less points it cannot be reduced
        if resultCount <= 2 || resultCount >= points.count
        {
            return points
        }
        var keep = [Bool](repeating: false, count: points.count)
        
        // first and last always stay
        keep[0] = true
        keep[points.count - 1] = true
        var currentStoredPoints = 2
        
        var queue = [LineAlt]()
        let line = LineAlt(start: 0, end: points.count - 1, points: points)
        queue.append(line)
        
        repeat {
            let line = queue.popLast()!
            
            // store the key
            keep[line.index] = true
            
            // check point count tolerance
            currentStoredPoints += 1
            
            if (currentStoredPoints == resultCount) {
                break;
            }
            
            // split the polyline at the key and recurse
            let left = LineAlt(start: line.start, end: line.index, points: points)
            if (left.index > 0) {
                self.insertLine(left, into: &queue)
            }
            
            let right = LineAlt(start: line.index, end: line.end, points: points)
            if (right.index > 0) {
                self.insertLine(right, into: &queue)
            }
            
        } while !queue.isEmpty
        
        // create a new array with series, only take the kept ones
        let reducedEntries = points.enumerated().compactMap { (index: Int, point: CGPoint) -> CGPoint? in
            return keep[index] ? point : nil
        }
        
        return reducedEntries
    }
    
    // Keeps array sorted
    private static func insertLine(_ line: LineAlt, into array: inout [LineAlt]) {
        let insertionIndex = self.insertionIndex(for: line, into: &array)
        array.insert(line, at: insertionIndex)
    }
    
    private static func insertionIndex(for line: LineAlt, into array: inout [LineAlt]) -> Int {
        var indices = array.indices
        
        while !indices.isEmpty {
            let midIndex = indices.lowerBound.advanced(by: indices.count / 2)
            let midLine = array[midIndex]
            
            if midLine == line {
                return midIndex
            }
            else if (line < midLine) {
                // perform search in left half
                indices = indices.lowerBound..<midIndex
            }
            else {
                // perform search in right half
                indices = (midIndex + 1)..<indices.upperBound
            }
        }
        
        return indices.lowerBound
    }
}


