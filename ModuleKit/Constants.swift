//
//  Constants.swift
//  ModuleKit
//
//  Created by Serhiy Mytrovtsiy on 15/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

public struct Popup_c_s {
    public let width: CGFloat = 264
    public let height: CGFloat = 400
    public let margins: CGFloat = 8
    public let headerHeight: CGFloat = 42
}

public struct Settings_c_s {
    public let width: CGFloat = 540
    public let height: CGFloat = 480
}

public struct Constants {
    public static let Popup: Popup_c_s = Popup_c_s()
    public static let Settings: Settings_c_s = Settings_c_s()
}
