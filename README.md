# Stats

<a href="https://github.com/exelban/stats/releases"><p align="center"><img src="https://serhiy.s3.eu-central-1.amazonaws.com/Github_repo/stats/logo.png?raw=true&v=1" width="120"></p></a>

[![Stats](https://serhiy.s3.eu-central-1.amazonaws.com/Github_repo/stats/menus%3Fv2.3.2.png?v1)](https://github.com/exelban/stats/releases)
[![Stats](https://serhiy.s3.eu-central-1.amazonaws.com/Github_repo/stats/popups%3Fv2.3.2.png?v3)](https://github.com/exelban/stats/releases)

macOS system monitor in your menu bar

## Installation
### Manual
You can download the latest version [here](https://github.com/exelban/stats/releases/latest/download/Stats.dmg).  
This will download a file called `Stats.dmg`. Open it and move the app to the application folder.

### Homebrew
To install it using Homebrew, open the Terminal app and type:
```bash
brew install stats
```

## Requirements
Stats is currently supported on macOS 10.13 (High Sierra) and higher.

## Features
Stats is an application that allows you to monitor your macOS system. 

 - Battery level
 - Bluetooth devices
 - CPU utilization
 - Disk utilization
 - Fan/s control
 - GPU utilization
 - Memory usage
 - Network usage
 - Sensors information (Temperature/Voltage/Power)

## FAQs

### How do you change the order of the menu bar icons?
macOS decides the order of the menu bar items not `Stats` - it may change after the first reboot after installing Stats.

To change the order of any menu bar icon - macOS Mojave (version 10.14) and up.

1. Hold down ⌘ (command key).
2. Drag the icon to the desired position on the menu bar.
3. Release ⌘ (command key)

### What if you don't see sensors (M1 macs)?
Sensors data on the first generation of M1 mac could be obtained only from HID services. It's disabled by default because it consumes a lot of CPU and energy. You can enable it in the Sensors module settings with the option `HID sensors`.

It's only valid for M1 Apple Silicon macs. If you don't see sensors on another mac, please open an issue for that.

### How to show the CPU frequency?
The CPU frequency is available only on Intel-based macs. You need to have installed [Intel Power Gadget](https://www.intel.com/content/www/us/en/developer/articles/tool/power-gadget.html) (IPG) for that. It allows receiving the CPU frequency from the IPG driver. There is no way to obtain a CPU frequency on Apple silicon macs.

### How to reduce energy impact or CPU usage of Stats?
Stats tries to be efficient as it's possible. But reading some data periodically it's not a cheap task. Each module has its own "price". So, if you want to reduce energy impact from the Stats you need to disable some Stats modules. The most inefficient modules are Sensors and Bluetooth. Disabling these modules could reduce CPU usage and power efficiency by up to 50% in some cases.

## Supported languages
- English
- Polski
- Українська
- Русский
- 中文 (简体) (thanks to [chenguokai](https://github.com/chenguokai) and [Tai-Zhou](https://github.com/Tai-Zhou))
- Türkçe (thanks to [yusufozgul](https://github.com/yusufozgul))
- Korean (thanks to [escapeanaemia](https://github.com/escapeanaemia))
- German (thanks to [natterstefan](https://github.com/natterstefan))
- 中文 (繁體) (thanks to [iamch15542](https://github.com/iamch15542) and [jrthsr700tmax](https://github.com/jrthsr700tmax))
- Spanish (thanks to [jcconca](https://github.com/jcconca))
- Vietnamese (thanks to [xuandung38](https://github.com/xuandung38))
- French (thanks to [RomainLt](https://github.com/RomainLt))
- Italian (thanks to [gmcinalli](https://github.com/gmcinalli))
- Portuguese (Brazil) (thanks to [marcelochaves95](https://github.com/marcelochaves95))
- Norwegian Bokmål (thanks to [rubjo](https://github.com/rubjo))
- 日本語 (thanks to [treastrain](https://github.com/treastrain))
- Portuguese (Portugal) (thanks to [AdamModus](https://github.com/AdamModus))
- Czech (thanks to [mpl75](https://github.com/mpl75))
- Magyar (thanks to [moriczr](https://github.com/moriczr))
- Bulgarian (thanks to [zbrox](https://github.com/zbrox))
- Romanian (thanks to [razluta](https://github.com/razluta))
- Dutch (thanks to [ngohungphuc](https://github.com/ngohungphuc))
- Hrvatski (thanks to [milotype](https://github.com/milotype))
- Danish (thanks to [casperes1996](https://github.com/casperes1996))
- Catalan (thanks to [davidalonso](https://github.com/davidalonso))
- Indonesian (thanks to [yooody](https://github.com/yooody))
- Hebrew (thanks to [BadSugar](https://github.com/BadSugar))
- Slovenian (thanks to [zigapovhe](https://github.com/zigapovhe))
- Greek (thanks to [sudoxcess](https://github.com/sudoxcess))

You can help by adding a new language or improve the existing translation.

## License
[MIT License](https://github.com/exelban/stats/blob/master/LICENSE)
