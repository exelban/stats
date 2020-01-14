//
//  ChartAnimationUtils.swift
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
import CoreGraphics

@objc
public enum ChartEasingOption: Int
{
    case Linear
    case EaseInQuad
    case EaseOutQuad
    case EaseInOutQuad
    case EaseInCubic
    case EaseOutCubic
    case EaseInOutCubic
    case EaseInQuart
    case EaseOutQuart
    case EaseInOutQuart
    case EaseInQuint
    case EaseOutQuint
    case EaseInOutQuint
    case EaseInSine
    case EaseOutSine
    case EaseInOutSine
    case EaseInExpo
    case EaseOutExpo
    case EaseInOutExpo
    case EaseInCirc
    case EaseOutCirc
    case EaseInOutCirc
    case EaseInElastic
    case EaseOutElastic
    case EaseInOutElastic
    case EaseInBack
    case EaseOutBack
    case EaseInOutBack
    case EaseInBounce
    case EaseOutBounce
    case EaseInOutBounce
}

public typealias ChartEasingFunctionBlock = ((elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat)

internal func easingFunctionFromOption(easing: ChartEasingOption) -> ChartEasingFunctionBlock
{
    switch easing
    {
    case .Linear:
        return EasingFunctions.Linear
    case .EaseInQuad:
        return EasingFunctions.EaseInQuad
    case .EaseOutQuad:
        return EasingFunctions.EaseOutQuad
    case .EaseInOutQuad:
        return EasingFunctions.EaseInOutQuad
    case .EaseInCubic:
        return EasingFunctions.EaseInCubic
    case .EaseOutCubic:
        return EasingFunctions.EaseOutCubic
    case .EaseInOutCubic:
        return EasingFunctions.EaseInOutCubic
    case .EaseInQuart:
        return EasingFunctions.EaseInQuart
    case .EaseOutQuart:
        return EasingFunctions.EaseOutQuart
    case .EaseInOutQuart:
        return EasingFunctions.EaseInOutQuart
    case .EaseInQuint:
        return EasingFunctions.EaseInQuint
    case .EaseOutQuint:
        return EasingFunctions.EaseOutQuint
    case .EaseInOutQuint:
        return EasingFunctions.EaseInOutQuint
    case .EaseInSine:
        return EasingFunctions.EaseInSine
    case .EaseOutSine:
        return EasingFunctions.EaseOutSine
    case .EaseInOutSine:
        return EasingFunctions.EaseInOutSine
    case .EaseInExpo:
        return EasingFunctions.EaseInExpo
    case .EaseOutExpo:
        return EasingFunctions.EaseOutExpo
    case .EaseInOutExpo:
        return EasingFunctions.EaseInOutExpo
    case .EaseInCirc:
        return EasingFunctions.EaseInCirc
    case .EaseOutCirc:
        return EasingFunctions.EaseOutCirc
    case .EaseInOutCirc:
        return EasingFunctions.EaseInOutCirc
    case .EaseInElastic:
        return EasingFunctions.EaseInElastic
    case .EaseOutElastic:
        return EasingFunctions.EaseOutElastic
    case .EaseInOutElastic:
        return EasingFunctions.EaseInOutElastic
    case .EaseInBack:
        return EasingFunctions.EaseInBack
    case .EaseOutBack:
        return EasingFunctions.EaseOutBack
    case .EaseInOutBack:
        return EasingFunctions.EaseInOutBack
    case .EaseInBounce:
        return EasingFunctions.EaseInBounce
    case .EaseOutBounce:
        return EasingFunctions.EaseOutBounce
    case .EaseInOutBounce:
        return EasingFunctions.EaseInOutBounce
    }
}

internal struct EasingFunctions
{
    internal static let Linear = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in return CGFloat(elapsed / duration); }
    
    internal static let EaseInQuad = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / duration)
        return position * position
    }
    
    internal static let EaseOutQuad = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / duration)
        return -position * (position - 2.0)
    }
    
    internal static let EaseInOutQuad = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / (duration / 2.0))
        if (position < 1.0)
        {
            return 0.5 * position * position
        }
        return -0.5 * ((--position) * (position - 2.0) - 1.0)
    }
    
    internal static let EaseInCubic = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / duration)
        return position * position * position
    }
    
    internal static let EaseOutCubic = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / duration)
        position--
        return (position * position * position + 1.0)
    }
    
    internal static let EaseInOutCubic = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / (duration / 2.0))
        if (position < 1.0)
        {
            return 0.5 * position * position * position
        }
        position -= 2.0
        return 0.5 * (position * position * position + 2.0)
    }
    
    internal static let EaseInQuart = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / duration)
        return position * position * position * position
    }
    
    internal static let EaseOutQuart = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / duration)
        position--
        return -(position * position * position * position - 1.0)
    }
    
    internal static let EaseInOutQuart = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / (duration / 2.0))
        if (position < 1.0)
        {
            return 0.5 * position * position * position * position
        }
        position -= 2.0
        return -0.5 * (position * position * position * position - 2.0)
    }
    
    internal static let EaseInQuint = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / duration)
        return position * position * position * position * position
    }
    
    internal static let EaseOutQuint = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / duration)
        position--
        return (position * position * position * position * position + 1.0)
    }
    
    internal static let EaseInOutQuint = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / (duration / 2.0))
        if (position < 1.0)
        {
            return 0.5 * position * position * position * position * position
        }
        else
        {
            position -= 2.0
            return 0.5 * (position * position * position * position * position + 2.0)
        }
    }
    
    internal static let EaseInSine = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position: NSTimeInterval = elapsed / duration
        return CGFloat( -cos(position * M_PI_2) + 1.0 )
    }
    
    internal static let EaseOutSine = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position: NSTimeInterval = elapsed / duration
        return CGFloat( sin(position * M_PI_2) )
    }
    
    internal static let EaseInOutSine = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position: NSTimeInterval = elapsed / duration
        return CGFloat( -0.5 * (cos(M_PI * position) - 1.0) )
    }
    
    internal static let EaseInExpo = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        return (elapsed == 0) ? 0.0 : CGFloat(pow(2.0, 10.0 * (elapsed / duration - 1.0)))
    }
    
    internal static let EaseOutExpo = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        return (elapsed == duration) ? 1.0 : (-CGFloat(pow(2.0, -10.0 * elapsed / duration)) + 1.0)
    }
    
    internal static let EaseInOutExpo = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        if (elapsed == 0)
        {
            return 0.0
        }
        if (elapsed == duration)
        {
            return 1.0
        }
        
        var position: NSTimeInterval = elapsed / (duration / 2.0)
        if (position < 1.0)
        {
            return CGFloat( 0.5 * pow(2.0, 10.0 * (position - 1.0)) )
        }
        return CGFloat( 0.5 * (-pow(2.0, -10.0 * --position) + 2.0) )
    }
    
    internal static let EaseInCirc = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / duration)
        return -(CGFloat(sqrt(1.0 - position * position)) - 1.0)
    }
    
    internal static let EaseOutCirc = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position = CGFloat(elapsed / duration)
        position--
        return CGFloat( sqrt(1 - position * position) )
    }
    
    internal static let EaseInOutCirc = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position: NSTimeInterval = elapsed / (duration / 2.0)
        if (position < 1.0)
        {
            return CGFloat( -0.5 * (sqrt(1.0 - position * position) - 1.0) )
        }
        position -= 2.0
        return CGFloat( 0.5 * (sqrt(1.0 - position * position) + 1.0) )
    }
    
    internal static let EaseInElastic = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        if (elapsed == 0.0)
        {
            return 0.0
        }
        
        var position: NSTimeInterval = elapsed / duration
        if (position == 1.0)
        {
            return 1.0
        }
        
        var p = duration * 0.3
        var s = p / (2.0 * M_PI) * asin(1.0)
        position -= 1.0
        return CGFloat( -(pow(2.0, 10.0 * position) * sin((position * duration - s) * (2.0 * M_PI) / p)) )
    }
    
    internal static let EaseOutElastic = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        if (elapsed == 0.0)
        {
            return 0.0
        }
        
        var position: NSTimeInterval = elapsed / duration
        if (position == 1.0)
        {
            return 1.0
        }
        
        var p = duration * 0.3
        var s = p / (2.0 * M_PI) * asin(1.0)
        return CGFloat( pow(2.0, -10.0 * position) * sin((position * duration - s) * (2.0 * M_PI) / p) + 1.0 )
    }
    
    internal static let EaseInOutElastic = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        if (elapsed == 0.0)
        {
            return 0.0
        }
        
        var position: NSTimeInterval = elapsed / (duration / 2.0)
        if (position == 2.0)
        {
            return 1.0
        }
        
        var p = duration * (0.3 * 1.5)
        var s = p / (2.0 * M_PI) * asin(1.0)
        if (position < 1.0)
        {
            position -= 1.0
            return CGFloat( -0.5 * (pow(2.0, 10.0 * position) * sin((position * duration - s) * (2.0 * M_PI) / p)) )
        }
        position -= 1.0
        return CGFloat( pow(2.0, -10.0 * position) * sin((position * duration - s) * (2.0 * M_PI) / p) * 0.5 + 1.0 )
    }
    
    internal static let EaseInBack = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        let s: NSTimeInterval = 1.70158
        var position: NSTimeInterval = elapsed / duration
        return CGFloat( position * position * ((s + 1.0) * position - s) )
    }
    
    internal static let EaseOutBack = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        let s: NSTimeInterval = 1.70158
        var position: NSTimeInterval = elapsed / duration
        position--
        return CGFloat( (position * position * ((s + 1.0) * position + s) + 1.0) )
    }
    
    internal static let EaseInOutBack = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var s: NSTimeInterval = 1.70158
        var position: NSTimeInterval = elapsed / (duration / 2.0)
        if (position < 1.0)
        {
            s *= 1.525
            return CGFloat( 0.5 * (position * position * ((s + 1.0) * position - s)) )
        }
        s *= 1.525
        position -= 2.0
        return CGFloat( 0.5 * (position * position * ((s + 1.0) * position + s) + 2.0) )
    }
    
    internal static let EaseInBounce = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        return 1.0 - EaseOutBounce(duration - elapsed, duration)
    }
    
    internal static let EaseOutBounce = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        var position: NSTimeInterval = elapsed / duration
        if (position < (1.0 / 2.75))
        {
            return CGFloat( 7.5625 * position * position )
        }
        else if (position < (2.0 / 2.75))
        {
            position -= (1.5 / 2.75)
            return CGFloat( 7.5625 * position * position + 0.75 )
        }
        else if (position < (2.5 / 2.75))
        {
            position -= (2.25 / 2.75)
            return CGFloat( 7.5625 * position * position + 0.9375 )
        }
        else
        {
            position -= (2.625 / 2.75)
            return CGFloat( 7.5625 * position * position + 0.984375 )
        }
    }
    
    internal static let EaseInOutBounce = { (elapsed: NSTimeInterval, duration: NSTimeInterval) -> CGFloat in
        if (elapsed < (duration / 2.0))
        {
            return EaseInBounce(elapsed * 2.0, duration) * 0.5
        }
        return EaseOutBounce(elapsed * 2.0 - duration, duration) * 0.5 + 0.5
    }
}