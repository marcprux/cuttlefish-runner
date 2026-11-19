# launch_cvd arguments specific to macOS hosts. Sourced by launch.sh.
args+=(
  --vm_manager=qemu_cli
  --qemu_binary_dir="$CF_QEMU_SHIM"
  --gpu_mode=guest_swiftshader
)
