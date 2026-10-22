#!/usr/bin/env python3
"""Build the bundled LevelDB archive with Snappy (macOS, Xcode, CMake, Python 3).

Run: python3 Kit/scripts/build-leveldb.py
Use --cmake for a CMake executable outside PATH, or --work-dir to retain builds
and reuse verified source downloads. The output includes arm64 and x86_64,
targets macOS 12.0, and contains Snappy without a separate runtime dependency.
Existing uncompressed databases remain readable. Older builds without Snappy
cannot read tables compressed by this library.
"""
import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
    # LevelDB 1.23 with the same public headers as Kit/lldb/include.
    "leveldb": (
        "068d5ee1a3ac40dabd00d211d5013af44be55bea",
        "8f6106a84eb6f22d1b28029741b1879081c38bd53722e5938f720397104ebc80",
    ),
    # Snappy 1.3.1.
    "snappy": (
        "9c28114a38866f6deeaa826db918293bc28ae410",
        "4371172392f382befcad0faccbf302ea9601b7a787db49f1c0744431feff3224",
    ),
}


def source(work, name):
    commit, checksum = SOURCES[name]
    archive = work / f"{name}.tar.gz"
    if not archive.exists():
        url = f"https://codeload.github.com/google/{name}/tar.gz/{commit}"
        subprocess.run(["curl", "-fL", "--retry", "3", url, "-o", str(archive)], check=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != checksum:
        raise RuntimeError(f"Source checksum mismatch: {archive}")
    subprocess.run(["tar", "-xzf", str(archive), "-C", str(work)], check=True)
    return work / f"{name}-{commit}"


def verify_headers(leveldb):
    bundled = ROOT / "Kit/lldb/include"
    upstream = leveldb / "include/leveldb"
    names = {header.name for header in bundled.glob("*.h")}
    if names != {header.name for header in upstream.glob("*.h")}:
        raise RuntimeError("Bundled LevelDB public header list differs from the pinned source")
    for name in sorted(names):
        normalized = (upstream / name).read_text().replace('"leveldb/', '"')
        if normalized != (bundled / name).read_text():
            raise RuntimeError(f"Bundled LevelDB header differs from the pinned source: {name}")


def xcrun(*args):
    return subprocess.check_output(["xcrun", *args], text=True).strip()


def build(work, cmake, output):
    work.mkdir(parents=True, exist_ok=True)
    leveldb = source(work, "leveldb")
    snappy = source(work, "snappy")
    verify_headers(leveldb)
    (work / "CMakeLists.txt").write_text(
        "cmake_minimum_required(VERSION 3.10)\n"
        "project(StatsLevelDB LANGUAGES C CXX)\n"
        "set(BUILD_SHARED_LIBS OFF CACHE BOOL \"\" FORCE)\n"
        "set(LEVELDB_BUILD_TESTS OFF CACHE BOOL \"\" FORCE)\n"
        "set(LEVELDB_BUILD_BENCHMARKS OFF CACHE BOOL \"\" FORCE)\n"
        "set(LEVELDB_INSTALL OFF CACHE BOOL \"\" FORCE)\n"
        "set(SNAPPY_BUILD_TESTS OFF CACHE BOOL \"\" FORCE)\n"
        "set(SNAPPY_BUILD_BENCHMARKS OFF CACHE BOOL \"\" FORCE)\n"
        "set(SNAPPY_INSTALL OFF CACHE BOOL \"\" FORCE)\n"
        "set(SNAPPY_REQUIRE_AVX OFF CACHE BOOL \"\" FORCE)\n"
        "set(SNAPPY_REQUIRE_AVX2 OFF CACHE BOOL \"\" FORCE)\n"
        f"add_subdirectory(\"{snappy.name}\" snappy)\n"
        "set(HAVE_SNAPPY ON CACHE BOOL \"\" FORCE)\n"
        "set(HAVE_CRC32C OFF CACHE BOOL \"\" FORCE)\n"
        "set(HAVE_ZSTD OFF CACHE BOOL \"\" FORCE)\n"
        "set(HAVE_TCMALLOC OFF CACHE BOOL \"\" FORCE)\n"
        f"add_subdirectory(\"{leveldb.name}\" leveldb)\n"
    )
    sdk = xcrun("--sdk", "macosx", "--show-sdk-path")
    clang = xcrun("--find", "clang")
    clangxx = xcrun("--find", "clang++")
    archives = []
    for arch in ("arm64", "x86_64"):
        directory = work / f"build-{arch}"
        print(f"\nBuilding LevelDB with Snappy: {arch}", flush=True)
        subprocess.run([
            cmake, "-S", str(work), "-B", str(directory), "-G", "Unix Makefiles",
            "-DCMAKE_BUILD_TYPE=Release", f"-DCMAKE_OSX_ARCHITECTURES={arch}",
            "-DCMAKE_OSX_DEPLOYMENT_TARGET=12.0", f"-DCMAKE_OSX_SYSROOT={sdk}",
            f"-DCMAKE_C_COMPILER={clang}", f"-DCMAKE_CXX_COMPILER={clangxx}",
            "-DCMAKE_CXX_STANDARD=14", "-DCMAKE_CXX_STANDARD_REQUIRED=ON",
            "-DCMAKE_CXX_EXTENSIONS=OFF", "-DCMAKE_CXX_FLAGS=-stdlib=libc++",
        ], check=True)
        config = (directory / "leveldb/include/port/port_config.h").read_text()
        if not re.search(r"^#define HAVE_SNAPPY 1$", config, re.MULTILINE):
            raise RuntimeError(f"Snappy support is disabled for {arch}")
        subprocess.run([
            cmake, "--build", str(directory), "--target", "leveldb",
            "--parallel", str(os.cpu_count() or 2),
        ], check=True)
        archive = directory / "libleveldb.a"
        subprocess.run([
            "xcrun", "libtool", "-static", "-o", str(archive),
            str(directory / "leveldb/libleveldb.a"), str(directory / "snappy/libsnappy.a"),
        ], check=True)
        archives.append(str(archive))
    universal = work / "libleveldb.a"
    subprocess.run(["xcrun", "lipo", "-create", *archives, "-output", str(universal)], check=True)
    if set(xcrun("lipo", "-archs", str(universal)).split()) != {"arm64", "x86_64"}:
        raise RuntimeError("The archive must contain both arm64 and x86_64")
    output.parent.mkdir(parents=True, exist_ok=True)
    if universal != output:
        shutil.copyfile(universal, output)
    print(f"\nBuilt {output} ({output.stat().st_size:,} bytes)", flush=True)


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cmake", default="cmake", help="CMake executable (default: cmake)")
    parser.add_argument("--work-dir", type=Path, help="Keep sources and builds in this directory")
    parser.add_argument("--output", type=Path, default=ROOT / "Kit/lldb/libleveldb.a",
                        help="Output universal archive (default: Kit/lldb/libleveldb.a)")
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("This build requires macOS and Xcode command line tools")
    cmake = shutil.which(args.cmake)
    if cmake is None:
        parser.error("CMake was not found; provide its executable with --cmake")
    output = args.output.resolve()
    if args.work_dir:
        build(args.work_dir.resolve(), cmake, output)
    else:
        with tempfile.TemporaryDirectory(prefix="stats-leveldb-build-") as directory:
            build(Path(directory), cmake, output)


if __name__ == "__main__":
    run()
