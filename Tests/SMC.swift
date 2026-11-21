import Foundation
import IOKit

// OS-boundary replacements used only by run-smc-tests.py's disposable source copy.
// No test links an SMC operation to the real driver, including open and close.
final class FakeSMC {
    struct Entry {
        var type: String
        var bytes: [UInt8]
    }
    static var current = FakeSMC()
    let lock = NSLock()
    var entries: [String: Entry] = [:]
    var firmwareErrors: [String: UInt8] = [:]
    var transportErrors: Set<String> = []
    var transientFailures: [String: Int] = [:]
    var calls: [String] = []
    var writes: [String] = []
    var sleeps: [UInt32] = []
    var keys: [String] = []
    var openResult = kIOReturnSuccess
    var matchingResult = kIOReturnSuccess
    var device: io_object_t = 2
    var releases: [io_object_t] = []
    var opened = 0
    var closed = 0
    
    func put(_ key: String, _ type: String, _ bytes: [UInt8]) {
        self.entries[key] = Entry(type: type, bytes: bytes)
    }
    func put(_ key: String, _ bytes: [UInt8]) { self.put(key, "ui8 ", bytes) }
    func count(_ command: String) -> Int { self.calls.filter { $0 == command }.count }
}

func mockIOServiceMatching(_ name: String) -> CFMutableDictionary {
    CFDictionaryCreateMutable(nil, 0, nil, nil)
}
func mockIOServiceGetMatchingServices(
    _ port: mach_port_t, _ dictionary: CFMutableDictionary,
    _ iterator: UnsafeMutablePointer<io_iterator_t>
) -> kern_return_t {
    iterator.pointee = 1
    return FakeSMC.current.matchingResult
}
func mockIOIteratorNext(_ iterator: io_iterator_t) -> io_object_t { FakeSMC.current.device }
@discardableResult
func mockIOObjectRelease(_ object: io_object_t) -> kern_return_t {
    FakeSMC.current.releases.append(object)
    return kIOReturnSuccess
}
func mockIOServiceOpen(_ service: io_service_t, _ task: task_port_t, _ type: UInt32,
                       _ connection: UnsafeMutablePointer<io_connect_t>) -> kern_return_t {
    FakeSMC.current.opened += 1
    connection.pointee = 3
    return FakeSMC.current.openResult
}
func mockIOServiceClose(_ connection: io_connect_t) -> kern_return_t {
    FakeSMC.current.closed += 1
    return kIOReturnSuccess
}
@discardableResult
func mockusleep(_ delay: UInt32) -> Int32 {
    FakeSMC.current.sleeps.append(delay)
    return 0
}
// Match the IOKit function signature so the test runner can replace calls directly.
// swiftlint:disable:next function_parameter_count
func mockIOConnectCallStructMethod(
    _ connection: io_connect_t, _ selector: UInt32,
    _ input: UnsafePointer<SMCKeyData_t>, _ inputSize: Int,
    _ output: UnsafeMutablePointer<SMCKeyData_t>,
    _ outputSize: UnsafeMutablePointer<Int>
) -> kern_return_t {
    let fake = FakeSMC.current
    fake.lock.lock()
    defer { fake.lock.unlock() }
    precondition(selector == 2 && inputSize == MemoryLayout<SMCKeyData_t>.stride)
    let request = input.pointee
    output.pointee = SMCKeyData_t()
    let key = request.key.toString()
    let command = request.data8
    let name = command == 8 ? "index:\(request.data32)" : "\(command):\(key)"
    fake.calls.append(name)
    if fake.transportErrors.contains(name) { return kIOReturnError }
    if let remaining = fake.transientFailures[name], remaining > 0 {
        fake.transientFailures[name] = remaining - 1
        output.pointee.result = 1
        return kIOReturnSuccess
    }
    if let failure = fake.firmwareErrors[name] {
        output.pointee.result = failure
        return kIOReturnSuccess
    }
    switch command {
    case 8:
        guard Int(request.data32) < fake.keys.count else {
            output.pointee.result = 0x84
            return kIOReturnSuccess
        }
        output.pointee.key = FourCharCode(fromString: fake.keys[Int(request.data32)])
    case 6:
        fake.writes.append(key)
        let bytes = withUnsafeBytes(of: request.bytes) { Array($0.prefix(Int(request.keyInfo.dataSize))) }
        fake.put(key, fake.entries[key]?.type ?? "fpe2", bytes)
    case 5, 9:
        guard let entry = fake.entries[key] else {
            output.pointee.result = 0x84
            return kIOReturnSuccess
        }
        if command == 9 {
            output.pointee.keyInfo.dataSize = UInt32(entry.bytes.count)
            output.pointee.keyInfo.dataType = FourCharCode(fromString: entry.type)
        } else {
            withUnsafeMutableBytes(of: &output.pointee.bytes) { $0.copyBytes(from: entry.bytes.prefix(32)) }
        }
    default:
        preconditionFailure("Unexpected SMC command \(command)")
    }
    return kIOReturnSuccess
}

import XCTest

final class SMCTests: XCTestCase {
    var fake: FakeSMC { FakeSMC.current }
    var smc: SMC!
    
    override func setUp() {
        super.setUp()
        FakeSMC.current = FakeSMC()
        FakeHelperEnvironment.current = FakeHelperEnvironment()
        self.smc = SMC()
    }
    override func tearDown() {
        self.smc = nil
        super.tearDown()
    }
    func fan(_ type: String = "flt ", mode: UInt8 = 1) {
        self.fake.put("F0md", [mode])
        self.fake.put("F0Md", [mode])
        self.fake.put("F0Tg", type, type == "flt " ? Float(1000).bytes : [0x0f, 0xa0])
    }
    func assertMask(_ initial: UInt16, id: Int, mode: FanMode,
                    file: StaticString = #filePath, line: UInt = #line) {
        self.fake.put("FS! ", "ui16", [UInt8(initial >> 8), UInt8(initial & 255)])
        self.fake.writes = []
        self.smc.setFanMode(id, mode: mode)
        let data = self.fake.entries["FS! "]!.bytes
        let actual = UInt16(bytes: (data[0], data[1]))
        for bit in 0..<16 {
            let expected = bit == id ? (mode == .forced ? UInt16(1) : 0) : ((initial >> bit) & 1)
            XCTAssertEqual((actual >> bit) & 1, expected, "mask=\(initial), fan=\(id), mode=\(mode), bit=\(bit)", file: file, line: line)
        }
        XCTAssertEqual(self.fake.writes, actual == initial ? [] : ["FS! "], file: file, line: line)
    }
    
    func testConnectionOpensAndReleasesObjects() {
        XCTAssertEqual(self.fake.opened, 1)
        XCTAssertEqual(self.fake.releases, [1, 2])
        self.smc = nil
        XCTAssertEqual(self.fake.closed, 1)
    }
    func testMatchingFailureDoesNotOpen() {
        self.smc = nil
        FakeSMC.current = FakeSMC()
        self.fake.matchingResult = kIOReturnError
        self.smc = SMC()
        XCTAssertEqual(self.fake.opened, 0)
        XCTAssertTrue(self.fake.releases.isEmpty)
    }
    func testMissingDeviceReleasesIterator() {
        self.smc = nil
        FakeSMC.current = FakeSMC()
        self.fake.device = 0
        self.smc = SMC()
        XCTAssertEqual(self.fake.opened, 0)
        XCTAssertEqual(self.fake.releases, [1])
    }
    func testFailedOpenReleasesDevice() {
        self.smc = nil
        FakeSMC.current = FakeSMC()
        self.fake.openResult = kIOReturnError
        self.smc = SMC()
        XCTAssertEqual(self.fake.releases, [1, 2])
    }
    func testUnsignedDecoders() {
        for (type, bytes, expected): (String, [UInt8], Double) in [
            ("ui8 ", [255], 255), ("ui16", [0x12, 0x34], 4660),
            ("ui32", [0x12, 0x34, 0x56, 0x78], 305419896),
            ("ui32", [255, 255, 255, 255], 4294967295)
        ] {
            let reader = SMC()
            self.fake.put("TEST", type, bytes)
            XCTAssertEqual(reader.getValue("TEST"), expected)
        }
    }
    func testPositiveFixedPointDecoders() {
        for (type, divisor): (String, Double) in [
            ("sp1e", 16384), ("sp3c", 4096), ("sp4b", 2048),
            ("sp5a", 1024), ("sp69", 512), ("sp78", 256),
            ("sp87", 128), ("sp96", 64), ("spa5", 32), ("spb4", 16), ("spf0", 1)
        ] {
            let reader = SMC()
            self.fake.put("TEST", type, [0x12, 0x34])
            XCTAssertEqual(reader.getValue("TEST"), 4660 / divisor, type)
        }
    }
    func testFloatDecoder() {
        for value: Float in [-12.5, 1.25, 6000] {
            self.fake.put("TEST", "flt ", value.bytes)
            XCTAssertEqual(self.smc.getValue("TEST"), Double(value))
        }
    }
    func testFanModesAndBitmaskAllowZero() {
        for key in ["F0Md", "F1Md", "F0md", "F1md", "FS! "] {
            self.fake.put(key, key == "FS! " ? "ui16" : "ui8 ", key == "FS! " ? [0, 0] : [0])
            XCTAssertEqual(self.smc.getValue(key), 0)
        }
    }
    func testUnknownNumericTypeReturnsNil() {
        self.fake.put("TEST", "xxxx", [1, 2, 3, 4])
        XCTAssertNil(self.smc.getValue("TEST"))
    }
    func testFanDescription() {
        self.fake.put("F0ID", "{fds", [0, 0, 0, 0] + Array("  Left Fan  ".utf8))
        XCTAssertEqual(self.smc.getStringValue("F0ID"), "Left Fan")
    }
    func testUnsupportedStringTypeReturnsNil() {
        self.fake.put("F0ID", "ui8 ", [1])
        XCTAssertNil(self.smc.getStringValue("F0ID"))
    }
    func testMetadataFirmwareErrorStopsRead() {
        self.fake.put("F0Md", [0])
        self.fake.firmwareErrors["9:F0Md"] = 1
        XCTAssertNil(self.smc.getValue("F0Md"))
        XCTAssertEqual(self.fake.calls, ["9:F0Md"])
    }
    func testMetadataTransportErrorStopsRead() {
        self.fake.transportErrors.insert("9:F0Md")
        XCTAssertNil(self.smc.getValue("F0Md"))
        XCTAssertEqual(self.fake.calls, ["9:F0Md"])
    }
    func testValueFirmwareErrorIsNotAnAutomaticMode() {
        self.fake.put("F0Md", [0])
        self.fake.firmwareErrors["5:F0Md"] = 1
        XCTAssertNil(self.smc.getValue("F0Md"))
    }
    func testValueTransportErrorReturnsNil() {
        self.fake.put("TEST", [42])
        self.fake.transportErrors.insert("5:TEST")
        XCTAssertNil(self.smc.getValue("TEST"))
    }
    func testStringReadFailureReturnsNil() {
        self.fake.put("F0ID", "{fds", [0, 0, 0, 0] + Array("  Left Fan  ".utf8))
        self.fake.firmwareErrors["5:F0ID"] = 1
        XCTAssertNil(self.smc.getStringValue("F0ID"))
    }
    func testMetadataIsCachedButValuesAreFresh() {
        self.fake.put("TEST", [1])
        XCTAssertEqual(self.smc.getValue("TEST"), 1)
        self.fake.put("TEST", [2])
        XCTAssertEqual(self.smc.getValue("TEST"), 2)
        XCTAssertEqual(self.fake.count("9:TEST"), 1)
        XCTAssertEqual(self.fake.count("5:TEST"), 2)
    }
    func testFirmwareFailureEvictsMetadata() {
        self.fake.put("TEST", [1])
        XCTAssertEqual(self.smc.getValue("TEST"), 1)
        self.fake.firmwareErrors["5:TEST"] = 1
        XCTAssertNil(self.smc.getValue("TEST"))
        self.fake.firmwareErrors = [:]
        self.fake.put("TEST", "ui16", [1, 0])
        XCTAssertEqual(self.smc.getValue("TEST"), 256)
        XCTAssertEqual(self.fake.count("9:TEST"), 2)
    }
    func testTransportFailureEvictsMetadata() {
        self.fake.put("TEST", [1])
        XCTAssertEqual(self.smc.getValue("TEST"), 1)
        self.fake.transportErrors.insert("5:TEST")
        XCTAssertNil(self.smc.getValue("TEST"))
        self.fake.transportErrors = []
        XCTAssertEqual(self.smc.getValue("TEST"), 1)
        XCTAssertEqual(self.fake.count("9:TEST"), 2)
    }
    func testMissingKeysAreNotCached() {
        XCTAssertNil(self.smc.getValue("TEST"))
        self.fake.put("TEST", [42])
        XCTAssertEqual(self.smc.getValue("TEST"), 42)
        XCTAssertEqual(self.fake.count("9:TEST"), 2)
    }
    func testMissingStringKeyCanBecomeAvailable() {
        XCTAssertNil(self.smc.getStringValue("F0ID"))
        self.fake.put("F0ID", "{fds", [0, 0, 0, 0] + Array("  Left Fan  ".utf8))
        XCTAssertEqual(self.smc.getStringValue("F0ID"), "Left Fan")
        XCTAssertEqual(self.fake.count("9:F0ID"), 2)
    }
    func testKeyDisappearingDuringReadEvictsMetadata() {
        self.fake.put("TEST", [1])
        XCTAssertEqual(self.smc.getValue("TEST"), 1)
        self.fake.entries.removeValue(forKey: "TEST")
        XCTAssertNil(self.smc.getValue("TEST"))
        self.fake.put("TEST", "ui16", [1, 0])
        XCTAssertEqual(self.smc.getValue("TEST"), 256)
        XCTAssertEqual(self.fake.count("9:TEST"), 2)
    }
    func testCachesAreIndependentAcrossInstances() {
        self.fake.put("TEST", [1])
        XCTAssertEqual(self.smc.getValue("TEST"), 1)
        XCTAssertEqual(SMC().getValue("TEST"), 1)
        XCTAssertEqual(self.fake.count("9:TEST"), 2)
    }
    func testConcurrentReadsShareMetadataCache() {
        self.fake.put("TEST", [42])
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            XCTAssertEqual(self.smc.getValue("TEST"), 42)
        }
        XCTAssertEqual(self.fake.count("9:TEST"), 1)
        XCTAssertEqual(self.fake.count("5:TEST"), 100)
    }
    func testInvalidKeysNeverReachDriver() {
        for key in ["", "abc", "abcde", "éabc", "😀abc", "e\u{301}abc"] {
            XCTAssertNil(self.smc.getValue(key))
            XCTAssertNil(self.smc.getStringValue(key))
            XCTAssertEqual(self.smc.write(key, 0), kIOReturnBadArgument)
        }
        XCTAssertTrue(self.fake.calls.isEmpty)
    }
    func testInvalidFanIDsNeverReachDriver() {
        for id in [Int.min, -1, 10, Int.max] {
            for mode in [FanMode.automatic, .forced, .auto3] { self.smc.setFanMode(id, mode: mode) }
            self.smc.setFanSpeed(id, speed: 0)
        }
        XCTAssertTrue(self.fake.calls.isEmpty)
    }
    func testNegativeSpeedsNeverReachDriver() {
        for speed in [Int.min, -1] { self.smc.setFanSpeed(0, speed: speed) }
        XCTAssertTrue(self.fake.calls.isEmpty)
    }
    func testInvalidFPE2WritesNeverReachDriver() {
        for value in [Int.min, -1, 16384, Int.max] {
            XCTAssertEqual(self.smc.write("TEST", value), kIOReturnBadArgument)
        }
        XCTAssertTrue(self.fake.calls.isEmpty)
    }
    func testEveryRepresentableIntegerFPE2Write() {
        for value in 0...16383 {
            XCTAssertEqual(self.smc.write("TEST", value), kIOReturnSuccess)
            let bytes = self.fake.entries["TEST"]!.bytes
            XCTAssertEqual(bytes.count, 2)
            // Independent integer representation, rather than using the production decoder.
            XCTAssertEqual(Int(bytes[0]) * 256 + Int(bytes[1]), value * 4)
        }
    }
    func testWriteFirmwareFailurePropagates() {
        self.fake.firmwareErrors["6:TEST"] = 1
        XCTAssertEqual(self.smc.write("TEST", 100), kIOReturnError)
        XCTAssertTrue(self.fake.writes.isEmpty)
    }
    func testWriteTransportFailurePropagates() {
        self.fake.transportErrors.insert("6:TEST")
        XCTAssertEqual(self.smc.write("TEST", 100), kIOReturnError)
        XCTAssertTrue(self.fake.writes.isEmpty)
    }
    func testEnumerationUsesExactlyTheKeyCount() {
        self.fake.keys = ["AAAA", "BBBB", "CCCC"]
        self.fake.put("#KEY", "ui32", [0, 0, 0, 3])
        XCTAssertEqual(self.smc.getAllKeys(), self.fake.keys)
        XCTAssertEqual(self.fake.calls.filter { $0.hasPrefix("index:") }, ["index:0", "index:1", "index:2"])
    }
    func testEnumerationSkipsFirmwareAndTransportErrors() {
        self.fake.keys = ["AAAA", "BBBB", "CCCC", "DDDD"]
        self.fake.put("#KEY", "ui32", [0, 0, 0, 4])
        self.fake.firmwareErrors["index:1"] = 1
        self.fake.transportErrors.insert("index:2")
        XCTAssertEqual(self.smc.getAllKeys(), ["AAAA", "DDDD"])
    }
    func testEnumerationWithoutCountDoesNotReadIndices() {
        XCTAssertTrue(self.smc.getAllKeys().isEmpty)
        XCTAssertFalse(self.fake.calls.contains { $0.hasPrefix("index:") })
    }
    func testEnumerationWithZeroCountDoesNotReadIndices() {
        self.fake.put("#KEY", "ui32", [0, 0, 0, 0])
        XCTAssertTrue(self.smc.getAllKeys().isEmpty)
        XCTAssertFalse(self.fake.calls.contains { $0.hasPrefix("index:") })
    }
    func testUnsupportedFanTargetIsNotWritten() {
        self.fan("ui16")
        self.smc.setFanSpeed(0, speed: 2000)
        XCTAssertFalse(self.fake.calls.contains("6:F0Tg"))
        XCTAssertEqual(self.fake.entries["F0Tg"]!.bytes, [0x0f, 0xa0])
    }
    func testFailedFanTargetReadIsNotWritten() {
        self.fan()
        self.fake.firmwareErrors["5:F0Tg"] = 1
        self.smc.setFanSpeed(0, speed: 2000)
        XCTAssertFalse(self.fake.calls.contains("6:F0Tg"))
    }
    func testFloatFanSpeedIncludingZero() {
        self.fan()
        for speed in [0, 1, 3000, 16384] {
            self.smc.setFanSpeed(0, speed: speed)
            XCTAssertEqual(self.fake.entries["F0Tg"]!.bytes, Float(speed).bytes)
        }
    }
    func testFPE2FanSpeedBoundaries() {
        self.fan("fpe2")
        for speed in [0, 1, 63, 64, 16383] {
            self.smc.setFanSpeed(0, speed: speed)
            let data = self.fake.entries["F0Tg"]!.bytes
            XCTAssertEqual(Int(data[0]) * 256 + Int(data[1]), speed * 4)
        }
        self.fake.writes = []
        self.smc.setFanSpeed(0, speed: 16384)
        XCTAssertTrue(self.fake.writes.isEmpty)
    }
    func testFanSpeedClampsToMaximum() {
        self.fan()
        self.fake.put("F0Mx", "flt ", Float(6000).bytes)
        self.smc.setFanSpeed(0, speed: Int.max)
        XCTAssertEqual(self.fake.entries["F0Tg"]!.bytes, Float(6000).bytes)
        XCTAssertEqual(self.fake.writes, ["F0Tg"])
    }
    func testAutomaticModeClassification() {
        XCTAssertTrue(FanMode.automatic.isAutomatic)
        XCTAssertTrue(FanMode.auto3.isAutomatic)
        XCTAssertFalse(FanMode.forced.isAutomatic)
        XCTAssertNil(FanMode(rawValue: 2))
    }
    
    #if TEST_ARM64
    func testARMLowercaseModeProbeIsCached() {
        self.fan()
        XCTAssertEqual(self.smc.fanModeKey(0), "F0md")
        XCTAssertEqual(self.smc.fanModeKey(1), "F1md")
        XCTAssertEqual(self.fake.count("5:F0md"), 1)
    }
    func testARMUppercaseModeFallback() {
        self.fake.put("F0Md", [0])
        XCTAssertEqual(self.smc.fanModeKey(0), "F0Md")
        XCTAssertEqual(self.smc.fanModeKey(1), "F1Md")
    }
    func testARMDirectUnlockDoesNotTouchFtstOrSleep() {
        self.fan(mode: 0)
        self.smc.setFanMode(0, mode: .forced)
        XCTAssertEqual(self.fake.writes, ["F0md"])
        XCTAssertEqual(self.fake.entries["F0md"]!.bytes, [1])
        XCTAssertFalse(self.fake.calls.contains { $0.contains("Ftst") })
        XCTAssertTrue(self.fake.sleeps.isEmpty)
    }
    func testARMFanSpeedUnlocksBeforeTargetWrite() {
        self.fan(mode: 0)
        self.smc.setFanSpeed(0, speed: 2000)
        XCTAssertEqual(self.fake.writes, ["F0md", "F0Tg"])
    }
    func testARMFailedModeReadDoesNotWriteTarget() {
        self.fan()
        XCTAssertEqual(self.smc.fanModeKey(0), "F0md")
        self.fake.transportErrors.insert("5:F0md")
        self.smc.setFanSpeed(0, speed: 2000)
        XCTAssertTrue(self.fake.writes.isEmpty)
    }
    func testARMFailedUnlockDoesNotWriteTarget() {
        self.fan(mode: 0)
        self.fake.firmwareErrors["6:F0md"] = 1
        self.smc.setFanSpeed(0, speed: 2000)
        XCTAssertFalse(self.fake.calls.contains("6:F0Tg"))
    }
    func testARMAutomaticClearsModeAndTarget() {
        self.fan()
        self.smc.setFanMode(0, mode: .automatic)
        XCTAssertEqual(self.fake.writes, ["F0md", "F0Tg"])
        XCTAssertEqual(self.fake.entries["F0md"]!.bytes, [0])
        XCTAssertEqual(self.fake.entries["F0Tg"]!.bytes, Float(0).bytes)
    }
    func testARMAuto3RestoresAutomaticControl() {
        self.fan()
        self.smc.setFanMode(0, mode: .auto3)
        XCTAssertEqual(self.fake.entries["F0md"]!.bytes, [0])
        XCTAssertEqual(self.fake.entries["F0Tg"]!.bytes, Float(0).bytes)
    }
    func testARMAutomaticSkipsAlreadyAutomaticModeWrite() {
        self.fan(mode: 0)
        self.smc.setFanMode(0, mode: .automatic)
        XCTAssertEqual(self.fake.writes, ["F0Tg"])
    }
    func testARMTargetWriteRetriesTransientFirmwareFailure() {
        self.fan()
        self.fake.transientFailures["6:F0Tg"] = 2
        self.smc.setFanSpeed(0, speed: 2000)
        XCTAssertEqual(self.fake.count("6:F0Tg"), 3)
        XCTAssertEqual(self.fake.sleeps, [50_000, 50_000])
        XCTAssertEqual(self.fake.entries["F0Tg"]!.bytes, Float(2000).bytes)
    }
    func testARMTargetWriteStopsAtRetryLimit() {
        self.fan()
        self.fake.transportErrors.insert("6:F0Tg")
        self.smc.setFanSpeed(0, speed: 2000)
        XCTAssertEqual(self.fake.count("6:F0Tg"), 10)
        XCTAssertEqual(self.fake.sleeps, Array(repeating: 50_000, count: 9))
        XCTAssertTrue(self.fake.writes.isEmpty)
    }
    func testARMFtstUnlockSequence() {
        self.fan(mode: 0)
        self.fake.put("Ftst", [0])
        self.fake.transientFailures["6:F0md"] = 3
        self.smc.setFanMode(0, mode: .forced)
        XCTAssertEqual(self.fake.writes, ["Ftst", "F0md"])
        XCTAssertEqual(self.fake.sleeps, [3_000_000, 100_000, 100_000])
        XCTAssertEqual(self.fake.count("6:F0md"), 4)
    }
    func testARMAlreadyUnlockedFtstUsesShortRetryLimit() {
        self.fan(mode: 0)
        self.fake.put("Ftst", [1])
        self.fake.firmwareErrors["6:F0md"] = 1
        self.smc.setFanMode(0, mode: .forced)
        XCTAssertEqual(self.fake.count("6:F0md"), 21) // direct attempt + 20 retries
        XCTAssertEqual(self.fake.sleeps, Array(repeating: 100_000, count: 19))
        XCTAssertFalse(self.fake.calls.contains("6:Ftst"))
    }
    func testARMFtstWriteFailureStopsUnlock() {
        self.fan(mode: 0)
        self.fake.firmwareErrors["6:F0md"] = 1
        self.fake.put("Ftst", [0])
        self.fake.firmwareErrors["6:Ftst"] = 1
        self.smc.setFanMode(0, mode: .forced)
        XCTAssertEqual(self.fake.count("6:Ftst"), 100)
        XCTAssertEqual(self.fake.count("6:F0md"), 1)
        XCTAssertEqual(self.fake.sleeps, Array(repeating: 50_000, count: 99))
    }
    func testARMLongUnlockRetryLimit() {
        self.fan(mode: 0)
        self.fake.put("Ftst", [0])
        self.fake.firmwareErrors["6:F0md"] = 1
        self.smc.setFanMode(0, mode: .forced)
        XCTAssertEqual(self.fake.count("6:F0md"), 301)
        XCTAssertEqual(self.fake.sleeps, [3_000_000] + Array(repeating: 100_000, count: 299))
    }
    func testARMResetFtst() {
        self.fake.put("Ftst", [1])
        XCTAssertTrue(self.smc.resetFanControl())
        XCTAssertEqual(self.fake.writes, ["Ftst"])
        XCTAssertEqual(self.fake.entries["Ftst"]!.bytes, [0])
    }
    func testARMResetAlreadyClearFtstDoesNotWrite() {
        self.fake.put("Ftst", [0])
        XCTAssertTrue(self.smc.resetFanControl())
        XCTAssertTrue(self.fake.writes.isEmpty)
    }
    func testARMResetFtstFailureReturnsFalse() {
        self.fake.put("Ftst", [1])
        self.fake.firmwareErrors["6:Ftst"] = 1
        XCTAssertFalse(self.smc.resetFanControl())
        XCTAssertEqual(self.fake.count("6:Ftst"), 10)
    }
    func testARMResetWithoutCountReturnsFalse() {
        XCTAssertFalse(self.smc.resetFanControl())
        XCTAssertTrue(self.fake.writes.isEmpty)
    }
    func testARMResetAllFanReadsFailReturnsFalse() {
        self.fake.put("FNum", [2])
        XCTAssertFalse(self.smc.resetFanControl())
        XCTAssertTrue(self.fake.writes.isEmpty)
    }
    func testARMResetContinuesAfterReadFailure() {
        self.fake.put("FNum", [2])
        self.fake.put("F0md", [1])
        self.fake.put("F1md", [1])
        XCTAssertEqual(self.smc.fanModeKey(0), "F0md")
        self.fake.firmwareErrors["5:F0md"] = 1
        XCTAssertFalse(self.smc.resetFanControl())
        XCTAssertEqual(self.fake.writes, ["F1md"])
    }
    func testARMResetContinuesAfterWriteFailure() {
        self.fake.put("FNum", [2])
        self.fake.put("F0md", [1])
        self.fake.put("F1md", [1])
        self.fake.firmwareErrors["6:F0md"] = 1
        XCTAssertFalse(self.smc.resetFanControl())
        XCTAssertEqual(self.fake.writes, ["F1md"])
    }
    func testARMResetSkipsAlreadyAutomaticFans() {
        self.fake.put("FNum", [2])
        self.fake.put("F0md", [0])
        self.fake.put("F1md", [1])
        XCTAssertTrue(self.smc.resetFanControl())
        XCTAssertEqual(self.fake.writes, ["F1md"])
    }
    #else
    func testIntelAllTwoFanMaskTransitions() {
        for mask in UInt16(0)...3 {
            for id in 0...1 {
                for mode in [FanMode.automatic, .forced, .auto3] { self.assertMask(mask, id: id, mode: mode) }
            }
        }
    }
    func testIntelMaskPreservesOtherBitsForEverySupportedFan() {
        for mask: UInt16 in [0, 0xFFFF, 0xAAAA, 0x5555, 0x8000, 0x7FFF] {
            for id in 0...9 {
                for mode in [FanMode.automatic, .forced, .auto3] { self.assertMask(mask, id: id, mode: mode) }
            }
        }
    }
    func testIntelRepeatedModeRequestsAreIdempotent() {
        self.fake.put("FS! ", "ui16", [0, 3])
        for _ in 0..<10 { self.smc.setFanMode(0, mode: .forced) }
        XCTAssertTrue(self.fake.writes.isEmpty)
        XCTAssertEqual(self.fake.entries["FS! "]!.bytes, [0, 3])
    }
    func testIntelFailedMaskReadDoesNotWrite() {
        self.fake.put("FS! ", "ui16", [0, 3])
        self.fake.firmwareErrors["5:FS! "] = 1
        self.smc.setFanMode(0, mode: .automatic)
        XCTAssertTrue(self.fake.writes.isEmpty)
    }
    func testIntelMissingMaskDoesNotWrite() {
        self.smc.setFanMode(0, mode: .forced)
        XCTAssertTrue(self.fake.writes.isEmpty)
    }
    func testIntelDirectModeAndMaskAreUpdated() {
        self.fake.put("F0Md", [0])
        self.fake.put("FS! ", "ui16", [0, 2])
        self.smc.setFanMode(0, mode: .forced)
        XCTAssertEqual(self.fake.writes, ["F0Md", "FS! "])
        XCTAssertEqual(self.fake.entries["F0Md"]!.bytes, [1])
        XCTAssertEqual(self.fake.entries["FS! "]!.bytes, [0, 3])
    }
    func testIntelDirectModeWriteFailureStopsMaskUpdate() {
        self.fake.put("F0Md", [0])
        self.fake.put("FS! ", "ui16", [0, 2])
        self.fake.firmwareErrors["6:F0Md"] = 1
        self.smc.setFanMode(0, mode: .forced)
        XCTAssertFalse(self.fake.calls.contains("6:FS! "))
    }
    func testIntelFanSpeedDoesNotChangeMode() {
        self.fan()
        self.smc.setFanSpeed(0, speed: 2000)
        XCTAssertEqual(self.fake.writes, ["F0Tg"])
        XCTAssertTrue(self.fake.sleeps.isEmpty)
    }
    func testIntelModeKeyUsesUppercaseWithoutProbe() {
        XCTAssertEqual(self.smc.fanModeKey(0), "F0Md")
        XCTAssertEqual(self.smc.fanModeKey(9), "F9Md")
        XCTAssertTrue(self.fake.calls.isEmpty)
    }
    #endif
}

// Fixtures for the actual helper lifecycle declarations compiled by the runner.
// These never open XPC connections, unregister services, or install helpers.
final class FakeHelperEnvironment {
    struct Request {
        let id: Int
        let mode: Int
        let reply: (String?) -> Void
        let fail: (Error) -> Void
    }
    static var current = FakeHelperEnvironment()
    var fanCount: Double? = 2
    var requests: [Request] = []
    var events: [String] = []
    var unregisterReply: ((Error?) -> Void)?
    var proxyAvailable = true
    var immediateReplies = false
    let error = NSError(domain: "SMCHelperTests", code: 1)
}

final class FakeHelperClientConnection {
    var invalidated = false
    func invalidate() {
        self.invalidated = true
        FakeHelperEnvironment.current.events.append("invalidate")
    }
    func remoteObjectProxyWithErrorHandler(_ error: @escaping (Error) -> Void) -> Any {
        guard FakeHelperEnvironment.current.proxyAvailable else { return NSObject() }
        return FakeHelperProxy(error: error)
    }
}

final class FakeHelperProxy: NSObject, HelperProtocol {
    let error: (Error) -> Void
    init(error: @escaping (Error) -> Void) { self.error = error }
    func version(completion: @escaping (String) -> Void) { completion("test") }
    func setSMCPath(_ path: String) {}
    func setFanMode(id: Int, mode: Int, completion: @escaping (String?) -> Void) {
        let env = FakeHelperEnvironment.current
        env.requests.append(.init(id: id, mode: mode, reply: completion, fail: self.error))
        if env.immediateReplies { completion("") }
    }
    func setFanSpeed(id: Int, value: Int, completion: @escaping (String?) -> Void) {
        XCTFail("Fan restoration must not set speeds")
    }
    func resetFanControl(completion: @escaping (String?) -> Void) {
        XCTFail("Per-fan restoration should preserve the existing helper protocol usage")
    }
    func uninstall() { FakeHelperEnvironment.current.events.append("legacy-uninstall") }
}

class HelperClientFixture {
    let plistName = "test.helper.plist"
    var connection: FakeHelperClientConnection? = FakeHelperClientConnection()
    var useModernService = true
    func helperConnection() -> FakeHelperClientConnection? { self.connection }
    func install(completion: @escaping (SMCHelperInstallState) -> Void) {
        FakeHelperEnvironment.current.events.append("install")
        completion(.enabled)
    }
}

struct FakeHelperService {
    static func daemon(plistName: String) -> FakeHelperService { FakeHelperService() }
    func unregister(completionHandler: @escaping (Error?) -> Void) {
        FakeHelperEnvironment.current.events.append("unregister")
        FakeHelperEnvironment.current.unregisterReply = completionHandler
    }
}

struct FakeHelperNotifications {
    static let `default` = FakeHelperNotifications()
    func post(name: Notification.Name, object: Any?, userInfo: [AnyHashable: Any]) {
        XCTAssertEqual(userInfo["state"] as? Bool, false)
        FakeHelperEnvironment.current.events.append("notify")
    }
}

extension Notification.Name {
    static let fanHelperState = Notification.Name("SMCHelperTests.fanHelperState")
}

extension SMCTests {
    var helperEnv: FakeHelperEnvironment { FakeHelperEnvironment.current }
    
    func drainHelperCallbacks() {
        let drained = self.expectation(description: "main queue callbacks completed")
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                DispatchQueue.main.async { drained.fulfill() }
            }
        }
        self.wait(for: [drained], timeout: 2)
    }
    
    func testHelperWaitsForItsFirstConnection() {
        XCTAssertFalse(HelperConnectionState().beginShutdownIfIdle())
    }
    func testHelperStaysAliveWithAConnection() {
        let state = HelperConnectionState()
        XCTAssertTrue(state.accept(FakeHelperClientConnection()))
        XCTAssertFalse(state.beginShutdownIfIdle())
    }
    func testHelperShutsDownAfterLastDisconnect() {
        let state = HelperConnectionState()
        let connection = FakeHelperClientConnection()
        XCTAssertTrue(state.accept(connection))
        state.remove(connection)
        XCTAssertTrue(state.beginShutdownIfIdle())
    }
    func testHelperReconnectCancelsPendingShutdown() {
        let state = HelperConnectionState()
        let old = FakeHelperClientConnection()
        XCTAssertTrue(state.accept(old))
        state.remove(old)
        let replacement = FakeHelperClientConnection()
        XCTAssertTrue(state.accept(replacement))
        XCTAssertFalse(state.beginShutdownIfIdle())
        state.remove(replacement)
        XCTAssertTrue(state.beginShutdownIfIdle())
    }
    func testHelperRejectsConnectionsAfterShutdownBegins() {
        let state = HelperConnectionState()
        let connection = FakeHelperClientConnection()
        XCTAssertTrue(state.accept(connection))
        state.remove(connection)
        XCTAssertTrue(state.beginShutdownIfIdle())
        XCTAssertFalse(state.accept(FakeHelperClientConnection()))
    }
    func testHelperDisconnectDoesNotRemoveOtherClients() {
        let state = HelperConnectionState()
        let first = FakeHelperClientConnection()
        let second = FakeHelperClientConnection()
        XCTAssertTrue(state.accept(first))
        XCTAssertTrue(state.accept(second))
        state.remove(first)
        state.remove(first) // duplicate invalidation must not remove the replacement
        state.remove(FakeHelperClientConnection())
        XCTAssertFalse(state.beginShutdownIfIdle())
        state.remove(second)
        XCTAssertTrue(state.beginShutdownIfIdle())
    }
    func testHelperConcurrentConnectionBookkeeping() {
        let state = HelperConnectionState()
        let persistent = FakeHelperClientConnection()
        XCTAssertTrue(state.accept(persistent))
        DispatchQueue.concurrentPerform(iterations: 200) { _ in
            let connection = FakeHelperClientConnection()
            XCTAssertTrue(state.accept(connection))
            state.remove(connection)
            XCTAssertFalse(state.beginShutdownIfIdle())
        }
        state.remove(persistent)
        XCTAssertTrue(state.beginShutdownIfIdle())
    }
    func testHelperAcceptAndShutdownAreMutuallyExclusive() {
        for _ in 0..<100 {
            let state = HelperConnectionState()
            let old = FakeHelperClientConnection()
            XCTAssertTrue(state.accept(old))
            state.remove(old)
            let group = DispatchGroup()
            let lock = NSLock()
            var accepted = false
            var stopped = false
            group.enter()
            DispatchQueue.global().async {
                let value = state.accept(FakeHelperClientConnection())
                lock.lock(); accepted = value; lock.unlock()
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                let value = state.beginShutdownIfIdle()
                lock.lock(); stopped = value; lock.unlock()
                group.leave()
            }
            XCTAssertEqual(group.wait(timeout: .now() + 2), .success)
            XCTAssertNotEqual(accepted, stopped)
        }
    }
    func testHelperUninstallWaitsForAllFanReplies() {
        let client = TestSMCHelper()
        var results: [Bool] = []
        client.uninstall { results.append($0) }
        XCTAssertEqual(self.helperEnv.requests.map { $0.id }, [0, 1])
        XCTAssertEqual(self.helperEnv.requests.map { $0.mode }, [0, 0])
        XCTAssertTrue(self.helperEnv.events.isEmpty)
        self.helperEnv.requests[1].reply("")
        self.drainHelperCallbacks()
        XCTAssertTrue(self.helperEnv.events.isEmpty)
        self.helperEnv.requests[0].reply("")
        self.drainHelperCallbacks()
        XCTAssertEqual(self.helperEnv.events, ["unregister"])
        XCTAssertTrue(results.isEmpty)
        self.helperEnv.unregisterReply?(nil)
        self.drainHelperCallbacks()
        XCTAssertEqual(self.helperEnv.events, ["unregister", "invalidate", "notify"])
        XCTAssertEqual(results, [true])
        XCTAssertNil(client.connection)
    }
    func testHelperFailedFanReplyPreventsRemoval() {
        let client = TestSMCHelper()
        var results: [Bool] = []
        client.uninstall { results.append($0) }
        self.helperEnv.requests[0].reply(nil)
        self.helperEnv.requests[1].reply("")
        self.drainHelperCallbacks()
        XCTAssertEqual(results, [false])
        XCTAssertTrue(self.helperEnv.events.isEmpty)
        XCTAssertNotNil(client.connection)
    }
    func testHelperUnresponsiveFanAllowsConfirmedRemoval() {
        let client = TestSMCHelper()
        let prompted = self.expectation(description: "confirm removal")
        client.uninstall(confirmRemoval: {
            prompted.fulfill()
            return true
        })
        self.wait(for: [prompted], timeout: 7)
        XCTAssertEqual(self.helperEnv.events, ["unregister"])
        self.helperEnv.requests[0].reply("")
        self.helperEnv.requests[1].reply("")
        self.drainHelperCallbacks()
        XCTAssertEqual(self.helperEnv.events, ["unregister"])
    }
    func testHelperXPCErrorPreventsRemoval() {
        let client = TestSMCHelper()
        var results: [Bool] = []
        client.uninstall { results.append($0) }
        self.helperEnv.requests[0].fail(self.helperEnv.error)
        self.helperEnv.requests[1].reply("")
        self.drainHelperCallbacks()
        XCTAssertEqual(results, [false])
        XCTAssertTrue(self.helperEnv.events.isEmpty)
    }
    func testHelperDuplicateCallbacksDoNotCompleteEarly() {
        let client = TestSMCHelper()
        var results: [Bool] = []
        client.uninstall { results.append($0) }
        self.helperEnv.requests[0].fail(self.helperEnv.error)
        self.helperEnv.requests[0].reply("")
        self.helperEnv.requests[0].fail(self.helperEnv.error)
        self.drainHelperCallbacks()
        XCTAssertTrue(results.isEmpty)
        self.helperEnv.requests[1].reply("")
        self.helperEnv.requests[1].reply("")
        self.drainHelperCallbacks()
        XCTAssertEqual(results, [false])
        XCTAssertTrue(self.helperEnv.events.isEmpty)
    }
    func testHelperMissingConnectionPreventsRemoval() {
        let client = TestSMCHelper()
        client.connection = nil
        var results: [Bool] = []
        client.uninstall { results.append($0) }
        self.drainHelperCallbacks()
        XCTAssertEqual(results, [false])
        XCTAssertTrue(self.helperEnv.requests.isEmpty)
        XCTAssertTrue(self.helperEnv.events.isEmpty)
    }
    func testHelperInvalidProxyPreventsRemoval() {
        self.helperEnv.proxyAvailable = false
        let client = TestSMCHelper()
        var results: [Bool] = []
        client.uninstall { results.append($0) }
        self.drainHelperCallbacks()
        XCTAssertEqual(results, [false])
        XCTAssertTrue(self.helperEnv.events.isEmpty)
    }
    func testHelperUnregisterFailureKeepsConnection() {
        self.helperEnv.immediateReplies = true
        let client = TestSMCHelper()
        var results: [Bool] = []
        client.uninstall { results.append($0) }
        self.drainHelperCallbacks()
        self.helperEnv.unregisterReply?(self.helperEnv.error)
        self.drainHelperCallbacks()
        XCTAssertEqual(results, [false])
        XCTAssertEqual(self.helperEnv.events, ["unregister"])
        XCTAssertNotNil(client.connection)
    }
    func testHelperSilentUninstallDoesNotNotify() {
        self.helperEnv.immediateReplies = true
        let client = TestSMCHelper()
        client.uninstall(silent: true)
        self.drainHelperCallbacks()
        self.helperEnv.unregisterReply?(nil)
        self.drainHelperCallbacks()
        XCTAssertEqual(self.helperEnv.events, ["unregister", "invalidate"])
    }
    func testHelperFanlessUninstallDoesNotWaitForReplies() {
        self.helperEnv.fanCount = 0
        let client = TestSMCHelper()
        client.uninstall()
        XCTAssertTrue(self.helperEnv.requests.isEmpty)
        XCTAssertEqual(self.helperEnv.events, ["unregister"])
    }
    func testHelperUnavailableCountPreservesExistingUninstallBehavior() {
        self.helperEnv.fanCount = nil
        let client = TestSMCHelper()
        client.uninstall()
        XCTAssertTrue(self.helperEnv.requests.isEmpty)
        XCTAssertEqual(self.helperEnv.events, ["unregister"])
    }
    func testHelperLegacyUninstallWaitsForReplies() {
        let client = TestSMCHelper()
        client.useModernService = false
        var results: [Bool] = []
        client.uninstall { results.append($0) }
        XCTAssertTrue(self.helperEnv.events.isEmpty)
        self.helperEnv.requests[0].reply("")
        self.drainHelperCallbacks()
        XCTAssertTrue(self.helperEnv.events.isEmpty)
        self.helperEnv.requests[1].reply("")
        self.drainHelperCallbacks()
        XCTAssertEqual(self.helperEnv.events, ["legacy-uninstall", "notify"])
        XCTAssertEqual(results, [true])
    }
    func testHelperLegacyFailurePreventsUninstall() {
        let client = TestSMCHelper()
        client.useModernService = false
        var results: [Bool] = []
        client.uninstall { results.append($0) }
        self.helperEnv.requests[0].reply(nil)
        self.helperEnv.requests[1].reply("")
        self.drainHelperCallbacks()
        XCTAssertEqual(results, [false])
        XCTAssertTrue(self.helperEnv.events.isEmpty)
    }
    func testHelperReinstallWaitsForRestorationAndUnregister() {
        let client = TestSMCHelper()
        client.reinstall()
        XCTAssertTrue(self.helperEnv.events.isEmpty)
        self.helperEnv.requests[0].reply("")
        self.helperEnv.requests[1].reply("")
        self.drainHelperCallbacks()
        XCTAssertEqual(self.helperEnv.events, ["unregister"])
        self.helperEnv.unregisterReply?(nil)
        self.drainHelperCallbacks()
        XCTAssertEqual(self.helperEnv.events, ["unregister", "invalidate", "install"])
    }
    func testHelperReinstallStopsOnRestorationFailure() {
        let client = TestSMCHelper()
        client.reinstall()
        self.helperEnv.requests[0].reply(nil)
        self.helperEnv.requests[1].reply("")
        self.drainHelperCallbacks()
        XCTAssertTrue(self.helperEnv.events.isEmpty)
    }
    func testHelperReinstallStopsOnUnregisterFailure() {
        self.helperEnv.immediateReplies = true
        let client = TestSMCHelper()
        client.reinstall()
        self.drainHelperCallbacks()
        self.helperEnv.unregisterReply?(self.helperEnv.error)
        self.drainHelperCallbacks()
        XCTAssertEqual(self.helperEnv.events, ["unregister"])
    }
    func testHelperLegacyReinstallWaitsForRestoration() {
        let client = TestSMCHelper()
        client.useModernService = false
        client.reinstall()
        XCTAssertTrue(self.helperEnv.events.isEmpty)
        self.helperEnv.requests[0].reply("")
        self.helperEnv.requests[1].reply("")
        self.drainHelperCallbacks()
        XCTAssertEqual(self.helperEnv.events, ["legacy-uninstall", "install"])
    }
    func testHelperBackgroundRepliesCompleteOnMainQueue() {
        let client = TestSMCHelper()
        let done = self.expectation(description: "restoration completed on main queue")
        client.restoreFanModes { success in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(success)
            done.fulfill()
        }
        let requests = self.helperEnv.requests
        DispatchQueue.global().async { requests.reversed().forEach { $0.reply("") } }
        self.wait(for: [done], timeout: 2)
    }
    func testHelperBackgroundUninstallStartsRestorationOnMainQueue() {
        self.helperEnv.immediateReplies = true
        let client = TestSMCHelper()
        let started = self.expectation(description: "background uninstall dispatched")
        DispatchQueue.global().async {
            client.uninstall()
            started.fulfill()
        }
        self.wait(for: [started], timeout: 2)
        self.drainHelperCallbacks()
        XCTAssertEqual(self.helperEnv.requests.count, 2)
        XCTAssertEqual(self.helperEnv.events, ["unregister"])
    }
}
