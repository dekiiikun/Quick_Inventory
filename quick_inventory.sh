#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Dekiiikun
# Licensed under the MIT License. See the LICENSE file for details.


set -euo pipefail
export LANG=C LC_ALL=C


have() { command -v "$1" >/dev/null 2>&1; }


OUT="/var/tmp/inventory_${HOSTNAME}_$(date +%F_%H%M%S).txt"
mkdir -p "$(dirname "$OUT")"
# Mirror all output to screen + file
exec > >(tee -a "$OUT") 2>&1


echo "Output file: $OUT"


distro_id="unknown"
if [ -r /etc/os-release ]; then
. /etc/os-release
distro_id="$ID"
fi


sep(){ printf '\n==== %s ====\n' "$1"; }


# ===== SYSTEM =====
sep "SYSTEM"
[ -f /etc/os-release ] && head -n 6 /etc/os-release || true
uname -r || true


echo
hostnamectl || true


echo
timedatectl || true


# ===== REPOSITORIES =====
sep "REPOSITORIES"
if have dnf; then
dnf repolist -v 2>/dev/null || dnf repolist 2>/dev/null || true
elif have yum; then
yum repolist -v 2>/dev/null || yum repolist 2>/dev/null || true
elif have apt; then
grep -hE "^[[:space:]]*deb " /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null | sed 's/#.*//' || true
fi


# ===== PACKAGE COUNTS =====
sep "PACKAGE COUNTS"
if have rpm; then
echo -n "Total RPM packages: "; rpm -qa 2>/dev/null | wc -l || true
elif have dpkg; then
echo -n "Total DEB packages: "; dpkg -l 2>/dev/null | awk '/^ii/{n++} END{print n+0}' || true
fi


# ===== USER-INSTALLED PACKAGES =====
sep "USER-INSTALLED PACKAGES"
if have dnf && dnf repoquery --help >/dev/null 2>&1; then
dnf -q repoquery --userinstalled --qf '%{name}-%{version}-%{release}.%{arch}' 2>/dev/null | sort | head -n 500 || true
elif have yum && have repoquery; then
repoquery --userinstalled --qf '%{name}-%{version}-%{release}.%{arch}' 2>/dev/null | sort | head -n 500 || true
elif have apt-mark; then
apt-mark showmanual 2>/dev/null | sort | head -n 500 || true
else
echo "(repoquery/apt-mark tidak tersedia; lewati bagian ini)"
fi


# ===== RECENTLY INSTALLED (last 20) =====
sep "RECENTLY INSTALLED (last 20)"
if have rpm; then
rpm -qa --last 2>/dev/null | head -n 20 || true
elif [ -f /var/log/dpkg.log ] || ls /var/log/dpkg.log* >/dev/null 2>&1; then
zgrep -h " install " /var/log/dpkg.log* 2>/dev/null | tail -n 20 || true
fi


# ===== INSTALLED GROUPS / TASKS =====
sep "INSTALLED GROUPS / TASKS"
if have dnf; then
dnf -q group list --installed 2>/dev/null || true
elif have yum; then
yum -q group list installed 2>/dev/null || true
elif have tasksel; then
tasksel --list-tasks 2>/dev/null || true
fi


# ===== SERVICES RUNNING =====
sep "SERVICES RUNNING"
if have systemctl; then
systemctl list-units --type=service --state=running --no-legend --plain 2>/dev/null \
echo "Inventory written to: $OUT"
