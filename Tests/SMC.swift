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
        entries[key] = Entry(type: type, bytes: bytes)
    }
    func put(_ key: String, _ bytes: [UInt8]) { put(key, "ui8 ", bytes) }
    func count(_ command: String) -> Int { calls.filter { $0 == command }.count }
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
        smc = SMC()
    }
    override func tearDown() {
        smc = nil
        super.tearDown()
    }
    func fan(_ type: String = "flt ", mode: UInt8 = 1) {
        fake.put("F0md", [mode])
        fake.put("F0Md", [mode])
        fake.put("F0Tg", type, type == "flt " ? Float(1000).bytes : [0x0f, 0xa0])
    }
    func assertMask(_ initial: UInt16, id: Int, mode: FanMode,
                    file: StaticString = #filePath, line: UInt = #line) {
        fake.put("FS! ", "ui16", [UInt8(initial >> 8), UInt8(initial & 255)])
        fake.writes = []
        smc.setFanMode(id, mode: mode)
        let data = fake.entries["FS! "]!.bytes
        let actual = UInt16(bytes: (data[0], data[1]))
        for bit in 0..<16 {
            let expected = bit == id ? (mode == .forced ? UInt16(1) : 0) : ((initial >> bit) & 1)
            XCTAssertEqual((actual >> bit) & 1, expected, "mask=\(initial), fan=\(id), mode=\(mode), bit=\(bit)", file: file, line: line)
        }
        XCTAssertEqual(fake.writes, actual == initial ? [] : ["FS! "], file: file, line: line)
    }

    func testConnectionOpensAndReleasesObjects() {
        XCTAssertEqual(fake.opened, 1)
        XCTAssertEqual(fake.releases, [1, 2])
        smc = nil
        XCTAssertEqual(fake.closed, 1)
    }
    func testMatchingFailureDoesNotOpen() {
        smc = nil
        FakeSMC.current = FakeSMC()
        fake.matchingResult = kIOReturnError
        smc = SMC()
        XCTAssertEqual(fake.opened, 0)
        XCTAssertTrue(fake.releases.isEmpty)
    }
    func testMissingDeviceReleasesIterator() {
        smc = nil
        FakeSMC.current = FakeSMC()
        fake.device = 0
        smc = SMC()
        XCTAssertEqual(fake.opened, 0)
        XCTAssertEqual(fake.releases, [1])
    }
    func testFailedOpenReleasesDevice() {
        smc = nil
        FakeSMC.current = FakeSMC()
        fake.openResult = kIOReturnError
        smc = SMC()
        XCTAssertEqual(fake.releases, [1, 2])
    }
    func testUnsignedDecoders() {
        for (type, bytes, expected): (String, [UInt8], Double) in [
            ("ui8 ", [255], 255), ("ui16", [0x12, 0x34], 4660),
            ("ui32", [0x12, 0x34, 0x56, 0x78], 305419896),
            ("ui32", [255, 255, 255, 255], 4294967295)
        ] {
            let reader = SMC()
            fake.put("TEST", type, bytes)
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
            fake.put("TEST", type, [0x12, 0x34])
            XCTAssertEqual(reader.getValue("TEST"), 4660 / divisor, type)
        }
    }
    func testFloatDecoder() {
        for value: Float in [-12.5, 1.25, 6000] {
            fake.put("TEST", "flt ", value.bytes)
            XCTAssertEqual(smc.getValue("TEST"), Double(value))
        }
    }
    func testFanModesAndBitmaskAllowZero() {
        for key in ["F0Md", "F1Md", "F0md", "F1md", "FS! "] {
            fake.put(key, key == "FS! " ? "ui16" : "ui8 ", key == "FS! " ? [0, 0] : [0])
            XCTAssertEqual(smc.getValue(key), 0)
        }
    }
    func testUnknownNumericTypeReturnsNil() {
        fake.put("TEST", "xxxx", [1, 2, 3, 4])
        XCTAssertNil(smc.getValue("TEST"))
    }
    func testFanDescription() {
        fake.put("F0ID", "{fds", [0, 0, 0, 0] + Array("  Left Fan  ".utf8))
        XCTAssertEqual(smc.getStringValue("F0ID"), "Left Fan")
    }
    func testUnsupportedStringTypeReturnsNil() {
        fake.put("F0ID", "ui8 ", [1])
        XCTAssertNil(smc.getStringValue("F0ID"))
    }
    func testMetadataFirmwareErrorStopsRead() {
        fake.put("F0Md", [0])
        fake.firmwareErrors["9:F0Md"] = 1
        XCTAssertNil(smc.getValue("F0Md"))
        XCTAssertEqual(fake.calls, ["9:F0Md"])
    }
    func testMetadataTransportErrorStopsRead() {
        fake.transportErrors.insert("9:F0Md")
        XCTAssertNil(smc.getValue("F0Md"))
        XCTAssertEqual(fake.calls, ["9:F0Md"])
    }
    func testValueFirmwareErrorIsNotAnAutomaticMode() {
        fake.put("F0Md", [0])
        fake.firmwareErrors["5:F0Md"] = 1
        XCTAssertNil(smc.getValue("F0Md"))
    }
    func testValueTransportErrorReturnsNil() {
        fake.put("TEST", [42])
        fake.transportErrors.insert("5:TEST")
        XCTAssertNil(smc.getValue("TEST"))
    }
    func testStringReadFailureReturnsNil() {
        fake.put("F0ID", "{fds", [0, 0, 0, 0] + Array("  Left Fan  ".utf8))
        fake.firmwareErrors["5:F0ID"] = 1
        XCTAssertNil(smc.getStringValue("F0ID"))
    }
    func testMetadataIsCachedButValuesAreFresh() {
        fake.put("TEST", [1])
        XCTAssertEqual(smc.getValue("TEST"), 1)
        fake.put("TEST", [2])
        XCTAssertEqual(smc.getValue("TEST"), 2)
        XCTAssertEqual(fake.count("9:TEST"), 1)
        XCTAssertEqual(fake.count("5:TEST"), 2)
    }
    func testFirmwareFailureEvictsMetadata() {
        fake.put("TEST", [1])
        XCTAssertEqual(smc.getValue("TEST"), 1)
        fake.firmwareErrors["5:TEST"] = 1
        XCTAssertNil(smc.getValue("TEST"))
        fake.firmwareErrors = [:]
        fake.put("TEST", "ui16", [1, 0])
        XCTAssertEqual(smc.getValue("TEST"), 256)
        XCTAssertEqual(fake.count("9:TEST"), 2)
    }
    func testTransportFailureEvictsMetadata() {
        fake.put("TEST", [1])
        XCTAssertEqual(smc.getValue("TEST"), 1)
        fake.transportErrors.insert("5:TEST")
        XCTAssertNil(smc.getValue("TEST"))
        fake.transportErrors = []
        XCTAssertEqual(smc.getValue("TEST"), 1)
        XCTAssertEqual(fake.count("9:TEST"), 2)
    }
    func testMissingKeysAreNotCached() {
        XCTAssertNil(smc.getValue("TEST"))
        fake.put("TEST", [42])
        XCTAssertEqual(smc.getValue("TEST"), 42)
        XCTAssertEqual(fake.count("9:TEST"), 2)
    }
    func testCachesAreIndependentAcrossInstances() {
        fake.put("TEST", [1])
        XCTAssertEqual(smc.getValue("TEST"), 1)
        XCTAssertEqual(SMC().getValue("TEST"), 1)
        XCTAssertEqual(fake.count("9:TEST"), 2)
    }
    func testConcurrentReadsShareMetadataCache() {
        fake.put("TEST", [42])
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            XCTAssertEqual(self.smc.getValue("TEST"), 42)
        }
        XCTAssertEqual(fake.count("9:TEST"), 1)
        XCTAssertEqual(fake.count("5:TEST"), 100)
    }
    func testInvalidKeysNeverReachDriver() {
        for key in ["", "abc", "abcde", "éabc", "😀abc", "e\u{301}abc"] {
            XCTAssertNil(smc.getValue(key))
            XCTAssertNil(smc.getStringValue(key))
            XCTAssertEqual(smc.write(key, 0), kIOReturnBadArgument)
        }
        XCTAssertTrue(fake.calls.isEmpty)
    }
    func testInvalidFanIDsNeverReachDriver() {
        for id in [Int.min, -1, 10, Int.max] {
            for mode in [FanMode.automatic, .forced, .auto3] { smc.setFanMode(id, mode: mode) }
            smc.setFanSpeed(id, speed: 0)
        }
        XCTAssertTrue(fake.calls.isEmpty)
    }
    func testNegativeSpeedsNeverReachDriver() {
        for speed in [Int.min, -1] { smc.setFanSpeed(0, speed: speed) }
        XCTAssertTrue(fake.calls.isEmpty)
    }
    func testInvalidFPE2WritesNeverReachDriver() {
        for value in [Int.min, -1, 16384, Int.max] {
            XCTAssertEqual(smc.write("TEST", value), kIOReturnBadArgument)
        }
        XCTAssertTrue(fake.calls.isEmpty)
    }
    func testEveryRepresentableIntegerFPE2Write() {
        for value in 0...16383 {
            XCTAssertEqual(smc.write("TEST", value), kIOReturnSuccess)
            let bytes = fake.entries["TEST"]!.bytes
            XCTAssertEqual(bytes.count, 2)
            // Independent integer representation, rather than using the production decoder.
            XCTAssertEqual(Int(bytes[0]) * 256 + Int(bytes[1]), value * 4)
        }
    }
    func testWriteFirmwareFailurePropagates() {
        fake.firmwareErrors["6:TEST"] = 1
        XCTAssertEqual(smc.write("TEST", 100), kIOReturnError)
        XCTAssertTrue(fake.writes.isEmpty)
    }
    func testWriteTransportFailurePropagates() {
        fake.transportErrors.insert("6:TEST")
        XCTAssertEqual(smc.write("TEST", 100), kIOReturnError)
        XCTAssertTrue(fake.writes.isEmpty)
    }
    func testEnumerationUsesExactlyTheKeyCount() {
        fake.keys = ["AAAA", "BBBB", "CCCC"]
        fake.put("#KEY", "ui32", [0, 0, 0, 3])
        XCTAssertEqual(smc.getAllKeys(), fake.keys)
        XCTAssertEqual(fake.calls.filter { $0.hasPrefix("index:") }, ["index:0", "index:1", "index:2"])
    }
    func testEnumerationSkipsFirmwareAndTransportErrors() {
        fake.keys = ["AAAA", "BBBB", "CCCC", "DDDD"]
        fake.put("#KEY", "ui32", [0, 0, 0, 4])
        fake.firmwareErrors["index:1"] = 1
        fake.transportErrors.insert("index:2")
        XCTAssertEqual(smc.getAllKeys(), ["AAAA", "DDDD"])
    }
    func testEnumerationWithoutCountDoesNotReadIndices() {
        XCTAssertTrue(smc.getAllKeys().isEmpty)
        XCTAssertFalse(fake.calls.contains { $0.hasPrefix("index:") })
    }
    func testEnumerationWithZeroCountDoesNotReadIndices() {
        fake.put("#KEY", "ui32", [0, 0, 0, 0])
        XCTAssertTrue(smc.getAllKeys().isEmpty)
        XCTAssertFalse(fake.calls.contains { $0.hasPrefix("index:") })
    }
    func testUnsupportedFanTargetIsNotWritten() {
        fan("ui16")
        smc.setFanSpeed(0, speed: 2000)
        XCTAssertFalse(fake.calls.contains("6:F0Tg"))
        XCTAssertEqual(fake.entries["F0Tg"]!.bytes, [0x0f, 0xa0])
    }
    func testFailedFanTargetReadIsNotWritten() {
        fan()
        fake.firmwareErrors["5:F0Tg"] = 1
        smc.setFanSpeed(0, speed: 2000)
        XCTAssertFalse(fake.calls.contains("6:F0Tg"))
    }
    func testFloatFanSpeedIncludingZero() {
        fan()
        for speed in [0, 1, 3000, 16384] {
            smc.setFanSpeed(0, speed: speed)
            XCTAssertEqual(fake.entries["F0Tg"]!.bytes, Float(speed).bytes)
        }
    }
    func testFPE2FanSpeedBoundaries() {
        fan("fpe2")
        for speed in [0, 1, 63, 64, 16383] {
            smc.setFanSpeed(0, speed: speed)
            let data = fake.entries["F0Tg"]!.bytes
            XCTAssertEqual(Int(data[0]) * 256 + Int(data[1]), speed * 4)
        }
        fake.writes = []
        smc.setFanSpeed(0, speed: 16384)
        XCTAssertTrue(fake.writes.isEmpty)
    }
    func testFanSpeedClampsToMaximum() {
        fan()
        fake.put("F0Mx", "flt ", Float(6000).bytes)
        smc.setFanSpeed(0, speed: Int.max)
        XCTAssertEqual(fake.entries["F0Tg"]!.bytes, Float(6000).bytes)
        XCTAssertEqual(fake.writes, ["F0Tg"])
    }
    func testAutomaticModeClassification() {
        XCTAssertTrue(FanMode.automatic.isAutomatic)
        XCTAssertTrue(FanMode.auto3.isAutomatic)
        XCTAssertFalse(FanMode.forced.isAutomatic)
        XCTAssertNil(FanMode(rawValue: 2))
    }

    #if TEST_ARM64
    func testARMLowercaseModeProbeIsCached() {
        fan()
        XCTAssertEqual(smc.fanModeKey(0), "F0md")
        XCTAssertEqual(smc.fanModeKey(1), "F1md")
        XCTAssertEqual(fake.count("5:F0md"), 1)
    }
    func testARMUppercaseModeFallback() {
        fake.put("F0Md", [0])
        XCTAssertEqual(smc.fanModeKey(0), "F0Md")
        XCTAssertEqual(smc.fanModeKey(1), "F1Md")
    }
    func testARMDirectUnlockDoesNotTouchFtstOrSleep() {
        fan(mode: 0)
        smc.setFanMode(0, mode: .forced)
        XCTAssertEqual(fake.writes, ["F0md"])
        XCTAssertEqual(fake.entries["F0md"]!.bytes, [1])
        XCTAssertFalse(fake.calls.contains { $0.contains("Ftst") })
        XCTAssertTrue(fake.sleeps.isEmpty)
    }
    func testARMFanSpeedUnlocksBeforeTargetWrite() {
        fan(mode: 0)
        smc.setFanSpeed(0, speed: 2000)
        XCTAssertEqual(fake.writes, ["F0md", "F0Tg"])
    }
    func testARMFailedModeReadDoesNotWriteTarget() {
        fan()
        XCTAssertEqual(smc.fanModeKey(0), "F0md")
        fake.transportErrors.insert("5:F0md")
        smc.setFanSpeed(0, speed: 2000)
        XCTAssertTrue(fake.writes.isEmpty)
    }
    func testARMFailedUnlockDoesNotWriteTarget() {
        fan(mode: 0)
        fake.firmwareErrors["6:F0md"] = 1
        smc.setFanSpeed(0, speed: 2000)
        XCTAssertFalse(fake.calls.contains("6:F0Tg"))
    }
    func testARMAutomaticClearsModeAndTarget() {
        fan()
        smc.setFanMode(0, mode: .automatic)
        XCTAssertEqual(fake.writes, ["F0md", "F0Tg"])
        XCTAssertEqual(fake.entries["F0md"]!.bytes, [0])
        XCTAssertEqual(fake.entries["F0Tg"]!.bytes, Float(0).bytes)
    }
    func testARMAuto3RestoresAutomaticControl() {
        fan()
        smc.setFanMode(0, mode: .auto3)
        XCTAssertEqual(fake.entries["F0md"]!.bytes, [0])
        XCTAssertEqual(fake.entries["F0Tg"]!.bytes, Float(0).bytes)
    }
    func testARMAutomaticSkipsAlreadyAutomaticModeWrite() {
        fan(mode: 0)
        smc.setFanMode(0, mode: .automatic)
        XCTAssertEqual(fake.writes, ["F0Tg"])
    }
    func testARMTargetWriteRetriesTransientFirmwareFailure() {
        fan()
        fake.transientFailures["6:F0Tg"] = 2
        smc.setFanSpeed(0, speed: 2000)
        XCTAssertEqual(fake.count("6:F0Tg"), 3)
        XCTAssertEqual(fake.sleeps, [50_000, 50_000])
        XCTAssertEqual(fake.entries["F0Tg"]!.bytes, Float(2000).bytes)
    }
    func testARMTargetWriteStopsAtRetryLimit() {
        fan()
        fake.transportErrors.insert("6:F0Tg")
        smc.setFanSpeed(0, speed: 2000)
        XCTAssertEqual(fake.count("6:F0Tg"), 10)
        XCTAssertEqual(fake.sleeps, Array(repeating: 50_000, count: 9))
        XCTAssertTrue(fake.writes.isEmpty)
    }
    func testARMFtstUnlockSequence() {
        fan(mode: 0)
        fake.put("Ftst", [0])
        fake.transientFailures["6:F0md"] = 3
        smc.setFanMode(0, mode: .forced)
        XCTAssertEqual(fake.writes, ["Ftst", "F0md"])
        XCTAssertEqual(fake.sleeps, [3_000_000, 100_000, 100_000])
        XCTAssertEqual(fake.count("6:F0md"), 4)
    }
    func testARMAlreadyUnlockedFtstUsesShortRetryLimit() {
        fan(mode: 0)
        fake.put("Ftst", [1])
        fake.firmwareErrors["6:F0md"] = 1
        smc.setFanMode(0, mode: .forced)
        XCTAssertEqual(fake.count("6:F0md"), 21) // direct attempt + 20 retries
        XCTAssertEqual(fake.sleeps, Array(repeating: 100_000, count: 19))
        XCTAssertFalse(fake.calls.contains("6:Ftst"))
    }
    func testARMFtstWriteFailureStopsUnlock() {
        fan(mode: 0)
        fake.firmwareErrors["6:F0md"] = 1
        fake.put("Ftst", [0])
        fake.firmwareErrors["6:Ftst"] = 1
        smc.setFanMode(0, mode: .forced)
        XCTAssertEqual(fake.count("6:Ftst"), 100)
        XCTAssertEqual(fake.count("6:F0md"), 1)
        XCTAssertEqual(fake.sleeps, Array(repeating: 50_000, count: 99))
    }
    func testARMLongUnlockRetryLimit() {
        fan(mode: 0)
        fake.put("Ftst", [0])
        fake.firmwareErrors["6:F0md"] = 1
        smc.setFanMode(0, mode: .forced)
        XCTAssertEqual(fake.count("6:F0md"), 301)
        XCTAssertEqual(fake.sleeps, [3_000_000] + Array(repeating: 100_000, count: 299))
    }
    func testARMResetFtst() {
        fake.put("Ftst", [1])
        XCTAssertTrue(smc.resetFanControl())
        XCTAssertEqual(fake.writes, ["Ftst"])
        XCTAssertEqual(fake.entries["Ftst"]!.bytes, [0])
    }
    func testARMResetAlreadyClearFtstDoesNotWrite() {
        fake.put("Ftst", [0])
        XCTAssertTrue(smc.resetFanControl())
        XCTAssertTrue(fake.writes.isEmpty)
    }
    func testARMResetFtstFailureReturnsFalse() {
        fake.put("Ftst", [1])
        fake.firmwareErrors["6:Ftst"] = 1
        XCTAssertFalse(smc.resetFanControl())
        XCTAssertEqual(fake.count("6:Ftst"), 10)
    }
    func testARMResetWithoutCountReturnsFalse() {
        XCTAssertFalse(smc.resetFanControl())
        XCTAssertTrue(fake.writes.isEmpty)
    }
    func testARMResetAllFanReadsFailReturnsFalse() {
        fake.put("FNum", [2])
        XCTAssertFalse(smc.resetFanControl())
        XCTAssertTrue(fake.writes.isEmpty)
    }
    func testARMResetContinuesAfterReadFailure() {
        fake.put("FNum", [2])
        fake.put("F0md", [1])
        fake.put("F1md", [1])
        XCTAssertEqual(smc.fanModeKey(0), "F0md")
        fake.firmwareErrors["5:F0md"] = 1
        XCTAssertFalse(smc.resetFanControl())
        XCTAssertEqual(fake.writes, ["F1md"])
    }
    func testARMResetContinuesAfterWriteFailure() {
        fake.put("FNum", [2])
        fake.put("F0md", [1])
        fake.put("F1md", [1])
        fake.firmwareErrors["6:F0md"] = 1
        XCTAssertFalse(smc.resetFanControl())
        XCTAssertEqual(fake.writes, ["F1md"])
    }
    func testARMResetSkipsAlreadyAutomaticFans() {
        fake.put("FNum", [2])
        fake.put("F0md", [0])
        fake.put("F1md", [1])
        XCTAssertTrue(smc.resetFanControl())
        XCTAssertEqual(fake.writes, ["F1md"])
    }
    #else
    func testIntelAllTwoFanMaskTransitions() {
        for mask in UInt16(0)...3 {
            for id in 0...1 {
                for mode in [FanMode.automatic, .forced, .auto3] { assertMask(mask, id: id, mode: mode) }
            }
        }
    }
    func testIntelMaskPreservesOtherBitsForEverySupportedFan() {
        for mask: UInt16 in [0, 0xFFFF, 0xAAAA, 0x5555, 0x8000, 0x7FFF] {
            for id in 0...9 {
                for mode in [FanMode.automatic, .forced, .auto3] { assertMask(mask, id: id, mode: mode) }
            }
        }
    }
    func testIntelRepeatedModeRequestsAreIdempotent() {
        fake.put("FS! ", "ui16", [0, 3])
        for _ in 0..<10 { smc.setFanMode(0, mode: .forced) }
        XCTAssertTrue(fake.writes.isEmpty)
        XCTAssertEqual(fake.entries["FS! "]!.bytes, [0, 3])
    }
    func testIntelFailedMaskReadDoesNotWrite() {
        fake.put("FS! ", "ui16", [0, 3])
        fake.firmwareErrors["5:FS! "] = 1
        smc.setFanMode(0, mode: .automatic)
        XCTAssertTrue(fake.writes.isEmpty)
    }
    func testIntelMissingMaskDoesNotWrite() {
        smc.setFanMode(0, mode: .forced)
        XCTAssertTrue(fake.writes.isEmpty)
    }
    func testIntelDirectModeAndMaskAreUpdated() {
        fake.put("F0Md", [0])
        fake.put("FS! ", "ui16", [0, 2])
        smc.setFanMode(0, mode: .forced)
        XCTAssertEqual(fake.writes, ["F0Md", "FS! "])
        XCTAssertEqual(fake.entries["F0Md"]!.bytes, [1])
        XCTAssertEqual(fake.entries["FS! "]!.bytes, [0, 3])
    }
    func testIntelDirectModeWriteFailureStopsMaskUpdate() {
        fake.put("F0Md", [0])
        fake.put("FS! ", "ui16", [0, 2])
        fake.firmwareErrors["6:F0Md"] = 1
        smc.setFanMode(0, mode: .forced)
        XCTAssertFalse(fake.calls.contains("6:FS! "))
    }
    func testIntelFanSpeedDoesNotChangeMode() {
        fan()
        smc.setFanSpeed(0, speed: 2000)
        XCTAssertEqual(fake.writes, ["F0Tg"])
        XCTAssertTrue(fake.sleeps.isEmpty)
    }
    func testIntelModeKeyUsesUppercaseWithoutProbe() {
        XCTAssertEqual(smc.fanModeKey(0), "F0Md")
        XCTAssertEqual(smc.fanModeKey(9), "F9Md")
        XCTAssertTrue(fake.calls.isEmpty)
    }
    #endif
}
