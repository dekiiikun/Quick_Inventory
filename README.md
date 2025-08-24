# quick_inventory

Automation agent to collect a quick server inventory: OS info, repos, package counts, recent installs, service states, listening ports, disks/FS, network, and common monitoring stack checks.


[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![Shell](https://img.shields.io/badge/language-shell-lightgrey)

> Full docs: [Summary.md](./Summary.md)

---

## Table of Contents

* [Features](#features)
* [Requirements](#requirements)
* [Install](#install)
* [Usage](#usage)
* [Output](#output)
* [Notes](#notes)
* [Troubleshooting](#troubleshooting)
* [Uninstall](#uninstall)
* [License](#license)
* [Contributing](#contributing)
* [Summary (full docs)](./Summary.md)

## Features

* Works on RHEL/CentOS/Fedora (dnf/yum) and Debian/Ubuntu (apt/dpkg)
* Mirrors output to both screen and file (`/var/tmp/inventory_<host>_<ts>.txt`)
* Stable output (`LANG=C`), safe fallbacks (`|| true`), and bounded sections
* Checks services, ports, containers, disks/FS, network, and monitoring stack (Prometheus/Grafana/node\_exporter)

## Requirements

* **RHEL/CentOS/Fedora**: `dnf` (opsional: `dnf-plugins-core` untuk `repoquery`)
* **Debian/Ubuntu**: standar `apt/dpkg` (opsional: `tasksel`)
* `systemd` tools (`systemctl`, `timedatectl`) untuk bagian service/timezone

## Install

```bash
sudo install -m 0755 quick_inventory.sh /usr/local/sbin/quick_inventory
```

## Usage

```bash
sudo /usr/local/sbin/quick_inventory
```

The script prints to screen and also writes a copy to **OUT** (lihat baris pertama output).

## Output

Bagian utama yang dihasilkan:

* **SYSTEM** — OS, kernel, hostname, waktu
* **REPOSITORIES** — daftar repo aktif (dnf/yum/apt)
* **PACKAGE COUNTS** — jumlah paket (rpm/deb)
* **USER-INSTALLED PACKAGES** — paket manual (jika tool tersedia)
* **RECENTLY INSTALLED** — 20 instalasi terakhir
* **INSTALLED GROUPS / TASKS** — grup/taskset terpasang
* **SERVICES RUNNING / ENABLED / FAILED** — status layanan via `systemctl`
* **LISTENING PORTS** — port TCP/UDP yang listen
* **DISKS & FILESYSTEMS** — `lsblk`, `df -hT`
* **NETWORK** — IP singkat + route + resolver
* **CONTAINER RUNTIMES** — docker/podman & container aktif
* **MONITORING STACK CHECK** — prom/grafana/node\_exporter

## Notes

* Pastikan line endings **LF**, bukan CRLF. Tambahkan `.gitattributes` di bawah bila perlu.
* SPDX header sudah disertakan: `# SPDX-License-Identifier: MIT`.

### `.gitattributes`

```gitattributes
# Enforce LF for shell scripts
*.sh text eol=lf
```

## Troubleshooting

* **`bash\r: bad interpreter`** → file masih CRLF. Ubah ke LF atau jalankan `dos2unix quick_inventory.sh`.
* **`ss: command not found`** → install paket iproute2/iproute atau gunakan fallback `netstat`.
* **Bagian layanan kosong** → host tidak memakai `systemd` atau `systemctl` tidak tersedia.

## Uninstall

```bash
sudo rm -f /usr/local/sbin/quick_inventory
```

## License

MIT — see [LICENSE](./LICENSE).

## Contributing

PR welcome. Silakan buka issue/PR untuk perbaikan atau fitur (misalnya mode `--json`, flags untuk memilih section).
