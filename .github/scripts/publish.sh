#! /bin/bash

set -eo pipefail

xcrun altool --upload-app -t macos -f build/mission.pkg -u "$APPLEID" -p "$APPLEID_PASSWORD" --verbose
