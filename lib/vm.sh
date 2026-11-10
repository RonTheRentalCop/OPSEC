#!/usr/bin/env bash

VM_DIR="${OPSEC_VM_DIR:-$HOME/.local/share/opsec-vm}"
VM_DISK="$VM_DIR/disk.qcow2"
VM_DISK_SIZE="24G"
VM_IMAGE_URL="https://cloud.debian.org/images/cloud/trixie/latest"
VM_PASS=""
QEMU_ARGS=()

vm_arch() {
  case "$(uname -m)" in
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64)  echo "amd64" ;;
    *) return 1 ;;
  esac
}

vm_qemu() {
  case "$(vm_arch)" in
    arm64) echo "qemu-system-aarch64" ;;
    amd64) echo "qemu-system-x86_64" ;;
  esac
}

vm_accel() {
  case "$(uname -s)" in
    Darwin) echo "hvf" ;;
    Linux)
      if [ -w /dev/kvm ]; then
        echo "kvm"
      fi
      ;;
  esac
}

vm_firmware() {
  local qemu_path prefix file
  qemu_path="$(command -v "$(vm_qemu)" 2>/dev/null)" || return 1
  prefix="$(cd "$(dirname "$qemu_path")/.." && pwd)"
  for file in \
    "$prefix/share/qemu/edk2-aarch64-code.fd" \
    /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
    /usr/share/edk2/aarch64/QEMU_EFI.fd \
    /usr/share/AAVMF/AAVMF_CODE.fd; do
    if [ -r "$file" ]; then
      echo "$file"
      return 0
    fi
  done
  return 1
}

vm_memory_mb() {
  local total=0
  case "$(uname -s)" in
    Darwin) total=$(($(sysctl -n hw.memsize) / 1048576)) ;;
    Linux)  total=$(($(awk '/MemTotal/ { print $2 }' /proc/meminfo) / 1024)) ;;
  esac
  local half=$((total / 2))
  if [ "$half" -gt 4096 ]; then
    half=4096
  fi
  if [ "$half" -lt 2048 ]; then
    half=2048
  fi
  echo "$half"
}

vm_cpus() {
  local total=2
  case "$(uname -s)" in
    Darwin) total="$(sysctl -n hw.ncpu)" ;;
    Linux)  total="$(nproc)" ;;
  esac
  local half=$((total / 2))
  if [ "$half" -gt 4 ]; then
    half=4
  fi
  if [ "$half" -lt 2 ]; then
    half=2
  fi
  echo "$half"
}

vm_exists() { [ -f "$VM_DISK" ]; }

vm_check_tools() {
  if ! vm_arch >/dev/null; then
    echo "The sealed VM does not support this kind of processor yet." >&2
    return 1
  fi
  if ! have "$(vm_qemu)" || ! have qemu-img; then
    echo "QEMU is not installed. Run 'opsec up 1' to install it." >&2
    return 1
  fi
  if [ -z "$(vm_accel)" ]; then
    echo "This account cannot use hardware virtualisation (/dev/kvm)." >&2
    echo "Add yourself to the kvm group, log out and back in, and try again:" >&2
    echo "  sudo usermod -aG kvm \"\$USER\"" >&2
    return 1
  fi
  if [ "$(vm_arch)" = "arm64" ] && ! vm_firmware >/dev/null; then
    echo "The UEFI firmware for ARM virtual machines was not found." >&2
    return 1
  fi
}

vm_require_vpn() {
  if vpn_connected; then
    return 0
  fi
  echo ""
  echo "The VM only runs while a VPN is connected on this computer. That way"
  echo "your network sees a VPN connection and never sees Tor."
  echo ""
  local answer
  while :; do
    printf 'Connect the VPN, then press Enter (or type q to stop): '
    read -r answer || answer="q"
    case "$answer" in
      q|Q) echo "Stopped. Nothing was started."; return 1 ;;
    esac
    if vpn_connected; then
      return 0
    fi
    echo "The VPN is not connected yet."
  done
}

vm_ask_passphrase() {
  VM_PASS=""
  printf '%s' "$1"
  IFS= read -rs VM_PASS || return 1
  echo ""
}

vm_new_passphrase() {
  local first
  echo ""
  echo "Choose a passphrase for the VM. Everything inside the VM is encrypted"
  echo "with it. There is no recovery: if you forget it, the VM is gone."
  echo "Use at least 12 characters and do not reuse another password."
  echo ""
  while :; do
    vm_ask_passphrase "New passphrase: " || return 1
    if [ "${#VM_PASS}" -lt 12 ]; then
      echo "That is shorter than 12 characters."
      continue
    fi
    first="$VM_PASS"
    vm_ask_passphrase "Type it again: " || return 1
    if [ "$first" = "$VM_PASS" ]; then
      return 0
    fi
    echo "Those did not match."
  done
}

vm_sha512() {
  if have sha512sum; then
    sha512sum "$1" | awk '{ print $1 }'
  else
    shasum -a 512 "$1" | awk '{ print $1 }'
  fi
}

vm_fetch_image() {
  local dest="$1" name expected actual
  name="debian-13-generic-$(vm_arch).qcow2"
  if [ -n "${OPSEC_VM_IMAGE:-}" ]; then
    note "Using the Debian image at $OPSEC_VM_IMAGE"
    cp "$OPSEC_VM_IMAGE" "$dest" || return 1
  else
    note "Downloading Debian ($name)"
    curl -fL --proto '=https' --tlsv1.2 --progress-bar -o "$dest" "$VM_IMAGE_URL/$name" || return 1
  fi
  expected="$(curl -fsSL --proto '=https' --tlsv1.2 "$VM_IMAGE_URL/SHA512SUMS" | awk -v name="$name" '$2 == name { print $1 }')"
  if [ -z "$expected" ]; then
    note "Could not download Debian's checksum list."
    return 1
  fi
  actual="$(vm_sha512 "$dest")"
  if [ "$expected" != "$actual" ]; then
    note "The Debian image does not match Debian's published checksum. It was deleted."
    rm -f "$dest"
    return 1
  fi
  note "The Debian image matches Debian's published checksum."
}

vm_build_args() {
  local mode="$1" arch
  arch="$(vm_arch)"
  QEMU_ARGS=(
    -nodefaults
    -name opsec
    -accel "$(vm_accel)"
    -cpu host
    -smp "$(vm_cpus)"
    -m "$(vm_memory_mb)"
  )
  case "$arch" in
    arm64) QEMU_ARGS+=(-machine virt -bios "$(vm_firmware)") ;;
    amd64) QEMU_ARGS+=(-machine q35) ;;
  esac
  QEMU_ARGS+=(
    -device virtio-rng-pci
    -netdev "user,id=net0,ipv6=off"
    -device "virtio-net-pci,netdev=net0"
    -object "secret,id=disk0,file=/dev/fd/3"
    -drive "if=virtio,format=qcow2,file=$2,encrypt.key-secret=disk0"
    -monitor none
  )
  case "$mode" in
    setup)
      QEMU_ARGS+=(
        -display none
        -chardev "file,id=console,path=$VM_DIR/console"
        -serial chardev:console
        -blockdev "driver=vvfat,node-name=seed,dir=$VM_DIR/seed,label=cidata,read-only=on"
        -device "virtio-blk-pci,drive=seed"
      )
      ;;
    desktop)
      QEMU_ARGS+=(-serial none -device qemu-xhci -device usb-kbd -device usb-tablet)
      case "$arch" in
        arm64) QEMU_ARGS+=(-device virtio-gpu-pci) ;;
        amd64) QEMU_ARGS+=(-device virtio-vga) ;;
      esac
      case "$(uname -s)" in
        Darwin) QEMU_ARGS+=(-display cocoa) ;;
        *)      QEMU_ARGS+=(-display gtk) ;;
      esac
      ;;
  esac
}

vm_keep_awake() {
  if have caffeinate; then
    caffeinate -i -w "$1" >/dev/null 2>&1 &
  fi
}

vm_first_boot() {
  local qemu pid watcher line result="failed" vpn_lost=0
  qemu="$(vm_qemu)"
  rm -f "$VM_DIR/console"
  mkfifo -m 600 "$VM_DIR/console" || return 1
  exec 4<>"$VM_DIR/console"

  "$qemu" "${QEMU_ARGS[@]}" 3< <(printf '%s' "$VM_PASS") >/dev/null 2>"$VM_DIR/setup.err" </dev/null &
  pid=$!
  vm_keep_awake "$pid"
  (
    while kill -0 "$pid" 2>/dev/null; do
      sleep 2
    done
    printf 'OPSEC-EXIT\n' >&4
  ) &
  watcher=$!
  trap 'kill "$pid" 2>/dev/null' INT TERM

  while IFS= read -r line <&4; do
    line="${line%$'\r'}"
    case "$line" in
      *"OPSEC-EXIT"*) break ;;
      *"OPSEC-RESULT: ok"*) result="ok" ;;
      *"OPSEC-RESULT: failed"*) result="failed" ;;
      *"OPSEC: "*)
        note "${line#*OPSEC: }"
        if ! vpn_connected; then
          vpn_lost=1
          kill "$pid" 2>/dev/null
        fi
        ;;
      *)
        if [ -n "${OPSEC_VM_DEBUG:-}" ]; then
          printf '%s\n' "$line"
        fi
        ;;
    esac
  done

  wait "$pid" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true
  trap - INT TERM
  exec 4<&-
  rm -f "$VM_DIR/console"

  if [ "$vpn_lost" -eq 1 ]; then
    note "The VPN disconnected, so the build was stopped to keep Tor hidden from your network."
    return 1
  fi
  if [ "$result" != "ok" ] && [ -s "$VM_DIR/setup.err" ]; then
    note "QEMU reported: $(head -n 3 "$VM_DIR/setup.err")"
  fi
  rm -f "$VM_DIR/setup.err"
  [ "$result" = "ok" ]
}

vm_create() {
  vm_check_tools || return 1
  if vm_exists; then
    note "The sealed VM already exists. Start it with 'opsec vm start'."
    return 0
  fi
  if [ ! -f "$ROOT_DIR/vm/provision.sh" ]; then
    note "vm/provision.sh is missing from this copy of OPSEC."
    return 1
  fi
  vm_require_vpn || return 1
  vm_new_passphrase || return 1

  local base="$VM_DIR/base.qcow2" building="$VM_DIR/building.qcow2"
  mkdir -p "$VM_DIR" && chmod 700 "$VM_DIR" || return 1
  rm -rf "$base" "$building" "$VM_DIR/seed" "$VM_DIR/console" "$VM_DIR/setup.err"

  vm_fetch_image "$base" || return 1
  qemu-img resize -q "$base" "$VM_DISK_SIZE" || return 1
  note "Encrypting the VM disk with your passphrase"
  qemu-img convert --object secret,id=disk0,file=/dev/fd/3 -f qcow2 -O qcow2 \
    -o encrypt.format=luks,encrypt.key-secret=disk0 "$base" "$building" \
    3< <(printf '%s' "$VM_PASS") || return 1
  rm -f "$base"
  chmod 600 "$building"

  mkdir -p "$VM_DIR/seed"
  cp "$ROOT_DIR/vm/provision.sh" "$VM_DIR/seed/user-data" || return 1
  printf 'instance-id: opsec\nlocal-hostname: host\n' >"$VM_DIR/seed/meta-data"

  note "Starting the VM for its one-time setup. Nothing appears on screen until it is done."
  note "This takes 15 to 40 minutes because everything after the first step is fetched through Tor."
  note "Keep the computer awake, plugged in and with the lid open until it finishes."
  vm_build_args setup "$building"
  local ok=0
  vm_first_boot || ok=1
  VM_PASS=""
  rm -rf "$VM_DIR/seed"

  if [ "$ok" -ne 0 ]; then
    rm -f "$building"
    note "The VM was not finished, so it was deleted. Run 'opsec vm create' to try again."
    return 1
  fi
  mv "$building" "$VM_DISK" || return 1
  note "The sealed VM is ready. Start it with 'opsec vm start'."
}

vm_start() {
  vm_check_tools || return 1
  if ! vm_exists; then
    echo "There is no sealed VM yet. Build it with 'opsec vm create'." >&2
    return 1
  fi
  vm_require_vpn || return 1
  vm_ask_passphrase "VM passphrase: " || return 1

  local errors status
  vm_build_args desktop "$VM_DISK"
  echo "Starting the VM. Shut it down from its own menu when you are done."
  echo "Shut it down before this computer goes to sleep, or its clock falls"
  echo "behind and Tor stops connecting."
  vm_keep_awake "$$"
  status=0
  errors="$("$(vm_qemu)" "${QEMU_ARGS[@]}" 3< <(printf '%s' "$VM_PASS") 2>&1 >/dev/null)" || status=$?
  VM_PASS=""
  if [ "$status" -ne 0 ]; then
    case "$errors" in
      *"Invalid password"*|*"cannot unlock"*) echo "That passphrase is wrong." >&2 ;;
      *) echo "The VM stopped with an error: $(printf '%s\n' "$errors" | head -n 3)" >&2 ;;
    esac
    return 1
  fi
  echo "The VM is off."
}

vm_destroy() {
  if [ ! -d "$VM_DIR" ]; then
    echo "There is no sealed VM to delete."
    return 0
  fi
  echo "This permanently deletes the sealed VM and everything inside it."
  echo "It lives in $VM_DIR"
  local answer
  printf "Type 'destroy' to delete it, or anything else to cancel: "
  read -r answer || answer=""
  if [ "$answer" != "destroy" ]; then
    echo "Cancelled. Nothing was deleted."
    return 0
  fi
  rm -rf "$VM_DIR" || return 1
  echo "The sealed VM is deleted. QEMU itself is still installed."
}

vm_status() {
  if vm_exists; then
    echo "The sealed VM is built. It lives in $VM_DIR"
    echo "On disk it is one encrypted file: $(du -h "$VM_DISK" | awk '{ print $1 }')"
  else
    echo "The sealed VM has not been built. Run 'opsec vm create'."
  fi
  if vpn_connected; then
    echo "A VPN is connected, so the VM can be started."
  else
    echo "No VPN is connected. The VM will not start until one is."
  fi
}

vm_create_step() {
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi
  vm_create
}

vm_manual_tier1() {
  manual "Start the VM with 'opsec vm start'. Tor Browser opens by itself. Do all anonymous activity inside the VM and nothing personal."
  manual "In Tor Browser, click the shield icon and set the security level to Safer. This blocks the scripts most attacks rely on."
  manual "Do not add extensions to Tor Browser or change its other settings. Looking like every other Tor user is what protects you."
  manual "Never log into personal accounts or reuse usernames inside the VM. No tool can undo that link."
  manual "Keep files you download inside the VM. Apps in the VM have no internet access except through Tor, so a document opened there cannot reveal your real address."
  manual "The VM protects the anonymous work from your everyday accounts and browser. It does not protect against monitoring software installed on this computer itself. Do not use a computer your school or employer manages."
  manual "This computer still shows that QEMU and OPSEC are installed, and that one large encrypted file exists. What is inside the file cannot be read without your passphrase."
  manual "No tool stops an adversary who can watch both ends of your connection at once. For that level of risk, use Tails (Tier 0)."
}

opsec_vm() {
  local action="${1:-}"
  if [ "$(id -u)" -eq 0 ]; then
    echo "Run 'opsec vm' as your normal user, not as root or with sudo." >&2
    exit 1
  fi
  case "$action" in
    create)  vm_create ;;
    start)   vm_start ;;
    destroy) vm_destroy ;;
    status)  vm_status ;;
    *)
      cat >&2 <<'EOF'
Usage:
  opsec vm create    Build the sealed, Tor-only virtual machine
  opsec vm start     Unlock and open it
  opsec vm status    Show whether it is built and whether it can start
  opsec vm destroy   Delete it and everything inside it
EOF
      exit 1
      ;;
  esac
}
