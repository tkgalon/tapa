#!/bin/sh
# Runs SwiftLint in strict mode. With only the Command Line Tools installed (no Xcode), SwiftLint
# can't find SourceKit on its own, so point it at the Command Line Tools toolchain.
set -eu

developer_dir=$(xcode-select -p)
case "$developer_dir" in
    */CommandLineTools)
        export TOOLCHAIN_DIR="$developer_dir"
        ;;
esac
exec swiftlint lint --strict "$@"
