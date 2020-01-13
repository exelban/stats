//
//  UpdatesViewController.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 05/09/2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Foundation

class UpdatesVC: NSViewController {
    @IBOutlet weak var mainView: NSStackView!
    @IBOutlet weak var spinnerView: NSView!
    @IBOutlet weak var noInternetView: NSView!
    @IBOutlet weak var mainTextLabel: NSTextFieldCell!
    @IBOutlet weak var currentVersionLabel: NSTextField!
    @IBOutlet weak var latestVersionLabel: NSTextField!
    @IBOutlet weak var downloadButton: NSButton!
    @IBOutlet weak var spinner: NSProgressIndicator!
    
    var url: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        
        self.spinner.startAnimation(self)
        
        updater.check() { result, error in
            if error != nil && error as! String == "No internet connection" {
                DispatchQueue.main.async(execute: {
                    self.spinnerView.isHidden = true
                    self.noInternetView.isHidden = false
                })
                return
            }
            
            guard error == nil, let version: version = result else {
                print("Error: \(error ?? "check error")")
                return
            }
            
            DispatchQueue.main.async(execute: {
                self.spinner.stopAnimation(self)
                self.spinnerView.isHidden = true
                self.mainView.isHidden = false
                self.currentVersionLabel.stringValue = version.current
                self.latestVersionLabel.stringValue = version.latest
                self.url = version.url
                
                if !version.newest {
                    self.mainTextLabel.stringValue = "No new version available"
                    self.downloadButton.isEnabled = false
                }
            })
        }
    }
    
    override func awakeFromNib() {
        if self.view.layer != nil {
            self.view.window?.backgroundColor = .windowBackgroundColor
        }
    }
    
    @IBAction func download(_ sender: Any) {
        guard let urlString = self.url, let url = URL(string: urlString) else {
            return
        }
        updater.download(url)
        self.spinner.startAnimation(self)
        self.spinnerView.isHidden = false
        self.mainView.isHidden = true
    }
    
    @IBAction func exit(_ sender: Any) {
        self.view.window?.close()
    }
}
