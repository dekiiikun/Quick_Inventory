# quick_inventory
Automation agent to collect a quick server inventory: OS info, repos, package counts, recent installs, service states, listening ports, disks/FS, network, and common monitoring stack checks.


## Features
- Works on RHEL/CentOS/Fedora (dnf/yum) and Debian/Ubuntu (apt/dpkg)
- Mirrors output to both screen and file (`/var/tmp/inventory_<host>_<ts>.txt`)
- Stable output (`LANG=C`), safe fallbacks (`|| true`), and bounded sections


## Requirements
- RHEL/CentOS/Fedora: `dnf` (optional: `dnf-plugins-core` for `repoquery`)
- Debian/Ubuntu: standard `apt/dpkg` (optional: `tasksel`)


## Install
```bash
sudo install -m 0755 quick_inventory.sh /usr/local/sbin/quick_inventory
