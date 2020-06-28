# Stats

<a href="https://github.com/exelban/stats/releases"><p align="center"><img src="https://serhiy.s3.eu-central-1.amazonaws.com/Github_repo/stats/logo.png?raw=true" width="120"></p></a>

[![Stats](https://serhiy.s3.eu-central-1.amazonaws.com/Github_repo/stats/cover%3Fv1.6.0.png)](https://github.com/exelban/stats/releases)

Simple macOS system monitor in your menu bar

## Installation
You can download latest version [here](https://github.com/exelban/stats/releases).

### Homebrew

```bash
brew cask install stats
```

## Requirements

Stats is currently supported on macOS 10.14 (Mojave) and higher.

## Features
Stats is a application which allows you to monitor your macOS system.  

 - CPU Usage
 - Memory Usage
 - Disk utilization
 - Sensors information (Temperature/Voltage/Power)
 - Battery level
 - Network usage

## Troubleshoots
The application supports a few arguments which can help to work with Stats. Also, it's very helpful to debug what module is not working properly (crash).

There are 2 arguments available:

- `--reset`: allows to reset application settings
- `--disable`: allow to disable some of the modules. A list of modules can be passed. (Example: `--disable disk`)

## Developing

Pull requests and impovment proposals are welcomed.

If you want to run the project locally you need to have [carthage](https://github.com/Carthage/Carthage#installing-carthage) and [XCode](https://apps.apple.com/app/xcode/id497799835) installed.

```bash
git clone https://github.com/exelban/stats
cd stats
make dep
open ./Stats.xcodeproj
```

## License
[MIT License](https://github.com/exelban/stats/blob/master/LICENSE)
