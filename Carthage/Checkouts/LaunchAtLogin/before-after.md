# Before and after

With `LaunchAtLogin`, you only have to do 2 steps instead of 13!

```diff
-  1. Create a new target that will be the helper app that launches your app
-  2. Set `LSBackgroundOnly` to true in the `Info.plist` file
-  3. Set `Skip Install` to `YES` in the build settings for the helper app
-  4. Enable sandboxing for the helper app
-  5. Add a new `Copy Files` build phase to the main app
-  6. Select `Wrapper` as destination
-  7. Enter `Contents/Library/LoginItems` as subpath
-  8. Add the helper build product to the build phase
-  9. Copy-paste some boilerplate code into the helper app
- 10. Remember to replace `bundleid.of.main.app` and `MainExectuableName` with your own values
- 11. Copy-paste some code to register the helper app into your main app
- 12. Make sure the main app and helper app use the same code signing certificate
- 13. Manually verify that you did everything correctly
+  1. Install this package
+  2. Add a new "Run Script Phase"
```
