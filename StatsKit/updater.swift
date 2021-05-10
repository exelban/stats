//
//  updater.swift
//  StatsKit
//
//  Created by Serhiy Mytrovtsiy on 14/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import SystemConfiguration

public struct version_s {
    public let current: String
    public let latest: String
    public let newest: Bool
    public let url: String
    
    public init(current: String, latest: String, newest: Bool, url: String) {
        self.current = current
        self.latest = latest
        self.newest = newest
        self.url = url
    }
}

public struct Version {
    var major: Int = 0
    var minor: Int = 0
    var patch: Int = 0
    
    var beta: Int? = nil
}

public class macAppUpdater {
    private let user: String
    private let repo: String
    
    private let appName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    private let currentVersion: String = "v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)"
    
    public var latest: version_s? = nil
    private var observation: NSKeyValueObservation?
    
    private var url: String {
        return "https://api.github.com/repos/\(user)/\(repo)/releases/latest"
    }
    
    public init(user: String, repo: String) {
        self.user = user
        self.repo = repo
    }
    
    deinit {
      observation?.invalidate()
    }
    
    public func check(completionHandler: @escaping (_ result: version_s?, _ error: Error?) -> Void) {
        if !isConnectedToNetwork() {
            completionHandler(nil, "No internet connection")
            return
        }
        
        fetchLastVersion() { result, error in
            guard error == nil else {
                completionHandler(nil, error)
                return
            }
            
            guard let results = result, results.count > 1 else {
                completionHandler(nil, "wrong results")
                return
            }
            
            let downloadURL: String = result![1]
            let lastVersion: String = result![0]
            let newVersion: Bool = IsNewestVersion(currentVersion: self.currentVersion, latestVersion: lastVersion)
            
            self.latest = version_s(current: self.currentVersion, latest: lastVersion, newest: newVersion, url: downloadURL)
            completionHandler(self.latest, nil)
        }
    }
    
    private func fetchLastVersion(completionHandler: @escaping (_ result: [String]?, _ error: Error?) -> Void) {
        guard let url = URL(string: self.url) else {
            completionHandler(nil, "wrong url")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
                guard let jsonArray = jsonResponse as? [String: Any] else {
                    completionHandler(nil, "parse json")
                    return
                }
                let lastVersion = jsonArray["tag_name"] as? String
                
                guard let assets = jsonArray["assets"] as? [[String: Any]] else {
                    completionHandler(nil, "parse assets")
                    return
                }
                if let asset = assets.first(where: {$0["name"] as! String == "\(self.appName).dmg"}) {
                    let downloadURL = asset["browser_download_url"] as? String
                    completionHandler([lastVersion!, downloadURL!], nil)
                }
            } catch let parsingError {
                completionHandler(nil, parsingError)
            }
        }.resume()
    }
    
    public func download(_ url: URL, progressHandler: @escaping (_ progress: Progress) -> Void = {_ in }, doneHandler: @escaping (_ path: String) -> Void = {_ in }) {
        let downloadTask = URLSession.shared.downloadTask(with: url) { urlOrNil, responseOrNil, errorOrNil in
            guard let fileURL = urlOrNil else { return }
            do {
                let downloadsURL = try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                let destinationURL = downloadsURL.appendingPathComponent(url.lastPathComponent)
                
                self.copyFile(from: fileURL, to: destinationURL) { (path, error) in
                    if error != nil {
                        print ("copy file error: \(error ?? "copy error")")
                        return
                    }
                    
                    doneHandler(path)
                }
            } catch {
                print ("file error: \(error)")
            }
        }
        
        self.observation = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
            progressHandler(progress)
        }
        
        downloadTask.resume()
    }
    
    public func install(path: String) {
        print("Started new version installation...")
        
        _ = syncShell("mkdir /tmp/Stats") // make sure that directory exist
        let res = syncShell("/usr/bin/hdiutil attach \(path) -mountpoint /tmp/Stats -noverify -nobrowse -noautoopen") // mount the dmg
        
        print("DMG is mounted")
        
        if res.contains("is busy") { // dmg can be busy, if yes, unmount it and mount again
            print("DMG is busy, remounting")
            
            _ = syncShell("/usr/bin/hdiutil detach $TMPDIR/Stats")
            _ = syncShell("/usr/bin/hdiutil attach \(path) -mountpoint /tmp/Stats -noverify -nobrowse -noautoopen")
        }
        
        _ = syncShell("cp -rf /tmp/Stats/Stats.app/Contents/Resources/Scripts/updater.sh $TMPDIR/updater.sh") // copy updater script to tmp folder
        
        print("Script is copied to $TMPDIR/updater.sh")
        
        let pwd = Bundle.main.bundleURL.absoluteString
            .replacingOccurrences(of: "file://", with: "")
            .replacingOccurrences(of: "Stats.app", with: "")
            .replacingOccurrences(of: "//", with: "/")
        let dmg = path.replacingOccurrences(of: "file://", with: "")
        asyncShell("sh $TMPDIR/updater.sh --app \(pwd) --dmg \(dmg) >/dev/null &") // run updater script in in background
        
        print("Run updater.sh with app: \(pwd) and dmg: \(dmg)")
        
        exit(0)
    }
    
    private func copyFile(from: URL, to: URL, completionHandler: @escaping (_ path: String, _ error: Error?) -> Void) {
        var toPath = to
        let fileName = (URL(fileURLWithPath: to.absoluteString)).lastPathComponent
        let fileExt  = (URL(fileURLWithPath: to.absoluteString)).pathExtension
        var fileNameWithotSuffix : String!
        var newFileName : String!
        var counter = 0
        
        if fileName.hasSuffix(fileExt) {
            fileNameWithotSuffix = String(fileName.prefix(fileName.count - (fileExt.count+1)))
        }
        
        while toPath.checkFileExist() {
            counter += 1
            newFileName =  "\(fileNameWithotSuffix!)-\(counter).\(fileExt)"
            toPath = to.deletingLastPathComponent().appendingPathComponent(newFileName)
        }
        
        do {
            try FileManager.default.moveItem(at: from, to: toPath)
            completionHandler(toPath.absoluteString, nil)
        } catch {
            completionHandler("", error)
        }
    }
    
    // https://stackoverflow.com/questions/30743408/check-for-internet-connection-with-swift
    private func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return false
        }
        
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        let ret = (isReachable && !needsConnection)
        
        return ret
    }
}
