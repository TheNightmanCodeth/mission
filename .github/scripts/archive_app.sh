#! /bin/bash

set -eo pipefail

xcodebuild -workspace Mission.xcworkspace \
	-scheme Mission \
	-configuration Release \
	-allowProvisioningUpdates \
	-archivePath $PWD/build/Mission.xcarchive \
	CODE_SIGN_IDENTITY="3rd Party Mac Developer Application: Joe Diragi (D44Y5BBJ48)" \
	PROVISIONING_PROFILE="5c49ec53-011d-4269-b2d6-bfa49d5e42f6" \
	clean archive
