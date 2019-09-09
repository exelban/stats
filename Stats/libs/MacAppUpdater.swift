//
//  macAppUpdater.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 25.06.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation
import SystemConfiguration

extension String: Error {}

struct version {
    let current: String
    let latest: String
    let newest: Bool
    let url: String
}

struct Version {
    var major: Int = 0
    var minor: Int = 0
    var patch: Int = 0
}

public class macAppUpdater {
    let user: String
    let repo: String
    
    let appName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    let currentVersion: String = "v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)"
    
    var url: String {
        return "https://api.github.com/repos/\(user)/\(repo)/releases/latest"
    }
    
    init(user: String, repo: String) {
        self.user = user
        self.repo = repo
    }
    
    func fetchLastVersion(completionHandler: @escaping (_ result: [String]?, _ error: Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: URL(string: self.url)!) { data, response, error in
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
        }
        task.resume()
    }
    
    func checkIfNewer(currentVersion: String, latestVersion: String) -> Bool {
        let currentNumber = currentVersion.replacingOccurrences(of: "v", with: "")
        let latestNumber = latestVersion.replacingOccurrences(of: "v", with: "")
        
        let currentArray = currentNumber.condenseWhitespace().split(separator: ".")
        let latestArray = latestNumber.condenseWhitespace().split(separator: ".")
        
        let current = Version(major: Int(currentArray[0]) ?? 0, minor: Int(currentArray[1]) ?? 0, patch: Int(currentArray[2]) ?? 0)
        let latest = Version(major: Int(latestArray[0]) ?? 0, minor: Int(latestArray[1]) ?? 0, patch: Int(latestArray[2]) ?? 0)

        if latest.major > current.major {
            return true
        }
        
        if latest.minor > current.minor && latest.major >= current.major {
            return true
        }
        
        if latest.patch > current.patch && latest.minor >= current.minor && latest.major >= current.major {
            return true
        }
        
        return false
    }
    
    func check(completionHandler: @escaping (_ result: version?, _ error: Error?) -> Void) {
        if !Reachability.isConnectedToNetwork() {
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
            let newVersion: Bool = self.checkIfNewer(currentVersion: self.currentVersion, latestVersion: lastVersion)

            completionHandler(version(current: self.currentVersion, latest: lastVersion, newest: newVersion, url: downloadURL), nil)
        }
    }
}


// https://stackoverflow.com/questions/30743408/check-for-internet-connection-with-swift
public class Reachability {
    class func isConnectedToNetwork() -> Bool {
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
        
        /* Only Working for WIFI
         let isReachable = flags == .reachable
         let needsConnection = flags == .connectionRequired
         
         return isReachable && !needsConnection
         */
        
        // Working for Cellular and WIFI
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        let ret = (isReachable && !needsConnection)
        
        return ret
        
    }
}
