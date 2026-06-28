APP = Stats
BUNDLE_ID = eu.exelban.$(APP)

BUILD_PATH = $(PWD)/build
APP_PATH = "$(BUILD_PATH)/$(APP).app"
ZIP_PATH = "$(BUILD_PATH)/$(APP).zip"
WIDGET_PATH = "$(BUILD_PATH)/$(APP).app/Contents/PlugIns/WidgetsExtension.appex"

.SILENT: archive notarize sign verify prepare-dmg prepare-dSYM clean next-version check history disk smc leveldb
.PHONY: build archive notarize sign verify prepare-dmg prepare-dSYM clean next-version check history open smc leveldb

build: clean next-version archive notarize sign verify prepare-dmg prepare-dSYM open

# --- MAIN WORLFLOW FUNCTIONS --- #

archive: clean
	osascript -e 'display notification "Exporting application archive..." with title "Build the Stats"'
	echo "Exporting application archive..."

	xcodebuild \
  		-scheme $(APP) \
  		-destination 'platform=OS X,arch=x86_64' \
  		-configuration Release archive \
  		-archivePath $(BUILD_PATH)/$(APP).xcarchive

	echo "Application built, starting the export archive..."

	xcodebuild -exportArchive \
  		-exportOptionsPlist "$(PWD)/exportOptions.plist" \
  		-archivePath $(BUILD_PATH)/$(APP).xcarchive \
  		-exportPath $(BUILD_PATH)

	ditto -c -k --keepParent $(APP_PATH) $(ZIP_PATH)

	echo "Project archived successfully"

notarize:
	osascript -e 'display notification "Submitting app for notarization..." with title "Build the Stats"'
	echo "Submitting app for notarization..."

	xcrun notarytool submit --keychain-profile "AC_PASSWORD" --wait $(ZIP_PATH)

	echo "Stats successfully notarized"

sign:
	osascript -e 'display notification "Stampling the Stats..." with title "Build the Stats"'
	echo "Going to staple an application..."

	xcrun stapler staple $(APP_PATH)
	spctl -a -t exec -vvv $(APP_PATH)

	osascript -e 'display notification "Stats successfully stapled" with title "Build the Stats"'
	echo "Stats successfully stapled"

verify:
	echo "Verifying widget extension..."

	if [ ! -d $(WIDGET_PATH) ]; then \
		echo "ERROR: widget extension is missing at $(WIDGET_PATH)"; \
		exit 1; \
	fi

	marketingVersion=$$(/usr/libexec/PlistBuddy -c "print :objects:9A141107229E721200D29793:buildSettings:MARKETING_VERSION" "$(PWD)/Stats.xcodeproj/project.pbxproj") ;\
	appShort=$$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$(BUILD_PATH)/$(APP).app/Contents/Info.plist") ;\
	appBuild=$$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$(BUILD_PATH)/$(APP).app/Contents/Info.plist") ;\
	widgetShort=$$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$(BUILD_PATH)/$(APP).app/Contents/PlugIns/WidgetsExtension.appex/Contents/Info.plist") ;\
	widgetBuild=$$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$(BUILD_PATH)/$(APP).app/Contents/PlugIns/WidgetsExtension.appex/Contents/Info.plist") ;\
	echo "Declared: $$marketingVersion" ;\
	echo "App:    $$appShort ($$appBuild)" ;\
	echo "Widget: $$widgetShort ($$widgetBuild)" ;\
	if [ "$$appShort" != "$$marketingVersion" ]; then \
		echo "ERROR: built app version ($$appShort) does not match the declared MARKETING_VERSION ($$marketingVersion)." ;\
		exit 1; \
	fi ;\
	if [ "$$appShort" != "$$widgetShort" ] || [ "$$appBuild" != "$$widgetBuild" ]; then \
		echo "ERROR: widget extension version ($$widgetShort/$$widgetBuild) does not match app version ($$appShort/$$appBuild)." ;\
		echo "PluginKit keys widgets on bundle-id + version; a stale version makes the widget disappear from the picker after update." ;\
		exit 1; \
	fi

	codesign --verify --strict $(WIDGET_PATH) || { echo "ERROR: widget extension code signature is invalid"; exit 1; }

	echo "Widget extension verified successfully"

prepare-dmg:
	if [ ! -d $(PWD)/create-dmg ]; then \
	    git clone https://github.com/create-dmg/create-dmg; \
	fi

	./create-dmg/create-dmg \
	    --volname $(APP) \
	    --background "./Stats/Supporting Files/background.png" \
	    --window-pos 200 120 \
	    --window-size 500 320 \
	    --icon-size 80 \
	    --icon "Stats.app" 125 175 \
	    --hide-extension "Stats.app" \
	    --app-drop-link 375 175 \
	    --no-internet-enable \
	    $(PWD)/$(APP).dmg \
	    $(APP_PATH)

	rm -rf ./create-dmg

prepare-dSYM:
	echo "Zipping dSYMs..."
	cd $(BUILD_PATH)/Stats.xcarchive/dSYMs && zip -r $(PWD)/dSYMs.zip .
	echo "Created zip with dSYMs"

# --- HELPERS --- #

clean:
	rm -rf $(BUILD_PATH)
	if [ -a $(PWD)/dSYMs.zip ]; then rm $(PWD)/dSYMs.zip; fi;
	if [ -a $(PWD)/Stats.dmg ]; then rm $(PWD)/Stats.dmg; fi;

next-version:
	versionNumber=$$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$(PWD)/Stats/Supporting Files/Info.plist") ;\
	echo "Actual version is: $$versionNumber" ;\
	versionNumber=$$((versionNumber + 1)) ;\
	echo "Next version is: $$versionNumber" ;\
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$versionNumber" "$(PWD)/Stats/Supporting Files/Info.plist" ;\

check:
	xcrun notarytool log 2d0045cc-8f0d-4f4c-ba6f-728895fd064a --keychain-profile "AC_PASSWORD"

history:
	xcrun notarytool history --keychain-profile "AC_PASSWORD"

open:
	osascript -e 'display notification "Stats signed and ready for distribution" with title "Build the Stats"'
	echo "Opening working folder..."
	open $(PWD)

smc:
	$(MAKE) --directory=./smc
	open $(PWD)/smc

leveldb:
	if [ ! -d $(PWD)/leveldb-source ]; then \
		git clone --recurse-submodules https://github.com/google/leveldb.git leveldb-source; \
	fi
	mkdir -p $(PWD)/leveldb-source/build
	cd $(PWD)/leveldb-source/build && cmake -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" -DCMAKE_BUILD_TYPE=Release .. && cmake --build .
	cp $(PWD)/leveldb-source/build/libleveldb.a $(PWD)/Kit/lldb/libleveldb.a
	rm -rf $(PWD)/leveldb-source