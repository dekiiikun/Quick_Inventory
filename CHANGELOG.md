# CHANGELOG.md (final)

```md
# Changelog
Semua perubahan penting pada proyek ini akan didokumentasikan di file ini.
Format mengikuti [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
dan versi mengikuti [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2025-08-25
### Added
- **CLI flags**: `--json`, `--out FILE`, `--days N`, `--sections LIST`, `--redact`, `--version`, `--help`.
- **JSON summary** untuk integrasi ke SIEM/ELK/Loki.
- **Security delta**: hitung jumlah security updates & status reboot-required (apt/dnf/yum).
- **Systemd**: `contrib/systemd/quick-inventory.service` & `.timer` untuk snapshot JSON harian.
- **Makefile**: target `install`, `install-systemd`, `enable-timer`, `uninstall-*`, `lint`, `fmt`, `test`.
- **CI**: GitHub Actions dengan ShellCheck (pinned `@2.0.0`) + `shfmt` (advisory).

### Changed
- Stabilkan output (`LANG=C`), tambah timeout wrapper, dan fallback commands.
- Selector section: jalankan hanya bagian yang dipilih via `--sections`.
- README: tambah Install via Makefile & Systemd, usage, dan panduan CI.

### Fixed
- Typo redirection pada cek `podman` (`/div/null` → `/dev/null`).
- Perbaikan minor hasil lint.

### Security
- Opsi `--redact` untuk anonimisasi host/IP pada output JSON (hash pendek).

## [0.2.0] - 2025-08-24
### Added
- Rilis dasar `quick_inventory.sh`: SYSTEM, REPOSITORIES, PACKAGE COUNTS,
  RECENTLY INSTALLED, SERVICES, PORTS, DISKS/FS, NETWORK, CONTAINER RUNTIMES,
  MONITORING STACK CHECK. Mirror output ke layar & file `/var/tmp`.

[Unreleased]: https://github.com/dekiiikun/Quick_Inventory/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/dekiiikun/Quick_Inventory/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/dekiiikun/Quick_Inventory/tree/v0.2.0
```

---

# README.md patches

## 1) Tambahkan badge "Release" di bagian atas (di bawah badge License/Shell/Lint)

```md
![Release](https://img.shields.io/github/v/release/dekiiikun/Quick_Inventory?sort=semver)
```

> Letakkan tepat setelah baris badge **Lint** agar tampil berurutan.

## 2) Tambahkan section "Changelog" di dekat bagian bawah README

Tambahkan ke **Table of Contents**:

```md
* [Changelog](#changelog)
```

Lalu tambahkan section ini (letakkan sebelum **License** atau setelah **Contributing**):

```md
## Changelog
Lihat riwayat perubahan di [CHANGELOG.md](./CHANGELOG.md).
```

---

# Catatan rilis (opsional; untuk GitHub Release v0.3.0)

```md
**Quick_Inventory v0.3.0**

### Added
- CLI flags: `--json`, `--out`, `--days`, `--sections`, `--redact`, `--version`, `--help`.
- JSON summary untuk integrasi SIEM/ELK/Loki.
- Security delta: hitung security updates & status reboot-required (apt/dnf/yum).
- Systemd unit & timer: snapshot JSON harian (`contrib/systemd/`).
- Makefile: `install`, `install-systemd`, `enable-timer`, `uninstall-*`, `lint`, `fmt`, `test`.
- CI: ShellCheck (pinned `@2.0.0`) + shfmt (advisory).

### Changed
- Output distabilkan (`LANG=C`), timeout wrapper, dan fallback commands.
- Selector section via `--sections`.
- README diperbarui (Install, Systemd, Usage, CI).

### Fixed
- Typo redirection pada cek `podman`.
- Perbaikan minor hasil lint.

### Security
- Opsi `--redact` untuk anonimisasi host/IP pada output JSON.
```

---

# Cara pakai ringkas

1. Buat file baru **CHANGELOG.md** di root repo → copy blok di atas (bagian pertama).
2. Update **README.md**: tambahkan badge Release + TOC + section *Changelog* sesuai patch.
3. Buat tag & rilis:

```bash
git tag v0.3.0
git push --tags
```

4. Di GitHub → **Releases** → *Draft a new release* → pilih tag `v0.3.0` → paste "Catatan rilis".
