#!/usr/bin/env bash

DOWN_FILES=()
DOWN_COUNT=0

down_add() {
  if [ -e "$1" ] || [ -e "$1.opsec-backup" ]; then
    DOWN_FILES[$DOWN_COUNT]="$1"
    DOWN_COUNT=$((DOWN_COUNT + 1))
  fi
}

down_collect() {
  case "$OPSEC_OS" in
    macos)
      down_add "$MAC_FIREFOX_PLIST"
      down_add /Applications/Firefox.app/Contents/Resources/distribution/policies.json
      ;;
    *)
      down_add /etc/firefox/policies/policies.json
      down_add /etc/firefox-esr/policies/policies.json
      down_add /etc/systemd/resolved.conf.d/opsec-quad9.conf
      down_add /etc/NetworkManager/conf.d/00-opsec-mac.conf
      down_add /etc/NetworkManager/conf.d/01-opsec-mac-random.conf
      down_add /etc/sysctl.d/60-opsec.conf
      down_add /etc/sysctl.d/61-opsec-anonymity.conf
      ;;
  esac
}

down_describe() {
  if [ -e "$1.opsec-backup" ]; then
    echo "put back the original"
  else
    echo "remove"
  fi
}

down_one() {
  local file="$1"
  if [ "$file" = "${MAC_FIREFOX_PLIST:-}" ]; then
    sudo defaults delete "${file%.plist}" >/dev/null 2>&1
    if sudo test -e "$file.opsec-backup"; then
      sudo defaults import "${file%.plist}" "$file.opsec-backup" && sudo rm -f "$file.opsec-backup"
    fi
    return $?
  fi
  if sudo test -e "$file.opsec-backup"; then
    sudo mv -f "$file.opsec-backup" "$file"
  else
    sudo rm -f "$file"
  fi
}

down_reload() {
  case "$OPSEC_OS" in
    macos) ;;
    *)
      if systemctl is-active --quiet systemd-resolved; then
        sudo systemctl restart systemd-resolved
      fi
      if have nmcli; then
        sudo systemctl reload NetworkManager
      fi
      sudo sysctl --system >/dev/null
      ;;
  esac
}

opsec_down() {
  local dry_run=0 arg i failed=0
  for arg in "$@"; do
    case "$arg" in
      --dry-run) dry_run=1 ;;
      *)
        echo "Usage: opsec down [--dry-run]" >&2
        exit 1
        ;;
    esac
  done
  if [ "$(id -u)" -eq 0 ]; then
    echo "Run 'opsec down' as your normal user, not as root or with sudo." >&2
    exit 1
  fi
  if ! detect_os; then
    echo "OPSEC does not support this system yet." >&2
    exit 1
  fi
  . "$ROOT_DIR/lib/vm.sh"
  . "$ROOT_DIR/configs/$OPSEC_OS.sh"
  down_collect

  if [ "$DOWN_COUNT" -eq 0 ]; then
    echo "OPSEC found none of its settings files on this computer. Nothing to undo."
    exit 0
  fi

  echo "OPSEC will undo these settings files:"
  i=0
  while [ "$i" -lt "$DOWN_COUNT" ]; do
    printf '  %2d. %s (%s)\n' "$((i + 1))" "${DOWN_FILES[$i]}" "$(down_describe "${DOWN_FILES[$i]}")"
    i=$((i + 1))
  done
  echo ""
  echo "It leaves these alone, because turning them off would make you less safe:"
  echo "   - the firewall, automatic updates and app confinement"
  echo "   - the VPN and its kill switch"
  echo "   - every app OPSEC installed (remove the ones you do not want yourself)"
  echo "   - the sealed VM (delete it with 'opsec vm destroy')"
  echo ""
  if [ "$dry_run" -eq 1 ]; then
    echo "Dry run: nothing was changed."
    exit 0
  fi

  local answer
  printf "Type 'yes' to undo these, or anything else to cancel: "
  read -r answer || answer=""
  case "$answer" in
    yes|YES|Yes) ;;
    *) echo "Cancelled. Nothing was changed."; exit 0 ;;
  esac
  if ! sudo -v; then
    echo "Could not get administrator access. Nothing was changed." >&2
    exit 1
  fi

  i=0
  while [ "$i" -lt "$DOWN_COUNT" ]; do
    if down_one "${DOWN_FILES[$i]}"; then
      echo "  undone  ${DOWN_FILES[$i]}"
    else
      echo "  FAILED  ${DOWN_FILES[$i]}"
      failed=1
    fi
    i=$((i + 1))
  done
  down_reload
  echo ""
  echo "Done. Restart the computer and Firefox so the old settings take effect."
  [ "$failed" -eq 0 ]
}
