#!/usr/bin/env python3
"""Run: python3 Kit/scripts/run-smc-tests.py (macOS, Xcode, Python 3).

Runs Tests/SMC.swift against both architecture branches with fake IOKit and
sleep calls. Production source is unchanged; temporary build files are removed.
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
            command += [str(build / "SMCUnderTest.swift"), str(TESTS / "SMC.swift"), str(build / "main.swift"),
                        "-o", str(executable)]
            subprocess.run(command, check=True, env=env, timeout=180)
            subprocess.run([str(executable)], check=True, env=env, timeout=60)


if __name__ == "__main__":
    run()
