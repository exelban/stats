//
//  Updater.swift
//  Kit
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

public class Updater {
    private let github: URL
    private let server: URL
    
    private let appName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    private let currentVersion: String = "v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)"
    
    private var teamID: String? = nil
    private var observation: NSKeyValueObservation?
    
    public init(github: String, url: String) {
        self.github = URL(string: "https://api.github.com/repos/\(github)/releases/latest")!
        self.server = URL(string: url)!
        
        Server.shared.getTeamID { (val, err) in
            if let teamID = val, err != nil {
                self.teamID = teamID
            }
        }
    }
    
    deinit {
        observation?.invalidate()
    }
    
    public func check(completion: @escaping (_ result: version_s?, _ error: Error?) -> Void) {
        if !isConnectedToNetwork() {
            completion(nil, "No internet connection")
            return
        }
        
        self.fetchRelease(uri: self.github) { (result, err) in
            guard let result = result, err == nil else {
                self.fetchRelease(uri: self.server) { (result, err) in
                    guard let result = result, err == nil else {
                        completion(nil, err)
                        return
                    }
                    
                    completion(version_s(
                        current: self.currentVersion,
                        latest: result.tag,
                        newest: isNewestVersion(currentVersion: self.currentVersion, latestVersion: result.tag),
                        url: result.url
                    ), nil)
                }
                return
            }
            
            completion(version_s(
                current: self.currentVersion,
                latest: result.tag,
                newest: isNewestVersion(currentVersion: self.currentVersion, latestVersion: result.tag),
                url: result.url
            ), nil)
        }
    }
    
    private func fetchRelease(uri: URL, completion: @escaping (_ result: (tag: String, url: String)?, _ error: Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: uri) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil, "no data")
                return
            }
            
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
                guard let jsonArray = jsonResponse as? [String: Any],
                      let lastVersion = jsonArray["tag_name"] as? String,
                      let assets = jsonArray["assets"] as? [[String: Any]],
                      let asset = assets.first(where: {$0["name"] as! String == "\(self.appName).dmg"}),
                      let downloadURL = asset["browser_download_url"] as? String else {
                    completion(nil, "parse json")
                    return
                }
                
                 completion((lastVersion, downloadURL), nil)
            } catch let parsingError {
                completion(nil, parsingError)
            }
        }
        task.resume()
    }
    
    public func download(_ url: URL, progress: @escaping (_ progress: Progress) -> Void = {_ in }, completion: @escaping (_ path: String) -> Void = {_ in }) {
        let downloadTask = URLSession.shared.downloadTask(with: url) { urlOrNil, _, _ in
            guard let fileURL = urlOrNil else { return }
            do {
                let downloadsURL = try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                let destinationURL = downloadsURL.appendingPathComponent(url.lastPathComponent)
                
                self.copyFile(from: fileURL, to: destinationURL) { (path, error) in
                    if error != nil {
                        print("copy file error: \(error ?? "copy error")")
                        return
                    }
                    
                    completion(path)
                }
            } catch {
                print("file error: \(error)")
            }
        }
        
        self.observation = downloadTask.progress.observe(\.fractionCompleted) { value, _ in
            progress(value)
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
    
    public func isSignatureOK(path: String) -> Bool {
        let line = syncShell("codesign -dv \(path) 2>&1 | grep TeamIdentifier")
        let arr = line.split(separator: "=")
        guard arr.count == 2 else {
            return true
        }
        let teamID = arr[1]
        
        guard let externalTeamID = self.teamID else {
            return true
        }
        
        return externalTeamID == teamID
    }
    
    private func copyFile(from: URL, to: URL, completionHandler: @escaping (_ path: String, _ error: Error?) -> Void) {
        var toPath = to
        let fileName = (URL(fileURLWithPath: to.absoluteString)).lastPathComponent
        let fileExt  = (URL(fileURLWithPath: to.absoluteString)).pathExtension
        var fileNameWithotSuffix: String!
        var newFileName: String!
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
