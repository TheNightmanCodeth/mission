#! /bin/bash
set -eo pipefail

gpg --quiet --batch --yes --decrypt --passphrase="$IOS_KEYS" --output ./.github/secrets/MissionProfile.provisionprofile.provisionprofile ./.github/secrets/MissionProfile.provisionprofile.gpg
gpg --quiet --batch --yes --decrypt --passphrase="$IOS_KEYS" --output ./.github/secrets/MacOSMissionCertificates.p12.p12 ./.github/secrets/MacOSMissionCertificates.p12.gpg

mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles

cp ./.github/secrets/MissionProfile.provisionprofile.provisionprofile ~/Library/MobileDevice/Provisioning\ Profiles/MissionProfile.provisionprofile.provisionprofile

security create-keychain -p "" build.keychain
security import ./.github/secrets/MacOSMissionCertificates.p12.p12 -t agg -k ~/Library/Keychains/build.keychain -P "" -A

security list-keychains -s ~/Library/Keychains/build.keychain
security default-keychain -s ~/Library/Keychains/build.keychain
security unlock-keychain -p "" ~/Library/Keychains/build.keychain

security set-key-partition-list -S apple-tool:,apple: -s -k "" ~/Library/Keychains/build.keychain
