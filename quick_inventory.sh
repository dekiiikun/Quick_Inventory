#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Dekiiikun
# quick_inventory - fast, safe server inventory
# Features:
#  - Sections: system,repos,pkgs,services,ports,fs,net,containers,monitoring,security
#  - Flags: --json --out FILE --days N --sections LIST --redact --version --help
#  - JSON mode = ringkasan aman untuk SIEM/ELK/Loki
#  - Text mode = mirror ke layar + file /var/tmp (default)
set -Eeuo pipefail
LANG=C

VERSION="0.3.0"

JSON=0; OUT=""; DAYS=20; SECTIONS="all"; REDACT=0

print_help() {
  cat <<EOF
quick_inventory ${VERSION}
Usage:
  Text mode (default):
    sudo ./quick_inventory.sh [--out FILE] [--days N] [--sections LIST]
  JSON mode (summary only):
    sudo ./quick_inventory.sh --json [--out FILE] [--days N] [--sections LIST] [--redact]

Options:
  --json            Keluarkan ringkasan JSON (tanpa output teks)
  --out FILE        Tulis output ke FILE (kalau kosong: text mode -> /var/tmp, json -> stdout)
  --days N          Batas hari untuk daftar instalasi terbaru (default: 20)
  --sections LIST   Comma-separated, contoh: system,security,services (default: all)
  --redact          Anonimasi host/ip pada JSON (hash pendek)
  --version         Tampilkan versi dan keluar
  -h, --help        Bantuan ini

Sections:
  system,repos,pkgs,services,ports,fs,net,containers,monitoring,security
EOF
}

# ---- arg parser sederhana (tanpa getopt) ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift;;
    --out) OUT="${2-}"; shift 2;;
    --days) DAYS="${2-20}"; shift 2;;
    --sections) SECTIONS="${2-all}"; shift 2;;
    --redact) REDACT=1; shift;;
    --version) echo "$VERSION"; exit 0;;
    -h|--help) print_help; exit 0;;
    *) echo "Unknown arg: $1"; print_help; exit 2;;
  esac
done

# ---- util ----
in_sections() {
  local name="$1"
  [[ "$SECTIONS" == "all" ]] && return 0
  [[ ",$SECTIONS," == *",$name,"* ]]
}

tmo() { # timeout wrapper: tmo 5s cmd...
  if command -v timeout >/dev/null 2>&1; then
    timeout "$@"
  else
    shift
    "$@"
  fi
}

line() { printf '\n===== %s =====\n' "$1"; }

# ---- validator sections (NEW) ----
VALID_SECTIONS="system repos pkgs services ports fs net containers monitoring security all"
validate_sections() {
  local bad=() s
  IFS=',' read -r -a _arr <<< "${SECTIONS:-all}"
  for s in "${_arr[@]}"; do
    [[ -z "$s" ]] && continue
    [[ " $VALID_SECTIONS " == *" $s "* ]] || bad+=("$s")
  done
  if ((${#bad[@]})); then
    echo "ERROR: unknown section(s): ${bad[*]}" >&2
    echo "Valid sections: ${VALID_SECTIONS// /, }" >&2
    exit 2
  fi
}

# ---- info dasar ----
HOST="$(hostname || echo unknown)"
OS_PRETTY="$(awk -F= '/^PRETTY_NAME=/{gsub(/"/,"");print $2}' /etc/os-release 2>/dev/null || echo unknown)"
KERNEL="$(uname -r || echo unknown)"
UPTIME_SEC="$(awk '{print int($1)}' /proc/uptime 2>/dev/null || true)"

_pkgmgr=""  # apt | dnf | yum | zypper | pacman | apk
if command -v apt >/dev/null 2>&1; then _pkgmgr="apt"
elif command -v dnf >/dev/null 2>&1; then _pkgmgr="dnf"
elif command -v yum >/dev/null 2>&1; then _pkgmgr="yum"
elif command -v zypper >/dev/null 2>&1; then _pkgmgr="zypper"
elif command -v pacman >/dev/null 2>&1; then _pkgmgr="pacman"
elif command -v apk >/dev/null 2>&1; then _pkgmgr="apk"
fi

# ---- counters (untuk JSON) ----
FAILED_SVC=0
LISTEN_CNT=0
SEC_UPD=0
PKG_TOTAL=0
REBOOT_NEEDED=0

# ---- sections ----
section_system() {
  line "SYSTEM"
  printf "Host: %s\nOS  : %s\nKernel: %s\n" "$HOST" "$OS_PRETTY" "$KERNEL"
  command -v timedatectl >/dev/null 2>&1 && timedatectl 2>/dev/null | sed 's/^/  /' || true
  printf "Uptime(s): %s\n" "${UPTIME_SEC:-unknown}"
}

section_repos() {
  line "REPOSITORIES"
  case "$_pkgmgr" in
    apt)   tmo 5s apt-cache policy 2>/dev/null || true ;;
    dnf)   tmo 5s dnf -q repolist --enabled || true ;;
    yum)   tmo 5s yum -q repolist enabled || true ;;
    zypper)tmo 5s zypper lr -u || true ;;
    pacman)tmo 5s pacman -Syy 1>/dev/null 2>&1 || true; tmo 5s pacman -Sl 2>/dev/null | head -n 200 || true ;;
    apk)   tmo 5s cat /etc/apk/repositories 2>/dev/null || true ;;
    *)     echo "(repository info: unknown pkg manager)";;
  esac
}

section_pkgs() {
  line "PACKAGES"
  case "$_pkgmgr" in
    apt)
      PKG_TOTAL=$(dpkg -l 2>/dev/null | awk '/^ii/{n++} END{print n+0}')
      echo "Total (dpkg -l ^ii): $PKG_TOTAL"
      echo "RECENTLY INSTALLED (last $DAYS days):"
      if [[ -f /var/log/dpkg.log ]]; then
        awk -v d="$DAYS" -v FS=' ' '
          BEGIN{cmd="date +%s"; cmd | getline now; close(cmd)}
          {if ($3=="install") print $0}
        ' /var/log/dpkg.log | tail -n 50 | sed 's/^/  /'
      else
        echo "  (no /var/log/dpkg.log)"
      fi
      ;;
    dnf|yum)
      PKG_TOTAL=$(rpm -qa 2>/dev/null | wc -l | awk '{print $1+0}')
      echo "Total (rpm -qa): $PKG_TOTAL"
      echo "RECENTLY INSTALLED (last $DAYS days):"
      if command -v rpm >/dev/null 2>&1; then
        rpm -qa --last 2>/dev/null | head -n 50 | sed 's/^/  /'
      fi
      ;;
    zypper|pacman|apk)
      echo "(package listing minimal for $_pkgmgr)"
      ;;
    *)
      echo "(unknown package manager)"
      ;;
  esac
}

section_services() {
  line "SERVICES (systemd)"
  if command -v systemctl >/dev/null 2>&1; then
    echo "- RUNNING:"
    tmo 5s systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | awk '{print "  "$1}' || true
    echo "- ENABLED:"
    tmo 5s systemctl list-unit-files --type=service --state=enabled --no-legend 2>/dev/null | awk '{print "  "$1}' || true
    echo "- FAILED:"
    FAILED_SVC=$(tmo 5s systemctl --failed --no-legend --type=service 2>/dev/null | wc -l | awk '{print $1+0}')
    tmo 5s systemctl --failed --no-legend --type=service 2>/dev/null | sed 's/^/  /' || true
  else
    echo "(systemctl not available)"
  fi
}

section_ports() {
  line "LISTENING PORTS"
  if command -v ss >/dev/null 2>&1; then
    LISTEN_CNT=$(tmo 5s ss -lntuH 2>/dev/null | wc -l | awk '{print $1+0}')
    tmo 5s ss -lntup 2>/dev/null || true
  elif command -v netstat >/dev/null 2>&1; then
    LISTEN_CNT=$(tmo 5s netstat -lntu 2>/dev/null | tail -n +3 | wc -l | awk '{print $1+0}')
    tmo 5s netstat -lntup 2>/dev/null || true
  else
    echo "(ss/netstat tidak ada)"
  fi
}

section_fs() {
  line "DISKS & FILESYSTEMS"
  command -v lsblk >/dev/null 2>&1 && lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE | sed 's/^/  /' || true
  df -hT | sed 's/^/  /'
}

section_net() {
  line "NETWORK"
  if command -v ip >/dev/null 2>&1; then
    ip -br addr 2>/dev/null | sed 's/^/  /' || true
    echo "ROUTES:"
    ip route 2>/dev/null | sed 's/^/  /' || true
  fi
  echo "RESOLVERS:"
  { grep -E '^(nameserver|search)' /etc/resolv.conf 2>/dev/null || true; } | sed 's/^/  /'
}

section_containers() {
  line "CONTAINER RUNTIMES"
  if command -v docker >/dev/null 2>&1; then
    echo "- docker ps:"
    tmo 5s docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}' || true
  fi
  if command -v podman >/dev/null 2>&1; then
    echo "- podman ps:"
    tmo 5s podman ps --format 'table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}' || true
  fi
}

section_monitoring() {
  line "MONITORING STACK CHECK"
  for svc in prometheus grafana-server grafana node_exporter; do
    if command -v systemctl >/dev/null 2>&1; then
      systemctl is-active --quiet "$svc" 2>/dev/null && echo "  $svc: active" || echo "  $svc: not active"
    fi
    command -v "$svc" >/dev/null 2>&1 && echo "  bin:$svc present" || echo "  bin:$svc missing"
  done
}

section_security() {
  line "SECURITY"
  case "$_pkgmgr" in
    apt)
      SEC_UPD=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l | awk '{print $1+0}')
      echo "Security updates available: $SEC_UPD"
      [[ -f /var/run/reboot-required ]] && { echo "REBOOT REQUIRED: yes"; REBOOT_NEEDED=1; } || echo "REBOOT REQUIRED: no"
      ;;
    dnf)
      if command -v dnf >/dev/null 2>&1; then
        S=$(dnf -q updateinfo --security list updates 2>/dev/null | grep -c ' \S')
        SEC_UPD=$(( S + 0 ))
        echo "Security updates available: $SEC_UPD"
      fi
      if command -v needs-restarting >/dev/null 2>&1; then
        if needs-restarting -r >/dev/null 2>&1; then
          echo "REBOOT REQUIRED: yes"; REBOOT_NEEDED=1
        else
          echo "REBOOT REQUIRED: no"
        fi
      fi
      ;;
    yum)
      S=$(yum -q --security updateinfo list updates 2>/dev/null | grep -c ' \S')
      SEC_UPD=$(( S + 0 ))
      echo "Security updates available: $SEC_UPD"
      if command -v needs-restarting >/dev/null 2>&1; then
        if needs-restarting -r >/dev/null 2>&1; then
          echo "REBOOT REQUIRED: yes"; REBOOT_NEEDED=1
        else
          echo "REBOOT REQUIRED: no"
        fi
      fi
      ;;
    *) echo "(security check minimal for $_pkgmgr)";;
  esac
}

# ---- JSON summary ----
emit_json() {
  local jhost="$HOST"
  if (( REDACT )); then
    jhost="host-$(printf %s "$HOST" | sha256sum | cut -c1-8)"
  fi

  case "$_pkgmgr" in
    apt)   PKG_TOTAL=$(dpkg -l 2>/dev/null | awk '/^ii/{n++} END{print n+0}') ;;
    dnf|yum) PKG_TOTAL=$(rpm -qa 2>/dev/null | wc -l | awk '{print $1+0}') ;;
    *)     PKG_TOTAL=0 ;;
  esac

  if command -v systemctl >/dev/null 2>&1; then
    FAILED_SVC=$(systemctl --failed --no-legend --type=service 2>/dev/null | wc -l | awk '{print $1+0}')
  fi

  if command -v ss >/dev/null 2>&1; then
    LISTEN_CNT=$(ss -lntuH 2>/dev/null | wc -l | awk '{print $1+0}')
  elif command -v netstat >/dev/null 2>&1; then
    LISTEN_CNT=$(netstat -lntu 2>/dev/null | tail -n +3 | wc -l | awk '{print $1+0}')
  fi

  if (( SEC_UPD == 0 && REBOOT_NEEDED == 0 )); then
    section_security >/dev/null || true
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg host "$jhost" \
      --arg os "$OS_PRETTY" \
      --arg kernel "$KERNEL" \
      --arg pkgmgr "$_pkgmgr" \
      --argjson pkgs "$PKG_TOTAL" \
      --argjson failed "$FAILED_SVC" \
      --argjson listening "$LISTEN_CNT" \
      --argjson secupd "$SEC_UPD" \
      --argjson reboot "$REBOOT_NEEDED" \
      --argjson days "$DAYS" \
      '{host:$host, os:$os, kernel:$kernel, pkgmgr:$pkgmgr,
        packages_total:$pkgs, services_failed:$failed, ports_listening:$listening,
        security_updates:$secupd, reboot_required:($reboot==1),
        since_days:$days}'
  else
    printf '{"host":"%s","os":"%s","kernel":"%s","pkgmgr":"%s","packages_total":%s,"services_failed":%s,"ports_listening":%s,"security_updates":%s,"reboot_required":%s,"since_days":%s}\n' \
      "$jhost" "$OS_PRETTY" "$KERNEL" "$_pkgmgr" "$PKG_TOTAL" "$FAILED_SVC" "$LISTEN_CNT" "$SEC_UPD" "$REBOOT_NEEDED" "$DAYS"
  fi
}

# ---- main ----
main() {
  # warning: sebagian fitur butuh root
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "WARNING: jalankan sebagai root/sudo untuk hasil lengkap (services/ports/repos)." >&2
  fi

  # validasi sections
  validate_sections

  if (( JSON == 1 )); then
    if [[ -n "$OUT" ]]; then
      mkdir -p "$(dirname "$OUT")"
      emit_json >"$OUT"
      printf "Wrote JSON to %s\n" "$OUT" >&2
    else
      emit_json
    fi
    exit 0
  fi

  # Text mode
  if [[ -z "$OUT" ]]; then
    OUT="/var/tmp/inventory_${HOST}_$(date +%Y%m%dT%H%M%S).txt"
  fi
  echo "OUT: $OUT"
  mkdir -p "$(dirname "$OUT")"
  exec > >(tee -a "$OUT") 2>&1

  in_sections system && section_system || true
  in_sections repos && section_repos || true
  in_sections pkgs && section_pkgs || true
  in_sections services && section_services || true
  in_sections ports && section_ports || true
  in_sections fs && section_fs || true
  in_sections net && section_net || true
  in_sections containers && section_containers || true
  in_sections monitoring && section_monitoring || true
  in_sections security && section_security || true

  echo
  echo "# Done."
}

main "$@"
