//
//  notifications.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 04/12/2023
//  Using Swift 5.0
//  Running on macOS 14.1
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import UserNotifications

open class NotificationsWrapper: NSStackView {
    public let module: String
    
    private var ids: [String: Bool?] = [:]
    
    public init(_ module: ModuleType, _ ids: [String] = []) {
        self.module = module.stringValue
        super.init(frame: NSRect.zero)
        self.initIDs(ids)
        
        self.orientation = .vertical
        self.distribution = .gravityAreas
        self.translatesAutoresizingMaskIntoConstraints = false
        self.spacing = Constants.Settings.margin
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func willTerminate() {
        for id in self.ids {
            removeNotification(id.key)
        }
    }
    
    public func initIDs(_ ids: [String]) {
        for id in ids {
            let notificationID = "Stats_\(self.module)_\(id)"
            self.ids[notificationID] = nil
            removeNotification(notificationID)
        }
    }
    
    public func checkDouble(id rid: String, value: Double, threshold: Double, title: String, subtitle: String, less: Bool = false) {
        let id = "Stats_\(self.module)_\(rid)"
        let first = less ? value > threshold : value < threshold
        let second = less ? value <= threshold : value >= threshold
        
        if self.ids[id] != nil, first {
            removeNotification(id)
            self.ids[id] = nil
        }
        
        if self.ids[id] == nil && second {
            self.showNotification(id: id, title: title, subtitle: subtitle)
            self.ids[id] = true
        }
    }
    
    public func newNotification(id rid: String, title: String, subtitle: String? = nil) {
        let id = "Stats_\(self.module)_\(rid)"
        
        if self.ids[id] != nil {
            removeNotification(id)
            self.ids[id] = nil
        }
        
        self.showNotification(id: id, title: title, subtitle: subtitle)
        self.ids[id] = true
    }
    
    public func hideNotification(_ rid: String) {
        let id = "Stats_\(self.module)_\(rid)"
        if self.ids[id] != nil {
            removeNotification(id)
            self.ids[id] = nil
        }
    }
    
    private func showNotification(id: String, title: String, subtitle: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let value = subtitle {
            content.subtitle = value
        }
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        center.add(request) { (error: Error?) in
            if let err = error {
                print(err)
            }
        }
    }
}
