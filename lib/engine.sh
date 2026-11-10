#!/usr/bin/env bash

STEP_NAMES=()
STEP_FUNCS=()
STEP_COUNT=0
MANUAL_STEPS=()
MANUAL_COUNT=0
DRY_RUN=0
SELECTED_TIER=""
OPSEC_OS=""
VPN_GATED=0
VPN_CHOICE=""
MULLVAD_KEY_FPR="A1198702FC3E0A09A9AE5B75D5A1D4F266DE8DDF"
CLOUDFLARE_KEY_FPR="C068A2B5771775193CBE1F2F6E2DD2174FA1C3BA"
SIGNAL_KEY_FPR="DBA36B5181D0C816F630E889D980A17457F6FB06"

step() {
  STEP_NAMES[$STEP_COUNT]="$1"
  STEP_FUNCS[$STEP_COUNT]="$2"
  STEP_COUNT=$((STEP_COUNT + 1))
}

manual() {
  MANUAL_STEPS[$MANUAL_COUNT]="$1"
  MANUAL_COUNT=$((MANUAL_COUNT + 1))
}

note() { printf '      %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

tier_name() {
  case "$1" in
    0) echo "Lockdown" ;;
    1) echo "Anonymous" ;;
    2) echo "Hardened" ;;
    3) echo "Private" ;;
    4) echo "Hygiene" ;;
  esac
}

detect_os() {
  case "$(uname -s)" in
    Darwin) OPSEC_OS="macos"; return 0 ;;
    Linux) ;;
    *) return 1 ;;
  esac
  [ -r /etc/os-release ] || return 1
  local ids
  ids="$(. /etc/os-release && echo "${ID:-} ${ID_LIKE:-}")"
  case " $ids " in
    *" debian "*|*" ubuntu "*) OPSEC_OS="debian" ;;
    *" fedora "*|*" rhel "*)   OPSEC_OS="fedora" ;;
    *) return 1 ;;
  esac
}

os_label() {
  case "$OPSEC_OS" in
    macos)  echo "macOS" ;;
    debian) echo "Debian / Ubuntu Linux" ;;
    fedora) echo "Fedora Linux" ;;
  esac
}

mullvad_cli() {
  if have mullvad; then
    echo "mullvad"
  elif [ -x "/Applications/Mullvad VPN.app/Contents/Resources/mullvad" ]; then
    echo "/Applications/Mullvad VPN.app/Contents/Resources/mullvad"
  elif [ -x /usr/local/bin/mullvad ]; then
    echo "/usr/local/bin/mullvad"
  fi
}

mullvad_connected() {
  local cli
  cli="$(mullvad_cli)"
  [ -n "$cli" ] && "$cli" status 2>/dev/null | grep -q "Connected"
}

vpn_connected() {
  if mullvad_connected; then
    return 0
  fi
  if have warp-cli && warp-cli status 2>/dev/null | grep -q "Connected"; then
    return 0
  fi
  return 1
}

vpn_connect_help() {
  if [ "$VPN_CHOICE" = "warp" ]; then
    if [ "$OPSEC_OS" = "macos" ]; then
      echo "      Open Cloudflare WARP from the menu bar, accept its terms and"
      echo "      switch it on."
    else
      echo "      Open a second terminal and run these two commands. The first"
      echo "      asks you to accept Cloudflare's terms:"
      echo "        warp-cli registration new"
      echo "        warp-cli connect"
    fi
  else
    echo "      Open Mullvad VPN, log in and press Connect."
  fi
}

choose_vpn() {
  if mullvad_connected; then
    VPN_CHOICE="mullvad"
    return 0
  fi
  if vpn_connected; then
    VPN_CHOICE="warp"
    return 0
  fi
  [ -z "$VPN_CHOICE" ] || return 0
  echo ""
  echo "This tier installs a VPN first, so the rest of the downloads are hidden"
  echo "from your internet provider."
  echo ""
  echo "Mullvad VPN is the recommended choice, but it needs a paid account."
  echo "If you do not have one, OPSEC uses Cloudflare WARP instead. WARP is"
  echo "free and hides your activity from your internet provider and Wi-Fi,"
  echo "but it does not hide your location from websites."
  echo ""
  local answer
  while :; do
    printf 'Do you have a Mullvad account? (yes/no, or q to quit): '
    read -r answer || exit 1
    case "$answer" in
      y|Y|yes|Yes|YES) VPN_CHOICE="mullvad"; return 0 ;;
      n|N|no|No|NO)    VPN_CHOICE="warp"; return 0 ;;
      q|Q) echo "Nothing was changed."; exit 0 ;;
      *) echo "Please type yes or no." ;;
    esac
  done
}

plan_vpn_first() {
  case "$VPN_CHOICE" in
    mullvad) step "Install Mullvad VPN (first, before anything else)" vpn_install_mullvad ;;
    warp)    step "Install Cloudflare WARP, the free VPN (first, before anything else)" vpn_install_warp ;;
  esac
  step "Wait for you to connect the VPN. Nothing else is downloaded until it is on" vpn_gate
}

plan_vpn_settings() {
  if [ "$VPN_CHOICE" = "warp" ]; then
    manual "Cloudflare WARP has no kill switch and does not hide your location from websites. Move to Mullvad VPN when you can."
  else
    step "Turn on the VPN kill switch (lockdown mode) and auto-connect" mullvad_settings
  fi
}

vpn_gate() {
  if vpn_connected; then
    note "The VPN is connected."
    VPN_GATED=1
    return 0
  fi
  echo ""
  echo "      OPSEC is paused. Nothing else will be downloaded until a VPN is on,"
  echo "      so your internet provider cannot see what gets installed next."
  echo ""
  vpn_connect_help
  echo ""
  local answer
  while :; do
    printf '      Press Enter once the VPN says Connected, or type q to stop here: '
    read -r answer || answer="q"
    case "$answer" in
      q|Q)
        echo ""
        echo "Stopped before installing anything else. Run 'opsec up $SELECTED_TIER' again"
        echo "once the VPN is connected and it will carry on from here."
        exit 1
        ;;
    esac
    if vpn_connected; then
      VPN_GATED=1
      return 0
    fi
    echo "      The VPN is not connected yet."
  done
}

mullvad_settings() {
  local cli
  cli="$(mullvad_cli)"
  if [ -z "$cli" ]; then
    note "Mullvad VPN is not installed, so there is nothing to set. If you use another VPN, turn on its kill switch yourself."
    return 0
  fi
  if ! "$cli" status 2>/dev/null | grep -q "Connected"; then
    note "Mullvad is not the VPN that is connected, so lockdown mode was left off."
    note "Turning it on now would cut off your internet. Turn it on in Mullvad's settings once you use it."
    return 0
  fi
  "$cli" lockdown-mode set on && "$cli" auto-connect set on
}

fetch_pinned_key() {
  local url="$1" expected="$2" out="$3" home found
  curl -fsSL --proto '=https' --tlsv1.2 -o "$out" "$url" || return 1
  home="$(mktemp -d)" || return 1
  found="$(gpg --homedir "$home" --batch --show-keys --with-colons "$out" 2>/dev/null |
    awk -F: '$1 == "pub" { want = 1; next } want && $1 == "fpr" { print $10; want = 0 }')"
  rm -rf "$home"
  if [ "$found" != "$expected" ]; then
    note "The signing key from $url is not the one OPSEC expects, so nothing was installed from it."
    note "Expected: $expected"
    note "Received: ${found:-nothing readable}"
    rm -f "$out"
    return 1
  fi
}

backup_file() {
  local dest="$1"
  if sudo test -e "$dest" && ! sudo test -e "$dest.opsec-backup"; then
    sudo cp -p "$dest" "$dest.opsec-backup"
  fi
}

install_root_file() {
  local src="$1" dest="$2"
  sudo mkdir -p "$(dirname "$dest")" || return 1
  backup_file "$dest" || return 1
  sudo cp "$src" "$dest" || return 1
  sudo chmod 644 "$dest"
}

write_root_file() {
  local dest="$1"
  sudo mkdir -p "$(dirname "$dest")" || return 1
  backup_file "$dest" || return 1
  sudo tee "$dest" >/dev/null || return 1
  sudo chmod 644 "$dest"
}

firefox_policy_source() {
  if [ "$SELECTED_TIER" -le 3 ]; then
    echo "$ROOT_DIR/configs/firefox/policies-tier3.json"
  else
    echo "$ROOT_DIR/configs/firefox/policies-tier4.json"
  fi
}

choose_tier() {
  echo "Which tier do you want to apply? Tier 0 is the most locked down."
  echo ""
  echo "  4  Hygiene     Everyday safety. Blocks ads, trackers and scams."
  echo "  3  Private     Hides your browsing from your internet provider."
  echo "  2  Hardened    Makes the computer much harder to break into."
  echo "  1  Anonymous   A sealed virtual machine where everything goes through Tor. Slow."
  echo "  0  Lockdown    A separate operating system. Guide only."
  echo ""
  local answer
  while :; do
    printf 'Enter a number from 0 to 4 (or q to quit): '
    read -r answer || exit 1
    case "$answer" in
      0|1|2|3|4) SELECTED_TIER="$answer"; return 0 ;;
      q|Q) echo "Nothing was changed."; exit 0 ;;
      *) echo "Please type 0, 1, 2, 3 or 4." ;;
    esac
  done
}

show_tier0_guide() {
  cat <<'EOF'
Tier 0: Lockdown cannot be applied to the system you are using now.
It means moving to a separate, purpose-built operating system, so
OPSEC gives you a checklist instead of changing this computer.

  1. Choose one:
       Tails     Runs from a USB stick and forgets everything on shutdown.
                 https://tails.net/install/
       Qubes OS  Installed on the computer. Keeps each activity in its
                 own sealed compartment.
                 https://www.qubes-os.org/downloads/
  2. Follow that project's own steps to verify the download before
     installing it. Do not skip the verification.
  3. Keep personal and anonymous activity in separate compartments.
  4. Keep encryption keys and sensitive files on a device that never
     goes online.

The emergency wipe and dead-man timer are not built yet.

Nothing was changed on this computer. To get the strongest setup that
can be applied here, run:  opsec up 1
EOF
}

build_plan() {
  local n
  if [ "$SELECTED_TIER" -le 3 ]; then
    plan_vpn_first
  fi
  for n in 4 3 2 1; do
    if [ "$n" -ge "$SELECTED_TIER" ]; then
      "plan_tier$n"
    fi
  done
}

show_plan() {
  local i
  echo ""
  echo "Tier $SELECTED_TIER: $(tier_name "$SELECTED_TIER") on $(os_label)"
  echo ""
  echo "OPSEC will make these changes:"
  i=0
  while [ "$i" -lt "$STEP_COUNT" ]; do
    printf '  %2d. %s\n' "$((i + 1))" "${STEP_NAMES[$i]}"
    i=$((i + 1))
  done
  if [ "$MANUAL_COUNT" -gt 0 ]; then
    echo ""
    echo "These need you, so OPSEC will only remind you at the end:"
    i=0
    while [ "$i" -lt "$MANUAL_COUNT" ]; do
      printf '   - %s\n' "${MANUAL_STEPS[$i]}"
      i=$((i + 1))
    done
  fi
  echo ""
}

confirm_plan() {
  echo "This installs apps and changes system settings. Some apps may be"
  echo "downloaded from their makers' own software sources. You will be"
  echo "asked for your computer password."
  if [ "$SELECTED_TIER" -le 3 ]; then
    echo ""
    echo "The VPN is installed first. OPSEC then waits until it is connected"
    echo "before downloading anything else. Your internet provider can see"
    echo "the VPN itself being downloaded, but not what follows."
    echo ""
  fi
  echo "'opsec down' removes the settings files OPSEC writes. It does not"
  echo "uninstall apps. Files OPSEC replaces are kept next to the original"
  echo "with '.opsec-backup' on the end."
  echo ""
  echo "OPSEC never encrypts your computer's disk or your own files. If disk"
  echo "encryption is off, it only tells you, and turning it on is left to you."
  if [ "$SELECTED_TIER" -le 1 ]; then
    echo "The sealed VM is the one exception: it is always encrypted, with a"
    echo "passphrase you choose."
  fi
  echo ""
  if [ "$SELECTED_TIER" -le 1 ] && [ "$VPN_CHOICE" = "warp" ]; then
    echo "WARNING: you are using Cloudflare WARP, which has no kill switch."
    echo "If WARP drops while the VM is running, your network can see that"
    echo "this computer is using Tor (not what you do with it). Cloudflare"
    echo "also knows your real address. Mullvad VPN closes both gaps."
    echo ""
    local warp_answer
    printf "Type 'warp' to accept that and continue, or anything else to cancel: "
    read -r warp_answer || warp_answer=""
    if [ "$warp_answer" != "warp" ]; then
      echo "Cancelled. Nothing was changed."
      exit 0
    fi
    echo ""
  fi
  local answer
  printf "Type 'yes' to apply these changes, or anything else to cancel: "
  read -r answer || answer=""
  case "$answer" in
    yes|YES|Yes) return 0 ;;
    *) echo "Cancelled. Nothing was changed."; exit 0 ;;
  esac
}

run_plan() {
  local i failed_count=0 failed_names=""

  if ! sudo -v; then
    echo "Could not get administrator access. Nothing was changed." >&2
    exit 1
  fi

  i=0
  while [ "$i" -lt "$STEP_COUNT" ]; do
    echo ""
    printf '[%d/%d] %s\n' "$((i + 1))" "$STEP_COUNT" "${STEP_NAMES[$i]}"
    if [ "$VPN_GATED" -eq 1 ] && ! vpn_connected; then
      echo "      The VPN has disconnected."
      VPN_GATED=0
      vpn_gate
    fi
    if "${STEP_FUNCS[$i]}"; then
      echo "      done"
    else
      echo "      FAILED"
      failed_count=$((failed_count + 1))
      failed_names="$failed_names
   - ${STEP_NAMES[$i]}"
    fi
    i=$((i + 1))
  done

  echo ""
  echo "Finished: $((STEP_COUNT - failed_count)) of $STEP_COUNT steps succeeded."
  if [ "$failed_count" -gt 0 ]; then
    echo ""
    echo "These steps did not finish. Scroll up to see why:$failed_names"
  fi
  if [ "$MANUAL_COUNT" -gt 0 ]; then
    echo ""
    echo "Still to do yourself:"
    i=0
    while [ "$i" -lt "$MANUAL_COUNT" ]; do
      printf '   - %s\n' "${MANUAL_STEPS[$i]}"
      i=$((i + 1))
    done
  fi
  echo ""
  echo "OPSEC keeps no record of this run. Run 'opsec status' to check what is on."
  echo "Restart the computer to make sure every change takes effect."
  [ "$failed_count" -eq 0 ]
}

opsec_up() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRY_RUN=1 ;;
      --mullvad) VPN_CHOICE="mullvad" ;;
      --warp)    VPN_CHOICE="warp" ;;
      0|1|2|3|4) SELECTED_TIER="$arg" ;;
      *)
        echo "Usage: opsec up [0-4] [--dry-run] [--mullvad | --warp]" >&2
        exit 1
        ;;
    esac
  done

  if [ "$(id -u)" -eq 0 ]; then
    echo "Run 'opsec up' as your normal user, not as root or with sudo." >&2
    echo "It asks for your password itself when it needs to." >&2
    exit 1
  fi

  if ! detect_os; then
    echo "OPSEC does not support this system yet." >&2
    echo "Supported: macOS, Debian, Ubuntu and Fedora. Windows uses windows/opsec.ps1." >&2
    exit 1
  fi

  [ -n "$SELECTED_TIER" ] || choose_tier

  if [ "$SELECTED_TIER" -eq 0 ]; then
    show_tier0_guide
    exit 0
  fi

  . "$ROOT_DIR/lib/vm.sh"
  . "$ROOT_DIR/configs/$OPSEC_OS.sh"
  if [ "$SELECTED_TIER" -le 3 ]; then
    choose_vpn
  fi
  build_plan
  show_plan

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run: nothing was changed."
    exit 0
  fi

  confirm_plan
  run_plan
}
