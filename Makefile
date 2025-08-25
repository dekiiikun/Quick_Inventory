# Makefile for Quick_Inventory
# Usage:
#   sudo make            # tampilkan bantuan
#   sudo make install
#   sudo make install-systemd enable-timer
#   sudo make disable-timer uninstall-systemd uninstall

.DEFAULT_GOAL := help
SHELL := /bin/sh

PREFIX  ?= /usr/local
BINDIR  ?= $(PREFIX)/sbin
UNITDIR ?= /etc/systemd/system

SCRIPT := quick_inventory.sh
TARGET := quick_inventory

.PHONY: help install uninstall install-systemd uninstall-systemd enable-timer disable-timer lint fmt test

help:
	@echo "Targets: install | uninstall | install-systemd | uninstall-systemd | enable-timer | disable-timer | lint | fmt | test"

install:
	install -m 0755 $(SCRIPT) $(BINDIR)/$(TARGET)

uninstall:
	rm -f $(BINDIR)/$(TARGET)

install-systemd:
	install -d -m 0755 /var/log/quick_inventory
	install -m 0644 contrib/systemd/quick-inventory.service $(UNITDIR)/
	install -m 0644 contrib/systemd/quick-inventory.timer $(UNITDIR)/
	systemctl daemon-reload

uninstall-systemd:
	- systemctl disable --now quick-inventory.timer
	rm -f $(UNITDIR)/quick-inventory.service $(UNITDIR)/quick-inventory.timer
	systemctl daemon-reload

enable-timer:
	systemctl enable --now quick-inventory.timer

disable-timer:
	- systemctl disable --now quick-inventory.timer

lint:
	@command -v shellcheck >/dev/null 2>&1 && shellcheck -x $(SCRIPT) || echo "shellcheck not installed; skipping"

fmt:
	@command -v shfmt >/dev/null 2>&1 && shfmt -w -i 2 -bn -ci $(SCRIPT) || echo "shfmt not installed; skipping"

test:
	$(BINDIR)/$(TARGET) --json --sections system,services,security --days 1 | head -n 1
