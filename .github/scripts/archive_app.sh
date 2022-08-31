#! /bin/bash

set -eo pipefail

xcodebuild -workspace Mission.xcworkspace \
	-scheme Mission \
	-configuration Release \
	-archivePath $PWD/build/Mission.xcarchive \
	clean archive
