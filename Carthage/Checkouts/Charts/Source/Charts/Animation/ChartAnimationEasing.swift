//
//  ChartAnimationUtils.swift
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

@objc
public enum ChartEasingOption: Int
{
    case linear
    case easeInQuad
    case easeOutQuad
    case easeInOutQuad
    case easeInCubic
    case easeOutCubic
    case easeInOutCubic
    case easeInQuart
    case easeOutQuart
    case easeInOutQuart
    case easeInQuint
    case easeOutQuint
    case easeInOutQuint
    case easeInSine
    case easeOutSine
    case easeInOutSine
    case easeInExpo
    case easeOutExpo
    case easeInOutExpo
    case easeInCirc
    case easeOutCirc
    case easeInOutCirc
    case easeInElastic
    case easeOutElastic
    case easeInOutElastic
    case easeInBack
    case easeOutBack
    case easeInOutBack
    case easeInBounce
    case easeOutBounce
    case easeInOutBounce
}

public typealias ChartEasingFunctionBlock = ((_ elapsed: TimeInterval, _ duration: TimeInterval) -> Double)

internal func easingFunctionFromOption(_ easing: ChartEasingOption) -> ChartEasingFunctionBlock
{
    switch easing
    {
    case .linear:
        return EasingFunctions.Linear
    case .easeInQuad:
        return EasingFunctions.EaseInQuad
    case .easeOutQuad:
        return EasingFunctions.EaseOutQuad
    case .easeInOutQuad:
        return EasingFunctions.EaseInOutQuad
    case .easeInCubic:
        return EasingFunctions.EaseInCubic
    case .easeOutCubic:
        return EasingFunctions.EaseOutCubic
    case .easeInOutCubic:
        return EasingFunctions.EaseInOutCubic
    case .easeInQuart:
        return EasingFunctions.EaseInQuart
    case .easeOutQuart:
        return EasingFunctions.EaseOutQuart
    case .easeInOutQuart:
        return EasingFunctions.EaseInOutQuart
    case .easeInQuint:
        return EasingFunctions.EaseInQuint
    case .easeOutQuint:
        return EasingFunctions.EaseOutQuint
    case .easeInOutQuint:
        return EasingFunctions.EaseInOutQuint
    case .easeInSine:
        return EasingFunctions.EaseInSine
    case .easeOutSine:
        return EasingFunctions.EaseOutSine
    case .easeInOutSine:
        return EasingFunctions.EaseInOutSine
    case .easeInExpo:
        return EasingFunctions.EaseInExpo
    case .easeOutExpo:
        return EasingFunctions.EaseOutExpo
    case .easeInOutExpo:
        return EasingFunctions.EaseInOutExpo
    case .easeInCirc:
        return EasingFunctions.EaseInCirc
    case .easeOutCirc:
        return EasingFunctions.EaseOutCirc
    case .easeInOutCirc:
        return EasingFunctions.EaseInOutCirc
    case .easeInElastic:
        return EasingFunctions.EaseInElastic
    case .easeOutElastic:
        return EasingFunctions.EaseOutElastic
    case .easeInOutElastic:
        return EasingFunctions.EaseInOutElastic
    case .easeInBack:
        return EasingFunctions.EaseInBack
    case .easeOutBack:
        return EasingFunctions.EaseOutBack
    case .easeInOutBack:
        return EasingFunctions.EaseInOutBack
    case .easeInBounce:
        return EasingFunctions.EaseInBounce
    case .easeOutBounce:
        return EasingFunctions.EaseOutBounce
    case .easeInOutBounce:
        return EasingFunctions.EaseInOutBounce
    }
}

internal struct EasingFunctions
{
    internal static let Linear = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in return Double(elapsed / duration) }
    
    internal static let EaseInQuad = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / duration)
        return position * position
    }
    
    internal static let EaseOutQuad = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / duration)
        return -position * (position - 2.0)
    }
    
    internal static let EaseInOutQuad = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / (duration / 2.0))
        if position < 1.0
        {
            return 0.5 * position * position
        }
        
        return -0.5 * ((position - 1.0) * (position - 3.0) - 1.0)
    }
    
    internal static let EaseInCubic = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / duration)
        return position * position * position
    }
    
    internal static let EaseOutCubic = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / duration)
        position -= 1.0
        return (position * position * position + 1.0)
    }
    
    internal static let EaseInOutCubic = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / (duration / 2.0))
        if position < 1.0
        {
            return 0.5 * position * position * position
        }
        position -= 2.0
        return 0.5 * (position * position * position + 2.0)
    }
    
    internal static let EaseInQuart = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / duration)
        return position * position * position * position
    }
    
    internal static let EaseOutQuart = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / duration)
        position -= 1.0
        return -(position * position * position * position - 1.0)
    }
    
    internal static let EaseInOutQuart = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / (duration / 2.0))
        if position < 1.0
        {
            return 0.5 * position * position * position * position
        }
        position -= 2.0
        return -0.5 * (position * position * position * position - 2.0)
    }
    
    internal static let EaseInQuint = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / duration)
        return position * position * position * position * position
    }
    
    internal static let EaseOutQuint = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / duration)
        position -= 1.0
        return (position * position * position * position * position + 1.0)
    }
    
    internal static let EaseInOutQuint = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / (duration / 2.0))
        if position < 1.0
        {
            return 0.5 * position * position * position * position * position
        }
        else
        {
            position -= 2.0
            return 0.5 * (position * position * position * position * position + 2.0)
        }
    }
    
    internal static let EaseInSine = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position: TimeInterval = elapsed / duration
        return Double( -cos(position * Double.pi / 2) + 1.0 )
    }
    
    internal static let EaseOutSine = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position: TimeInterval = elapsed / duration
        return Double( sin(position * Double.pi / 2) )
    }
    
    internal static let EaseInOutSine = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position: TimeInterval = elapsed / duration
        return Double( -0.5 * (cos(Double.pi * position) - 1.0) )
    }
    
    internal static let EaseInExpo = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        return (elapsed == 0) ? 0.0 : Double(pow(2.0, 10.0 * (elapsed / duration - 1.0)))
    }
    
    internal static let EaseOutExpo = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        return (elapsed == duration) ? 1.0 : (-Double(pow(2.0, -10.0 * elapsed / duration)) + 1.0)
    }
    
    internal static let EaseInOutExpo = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        if elapsed == 0
        {
            return 0.0
        }
        if elapsed == duration
        {
            return 1.0
        }
        
        var position: TimeInterval = elapsed / (duration / 2.0)
        if position < 1.0
        {
            return Double( 0.5 * pow(2.0, 10.0 * (position - 1.0)) )
        }
        
        position = position - 1.0
        return Double( 0.5 * (-pow(2.0, -10.0 * position) + 2.0) )
    }
    
    internal static let EaseInCirc = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / duration)
        return -(Double(sqrt(1.0 - position * position)) - 1.0)
    }
    
    internal static let EaseOutCirc = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position = Double(elapsed / duration)
        position -= 1.0
        return Double( sqrt(1 - position * position) )
    }
    
    internal static let EaseInOutCirc = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position: TimeInterval = elapsed / (duration / 2.0)
        if position < 1.0
        {
            return Double( -0.5 * (sqrt(1.0 - position * position) - 1.0) )
        }
        position -= 2.0
        return Double( 0.5 * (sqrt(1.0 - position * position) + 1.0) )
    }
    
    internal static let EaseInElastic = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        if elapsed == 0.0
        {
            return 0.0
        }
        
        var position: TimeInterval = elapsed / duration
        if position == 1.0
        {
            return 1.0
        }
        
        var p = duration * 0.3
        var s = p / (2.0 * Double.pi) * asin(1.0)
        position -= 1.0
        return Double( -(pow(2.0, 10.0 * position) * sin((position * duration - s) * (2.0 * Double.pi) / p)) )
    }
    
    internal static let EaseOutElastic = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        if elapsed == 0.0
        {
            return 0.0
        }
        
        var position: TimeInterval = elapsed / duration
        if position == 1.0
        {
            return 1.0
        }
        
        var p = duration * 0.3
        var s = p / (2.0 * Double.pi) * asin(1.0)
        return Double( pow(2.0, -10.0 * position) * sin((position * duration - s) * (2.0 * Double.pi) / p) + 1.0 )
    }
    
    internal static let EaseInOutElastic = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        if elapsed == 0.0
        {
            return 0.0
        }
        
        var position: TimeInterval = elapsed / (duration / 2.0)
        if position == 2.0
        {
            return 1.0
        }
        
        var p = duration * (0.3 * 1.5)
        var s = p / (2.0 * Double.pi) * asin(1.0)
        if position < 1.0
        {
            position -= 1.0
            return Double( -0.5 * (pow(2.0, 10.0 * position) * sin((position * duration - s) * (2.0 * Double.pi) / p)) )
        }
        position -= 1.0
        return Double( pow(2.0, -10.0 * position) * sin((position * duration - s) * (2.0 * Double.pi) / p) * 0.5 + 1.0 )
    }
    
    internal static let EaseInBack = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        let s: TimeInterval = 1.70158
        var position: TimeInterval = elapsed / duration
        return Double( position * position * ((s + 1.0) * position - s) )
    }
    
    internal static let EaseOutBack = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        let s: TimeInterval = 1.70158
        var position: TimeInterval = elapsed / duration
        position -= 1.0
        return Double( position * position * ((s + 1.0) * position + s) + 1.0 )
    }
    
    internal static let EaseInOutBack = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var s: TimeInterval = 1.70158
        var position: TimeInterval = elapsed / (duration / 2.0)
        if position < 1.0
        {
            s *= 1.525
            return Double( 0.5 * (position * position * ((s + 1.0) * position - s)) )
        }
        s *= 1.525
        position -= 2.0
        return Double( 0.5 * (position * position * ((s + 1.0) * position + s) + 2.0) )
    }
    
    internal static let EaseInBounce = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        return 1.0 - EaseOutBounce(duration - elapsed, duration)
    }
    
    internal static let EaseOutBounce = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        var position: TimeInterval = elapsed / duration
        if position < (1.0 / 2.75)
        {
            return Double( 7.5625 * position * position )
        }
        else if position < (2.0 / 2.75)
        {
            position -= (1.5 / 2.75)
            return Double( 7.5625 * position * position + 0.75 )
        }
        else if position < (2.5 / 2.75)
        {
            position -= (2.25 / 2.75)
            return Double( 7.5625 * position * position + 0.9375 )
        }
        else
        {
            position -= (2.625 / 2.75)
            return Double( 7.5625 * position * position + 0.984375 )
        }
    }
    
    internal static let EaseInOutBounce = { (elapsed: TimeInterval, duration: TimeInterval) -> Double in
        if elapsed < (duration / 2.0)
        {
            return EaseInBounce(elapsed * 2.0, duration) * 0.5
        }
        return EaseOutBounce(elapsed * 2.0 - duration, duration) * 0.5 + 0.5
    }
}
