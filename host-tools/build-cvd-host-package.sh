#!/bin/bash
# Builds the macOS Cuttlefish host package from an AOSP checkout that has the
# cuttlefish-wearables patch series applied.
# Usage: build-cvd-host-package.sh AOSP_ROOT
set -uo pipefail

cd "$1"
ulimit -n 65536 2> /dev/null || ulimit -n 10240
# shellcheck source=/dev/null
source build/envsetup.sh
lunch aosp_cf_arm64_phone-bp2a-userdebug
m out/host/darwin-x86/cvd-host_package.tar.gz
