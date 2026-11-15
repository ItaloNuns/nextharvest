#!/usr/bin/env sh
# Foreground-only geolocator configuration for Swift Package Manager.
# Usage: sh tool/flutter_ios.sh build ios
#        sh tool/flutter_ios.sh run -d <ios-device>
export BYPASS_PERMISSION_LOCATION_ALWAYS=1
exec flutter "$@"
