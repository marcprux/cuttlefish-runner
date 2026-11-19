#!/bin/bash
# Stands in for qemu-system-aarch64 in the directory passed to launch_cvd as
# --qemu_binary_dir. The macOS Cuttlefish host tools always ask QEMU for the
# HVF accelerator, a Cocoa window and CoreAudio output. Hosted macOS runners
# are virtual machines without nested virtualization, so on hosts where
# Hypervisor.framework is unavailable the arguments are rewritten to use
# software emulation. The display and audio devices are always made headless.
set -euo pipefail

real="${CF_QEMU_REAL:-$(cd "$(dirname "$0")" && pwd)/../qemu/bin/qemu-system-aarch64}"

hvf=0
if [ "${CF_FORCE_TCG:-}" != 1 ] && [ "$(sysctl -n kern.hv_support 2> /dev/null || echo 0)" = 1 ]; then
  hvf=1
fi

args=()
while [ $# -gt 0 ]; do
  case "$1" in
    -accel)
      if [ "$hvf" = 0 ] && [[ "${2:-}" == hvf* ]]; then
        args+=(-accel "tcg,thread=multi,tb-size=${CF_TCG_TB_SIZE:-1024}")
      else
        args+=("$1" "$2")
      fi
      shift 2
      ;;
    -cpu)
      if [ "$hvf" = 0 ] && [ "${2:-}" = host ]; then
        # Emulating the architected pointer authentication algorithm is slow.
        args+=(-cpu "${CF_TCG_CPU:-max,pauth-impdef=on}")
      else
        args+=("$1" "$2")
      fi
      shift 2
      ;;
    -display)
      if [[ "${2:-}" == cocoa* ]]; then
        args+=(-display none)
      else
        args+=("$1" "$2")
      fi
      shift 2
      ;;
    -audiodev)
      if [[ "${2:-}" == coreaudio,* ]]; then
        args+=(-audiodev "none,${2#coreaudio,}")
      else
        args+=("$1" "$2")
      fi
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

exec "$real" ${args[@]+"${args[@]}"}
