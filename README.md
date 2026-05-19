# Stats

<a href="https://github.com/exelban/stats/releases"><p align="center"><img src="https://github.com/exelban/stats/raw/master/Stats/Supporting%20Files/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="120"></p></a>

macOS system monitor in your menu bar

---

## Fork customizations

This is a personal fork of [exelban/stats](https://github.com/exelban/stats) with a redesigned unified popup and dark UI.

### What's different

**Single menu bar icon**
All active modules are combined into one icon by default (`CombinedModules = true`). Clicking it opens a single unified popup instead of per-module popovers.

**Unified dark popup — `MonitorView`**
Replaces the original per-module popups with a single dark-themed panel (360 pt wide) containing six tabs:

| Tab | Contents |
|-----|----------|
| **CPU** | Line chart (60 samples) + stats grid (User / System / Idle / Cores) + process search + app-icon process list (8 rows) + CPU temperature sensors (color-coded: green / orange / red) |
| **Memory** | Line chart with GB Y-axis labels + process search + app-icon process list (8 rows) |
| **Network** | Dual-line chart (upload orange, download blue) + stats grid (Download / Upload / Total Down / Total Up) |
| **Storage** | Horizontal usage bar + stats grid (Total / Used / Free / Purgeable) |
| **Battery** | Horizontal level bar + stats grid (Level / Source / Health / Cycles) + secondary grid (Time / Temperature / Voltage / AC Watts) |
| **Fans** | Fan speed rows with RPM value and proportional progress bar (% of max speed) |

**Design language**
- Near-black navy background (`#0A0A14`) with dark card surfaces (`#141423`)
- Text-only pill tab bar — white pill animates to the active tab
- App icons in the CPU and Memory process lists loaded live from running processes
- Y-axis GB gridlines on the memory chart (25 / 50 / 75 % of total RAM)
- CPU temperature color coding: green ≤ 65 °C, orange 66–85 °C, red > 85 °C

**Data routing**
Module readers post their data via `NotificationCenter` so `MonitorView` can consume them without touching any reader code:

| Notification | Source |
|---|---|
| `.monitorCPULoad` | CPU module |
| `.monitorCPUProcesses` | CPU module |
| `.monitorRAMUsage` | RAM module |
| `.monitorRAMProcesses` | RAM module |
| `.monitorNetUsage` | Network module |
| `.monitorBatteryUsage` | Battery module |
| `.monitorSensorsData` | Sensors module (always-on reader, independent of module enabled state) |

The Sensors reader is started unconditionally at launch so fan speeds and CPU temperatures are available even when the Sensors menu bar widget is disabled.

### Building locally

A `run.sh` script at the repo root kills any running instance, builds with ad-hoc signing (no Developer ID certificate required), and launches the app:

```bash
chmod +x run.sh
./run.sh
```

To see full compiler output on a failed build:

```bash
xcodebuild -project Stats.xcodeproj -scheme Stats -configuration Debug \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### Branch

All customizations live on the `feature/monitor-view` branch. `master` tracks upstream.

---

## Installation
### Manual
You can download the latest version [here](https://github.com/exelban/stats/releases/latest/download/Stats.dmg).
This will download a file called `Stats.dmg`. Open it and move the app to the application folder.

### Homebrew
To install it using Homebrew, open the Terminal app and type:
```bash
brew install stats
```

### Legacy version
Legacy version for older systems could be found [here](https://mac-stats.com/downloads).

## Requirements
Stats is supported on the released macOS version starting from macOS 11.15 (Big Sur).

## Features
Stats is an application that allows you to monitor your macOS system.

 - CPU utilization
 - GPU utilization
 - Memory usage
 - Disk utilization
 - Network usage
 - Battery level
 - Fan's control (not maintained)
 - Sensors information (Temperature/Voltage/Power)
 - Bluetooth devices
 - Multiple time zone clock

## FAQs

### How do you change the order of the menu bar icons?
macOS decides the order of the menu bar items not `Stats` - it may change after the first reboot after installing Stats.

To change the order of any menu bar icon - macOS Mojave (version 10.14) and up.

1. Hold down ⌘ (command key).
2. Drag the icon to the desired position on the menu bar.
3. Release ⌘ (command key)

### Stats icons do not appear in the menu bar
macOS 26 introduced a new privacy control under System Settings → Menu Bar. Apps must be explicitly allowed there to display menu bar items. If Stats is running with at least one module active and one widget enabled, but none of its icons show up in the menu bar, this is almost certainly the cause. More details you can find [here](https://github.com/exelban/stats/issues/3120).

**Solution:** open **System Settings → Menu Bar** and toggle **Stats** ON.

### How to reduce energy impact or CPU usage of Stats?
Stats tries to be efficient as it's possible. But reading some data periodically is not a cheap task. Each module has its own "price". So, if you want to reduce energy impact from the Stats you need to disable some Stats modules. The most inefficient modules are Sensors and Bluetooth. Disabling these modules could reduce CPU usage and power efficiency by up to 50% in some cases.

### Fan control
Fan control is in legacy mode. It does not receive any updates or fixes. It's not dropped from the app just because in the old Macs it works pretty acceptable. I'm open to accepting fixed or improvements (via PR) for this feature in case someone would like to help with that. But have no option and time to provide support for this feature.

### Sensors show incorrect CPU/GPU core count
CPU/GPU sensors are simply thermal zones (sensors) on the CPU/GPU. They have no relation to the number of cores or specific cores.
For example, a CPU is typically divided into two clusters: efficiency and performance. Each cluster contains multiple temperature sensors, and Stats simply displays these sensors. However, "CPU Efficient Core 1" does not represent the temperature of a single efficient core—it only indicates one of the temperature sensors within the efficiency core cluster.
Additionally, with each new SoC, Apple changes the sensor keys. As a result, it takes time to determine which SMC values correspond to the appropriate sensors. If anyone knows how to accurately match the sensors for Apple Silicon, please contact me.

### App crash – what to do?
First, ensure that you are using the latest version of Stats. There is a high chance that a fix preventing the crash has already been released. If you are already running the latest version, check the open issues. Only if none of the existing issues address your problem should you open a new issue.

### Why my issue was closed without any response?
Most probably because it's a duplicated issue and there is an answer to the question, report, or proposition. Please use a search by closed issues to get an answer.
So, if your issue was closed without any response, most probably it already has a response.

### External API
Stats uses some external APIs, such as:

- https://api.mac-stats.com – For update checks and retrieving the public IP address
- https://api.github.com – Fallback for update checks

Both of these APIs are used to check for updates. Additionally, an external request is required to obtain the public IP address. I do not want to use any third-party providers for retrieving the public IP address, so I use my own server for this purpose.

If you have concerns about these requests, you have a few options:

- propose a PR that allows these features to work without an external server
- block both of these servers using any network filtering app (if you're reading this, you're likely using something like Little Snitch, so you can easily do this). In this case do not expect to receive any updates or see your public IP in the network module.

### How to contribute to the project?
If you want to develop a new feature or you've found something that doesn't work, the first step is to open an issue so the feature or problem can be discussed. Pull requests should only be opened for existing issues and after discussion; otherwise, they may be closed automatically. There are a few cases where this can be skipped: for language changes, and for contributors who have already made significant contributions and whose implementations align well with the project.

## Supported languages
- English
- Polski
- Українська
- Русский
- 中文 (简体) (thanks to [chenguokai](https://github.com/chenguokai), [Tai-Zhou](https://github.com/Tai-Zhou), and [Jerry](https://github.com/Jerry23011))
- Türkçe (thanks to [yusufozgul](https://github.com/yusufozgul) and [setanarut](https://github.com/setanarut))
- 한국어 (thanks to [escapeanaemia](https://github.com/escapeanaemia) and [iamhslee](https://github.com/iamhslee))
- German (thanks to [natterstefan](https://github.com/natterstefan) and [aneitel](https://github.com/aneitel))
- 中文 (繁體) (thanks to [iamch15542](https://github.com/iamch15542) and [jrthsr700tmax](https://github.com/jrthsr700tmax))
- Spanish (thanks to [jcconca](https://github.com/jcconca))
- Vietnamese (thanks to [HXD.VN](https://github.com/xuandung38))
- French (thanks to [RomainLt](https://github.com/RomainLt))
- Italian (thanks to [gmcinalli](https://github.com/gmcinalli))
- Portuguese (Brazil) (thanks to [marcelochaves95](https://github.com/marcelochaves95) and [pedroserigatto](https://github.com/pedroserigatto))
- Norwegian Bokmål (thanks to [rubjo](https://github.com/rubjo))
- 日本語 (thanks to [treastrain](https://github.com/treastrain))
- Portuguese (Portugal) (thanks to [AdamModus](https://github.com/AdamModus))
- Czech (thanks to [mpl75](https://github.com/mpl75))
- Magyar (thanks to [moriczr](https://github.com/moriczr))
- Bulgarian (thanks to [zbrox](https://github.com/zbrox))
- Romanian (thanks to [razluta](https://github.com/razluta))
- Dutch (thanks to [ngohungphuc](https://github.com/ngohungphuc))
- Hrvatski (thanks to [milotype](https://github.com/milotype))
- Danish (thanks to [casperes1996](https://github.com/casperes1996) and [aleksanderbl29](https://github.com/aleksanderbl29))
- Catalan (thanks to [davidalonso](https://github.com/davidalonso))
- Indonesian (thanks to [yooody](https://github.com/yooody))
- Hebrew (thanks to [BadSugar](https://github.com/BadSugar))
- Slovenian (thanks to [zigapovhe](https://github.com/zigapovhe))
- Greek (thanks to [sudoxcess](https://github.com/sudoxcess) and [vaionicle](https://github.com/vaionicle))
- Persian (thanks to [ShawnAlisson](https://github.com/ShawnAlisson))
- Slovenský (thanks to [martinbernat](https://github.com/martinbernat))
- Thai (thanks to [apiphoomchu](https://github.com/apiphoomchu))
- Estonian (thanks to [postylem](https://github.com/postylem))
- Hindi (thanks to [patiljignesh](https://github.com/patiljignesh))
- Finnish (thanks to [eightscrow](https://github.com/eightscrow))

You can help by adding a new language or improving the existing translation.

## License
[MIT License](https://github.com/exelban/stats/blob/master/LICENSE)
