//
//  Widget.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 08.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

protocol Widget {
    var size: CGFloat { get }
    var label: String { get set }
    
    func value(value: Double)
    func color(state: Bool)
    func label(state: Bool)
    
    func redraw()
}

extension Widget {
    func lable(state: Bool) {}
}

typealias WidgetType = Float

struct Widgets {
    static let Mini: WidgetType = 0.0
    static let Chart: WidgetType = 1.0
    static let ChartWithValue: WidgetType = 1.1
    
    static let NetworkDots: WidgetType = 2.0
    static let NetworkArrows: WidgetType = 2.1
    static let NetworkText: WidgetType = 2.2
    static let NetworkDotsWithText: WidgetType = 2.3
    static let NetworkArrowsWithText: WidgetType = 2.4
    
    static let BarChart: WidgetType = 3.0
}
