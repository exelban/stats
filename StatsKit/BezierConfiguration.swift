//
//  BezierConfiguration.swift
//  BezierCurve
//
//  Created by Muhammad Osama Naeem on 4/18/20.
//  Copyright © 2020 Muhammad Osama Naeem. All rights reserved.
//

import Cocoa

struct BezierSegmentControlPoints {
    var firstControlPoint: CGPoint
    var secondControlPoint: CGPoint
}

class BezierConfiguration {
    
    
    var firstControlPoints: [CGPoint?] = []
    var secondControlPoints: [CGPoint?] = []
    
    func configureControlPoints(data: [CGPoint]) -> [BezierSegmentControlPoints] {
        
        
        let segments = data.count - 1
        
        
        if segments == 1 {
            
            // straight line calculation here
            let p0 = data[0]
            let p3 = data[1]
            
            return [BezierSegmentControlPoints(firstControlPoint: p0, secondControlPoint: p3)]
        }else if segments > 1 {
            
            //left hand side coefficients
            var ad = [CGFloat]()
            var d = [CGFloat]()
            var bd = [CGFloat]()
            
            
            var rhsArray = [CGPoint]()
            
            for i in 0..<segments {
                
                var rhsXValue : CGFloat = 0
                var rhsYValue : CGFloat = 0
                
                let p0 = data[i]
                let p3 = data[i+1]
                
                if i == 0 {
                    bd.append(0.0)
                    d.append(2.0)
                    ad.append(1.0)
                    
                    rhsXValue = p0.x + 2*p3.x
                    rhsYValue = p0.y + 2*p3.y
                    
                }else if i == segments - 1 {
                    bd.append(2.0)
                    d.append(7.0)
                    ad.append(0.0)
                    
                    rhsXValue = 8*p0.x + p3.x
                    rhsYValue = 8*p0.y + p3.y
                }else {
                    bd.append(1.0)
                    d.append(4.0)
                    ad.append(1.0)
                    
                    rhsXValue = 4*p0.x + 2*p3.x
                    rhsYValue = 4*p0.y + 2*p3.y
                }
                
                rhsArray.append(CGPoint(x: rhsXValue, y: rhsYValue))
                
                
            }
            
            let solution1 = thomasAlgorithm(bd: bd, d: d, ad: ad, rhsArray: rhsArray, segments: segments, data: data)
            
            return solution1
        }
        
        return []
    }
    
    func thomasAlgorithm(bd: [CGFloat], d: [CGFloat], ad: [CGFloat], rhsArray: [CGPoint], segments: Int, data: [CGPoint]) -> [BezierSegmentControlPoints] {
        
        var controlPoints : [BezierSegmentControlPoints] = []
        var ad = ad
        let bd = bd
        let d = d
        var rhsArray = rhsArray
        let segments = segments
        
        var solutionSet1 = [CGPoint?]()
        solutionSet1 = Array(repeating: nil, count: segments)
        
        //First segment
        ad[0] = ad[0] / d[0]
        rhsArray[0].x = rhsArray[0].x / d[0]
        rhsArray[0].y = rhsArray[0].y / d[0]
        
        //Middle Elements
        if segments > 2 {
            for i in 1...segments - 2  {
                let rhsValueX = rhsArray[i].x
                let prevRhsValueX = rhsArray[i - 1].x
                
                let rhsValueY = rhsArray[i].y
                let prevRhsValueY = rhsArray[i - 1].y
                
                ad[i] = ad[i] / (d[i] - bd[i]*ad[i-1]);
                
                let exp1x = (rhsValueX - (bd[i]*prevRhsValueX))
                let exp1y = (rhsValueY - (bd[i]*prevRhsValueY))
                let exp2 = (d[i] - bd[i]*ad[i-1])
                
                rhsArray[i].x = exp1x / exp2
                rhsArray[i].y = exp1y / exp2
            }
        }
        
        //Last Element
        let lastElementIndex = segments - 1
        let exp1 = (rhsArray[lastElementIndex].x - bd[lastElementIndex] * rhsArray[lastElementIndex - 1].x)
        let exp1y = (rhsArray[lastElementIndex].y - bd[lastElementIndex] * rhsArray[lastElementIndex - 1].y)
        let exp2 = (d[lastElementIndex] - bd[lastElementIndex] * ad[lastElementIndex - 1])
        rhsArray[lastElementIndex].x = exp1 / exp2
        rhsArray[lastElementIndex].y = exp1y / exp2
        
        solutionSet1[lastElementIndex] = rhsArray[lastElementIndex]
        
        for i in (0..<lastElementIndex).reversed() {
            let controlPointX = rhsArray[i].x - (ad[i] * solutionSet1[i + 1]!.x)
            let controlPointY = rhsArray[i].y - (ad[i] * solutionSet1[i + 1]!.y)
            
            solutionSet1[i] = CGPoint(x: controlPointX, y: controlPointY)
        }
        
        firstControlPoints = solutionSet1
        
        for i in (0..<segments) {
            if i == (segments - 1) {
                
                let lastDataPoint = data[i + 1]
                let p1 = firstControlPoints[i]
                guard let controlPoint1 = p1 else { continue }
                
                let controlPoint2X = (0.5)*(lastDataPoint.x + controlPoint1.x)
                let controlPoint2y = (0.5)*(lastDataPoint.y + controlPoint1.y)
                
                let controlPoint2 = CGPoint(x: controlPoint2X, y: controlPoint2y)
                secondControlPoints.append(controlPoint2)
            }else {
                
                let dataPoint = data[i+1]
                let p1 = firstControlPoints[i+1]
                guard let controlPoint1 = p1 else { continue }
                
                let controlPoint2X = 2*dataPoint.x - controlPoint1.x
                let controlPoint2Y = 2*dataPoint.y - controlPoint1.y
                
                secondControlPoints.append(CGPoint(x: controlPoint2X, y: controlPoint2Y))
            }
        }
        
        for i in (0..<segments) {
            guard let firstCP = firstControlPoints[i] else { continue }
            guard let secondCP = secondControlPoints[i] else { continue }
            
            let segmentControlPoint = BezierSegmentControlPoints(firstControlPoint: firstCP, secondControlPoint: secondCP)
            controlPoints.append(segmentControlPoint)
        }
        
        return controlPoints
    }
    
}
