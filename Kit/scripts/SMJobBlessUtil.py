#! /usr/bin/python3
#
#   File:       SMJobBlessUtil.py
#
#   Contains:   Tool for checking and correcting apps that use SMJobBless.
#
#   Written by: DTS
#
#   Copyright:  Copyright (c) 2012 Apple Inc. All Rights Reserved.
#
#   Disclaimer: IMPORTANT: This Apple software is supplied to you by Apple Inc.
#               ("Apple") in consideration of your agreement to the following
#               terms, and your use, installation, modification or
#               redistribution of this Apple software constitutes acceptance of
#               these terms.  If you do not agree with these terms, please do
#               not use, install, modify or redistribute this Apple software.
#
#               In consideration of your agreement to abide by the following
#               terms, and subject to these terms, Apple grants you a personal,
#               non-exclusive license, under Apple's copyrights in this
#               original Apple software (the "Apple Software"), to use,
#               reproduce, modify and redistribute the Apple Software, with or
#               without modifications, in source and/or binary forms; provided
#               that if you redistribute the Apple Software in its entirety and
#               without modifications, you must retain this notice and the
#               following text and disclaimers in all such redistributions of
#               the Apple Software. Neither the name, trademarks, service marks
#               or logos of Apple Inc. may be used to endorse or promote
#               products derived from the Apple Software without specific prior
#               written permission from Apple.  Except as expressly stated in
#               this notice, no other rights or licenses, express or implied,
#               are granted by Apple herein, including but not limited to any
#               patent rights that may be infringed by your derivative works or
#               by other works in which the Apple Software may be incorporated.
#
#               The Apple Software is provided by Apple on an "AS IS" basis.
#               APPLE MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
#               WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
#               MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING
#               THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
#               COMBINATION WITH YOUR PRODUCTS.
#
#               IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT,
#               INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
#               TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#               DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY
#               OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
#               OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY
#               OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR
#               OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF
#               SUCH DAMAGE.
#

import sys
import os
import getopt
import subprocess
import plistlib
import operator
import platform

class UsageException (Exception):
    """
    Raised when the progam detects a usage issue; the top-level code catches this
    and prints a usage message.
    """
    pass

class CheckException (Exception):
    """
    Raised when the "check" subcommand detects a problem; the top-level code catches
    this and prints a nice error message.
    """
    def __init__(self, message, path=None):
        self.message = message
        self.path = path

def checkCodeSignature(programPath, programType):
    """Checks the code signature of the referenced program."""

    # Use the codesign tool to check the signature.  The second "-v" is required to enable
    # verbose mode, which causes codesign to do more checking.  By default it does the minimum
    # amount of checking ("Is the program properly signed?").  If you enabled verbose mode it
    # does other sanity checks, which we definitely want.  The specific thing I'd like to
    # detect is "Does the code satisfy its own designated requirement?" and I need to enable
    # verbose mode to get that.

    args = [
        # "false",
        "codesign",
        "-v",
        "-v",
        programPath
    ]
    try:
        subprocess.check_call(args, stderr=open("/dev/null"))
    except subprocess.CalledProcessError as e:
        raise CheckException("%s code signature invalid" % programType, programPath)

def readDesignatedRequirement(programPath, programType):
    """Returns the designated requirement of the program as a string."""
    args = [
        # "false",
        "codesign",
        "-d",
        "-r",
        "-",
        programPath
    ]
    try:
        req = subprocess.check_output(args, stderr=open("/dev/null"), encoding="utf-8")
    except subprocess.CalledProcessError as e:
        raise CheckException("%s designated requirement unreadable" % programType, programPath)

    reqLines = req.splitlines()
    if len(reqLines) != 1 or not req.startswith("designated => "):
        raise CheckException("%s designated requirement malformed" % programType, programPath)
    return reqLines[0][len("designated => "):]

def readInfoPlistFromPath(infoPath):
    """Reads an "Info.plist" file from the specified path."""
    try:
        with open(infoPath, 'rb') as fp:
            info = plistlib.load(fp)
    except:
        raise CheckException("'Info.plist' not readable", infoPath)
    if not isinstance(info, dict):
        raise CheckException("'Info.plist' root must be a dictionary", infoPath)
    return info

def readPlistFromToolSection(toolPath, segmentName, sectionName):
    """Reads a dictionary property list from the specified section within the specified executable."""

    # Run otool -s to get a hex dump of the section.

    args = [
        # "false",
        "otool",
        "-V",
        "-arch",
        platform.machine(),
        "-s",
        segmentName,
        sectionName,
        toolPath
    ]
    try:
        plistDump = subprocess.check_output(args, encoding="utf-8")
    except subprocess.CalledProcessError as e:
        raise CheckException("tool %s / %s section unreadable" % (segmentName, sectionName), toolPath)

    # Convert that dump to an property list.

    plistLines = plistDump.strip().splitlines(keepends=True)

    if len(plistLines) < 3:
        raise CheckException("tool %s / %s section dump malformed (1)" % (segmentName, sectionName), toolPath)

    header = plistLines[1].strip()

    if not header.endswith("(%s,%s) section" % (segmentName, sectionName)):
        raise CheckException("tool %s / %s section dump malformed (2)" % (segmentName, sectionName), toolPath)

    del plistLines[0:2]

    try:

        if header.startswith('Contents of'):
            data = []
            for line in plistLines:
                # line looks like this:
                #
                # '100000000 3c 3f 78 6d 6c 20 76 65 72 73 69 6f 6e 3d 22 31 |<?xml version="1|'
                parts = line.split('|')
                assert len(parts) == 3
                columns = parts[0].split()
                assert len(columns) >= 2
                del columns[0]
                for hexStr in columns:
                    data.append(int(hexStr, 16))
            data = bytes(data)
        else:
            data = bytes("".join(plistLines), encoding="utf-8")

        plist = plistlib.loads(data)
    except:
        raise CheckException("tool %s / %s section dump malformed (3)" % (segmentName, sectionName), toolPath)

    # Check the root of the property list.

    if not isinstance(plist, dict):
        raise CheckException("tool %s / %s property list root must be a dictionary" % (segmentName, sectionName), toolPath)

    return plist

def checkStep1(appPath):
    """Checks that the app and the tool are both correctly code signed."""

    if not os.path.isdir(appPath):
        raise CheckException("app not found", appPath)

    # Check the app's code signature.

    checkCodeSignature(appPath, "app")

    # Check the tool directory.

    toolDirPath = os.path.join(appPath, "Contents", "Library", "LaunchServices")
    if not os.path.isdir(toolDirPath):
        raise CheckException("tool directory not found", toolDirPath)

    # Check each tool's code signature.

    toolPathList = []
    for toolName in os.listdir(toolDirPath):
        if toolName != ".DS_Store":
            toolPath = os.path.join(toolDirPath, toolName)
            if not os.path.isfile(toolPath):
                raise CheckException("tool directory contains a directory", toolPath)
            checkCodeSignature(toolPath, "tool")
            toolPathList.append(toolPath)

    # Check that we have at least one tool.

    if len(toolPathList) == 0:
        raise CheckException("no tools found", toolDirPath)

    return toolPathList

def checkStep2(appPath, toolPathList):
    """Checks the SMPrivilegedExecutables entry in the app's "Info.plist"."""

    # Create a map from the tool name (not path) to its designated requirement.

    toolNameToReqMap = dict()
    for toolPath in toolPathList:
        req = readDesignatedRequirement(toolPath, "tool")
        toolNameToReqMap[os.path.basename(toolPath)] = req

    # Read the Info.plist for the app and extract the SMPrivilegedExecutables value.

    infoPath = os.path.join(appPath, "Contents", "Info.plist")
    info = readInfoPlistFromPath(infoPath)
    if "SMPrivilegedExecutables" not in info:
        raise CheckException("'SMPrivilegedExecutables' not found", infoPath)
    infoToolDict = info["SMPrivilegedExecutables"]
    if not isinstance(infoToolDict, dict):
        raise CheckException("'SMPrivilegedExecutables' must be a dictionary", infoPath)

    # Check that the list of tools matches the list of SMPrivilegedExecutables entries.

    if sorted(infoToolDict.keys()) != sorted(toolNameToReqMap.keys()):
        raise CheckException("'SMPrivilegedExecutables' and tools in 'Contents/Library/LaunchServices' don't match")

    # Check that all the requirements match.

    # This is an interesting policy choice.  Technically the tool just needs to match
    # the requirement listed in SMPrivilegedExecutables, and we can check that by
    # putting the requirement into tmp.req and then running
    #
    # $ codesign -v -R tmp.req /path/to/tool
    #
    # However, for a Developer ID signed tool we really want to have the SMPrivilegedExecutables
    # entry contain the tool's designated requirement because Xcode has built a
    # more complex DR that does lots of useful and important checks.  So, as a matter
    # of policy we require that the value in SMPrivilegedExecutables match the tool's DR.

    for toolName in infoToolDict:
        if infoToolDict[toolName] != toolNameToReqMap[toolName]:
            raise CheckException("tool designated requirement (%s) doesn't match entry in 'SMPrivilegedExecutables' (%s)" % (toolNameToReqMap[toolName], infoToolDict[toolName]))

def checkStep3(appPath, toolPathList):
    """Checks the "Info.plist" embedded in each helper tool."""

    # First get the app's designated requirement.

    appReq = readDesignatedRequirement(appPath, "app")

    # Then check that the tool's SMAuthorizedClients value matches it.

    for toolPath in toolPathList:
        info = readPlistFromToolSection(toolPath, "__TEXT", "__info_plist")

        if "CFBundleInfoDictionaryVersion" not in info or info["CFBundleInfoDictionaryVersion"] != "6.0":
            raise CheckException("'CFBundleInfoDictionaryVersion' in tool __TEXT / __info_plist section must be '6.0'", toolPath)

        if "CFBundleIdentifier" not in info or info["CFBundleIdentifier"] != os.path.basename(toolPath):
            raise CheckException("'CFBundleIdentifier' in tool __TEXT / __info_plist section must match tool name", toolPath)

        if "SMAuthorizedClients" not in info:
            raise CheckException("'SMAuthorizedClients' in tool __TEXT / __info_plist section not found", toolPath)
        infoClientList = info["SMAuthorizedClients"]
        if not isinstance(infoClientList, list):
            raise CheckException("'SMAuthorizedClients' in tool __TEXT / __info_plist section must be an array", toolPath)
        if len(infoClientList) != 1:
            raise CheckException("'SMAuthorizedClients' in tool __TEXT / __info_plist section must have one entry", toolPath)

        # Again, as a matter of policy we require that the SMAuthorizedClients entry must
        # match exactly the designated requirement of the app.

        if infoClientList[0] != appReq:
            raise CheckException("app designated requirement (%s) doesn't match entry in 'SMAuthorizedClients' (%s)" % (appReq, infoClientList[0]), toolPath)

def checkStep4(appPath, toolPathList):
    """Checks the "launchd.plist" embedded in each helper tool."""

    for toolPath in toolPathList:
        launchd = readPlistFromToolSection(toolPath, "__TEXT", "__launchd_plist")

        if "Label" not in launchd or launchd["Label"] != os.path.basename(toolPath):
            raise CheckException("'Label' in tool __TEXT / __launchd_plist section must match tool name", toolPath)

        # We don't need to check that the label matches the bundle identifier because
        # we know it matches the tool name and step 4 checks that the tool name matches
        # the bundle identifier.

def checkStep5(appPath):
    """There's nothing to do here; we effectively checked for this is steps 1 and 2."""
    pass

def check(appPath):
    """Checks the SMJobBless setup of the specified app."""

    # Each of the following steps matches a bullet point in the SMJobBless header doc.

    toolPathList = checkStep1(appPath)

    checkStep2(appPath, toolPathList)

    checkStep3(appPath, toolPathList)

    checkStep4(appPath, toolPathList)

    checkStep5(appPath)

def setreq(appPath, appInfoPlistPath, toolInfoPlistPaths):
    """
    Reads information from the built app and uses it to set the SMJobBless setup
    in the specified app and tool Info.plist source files.
    """

    if not os.path.isdir(appPath):
        raise CheckException("app not found", appPath)

    if not os.path.isfile(appInfoPlistPath):
        raise CheckException("app 'Info.plist' not found", appInfoPlistPath)
    for toolInfoPlistPath in toolInfoPlistPaths:
        if not os.path.isfile(toolInfoPlistPath):
            raise CheckException("app 'Info.plist' not found", toolInfoPlistPath)

    # Get the designated requirement for the app and each of the tools.

    appReq = readDesignatedRequirement(appPath, "app")

    toolDirPath = os.path.join(appPath, "Contents", "Library", "LaunchServices")
    if not os.path.isdir(toolDirPath):
        raise CheckException("tool directory not found", toolDirPath)

    toolNameToReqMap = {}
    for toolName in os.listdir(toolDirPath):
        req = readDesignatedRequirement(os.path.join(toolDirPath, toolName), "tool")
        toolNameToReqMap[toolName] = req

    if len(toolNameToReqMap) > len(toolInfoPlistPaths):
        raise CheckException("tool directory has more tools (%d) than you've supplied tool 'Info.plist' paths (%d)" % (len(toolNameToReqMap), len(toolInfoPlistPaths)), toolDirPath)
    if len(toolNameToReqMap) < len(toolInfoPlistPaths):
        raise CheckException("tool directory has fewer tools (%d) than you've supplied tool 'Info.plist' paths (%d)" % (len(toolNameToReqMap), len(toolInfoPlistPaths)), toolDirPath)

    # Build the new value for SMPrivilegedExecutables.

    appToolDict = {}
    toolInfoPlistPathToToolInfoMap = {}
    for toolInfoPlistPath in toolInfoPlistPaths:
        toolInfo = readInfoPlistFromPath(toolInfoPlistPath)
        toolInfoPlistPathToToolInfoMap[toolInfoPlistPath] = toolInfo
        if "CFBundleIdentifier" not in toolInfo:
            raise CheckException("'CFBundleIdentifier' not found", toolInfoPlistPath)
        bundleID = toolInfo["CFBundleIdentifier"]
        if not isinstance(bundleID, str):
            raise CheckException("'CFBundleIdentifier' must be a string", toolInfoPlistPath)
        appToolDict[bundleID] = toolNameToReqMap[bundleID]

    # Set the SMPrivilegedExecutables value in the app "Info.plist".

    appInfo = readInfoPlistFromPath(appInfoPlistPath)
    needsUpdate = "SMPrivilegedExecutables" not in appInfo
    if not needsUpdate:
        oldAppToolDict = appInfo["SMPrivilegedExecutables"]
        if not isinstance(oldAppToolDict, dict):
            raise CheckException("'SMPrivilegedExecutables' must be a dictionary", appInfoPlistPath)
        appToolDictSorted = sorted(appToolDict.items(), key=operator.itemgetter(0))
        oldAppToolDictSorted = sorted(oldAppToolDict.items(), key=operator.itemgetter(0))
        needsUpdate = (appToolDictSorted != oldAppToolDictSorted)

    if needsUpdate:
        appInfo["SMPrivilegedExecutables"] = appToolDict
        with open(appInfoPlistPath, 'wb') as fp:
            plistlib.dump(appInfo, fp)
        print ("%s: updated" % appInfoPlistPath, file = sys.stdout)

    # Set the SMAuthorizedClients value in each tool's "Info.plist".

    toolAppListSorted = [ appReq ]      # only one element, so obviously sorted (-:
    for toolInfoPlistPath in toolInfoPlistPaths:
        toolInfo = toolInfoPlistPathToToolInfoMap[toolInfoPlistPath]

        needsUpdate = "SMAuthorizedClients" not in toolInfo
        if not needsUpdate:
            oldToolAppList = toolInfo["SMAuthorizedClients"]
            if not isinstance(oldToolAppList, list):
                raise CheckException("'SMAuthorizedClients' must be an array", toolInfoPlistPath)
            oldToolAppListSorted = sorted(oldToolAppList)
            needsUpdate = (toolAppListSorted != oldToolAppListSorted)

        if needsUpdate:
            toolInfo["SMAuthorizedClients"] = toolAppListSorted
            with open(toolInfoPlistPath, 'wb') as f:
                plistlib.dump(toolInfo, f)
            print("%s: updated" % toolInfoPlistPath, file = sys.stdout)

def main():
    options, appArgs = getopt.getopt(sys.argv[1:], "d")

    debug = False
    for opt, val in options:
        if opt == "-d":
            debug = True
        else:
            raise UsageException()

    if len(appArgs) == 0:
        raise UsageException()
    command = appArgs[0]
    if command == "check":
        if len(appArgs) != 2:
            raise UsageException()
        check(appArgs[1])
    elif command == "setreq":
        if len(appArgs) < 4:
            raise UsageException()
        setreq(appArgs[1], appArgs[2], appArgs[3:])
    else:
        raise UsageException()

if __name__ == "__main__":
    try:
        main()
    except CheckException as e:
        if e.path is None:
            print("%s: %s" % (os.path.basename(sys.argv[0]), e.message), file = sys.stderr)
        else:
            path = e.path
            if path.endswith("/"):
                path = path[:-1]
            print("%s: %s" % (path, e.message), file = sys.stderr)
        sys.exit(1)
    except UsageException as e:
        print("usage: %s check  /path/to/app" % os.path.basename(sys.argv[0]), file = sys.stderr)
        print("       %s setreq /path/to/app /path/to/app/Info.plist /path/to/tool/Info.plist..." % os.path.basename(sys.argv[0]), file = sys.stderr)
        sys.exit(1)
