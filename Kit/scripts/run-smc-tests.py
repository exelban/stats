#!/usr/bin/env python3
"""Run: python3 Kit/scripts/run-smc-tests.py (macOS, Xcode, Python 3).

Runs Tests/SMC.swift against both architecture branches with fake IOKit and
sleep calls, plus helper lifecycle tests with fake XPC and service operations.
Production source is unchanged; temporary build files are removed.
This standalone suite is independent of the existing Xcode Tests target.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / "Tests"
BOUNDARIES = (
    "IOServiceMatching", "IOServiceGetMatchingServices", "IOIteratorNext",
    "IOObjectRelease", "IOServiceOpen", "IOServiceClose",
    "IOConnectCallStructMethod", "usleep",
)


def swift_block(source, declaration):
    """Extract a complete declaration; fail if the expected source moves."""
    if source.count(declaration) != 1:
        raise RuntimeError(f"Missing or ambiguous declaration: {declaration}")
    start = source.index(declaration)
    opening = source.rfind("{", start, source.index("\n", start))
    if opening < start:
        raise RuntimeError(f"Declaration must open on its first line: {declaration}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index + 1]
    raise RuntimeError(f"Unbalanced declaration: {declaration}")


def helper_source():
    # Compile the actual lifecycle logic, with XPC/service boundaries supplied
    # by Tests/SMC.swift. Never run the privileged helper's entry point.
    server = (ROOT / "SMC/Helper/main.swift").read_text()
    state = swift_block(server, "final class HelperConnectionState {")
    state = state.replace("NSXPCConnection", "FakeHelperClientConnection")
    client = (ROOT / "Kit/helpers.swift").read_text()
    methods = "\n".join(swift_block(client, declaration) for declaration in (
        "private func reinstall()",
        "private func helper(_ completion:",
        "private func restoreFanModes(completion:",
        "public func uninstall(silent:",
    ))
    methods = methods.replace("private func", "func")
    methods = methods.replace('SMC.shared.getValue("FNum")', "FakeHelperEnvironment.current.fanCount")
    methods = methods.replace("if #available(macOS 13, *)", "if self.useModernService")
    methods = methods.replace("SMAppService.", "FakeHelperService.")
    methods = methods.replace("NotificationCenter.default", "FakeHelperNotifications.default")
    methods = methods.replace('Bundle.main.path(forResource: "smc", ofType: nil)!', '"/mock/smc"')
    return ("import Foundation\n" + state + "\n" +
            swift_block(client, "public enum SMCHelperInstallState {") + "\n" +
            "final class TestSMCHelper: HelperClientFixture {\n" + methods + "\n}\n")


def run():
    platform = Path(subprocess.check_output(
        ["xcrun", "--sdk", "macosx", "--show-sdk-platform-path"], text=True).strip())
    frameworks = platform / "Developer/Library/Frameworks"
    libraries = platform / "Developer/usr/lib"
    if not (frameworks / "XCTest.framework").exists():
        raise RuntimeError("XCTest requires a full Xcode installation selected with xcode-select")
    source = (ROOT / "SMC/smc.swift").read_text()
    # Keep production algorithms and connection lifecycle intact. Only redirect
    # OS calls in a disposable copy; never compile the live driver into tests.
    for name in BOUNDARIES:
        source, count = re.subn(r"\b" + name + r"(?=\()", "mock" + name, source)
        if not count:
            raise RuntimeError(f"Missing expected OS boundary: {name}")
    source = source.replace("#if arch(arm64)", "#if TEST_ARM64")
    if re.search(r"\b(?:" + "|".join(BOUNDARIES) + r")\s*\(", source):
        raise RuntimeError("An unmocked OS call remains")
    tests = (TESTS / "SMC.swift").read_text()
    names = re.findall(r"^    func (test\w+)\(\)", tests, re.MULTILINE)
    if not names or len(names) != len(set(names)):
        raise RuntimeError("Missing or duplicate tests")
    with tempfile.TemporaryDirectory(prefix="stats-smc-tests-") as directory:
        build = Path(directory)
        (build / "SMCUnderTest.swift").write_text(source)
        (build / "HelperUnderTest.swift").write_text(helper_source())
        env = dict(os.environ, SWIFT_MODULECACHE_PATH=str(build / "cache"))
        for branch in ("intel", "arm64"):
            selected = [n for n in names if not n.startswith(
                "testARM" if branch == "intel" else "testIntel")]
            (build / "main.swift").write_text(
                "import XCTest\nimport Darwin\n"
                "let suite = SMCTests.defaultTestSuite\nsuite.run()\n"
                f"exit(suite.testRun?.hasSucceeded == true && suite.testRun?.executionCount == {len(selected)} ? 0 : 1)\n"
            )
            print(f"\nRunning {len(selected)} SMC tests: {branch} branch", flush=True)
            executable = build / branch
            command = ["xcrun", "swiftc", "-swift-version", "5", "-g",
                       "-module-cache-path", str(build / "cache"),
                       "-I", str(libraries), "-L", str(libraries),
                       "-Xlinker", "-rpath", "-Xlinker", str(libraries),
                       "-F", str(frameworks), "-Xlinker", "-rpath", "-Xlinker", str(frameworks)]
            if branch == "arm64":
                command += ["-D", "TEST_ARM64"]
            command += [str(build / "SMCUnderTest.swift"), str(build / "HelperUnderTest.swift"),
                        str(ROOT / "SMC/Helper/protocol.swift"),
                        str(TESTS / "SMC.swift"), str(build / "main.swift"),
                        "-o", str(executable)]
            subprocess.run(command, check=True, env=env, timeout=180)
            subprocess.run([str(executable)], check=True, env=env, timeout=60)


if __name__ == "__main__":
    run()
