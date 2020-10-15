APP = Stats
BUNDLE_ID = eu.exelban.$(APP)

BUILD_PATH = $(PWD)/build
APP_PATH = "$(BUILD_PATH)/$(APP).app"
ZIP_PATH = "$(BUILD_PATH)/$(APP).zip"

.SILENT: archive notarize sign prepare-dmg prepare-dSYM clean next-version check history
.PHONY: build archive notarize sign prepare-dmg prepare-dSYM clean next-version check history dep

build: clean next-version archive notarize sign prepare-dmg prepare-dSYM open

# --- MAIN WORLFLOW FUNCTIONS --- #

archive: next-version clean
	echo "Starting archiving the project..."

	xcodebuild \
  		-scheme $(APP) \
  		-destination 'platform=OS X,arch=x86_64' \
  		-configuration AppStoreDistribution archive \
  		-archivePath $(BUILD_PATH)/$(APP).xcarchive

	echo "Application built, starting the export archive..."

	xcodebuild -exportArchive \
  		-exportOptionsPlist "$(PWD)/exportOptions.plist" \
  		-archivePath $(BUILD_PATH)/$(APP).xcarchive \
  		-exportPath $(BUILD_PATH)

	ditto -c -k --keepParent $(APP_PATH) $(ZIP_PATH)

	echo "Project archived successfully"

notarize:
	echo "Starting notarizing the project..."

	xcrun altool --notarize-app \
	  --primary-bundle-id $(BUNDLE_ID)\
	  -itc_provider $(AC_PROVIDER) \
	  -u $(AC_USERNAME) \
	  -p @keychain:AC_PASSWORD \
	  --file $(ZIP_PATH)

	echo "Application sent to the notarization center"

	sleep 30s

LAST_REQUEST="test"

sign:
	echo "Checking if package is approved by Apple..."

	while true; do \
		if [[ "$$(xcrun altool --notarization-history 0 -itc_provider $(AC_PROVIDER) -u $(AC_USERNAME) -p @keychain:AC_PASSWORD | sed -n '6p')" == *"success"* ]]; then \
			echo "OK" ;\
			break ;\
		fi ;\
		echo "Package was not approved by Apple, recheck in 10s..."; \
		sleep 10s ;\
	done

	echo "Going to staple an application..."

	xcrun stapler staple $(APP_PATH)
	spctl -a -t exec -vvv $(APP_PATH)

	echo "Application successfully stapled"

prepare-dmg:
	if [ ! -d $(PWD)/create-dmg ]; then \
	    git clone https://github.com/andreyvit/create-dmg; \
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
	xcrun altool \
	  --notarization-info 9b7c4d1f-ae81-4571-9ab1-592289f9d57a \
	  -itc_provider $(AC_PROVIDER) \
	  -u $(AC_USERNAME) \
	  -p @keychain:AC_PASSWORD

history:
	xcrun altool --notarization-history 0 \
		-itc_provider $(AC_PROVIDER) \
		-u $(AC_USERNAME) \
		-p @keychain:AC_PASSWORD

open:
	echo "Opening working folder..."
	open $(PWD)
