# Stats
Simple macOS system monitor in your menu bar

[<img src="https://serhiy.s3.eu-central-1.amazonaws.com/Github_repo/stats/widgets%3Fv1.1.0.1.png">](https://github.com/exelban/stats/releases)

## Features
Stats is a application which allows you to monitor your macOS system.  

 - CPU Usage
 - Memory Usage
 - Disk utilization
 - Battery level
 - Network usage
 - Black theme compatible

## Installation
You can download latest version [here](https://github.com/exelban/stats/releases).

## Modules

| Name | Available widgets | Description |
| --- | --- | --- |
| **CPU** | Percentage / Chart / Chart with value | Shows CPU usage |
| **Memory** | Percentage / Chart / Chart with value | Shows RAM usage |
| **Disk** | Percentage | Shows disk utilization |
| **Battery** | Graphic / Percentage | Shows battery level and charging status |
| **Newtork** | Dots / Upload/Download traffic | Shows network activity |

## Compatibility
| macOS | Compatible |
| --- | --- |
| 10.13.6 *(High Sierra)* | **true** |
| 10.14.1 *(Mojave)* | **true** |

## Todo
 - [X] Battery percentage
 - [ ] Create new logo
 - [ ] Window with preferences
 - [ ] Save last modules values
 - [ ] Colors toggle for each module
 - [ ] temperature module
 - [X] battery module
 - [X] move to module system (CPU, RAM, DISK)
 - [X] network module
 - [X] save settings
 - [ ] OTA updates
 - [X] charts
 - [X] autostart on boot

## What's new

### v1.2.2
    - added name of the indicators in the Chart/Chart with value ([#6](https://github.com/exelban/stats/issues/6))
    - added check for new version on start
    - removed charts and charts with value to Disk module
    - now module submenu is disabled if module is disabled
    - fixed bug when network module stop working after turn on/of
    - fixed few bugs
    
### v1.2.1
    - added charts and charts with value to Disk module
    - fixed bug when Chart with value does not shows

### v1.2.0
    - added network module
    - added Check for updates window
    - fixed few bugs

### v1.1.0
    - added battery module
    - added chart widget for CPU and Memory
    - added About Stats window

### v1.0.0
    - first release

## License
[MIT License](https://github.com/exelban/stats/blob/master/LICENSE)
