# Changelog
All notable changes to this project will be documented in this file.

### [v1.3.5]
    - removed first empty point from CPU and Memory charts
    - percentage value disabled if battery is fully charged
    - removed n/a from battery time
    - small fixes

### [v1.3.4]
    - rewrited readers for Top Processes in CPU and Memory modules
    - improved power consumption

### [v1.3.3]
    - new option to set update time for each module
    - fixed widget initialization

### [v1.3.2]
    - new battery widget with time remaining
    - rewrited battery widget
    - new menu item to open Activity Monitor

### [v1.3.1]
    - fixed battery widget width
    - fixed initWidget function in battery module
    - new build and update algorithm for menu bar
    - added view with empty text in popup when no active module
    - changed the source for battery charging information
    - changed battery widget percentage view
    - fixed values visibility in network widget
    - fixed parsing data from top output in cpu and memory reader

### [v1.3.0]
    - CPU hyperthreading mode disabled by default in bar chart widget
    - added view for CPU module
    - added view for Memory module
    - added view for Battery module
    - changed the menu item with preferences to list
    - improved widgets draw algorithm
    - implemented view for modules with charts and some information
    - moved from own implementation to LauncAtLogin library
    - fixed a lot of bugs

### [v1.2.13]
    - changed version checker logic

### [v1.2.12]
    - module settings are unavailable if the module is turned off
    - fixed battery module visibility when disabled

### [v1.2.11]
    - fixed network text widget visibility

### [v1.2.10]
    - moved to swift 5
    - fixed start on boot

### [v1.2.9]
    - fixed start on boot button
    - changed the weight of some fonts

### [v1.2.8]
    - small changes in Widgets structure
    - widgets settings moved from modules to widgets
    - fixed Bar chart visibility on start
    - small changes in Widget protocol
    - appStore mode added
    - fixed few bugs

### [v1.2.7]
    - added hyperthreading mode in Bar Chart for CPU
    - fixed few bugs

### [v1.2.6]
    - fixed CPU usage

### [v1.2.5]
    - added chart bar widget for CPU, Memory and Disk module
    - label in Charts are enabled by default
    - color and label option are visible only if available in selected widget
    - fixed few bugs

### [v1.2.4]
    - fixed bug when widgets don't display properly (or don't shows at all)
    - initialized bar chart widget
    - fixed few bugs

### [v1.2.3]
    - new icon
    - small code refactoring
    - changed font style name of the indicator in the Chart/Chart with value
    - added dock icon visibility to preferences
    - moved color and label preference from global to local (now each module can be configurated separately)
    - now check for updates on start can be disabled in preferences
    - fixed few bugs

### [v1.2.2]
    - fully automated build and sign app process
    - fixed update and about visibility window in dark mode
    - added name of the indicators in the Chart/Chart with value
    - added check for new version on start
    - removed charts and charts with value to Disk module
    - now module submenu is disabled if module is disabled
    - fixed bug when network module stop working after turn on/of
    - fixed few bugs
    
### [v1.2.1]
    - added charts and charts with value to Disk module
    - fixed bug when Chart with value does not shows

### [v1.2.0]
    - added network module
    - added Check for updates window
    - fixed few bugs

### [v1.1.0]
    - added battery module
    - added chart widget for CPU and Memory
    - added About Stats window

### [v1.0.0]
    - first release

[v1.3.5]: https://github.com/exelban/stats/releases/tag/v1.3.5
[v1.3.4]: https://github.com/exelban/stats/releases/tag/v1.3.4
[v1.3.3]: https://github.com/exelban/stats/releases/tag/v1.3.3
[v1.3.2]: https://github.com/exelban/stats/releases/tag/v1.3.2
[v1.3.1]: https://github.com/exelban/stats/releases/tag/v1.3.1
[v1.3.0]: https://github.com/exelban/stats/releases/tag/v1.3.0
[v1.2.13]: https://github.com/exelban/stats/releases/tag/v1.2.13
[v1.2.12]: https://github.com/exelban/stats/releases/tag/v1.2.12
[v1.2.11]: https://github.com/exelban/stats/releases/tag/v1.2.11
[v1.2.10]: https://github.com/exelban/stats/releases/tag/v1.2.10
[v1.2.9]: https://github.com/exelban/stats/releases/tag/v1.2.9
[v1.2.8]: https://github.com/exelban/stats/releases/tag/v1.2.8
[v1.2.7]: https://github.com/exelban/stats/releases/tag/v1.2.7
[v1.2.6]: https://github.com/exelban/stats/releases/tag/v1.2.6
[v1.2.5]: https://github.com/exelban/stats/releases/tag/v1.2.5
[v1.2.4]: https://github.com/exelban/stats/releases/tag/v1.2.4
[v1.2.3]: https://github.com/exelban/stats/releases/tag/v1.2.3
[v1.2.2]: https://github.com/exelban/stats/releases/tag/v1.2.2
[v1.2.1]: https://github.com/exelban/stats/releases/tag/v1.2.1
[v1.2.0]: https://github.com/exelban/stats/releases/tag/v1.2.0
[v1.1.0]: https://github.com/exelban/stats/releases/tag/v1.1.0
[v1.0.0]: https://github.com/exelban/stats/releases/tag/v1.0.0
