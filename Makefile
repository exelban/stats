APP = Stats
BUNDLE_ID = eu.exelban.Stats

ITC_USERNAME = $(AC_USERNAME)
ITC_PASSWORD = @keychain:AC_PASSWORD
ITC_PROVIDER = $(AC_PROVIDER)

RequestUUID = 32c80f6c-36ed-4042-9837-b9093c9f4eb9

BUILD_PATH = $(PWD)/build
ARCHIVE_PATH = $(BUILD_PATH)/$(APP).xcarchive
APP_PATH = "$(BUILD_PATH)/$(APP).app"
ZIP_PATH = "$(BUILD_PATH)/$(APP).zip"
DMG_PATH = $(PWD)/$(APP).dmg

all: clean archive notarize sign build

clean:
# 	rm -rf $(BUILD_PATH)

.PHONY: archive
archive: clean
	xcodebuild \
  		-scheme $(APP) \
  		-destination 'platform=OS X,arch=x86_64' \
  		-configuration AppStoreDistribution archive \
  		-archivePath $(ARCHIVE_PATH)

	xcodebuild \
  		-exportArchive \
  		-exportOptionsPlist "$(PWD)/exportOptions.plist" \
  		-archivePath $(ARCHIVE_PATH) \
  		-exportPath $(BUILD_PATH)

	ditto -c -k --keepParent $(APP_PATH) $(ZIP_PATH)

.PHONY: notarize
notarize:
	xcrun altool \
	  --notarize-app \
	  --primary-bundle-id $(BUNDLE_ID)\
	  -itc_provider $(ITC_PROVIDER) \
	  -u $(ITC_USERNAME) \
	  -p $(ITC_PASSWORD) \
	  --file $(ZIP_PATH) 

	sleep 380

.PHONY: sign
sign:
	xcrun stapler staple $(APP_PATH)
	spctl -a -t exec -vvv $(APP_PATH)

.PHONY: build
build: sign
	if [ ! -d $(PWD)/create-dmg ]; then \
	    git clone https://github.com/andreyvit/create-dmg; \
	fi

	./create-dmg/create-dmg \
	    --volname $(APP) \
	    --background "./resources/background.png" \
	    --window-pos 200 120 \
	    --window-size 500 320 \
	    --icon-size 80 \
	    --icon "Stats.app" 125 175 \
	    --hide-extension "Stats.app" \
	    --app-drop-link 375 175 \
	    $(DMG_PATH) \
	    $(APP_PATH)

	rm -rf ./create-dmg
# 	rm -rf $(BUILD_PATH)
	open $(PWD)

check:
	xcrun altool \
	  --notarization-info $(RequestUUID) \
	  -itc_provider $(ITC_PROVIDER) \
	  -u $(ITC_USERNAME) \
	  -p $(ITC_PASSWORD)

history:
	xcrun altool \
	  --notarization-history 0 \
	  -itc_provider $(ITC_PROVIDER) \
	  -u $(ITC_USERNAME) \
	  -p $(ITC_PASSWORD)

.PHONY: dep
dep:
	carthage update --platform macOS