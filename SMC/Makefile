.PHONY: build test-smc
.SILENT: build

build: test-smc
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

test-smc:
	python3 ../Kit/scripts/run-smc-tests.py
