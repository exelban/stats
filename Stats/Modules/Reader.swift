//
//  Reader.swift
//  Stats
//
//  Created by Serhiy Mytrovtsiy on 08.07.2019.
//  Copyright © 2019 Serhiy Mytrovtsiy. All rights reserved.
//

import Foundation

protocol Reader {
    var value: Observable<[Double]>! { get }
    
    var available: Bool { get }
    var availableAdditional: Bool { get }
    
    func start()
    func stop()
    
    func startAdditional()
    func stopAdditional()
    
    func setInterval(value: Int)
}

extension Reader {
    func startAdditional() {}
    func stopAdditional() {}
}
