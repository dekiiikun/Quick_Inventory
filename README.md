# quick_inventory

Automation agent to collect a quick server inventory: OS info, repos, package counts, recent installs, service states, listening ports, disks/FS, network, and common monitoring stack checks.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![Shell](https://img.shields.io/badge/language-shell-lightgrey)

---

## Table of Contents
- [Features](#features)
- [Requirements](#requirements)
- [Install](#install)
- [Usage](#usage)
- [Output](#output)
- [Notes](#notes)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [License](#license)
- [Contributing](#contributing)

## Features
- Works on RHEL/CentOS/Fedora (dnf/yum) and Debian/Ubuntu (apt/dpkg)
- Mirrors output to both screen and file (`/var/tmp/inventory_<host>_<ts>.txt`)
- Stable output (`LANG=C`), safe fallbacks (`|| true`), and bounded sections
- Checks services, ports, containers, disks/FS, network, and monitoring stack (Prometheus/Grafana/node_exporter)

## Requirements
- **RHEL/CentOS/Fedora**: `dnf` (opsional: `dnf-plugins-core` untuk `repoquery`)
- **Debian/Ubuntu**: standar `apt/dpkg` (opsional: `tasksel`)
- `systemd` tools (`systemctl`, `timedatectl`) untuk bagian service/timezone

## Install
```bash
sudo install -m 0755 quick_inventory.sh /usr/local/sbin/quick_inventory
