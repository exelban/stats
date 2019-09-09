//
//  AboutViewController.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 05/09/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Foundation

class AboutVC: NSViewController {
    @IBOutlet weak var versionLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
    }
    
    @IBAction func openLink(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/exelban/stats")!)
    }
    
    @IBAction func exit(_ sender: Any) {
        self.view.window?.close()
    }
    
    override func awakeFromNib() {
        if self.view.layer != nil {
            self.view.window?.backgroundColor = .windowBackgroundColor
            let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
            versionLabel.stringValue = "Version \(versionNumber)"
        }
    }
}
