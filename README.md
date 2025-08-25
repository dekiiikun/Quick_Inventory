# quick\_inventory

Automation agent to collect a quick server inventory: OS info, repos, package counts, recent installs, service states, listening ports, disks/FS, network, and common monitoring stack checks.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![Shell](https://img.shields.io/badge/language-shell-lightgrey)
![Lint](https://github.com/dekiiikun/Quick_Inventory/actions/workflows/lint.yml/badge.svg)
![Test](https://github.com/dekiiikun/Quick_Inventory/actions/workflows/test.yml/badge.svg)
![Release](https://img.shields.io/github/v/release/dekiiikun/Quick_Inventory?sort=semver)
![Release](https://img.shields.io/github/v/tag/dekiiikun/Quick_Inventory?sort=semver)
![Linux](https://img.shields.io/badge/OS-Linux-informational?logo=linux)
![Debian/Ubuntu](https://img.shields.io/badge/apt%2Fdpkg-Debian%2FUbuntu-A81D33?logo=debian&logoColor=white)
![RHEL/CentOS/Fedora](https://img.shields.io/badge/dnf%2Fyum-RHEL%2FCentOS%2FFedora-EE0000?logo=redhat&logoColor=white)
![openSUSE](https://img.shields.io/badge/zypper-openSUSE-73BA25?logo=opensuse&logoColor=white)
![Arch](https://img.shields.io/badge/pacman-Arch-1793D1?logo=archlinux&logoColor=white)
![Alpine](https://img.shields.io/badge/apk-Alpine-0D597F?logo=alpinelinux&logoColor=white)

### Supported / Tested
| Distro family | Package manager | Status |
|---|---|---|
| Debian / Ubuntu | `apt` / `dpkg` | ✅ Tested |
| RHEL / CentOS / Fedora | `dnf` / `yum` | ✅ Tested |
| openSUSE | `zypper` | 🟡 Minimal |
| Arch Linux | `pacman` | 🟡 Minimal |
| Alpine | `apk` | 🟡 Minimal |


> Full docs: [Summary.md](./Summary.md)

---

## Table of Contents

* [Features](#features)
* [Requirements](#requirements)
* [Install](#install)
* [Usage](#usage)
* [Systemd (optional)](#systemd-optional)
* [Output](#output)
* [CI / Lint & Format](#ci--lint--format)
* [Notes](#notes)
* [Troubleshooting](#troubleshooting)
* [Uninstall](#uninstall)
* [License](#license)
* [Changelog](#changelog)
* [Contributing](#contributing)
* [Summary (full docs)](./Summary.md)

## Features

* Works on RHEL/CentOS/Fedora (dnf/yum) and Debian/Ubuntu (apt/dpkg)
* Mirrors output to both screen and file (`/var/tmp/inventory_<host>_<ts>.txt`)
* Stable output (`LANG=C`), safe fallbacks (`|| true`), bounded sections
* Checks services, ports, containers, disks/FS, network, and monitoring stack (Prometheus/Grafana/node\_exporter)
* **JSON mode**: `--json` + `--out FILE` + `--days N` + `--sections LIST` + `--redact`
* **Security delta**: jumlah security updates & info reboot-required (apt/dnf/yum)

## Requirements

* **RHEL/CentOS/Fedora**: `dnf`/`yum` (opsional: `dnf-plugins-core`)
* **Debian/Ubuntu**: standar `apt/dpkg`
* `systemd` tools (`systemctl`, `timedatectl`) untuk bagian service/timezone
* **Disarankan**: `iproute2` (`ss`, `ip`), `jq` (untuk memproses JSON)

## Install

### Opsi A — via Makefile (disarankan)

```bash
# pasang binari
sudo make install

# pasang unit service+timer systemd
sudo make install-systemd
sudo make enable-timer
```

Cek:

```bash
systemctl list-timers | grep quick-inventory
journalctl -u quick-inventory.service --since today
```

### Opsi B — manual (tanpa Makefile)

```bash
sudo install -m 0755 quick_inventory.sh /usr/local/sbin/quick_inventory
sudo install -m 0644 contrib/systemd/quick-inventory.service /etc/systemd/system/
sudo install -m 0644 contrib/systemd/quick-inventory.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now quick-inventory.timer
```

## Usage

### CLI Flags

```
--json           Keluarkan ringkasan JSON (tanpa output teks)
--out FILE       Tulis output ke FILE (default: /var/tmp/*.txt pada text mode)
--days N         Batas hari untuk daftar instalasi terbaru (default: 20)
--sections LIST  Comma-separated: system,repos,pkgs,services,ports,fs,net,containers,monitoring,security
--redact         Anonimasi host/IP pada JSON (hash pendek)
--version        Tampilkan versi
--help           Bantuan
```

### Contoh pemakaian

```bash
# Text mode, mirror ke layar + simpan ke /var/tmp
sudo quick_inventory

# Pilih section + perbesar horizon hari
sudo quick_inventory --sections system,services,security --days 30

# JSON ringkas (untuk SIEM/ELK/Loki)
sudo quick_inventory --json | jq .

# JSON dengan redaksi (aman untuk dibagikan)
sudo quick_inventory --json --redact --out /var/log/quick_inventory/$(hostname)-$(date +%Y%m%dT%H%M%S).json
```

## Systemd (optional)

Unit tersedia di `contrib/systemd/`.

**Jalankan harian otomatis** (melalui timer):

```bash
sudo make install-systemd
sudo make enable-timer
```

Atau manual seperti pada bagian **Install (Opsi B)**.

Log & verifikasi:

```bash
systemctl list-timers | grep quick-inventory
journalctl -u quick-inventory.service --since today
```

> Service akan menulis snapshot JSON ke `/var/log/quick_inventory/` dengan pola nama: `%H-%Y%m%dT%H%M%S.json`.

> **Security defaults**
> Unit systemd memakai `UMask=0027` dan membuat folder log
> `/var/log/quick_inventory` dengan permission `0750` (root + group).
> Artinya file JSON akan dibuat dengan mode efektif `0640` (tidak world-readable).
> Jika tim lain perlu membaca log:
>
> * tambahkan user ke group yang sama dengan service (`Group=` pada unit), atau
> * ubah `Group=` dan/atau mode di unit sesuai kebijakan (lihat `contrib/systemd/quick-inventory.service`), lalu `systemctl daemon-reload`.

## Output

### Text mode (section yang dicetak)

* **SYSTEM** — OS, kernel, hostname, waktu
* **REPOSITORIES** — daftar repo aktif (dnf/yum/apt)
* **PACKAGE COUNTS** — jumlah paket (rpm/deb)
* **USER-INSTALLED PACKAGES** — paket manual (jika tool tersedia)
* **RECENTLY INSTALLED** — instalasi terbaru
* **INSTALLED GROUPS / TASKS** — grup/taskset terpasang
* **SERVICES RUNNING / ENABLED / FAILED** — status layanan via `systemctl`
* **LISTENING PORTS** — port TCP/UDP yang listen
* **DISKS & FILESYSTEMS** — `lsblk`, `df -hT`
* **NETWORK** — IP singkat + route + resolver
* **CONTAINER RUNTIMES** — docker/podman & container aktif
* **MONITORING STACK CHECK** — prom/grafana/node\_exporter
* **SECURITY** — security updates & reboot-required

### Example output (text)

```
===== SYSTEM =====
Host: web-01
OS  : Ubuntu 22.04.5 LTS
Kernel: 6.8.0-40-generic
Uptime(s): 123456

===== SERVICES (systemd) =====
- RUNNING:
  ssh.service
  cron.service
- ENABLED:
  ssh.service
- FAILED:
  (none)

===== LISTENING PORTS =====
Netid State  Local Address:Port  Peer Address:Port  Process
tcp   LISTEN 0.0.0.0:22          0.0.0.0:*        users:(("sshd",pid=123,fd=3))
```

### JSON fields

`host`, `os`, `kernel`, `pkgmgr`, `packages_total`, `services_failed`, `ports_listening`, `security_updates`, `reboot_required`, `since_days`.

### Example output (JSON)

```json
{"host":"host-1a2b3c4d","os":"Ubuntu 22.04.5 LTS","kernel":"6.8.0-40-generic","pkgmgr":"apt","packages_total":412,"services_failed":0,"ports_listening":7,"security_updates":2,"reboot_required":false,"since_days":20}
```

## CI / Lint & Format

Workflow **Lint** menggunakan ShellCheck dan shfmt.

* Status badge di atas menggunakan `actions/workflows/lint.yml`.
* Konfigurasi: `.github/workflows/lint.yml` (ShellCheck `severity: error`, `check_together: yes`).
* Jalankan lint lokal (opsional):

```bash
shellcheck -x quick_inventory.sh
shfmt -d -i 2 -bn -ci quick_inventory.sh
# auto-format
shfmt -w -i 2 -bn -ci quick_inventory.sh
```

## Notes

* Jalankan dengan **sudo/root** agar bagian services/ports/repos lengkap. Jika tidak, skrip akan menampilkan peringatan dan tetap berjalan dengan data terbatas.
* End-of-line: repo menyertakan `.gitattributes` untuk memaksa **LF** pada file `.sh`.
* Jika muncul `bash\r: bad interpreter`, ubah line endings ke LF atau jalankan `dos2unix quick_inventory.sh`.
* Jika `ss` tidak ada, instal `iproute2` (Debian/Ubuntu) atau gunakan fallback `netstat`.
* SPDX header: `# SPDX-License-Identifier: MIT`.

## Troubleshooting

* **`ERROR: unknown section(s)`** → nilai `--sections` tidak valid. Daftar yang valid: `system, repos, pkgs, services, ports, fs, net, containers, monitoring, security, all`.
* **`bash\r: bad interpreter`** → file masih CRLF. Ubah ke LF atau jalankan `dos2unix quick_inventory.sh`.
* **`ss: command not found`** → install paket `iproute2` atau gunakan `netstat`.
* **Bagian layanan kosong** → host tidak memakai `systemd` atau `systemctl` tidak tersedia.

## Uninstall

```bash
# hentikan timer & hapus unit
sudo make disable-timer
sudo make uninstall-systemd

# hapus binari
sudo make uninstall
```

## License

MIT — see [LICENSE](./LICENSE).

## Changelog

Lihat riwayat perubahan di [CHANGELOG.md](./CHANGELOG.md).

## Contributing

PR welcome. Gunakan gaya commit **Conventional Commits** (`feat:`, `fix:`, `docs:`). Fitur yang disarankan: penambahan section/plugins, dukungan distro tambahan, atau integrasi output JSON ke pipeline.

[↑ back to top](#table-of-contents)
