.PHONY: build
.SILENT: build

build:
	rm -rf ./build

	xcodebuild \
		-project ../Stats.xcodeproj \
  		-scheme SMC \
  		-destination 'platform=OS X,arch=x86_64' \
  		-configuration Release archive \
  		-archivePath ./build/smc.xcarchive \
  		SKIP_INSTALL=NO

	cp ./build/smc.xcarchive/Products/usr/local/bin/smc ./

	rm -rf ./build
