#!/usr/bin/env bash
# Hardware KVM on ubuntu-latest per reactivecircus/android-emulator-runner README.
set -euo pipefail
if [[ "$(uname -s)" != Linux ]]; then
  echo "KVM enable skipped (not Linux)"
  exit 0
fi
echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules >/dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=kvm
if [[ -e /dev/kvm ]]; then
  ls -l /dev/kvm
else
  echo "warning: /dev/kvm missing after udev trigger" >&2
  exit 1
fi
