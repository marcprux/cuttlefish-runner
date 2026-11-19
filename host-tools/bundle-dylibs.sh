#!/bin/bash
# Makes a QEMU install tree relocatable: copies every non-system dylib the
# binaries link against into lib/, rewrites the load paths to be relative,
# and re-signs everything ad hoc.
# Usage: bundle-dylibs.sh PREFIX [ENTITLEMENTS_PLIST]
set -euo pipefail

prefix="$1"
entitlements="${2:-}"
mkdir -p "$prefix/lib"

external_deps() {
  otool -L "$1" | awk 'NR > 1 { print $1 }' | grep -Ev '^(/usr/lib/|/System/|@)' || true
}

relocate() {
  local file="$1" relative="$2" dep name
  for dep in $(external_deps "$file"); do
    name="$(basename "$dep")"
    if [ "$name" = "$(basename "$file")" ]; then
      continue
    fi
    if [ ! -e "$prefix/lib/$name" ]; then
      cp -L "$dep" "$prefix/lib/$name"
      chmod u+w "$prefix/lib/$name"
      install_name_tool -id "@loader_path/$name" "$prefix/lib/$name" 2> /dev/null
      relocate "$prefix/lib/$name" "@loader_path"
    fi
    install_name_tool -change "$dep" "$relative/$name" "$file" 2> /dev/null
  done
}

for binary in "$prefix"/bin/*; do
  if file -b "$binary" | grep -q 'Mach-O'; then
    relocate "$binary" "@executable_path/../lib"
  fi
done

for lib in "$prefix"/lib/*.dylib; do
  codesign --force --sign - "$lib"
done
for binary in "$prefix"/bin/*; do
  if file -b "$binary" | grep -q 'Mach-O'; then
    if [ -n "$entitlements" ] && [[ "$(basename "$binary")" == qemu-system-* ]]; then
      codesign --force --sign - --entitlements "$entitlements" "$binary"
    else
      codesign --force --sign - "$binary"
    fi
  fi
done

remaining="$(for f in "$prefix"/bin/* "$prefix"/lib/*.dylib; do
  file -b "$f" | grep -q 'Mach-O' && external_deps "$f"
done | grep -v ':$' | sort -u || true)"
if [ -n "$remaining" ]; then
  echo "unbundled dependencies remain:" >&2
  echo "$remaining" >&2
  exit 1
fi
