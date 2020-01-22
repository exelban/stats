# LaunchAtLogin

> Add “Launch at Login” functionality to your macOS app in seconds

It's usually quite a [convoluted and error-prone process](before-after.md) to add this. **No more!**

This package works with both sandboxed and non-sandboxed apps and it's App Store compatible and used in apps like [Plash](https://github.com/sindresorhus/Plash), [Dato](https://sindresorhus.com/dato), [Lungo](https://sindresorhus.com/lungo), and [Battery Indicator](https://sindresorhus.com/battery-indicator).

## Requirements

- macOS 10.12+
- Xcode 11+
- Swift 5+

## Install

#### Carthage

```
github "sindresorhus/LaunchAtLogin"
```

## Usage

Add a new ["Run Script Phase"](http://stackoverflow.com/a/39633955/64949) below "Embed Frameworks" in "Build Phases" with the following:

```sh
"${PROJECT_DIR}/Carthage/Build/Mac/LaunchAtLogin.framework/Resources/copy-helper.sh"
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

No need to store any state to UserDefaults.

*Note that the [Mac App Store guidelines](https://developer.apple.com/app-store/review/guidelines/) requires “launch at login” functionality to be enabled in response to a user action. This is usually solved by making it a preference that is disabled by default. Many apps also let the user activate it in a welcome screen.*

## How does it work?

The framework bundles the helper app needed to launch your app and copies it into your app at build time.

## FAQ

#### My app doesn't show up in “System Preferences › Users & Groups › Login Items”

[This is the expected behavior](https://stackoverflow.com/a/15104481/64949), unfortunately.

#### My app doesn't launch at login when testing

This is usually caused by having one or more older builds of your app laying around somewhere on the system, and macOS picking one of those instead, which doesn't have the launch helper, and thus fails to start.

Some things you can try:
- Bump the version & build of your app so macOS is more likely to pick it.
- Delete the [`DerivedData` directory](https://mgrebenets.github.io/mobile%20ci/2015/02/01/xcode-derived-data).
- Ensure you don't have any other builds laying around somewhere.

Some helpful Stack Overflow answers:
- https://stackoverflow.com/a/43281810/64949
- https://stackoverflow.com/a/51683190/64949
- https://stackoverflow.com/a/53110832/64949
- https://stackoverflow.com/a/53110852/64949

#### Can you support CocoaPods?

CocoaPods used to be supported, but [it did not work well](https://github.com/sindresorhus/LaunchAtLogin/issues/22) and there was no easy way to fix it, so support was dropped. Even though you mainly use CocoaPods, you can still use Carthage just for this package without any problems.

#### I'm getting a `'SMCopyAllJobDictionaries' was deprecated in OS X 10.10` warning

Apple deprecated that API without providing an alternative. Apple engineers have [stated that it's still the preferred API to use](https://github.com/alexzielenski/StartAtLoginController/issues/12#issuecomment-307525807). I plan to use it as long as it's available. There are workarounds I can implement if Apple ever removes the API, so rest assured, this module will be made to work even then. If you want to see this resolved, submit a [Feedback Assistant](https://feedbackassistant.apple.com) report with [the following text](https://github.com/feedback-assistant/reports/issues/16). There's unfortunately still [no way to suppress warnings in Swift](https://stackoverflow.com/a/32861678/64949).

## Related

- [Defaults](https://github.com/sindresorhus/Defaults) - Swifty and modern UserDefaults
- [Preferences](https://github.com/sindresorhus/Preferences) - Add a preferences window to your macOS app in minutes
- [DockProgress](https://github.com/sindresorhus/DockProgress) - Show progress in your app's Dock icon
- [create-dmg](https://github.com/sindresorhus/create-dmg) - Create a good-looking DMG for your macOS app in seconds
- [More…](https://github.com/search?q=user%3Asindresorhus+language%3Aswift)
