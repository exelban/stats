**Version 2.1.4**, synced to [MPAndroidChart #6ae1eef](https://github.com/PhilJay/MPAndroidChart/commit/497beac)

![alt tag](https://raw.github.com/danielgindi/ios-charts/master/Assets/feature_graphic.png)
[![CodeHunt.io](https://img.shields.io/badge/vote-codehunt.io-02AFD1.svg)](http://codehunt.io/sub/ios-charts/?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)   

* Xcode 7 / Swift 2.0
* iOS 7.0 (Drag .swift files to your project)
* iOS 8.0 / 9.0 (Use as an **Embedded** Framework)

Okay so there's this beautiful library called [MPAndroidChart](https://github.com/PhilJay/MPAndroidChart) by [Philipp Jahoda](https://www.linkedin.com/in/philippjahoda) which has become very popular amongst Android developers, and in the meanwhile there's no decent charting solution for iOS.

I've chosen to write it in `Swift` as it can be highly optimized by the compiler, and can be used in both `Swift` and `ObjC` project. The demo project is written in `ObjC` to demonstrate how it works.

**An amazing feature** of this library now, both Android and iOS, is the time it saves you when developing for both platforms, as the learning curve is singleton- it happens only once, and the code stays very similar so developers don't have to go around and re-invent the app to produce the same output with a different library. (And that's not even considering the fact that there's not really another good choice out there currently...)

## Usage

In order to correctly compile:

1. Drag the `Charts.xcodeproj` to your project  
2. Go to your target's settings, hit the "+" under the "Embedded Binaries" section, and select the Charts.framework  
3. **Temporary workaround**: Xcode 6.3.1 has a bug, where you have to build your project once before actually writing the `@import` line. So hit "Build" now!  
4. `@import Charts`  
5.  When using Swift in an ObjC project:
   - You need to import your Bridging Header. Usually it is "*YourProject-Swift.h*", so in ChartsDemo it's "*ChartsDemo-Swift.h*". Do not try to actually include "*ChartsDemo-Swift.h*" in your project :-)
   - Under "Build Options", mark "Embedded Content Contains Swift Code"


If you want to compile for iOS 7:

1. Drag the code itself (.swift files) to your project. As sadly, Swift currently does not support compiling Frameworks for iOS 7.
2. Make sure that the files are added to the Target membership.

## CocoaPods Install

Add `pod 'Charts'` to your Podfile. "Charts" is the name of the library.  
**Note:** ~~`pod 'ios-charts'`~~ is not the correct library, and refers to a different project by someone else.

## Help

If you like what you see here, and want to support the work being done in this repository, you could:
* Contribute code, issues and pull requests
* Let people know this library exists (spread the word!)
* 
[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=68UL6Y8KUPS96) (You can buy me a beer, or you can buy me dinner :-)

**Note:** The author of [MPAndroidChart](https://github.com/PhilJay/MPAndroidChart) is the reason that this library exists, and is accepting [donations](https://github.com/PhilJay/MPAndroidChart#donations) on his page. He deserves them!

Questions & Issues
-----

If you are having questions or problems, you should:

 - Make sure you are using the latest version of the library. Check the [**release-section**](https://github.com/danielgindi/ios-charts/releases).
 - Study the [**Documentation-Wiki**](https://github.com/PhilJay/MPAndroidChart/wiki)
 - Search or open questions on [**stackoverflow**](http://stackoverflow.com/questions/tagged/ios-charts) with the `ios-charts` tag
 - Search [**known issues**](https://github.com/danielgindi/ios-charts/issues) for your problem (open and closed)
 - Create new issues (please **search known issues before**, do not create duplicate issues)


Features
=======

**Core features:**
 - 8 different chart types
 - Scaling on both axes (with touch-gesture, axes separately or pinch-zoom)
 - Dragging / Panning (with touch-gesture)
 - Combined-Charts (line-, bar-, scatter-, candle-stick-, bubble-)
 - Dual (separate) Y-Axis
 - Finger drawing (draw values into the chart with touch-gesture)
 - Highlighting values (with customizeable popup-views)
 - Multiple / Separate Axes
 - Save chart to camera-roll / export to PNG/JPEG
 - Predefined color templates
 - Legends (generated automatically, customizeable)
 - Customizeable Axes (both x- and y-axis)
 - Animations (build up animations, on both x- and y-axis)
 - Limit lines (providing additional information, maximums, ...)
 - Fully customizeable (paints, typefaces, legends, colors, background, gestures, dashed lines, ...)
 
**Chart types:**

*Screenshots are currently taken from the original repository, as they render exactly the same :-)*


 - **LineChart (with legend, simple design)**
![alt tag](https://raw.github.com/PhilJay/MPChart/master/screenshots/simpledesign_linechart4.png)
 - **LineChart (with legend, simple design)**
![alt tag](https://raw.github.com/PhilJay/MPChart/master/screenshots/simpledesign_linechart3.png)

 - **LineChart (cubic lines)**
![alt tag](https://raw.github.com/PhilJay/MPChart/master/screenshots/cubiclinechart.png)

 - **Combined-Chart (bar- and linechart in this case)**
![alt tag](https://raw.github.com/PhilJay/MPChart/master/screenshots/combined_chart.png)

 - **BarChart (with legend, simple design)**

![alt tag](https://raw.github.com/PhilJay/MPChart/master/screenshots/simpledesign_barchart3.png)

 - **BarChart (grouped DataSets)**

![alt tag](https://raw.github.com/PhilJay/MPChart/master/screenshots/groupedbarchart.png)

 - **Horizontal-BarChart**

![alt tag](https://raw.github.com/PhilJay/MPChart/master/screenshots/horizontal_barchart.png)


 - **PieChart (with selection, ...)**

![alt tag](https://raw.github.com/PhilJay/MPAndroidChart/master/screenshots/simpledesign_piechart1.png)

 - **ScatterChart** (with squares, triangles, circles, ... and more)

![alt tag](https://raw.github.com/PhilJay/MPAndroidChart/master/screenshots/scatterchart.png)

 - **CandleStickChart** (for financial data)

![alt tag](https://raw.github.com/PhilJay/MPAndroidChart/master/screenshots/candlestickchart.png)

 - **BubbleChart** (area covered by bubbles indicates the value)

![alt tag](https://raw.github.com/PhilJay/MPAndroidChart/master/screenshots/bubblechart.png)

 - **RadarChart** (spider web chart)

![alt tag](https://raw.github.com/PhilJay/MPAndroidChart/master/screenshots/radarchart.png)


Documentation
=======
Currently there's no need for documentation for the iOS version, as the API is **95% the same** as on Android.  
You can read the official [MPAndroidChart](https://github.com/PhilJay/MPAndroidChart) documentation here: [**Wiki**](https://github.com/PhilJay/MPAndroidChart/wiki)

Or you can see the [**ChartsDemo**](https://github.com/danielgindi/ios-charts/tree/master/ChartsDemo) project and learn the how-tos from it.


Special Thanks
=======

Goes to [@petester42](https://github.com/petester42) (Pierre-Marc Airoldi) for implementing a Bubble chart!  
To [@AlBirdie](https://github.com/AlBirdie) and for [@liuxuan30](https://github.com/liuxuan30) for their contributions and involvement in our community!  

License
=======
Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
