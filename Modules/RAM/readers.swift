//
//  readers.swift
//  Memory
//
//  Created by Serhiy Mytrovtsiy on 12/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

internal class UsageReader: Reader<RAM_Usage> {
    public var totalSize: Double = 0
    
    public override func setup() {
        var stats = host_basic_info()
        var count = UInt32(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_info(mach_host_self(), HOST_BASIC_INFO, $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            self.totalSize = Double(stats.max_mem)
            return
        }
        
        self.totalSize = 0
        error("host_info(): \(String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error")", log: self.log)
    }
    
    public override func read() {
        var stats = vm_statistics64()
        var count = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let active = Double(stats.active_count) * Double(vm_page_size)
            let speculative = Double(stats.speculative_count) * Double(vm_page_size)
            let inactive = Double(stats.inactive_count) * Double(vm_page_size)
            let wired = Double(stats.wire_count) * Double(vm_page_size)
            let compressed = Double(stats.compressor_page_count) * Double(vm_page_size)
            let purgeable = Double(stats.purgeable_count) * Double(vm_page_size)
            let external = Double(stats.external_page_count) * Double(vm_page_size)
            let swapins = Int64(stats.swapins)
            let swapouts = Int64(stats.swapouts)
            
            let used = active + inactive + speculative + wired + compressed - purgeable - external
            let free = self.totalSize - used
            
            var intSize: size_t = MemoryLayout<uint>.size
            var pressureLevel: Int = 0
            sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &intSize, nil, 0)
            
            var pressureValue: RAMPressure
            switch pressureLevel {
            case 2: pressureValue = .warning
            case 4: pressureValue = .critical
            default: pressureValue = .normal
            }
            
            var stringSize: size_t = MemoryLayout<xsw_usage>.size
            var swap: xsw_usage = xsw_usage()
            sysctlbyname("vm.swapusage", &swap, &stringSize, nil, 0)
            
            self.callback(RAM_Usage(
                total: self.totalSize,
                used: used,
                free: free,
                
                active: active,
                inactive: inactive,
                wired: wired,
                compressed: compressed,
                
                app: used - wired - compressed,
                cache: purgeable + external,
                
                swap: Swap(
                    total: Double(swap.xsu_total),
                    used: Double(swap.xsu_used),
                    free: Double(swap.xsu_avail)
                ),
                pressure: Pressure(level: pressureLevel, value: pressureValue),
                
                swapins: swapins,
                swapouts: swapouts
            ))
            return
        }
        
        error("host_statistics64(): \(String(cString: mach_error_string(result), encoding: String.Encoding.ascii) ?? "unknown error")", log: self.log)
    }
}

public class ProcessReader: Reader<[TopProcess]> {
    private let title: String = "RAM"
    
    private var numberOfProcesses: Int {
        get {
            return Store.shared.int(key: "\(self.title)_processes", defaultValue: 8)
        }
    }
    
    private var combineProcesses: Bool{
        get {
            return Store.shared.bool(key: "\(self.title)_combineProcesses", defaultValue: true)
        }
    }
    
    public override func setup() {
        self.popup = true
        self.setInterval(Store.shared.int(key: "\(self.title)_updateTopInterval", defaultValue: 1))
    }
    
    public override func read() {
        let initialNumPids = proc_listallpids(nil, 0)
        guard initialNumPids > 0 else {
            error("proc_listallpids(): \(String(cString: strerror(errno), encoding: String.Encoding.ascii) ?? "unknown error")", log: self.log)
            return
        }
        
        let allPids = UnsafeMutablePointer<Int32>.allocate(capacity: Int(initialNumPids))
        defer { allPids.deallocate() }

        let numPids = proc_listallpids(allPids, Int32(MemoryLayout<Int32>.size) * initialNumPids)
        guard numPids > 0 else {
            error("proc_listallpids(): \(String(cString: strerror(errno), encoding: String.Encoding.ascii) ?? "unknown error")", log: self.log)
            return
        }
        
        var processTree: [Int: ProcessTreeNode] = [:]
        var groupTree: [ProcessTreeNode] = []
        
        let taskInfo = UnsafeMutablePointer<proc_taskallinfo>.allocate(capacity: 1)
        defer { taskInfo.deallocate() }

        for index in 0..<numPids {
            let processId = Int(allPids.advanced(by: Int(index)).pointee)

            memset(taskInfo, 0, MemoryLayout<proc_taskallinfo>.size)
            let pidInfoSize = proc_pidinfo(Int32(processId),
                                           PROC_PIDTASKALLINFO,
                                           0,
                                           taskInfo,
                                           Int32(MemoryLayout<proc_taskallinfo>.size))
            
            if pidInfoSize > 0 {
                let thisProcess = taskInfo.pointee

                var treeEntry = processTree[processId]
                if treeEntry == nil {
                    treeEntry = ProcessTreeNode(pid: processId)
                    processTree[processId] = treeEntry
                }
                treeEntry!.name = getProcessName(thisProcess)
                treeEntry!.ownMemoryUsage = thisProcess.ptinfo.pti_resident_size
                              
                if combineProcesses {
                    let originatingPid = findOriginatingPid(thisProcess)
                    
                    if originatingPid != processId && originatingPid > 1 {
                        var originatingEntry = processTree[originatingPid]
                        if originatingEntry == nil {
                            originatingEntry = ProcessTreeNode(pid: originatingPid)
                            processTree[originatingPid] = originatingEntry
                        }
                        originatingEntry!.addChildProcess(treeEntry!)
                    } else {
                        groupTree.append(treeEntry!)
                    }
                } else {
                    groupTree.append(treeEntry!)
                }
            }
        }
        
        groupTree = groupTree.sorted { $0.totalMemoryUsage > $1.totalMemoryUsage  }
        
        let topProcessList = groupTree.prefix(numberOfProcesses).map({
            TopProcess(pid: $0.pid, name: $0.name, usage: Double($0.totalMemoryUsage))
        })

        self.callback(topProcessList)
    }
    
    class ProcessTreeNode {
        let pid: Int
        var name: String = "UNKNOWN"
        var ownMemoryUsage: UInt64 = 0
        var childMemoryUsage: UInt64 = 0
        
        var totalMemoryUsage: UInt64 {
            get {
                #if DEBUG
                assert(calcTotalMemoryUsage() == ownMemoryUsage + childMemoryUsage)
                #endif
                return ownMemoryUsage + childMemoryUsage
            }
        }
        
        private var childProcesses: [ProcessTreeNode] = []
        private weak var parentProcess: ProcessTreeNode?
        
        init(pid: Int) {
            self.pid = pid
        }
        
        func addChildProcess(_ childProcess: ProcessTreeNode) {
            childProcesses.append(childProcess)
            childProcess.parentProcess = self

            var currentNode = childProcess
            while let parent = currentNode.parentProcess {
                parent.childMemoryUsage += childProcess.totalMemoryUsage
                currentNode = parent
            }
        }
        
        #if DEBUG
        private func calcTotalMemoryUsage() -> UInt64 {
            childProcesses.reduce(ownMemoryUsage) { $0 + $1.calcTotalMemoryUsage() }
        }
        #endif
    }

    private func getProcessName(_ thisProcess: proc_taskallinfo) -> String {
        var processName: String
        if let app = NSRunningApplication(processIdentifier: pid_t(thisProcess.pbsd.pbi_pid)), let n = app.localizedName {
            processName = n
        } else {
            let comm = thisProcess.pbsd.pbi_comm
            processName = String(cString: Mirror(reflecting: comm).children.map { $0.value as! CChar })
        }
        return processName
    }
    
    // Use private Apple API call if found, otherwise fall back to parent pid
    private func findOriginatingPid(_ thisProcess: proc_taskallinfo) -> Int {
        if ProcessReader.dynGetResponsiblePidFunc != nil {
            getResponsiblePid(Int(thisProcess.pbsd.pbi_pid))
        } else {
            Int(thisProcess.pbsd.pbi_ppid)
        }
    }

    typealias dynGetResponsiblePidFuncType = @convention(c) (CInt) -> CInt
    
    // Load function to get responsible pid using private Apple API call
    private static let dynGetResponsiblePidFunc: UnsafeMutableRawPointer? = {
        let result = dlsym(UnsafeMutableRawPointer(bitPattern: -1), "responsibility_get_pid_responsible_for_pid")
        if result == nil {
            error("Error loading responsibility_get_pid_responsible_for_pid")
        }
        return result
    }()
    
    func getResponsiblePid(_ childPid: Int) -> Int {
        guard ProcessReader.dynGetResponsiblePidFunc != nil else {
            return childPid
        }
        
        let responsiblePid = unsafeBitCast(ProcessReader.dynGetResponsiblePidFunc, to: dynGetResponsiblePidFuncType.self)(CInt(childPid))
        guard responsiblePid != -1 else {
            error("Error getting responsible pid for process \(childPid). Setting responsible pid to itself")
            return childPid
        }
        return Int(responsiblePid)
    }
}
