//
//  Widget.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 08.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

protocol Widget {
    var name: String { get set }
    var shortName: String { get set }
    var activeModule: Observable<Bool> { get set }
    var menus: [NSMenuItem] { get }
    
    func setValue(data: [Double])
    
    func redraw()
    func Init()
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
    static let NetworkChart: WidgetType = 2.5
    
    static let BarChart: WidgetType = 3.0
    
    static let Battery: WidgetType = 4.0
    static let BatteryPercentage: WidgetType = 4.1
    static let BatteryTime: WidgetType = 4.2
}

struct WidgetSize {
    let width: CGFloat = 32
    let height: CGFloat = NSApplication.shared.mainMenu?.menuBarHeight ?? 22
    let margin: CGFloat = 2
}
let widgetSize = WidgetSize()
