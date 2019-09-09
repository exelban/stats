# LaunchAtLogin

> Add "Launch at Login" functionality to your macOS app in seconds

It's usually quite a [convoluted and error-prone process](before-after.md) to add this. **No more!**

This package works with both sandboxed and non-sandboxed apps and it's App Store compatible and used in my [Lungo](https://blog.sindresorhus.com/lungo-b364a6c2745f) and [Battery Indicator](https://sindresorhus.com/battery-indicator) apps.

*You might also find my [`create-dmg`](https://github.com/sindresorhus/create-dmg) project useful if you're publishing your app outside the App Store.*


## Requirements

- macOS 10.12+
- Xcode 10+
- Swift 4.2+


## Install

#### Carthage

```
github "sindresorhus/LaunchAtLogin"
```

#### CocoaPods

```ruby
pod 'LaunchAtLogin'
```

<a href="https://www.patreon.com/sindresorhus">
	<img src="https://c5.patreon.com/external/logo/become_a_patron_button@2x.png" width="160">
</a>


## Usage

Add a new ["Run Script Phase"](http://stackoverflow.com/a/39633955/64949) below "Embed Frameworks" in "Build Phases" with the following:

Carthage:

```sh
"${PROJECT_DIR}/Carthage/Build/Mac/LaunchAtLogin.framework/Resources/copy-helper.sh"
```

CocoaPods:

```sh
"${PROJECT_DIR}/Pods/LaunchAtLogin/LaunchAtLogin/copy-helper.sh"
```

Use it in your app:

```swift
import LaunchAtLogin

print(LaunchAtLogin.isEnabled)
//=> false

LaunchAtLogin.isEnabled = true

print(LaunchAtLogin.isEnabled)
//=> true
```

*Note that the [Mac App Store guidelines](https://developer.apple.com/app-store/review/guidelines/) requires "launch at login" functionality to be enabled in response to a user action. This is usually solved by making it a preference that is disabled by default.*


## How does it work?

The framework bundles the helper app needed to launch your app and copies it into your app at build time.


## Related

- [Defaults](https://github.com/sindresorhus/Defaults) - Swifty and modern UserDefaults
- [Preferences](https://github.com/sindresorhus/Preferences) - Add a preferences window to your macOS app in minutes
- [DockProgress](https://github.com/sindresorhus/DockProgress) - Show progress in your app's Dock icon
- [More…](https://github.com/search?q=user%3Asindresorhus+language%3Aswift)


## License

MIT © [Sindre Sorhus](https://sindresorhus.com)
