# Reachability.swift

Reachability.swift is a replacement for Apple's Reachability sample, re-written in Swift with closures.

It is compatible with **iOS** (8.0 - 12.0), **OSX** (10.9 - 10.14) and **tvOS** (9.0 - 12.0)

Inspired by https://github.com/tonymillion/Reachability

## Supporting **Reachability.swift**
Keeping **Reachability.swift** up-to-date is a time consuming task. Making updates, reviewing pull requests, responding to issues and answering emails all take time. 

If you're an iOS developer who's looking for a quick and easy way to create App Store screenshots, please try out my app [Screenshot Producer](https://itunes.apple.com/app/apple-store/id1252374855?pt=215893&ct=reachability&mt=8)…

 Devices | Layout | Copy | Localize | Export      
:------:|:------:|:------:|:------:|:------:
![](http://is2.mzstatic.com/image/thumb/Purple118/v4/64/af/55/64af55bc-2ef0-691c-f5f3-4963685f7f63/source/552x414bb.jpg) |  ![](http://is4.mzstatic.com/image/thumb/Purple128/v4/fb/4c/bd/fb4cbd2f-dd04-22ba-4fdf-5ac652693fb8/source/552x414bb.jpg) |  ![](http://is1.mzstatic.com/image/thumb/Purple118/v4/5a/4f/cf/5a4fcfdf-ca04-0307-9f2e-83178e8ad90d/source/552x414bb.jpg) |  ![](http://is4.mzstatic.com/image/thumb/Purple128/v4/17/ea/56/17ea562e-e045-96e7-fcac-cfaaf4f499fd/source/552x414bb.jpg) |  ![](http://is4.mzstatic.com/image/thumb/Purple118/v4/59/9e/dd/599edd50-f05c-f413-8e88-e614731fd828/source/552x414bb.jpg)

And don't forget to **★** the repo. This increases its visibility and encourages others to contribute.

Thanks
Ash


## Got a problem?

Please read https://github.com/ashleymills/Reachability.swift/blob/master/CONTRIBUTING.md before raising an issue.

## Installation
### Manual
Just drop the **Reachability.swift** file into your project. That's it!

### CocoaPods
[CocoaPods][] is a dependency manager for Cocoa projects. To install Reachability.swift with CocoaPods:

 1. Make sure CocoaPods is [installed][CocoaPods Installation].

 2. Update your Podfile to include the following:

    ``` ruby
    use_frameworks!
    pod 'ReachabilitySwift'
    ```

 3. Run `pod install`.

[CocoaPods]: https://cocoapods.org
[CocoaPods Installation]: https://guides.cocoapods.org/using/getting-started.html#getting-started
 
 4. In your code import Reachability like so:
   `import Reachability`

### Carthage
[Carthage][] is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.
To install Reachability.swift with Carthage:

1. Install Carthage via [Homebrew][]
  ```bash
  $ brew update
  $ brew install carthage
  ```

2. Add `github "ashleymills/Reachability.swift"` to your Cartfile.

3. Run `carthage update`.

4. Drag `Reachability.framework` from the `Carthage/Build/iOS/` directory to the `Linked Frameworks and Libraries` section of your Xcode project’s `General` settings.

5. Add `$(SRCROOT)/Carthage/Build/iOS/Reachability.framework` to `Input Files` of Run Script Phase for Carthage.

6. In your code import Reachability like so:
`import Reachability`


[Carthage]: https://github.com/Carthage/Carthage
[Homebrew]: http://brew.sh
[Photo Flipper]: https://itunes.apple.com/app/apple-store/id749627884?pt=215893&ct=GitHubReachability&mt=8

## Example - closures

NOTE: All closures are run on the **main queue**.

```swift
//declare this property where it won't go out of scope relative to your listener
let reachability = Reachability()!

reachability.whenReachable = { reachability in
    if reachability.connection == .wifi {
        print("Reachable via WiFi")
    } else {
        print("Reachable via Cellular")
    }
}
reachability.whenUnreachable = { _ in
    print("Not reachable")
}

do {
    try reachability.startNotifier()
} catch {
    print("Unable to start notifier")
}
```

and for stopping notifications

```swift
reachability.stopNotifier()
```

## Example - notifications

NOTE: All notifications are delivered on the **main queue**.

```swift
//declare this property where it won't go out of scope relative to your listener
let reachability = Reachability()!

//declare this inside of viewWillAppear

     NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged, object: reachability)
    do{
      try reachability.startNotifier()
    }catch{
      print("could not start reachability notifier")
    }
```

and

```swift
@objc func reachabilityChanged(note: Notification) {

  let reachability = note.object as! Reachability

  switch reachability.connection {
  case .wifi:
      print("Reachable via WiFi")
  case .cellular:
      print("Reachable via Cellular")
  case .unavailable:
    print("Network not reachable")
  }
}
```

and for stopping notifications

```swift
reachability.stopNotifier()
NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
```

## Want to help?

Got a bug fix, or a new feature? Create a pull request and go for it!

## Let me know!

If you use **Reachability.swift**, please let me know about your app and I'll put a link [here…](https://github.com/ashleymills/Reachability.swift/wiki/Apps-using-Reachability.swift) and tell your friends!

Cheers,
Ash
