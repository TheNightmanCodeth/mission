xcodebuild -archivePath $PWD/build/Mission.xcarchive \
	-exportOptionsPlist Mission/exportOptions.plist \
	-exportPath $PWD/build \
	-allowProvisioningUpdates \
	-exportArchive
