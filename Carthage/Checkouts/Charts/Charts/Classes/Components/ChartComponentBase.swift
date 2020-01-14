//
//  ChartComponentBase.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 16/3/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import UIKit

/// This class encapsulates everything both Axis and Legend have in common.
public class ChartComponentBase: NSObject
{
    /// flag that indicates if this component is enabled or not
    public var enabled = true
    
    public override init()
    {
        super.init()
    }

    public var isEnabled: Bool { return enabled; }
}
