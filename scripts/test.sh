#!/bin/sh
# Runs `swift test`. With only the Command Line Tools installed (no Xcode), Swift Testing ships
# but is not on the default search path, so point the compiler and linker at it. Its Foundation
# cross-import overlay ships without a module there, so cross-import overlays are turned off.
set -eu

developer_dir=$(xcode-select -p)
case "$developer_dir" in
    */CommandLineTools)
        frameworks="$developer_dir/Library/Developer/Frameworks"
        exec swift test \
            -Xswiftc -F"$frameworks" \
            -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
            -Xlinker -F"$frameworks" \
            -Xlinker -rpath -Xlinker "$frameworks" \
            "$@"
        ;;
    *)
        exec swift test "$@"
        ;;
esac
