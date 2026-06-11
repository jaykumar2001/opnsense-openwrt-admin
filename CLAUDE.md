# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

OPNsense plugin for managing a fleet of OpenWrt access points and routers from a central firewall UI. The plugin consists of a Python broker daemon, PHP MVC frontend (OPNsense framework), and a SQLite database for state.

## Architecture

```
OPNsense web UI (PHP/Volt views)
  └─ REST API (PHP controllers under Api/)
       └─ BrokerClient (PHP) → HTTP localhost:9783 → broker daemon (Python)
                                                         └─ SSH → OpenWrt routers
```

**Broker** (`src/opnsense/scripts/OPNsense/OpenWrtAdmin/broker.py`): Single-file Python daemon (~1700 lines). Polls routers via SSH, stores state in SQLite (`/var/db/openwrt-admin/state.sqlite`), exposes a localhost-only HTTP API on port 9783. Key classes: `BrokerState` (DB + config), `BrokerHandler` (HTTP endpoints), `BrokerDaemon` (lifecycle). No external Python dependencies — stdlib only.

**PHP layer** follows OPNsense MVC conventions:
- **Controllers**: `Api/GeneralController` (model CRUD), `Api/ServiceController` (broker proxy + actions), `Api/SettingsController` (SSH keys). Page controllers render Volt templates.
- **Library**: `BrokerClient` (HTTP client to broker), `Logger` (syslog wrapper), `DhcpHelper` (reads DHCP leases from config.xml).
- **Model**: `OpenWrtAdmin.xml` defines settings and router inventory fields. `ACL.xml` and `Menu.xml` wire up permissions and navigation.

**configd** glues the PHP UI to the daemon via `actions_openwrtadmin.conf` (start/stop/restart/status/poll-now).

## Commands

```sh
# Run broker unit tests (stdlib unittest, no dependencies)
make test
# or directly:
python3 -m unittest discover -s tests -p 'test_*.py'

# Run a single test class or method
python3 -m unittest tests.test_broker.BrokerStateTestCase
python3 -m unittest tests.test_broker.BrokerStateTestCase.test_some_method

# Deploy to a live OPNsense firewall (copies files, restarts services)
scripts/deploy-dev.sh <ssh-host>

# Lint check (no linter configured — use python3 -m py_compile for syntax)
python3 -m py_compile src/opnsense/scripts/OPNsense/OpenWrtAdmin/broker.py
```

## Testing

Tests live in `tests/test_broker.py`. The broker module is loaded dynamically via `importlib` (not a package import) because it's a standalone script, not an installable module. Tests use `tempfile.TemporaryDirectory` for isolated SQLite state — no real SSH or network calls. The `BrokerState` constructor accepts `data_dir` and `config_xml_path` overrides specifically for test isolation.

## Development Notes

- The broker is a single `.py` file with zero third-party dependencies. It runs on the Python 3 bundled with FreeBSD/OPNsense.
- PHP code targets the OPNsense framework (Phalcon-based). Controllers extend `ApiMutableModelControllerBase` or `ApiControllerBase`.
- The deploy script has two modes: SSHFS mount path (fast, direct copy) or SCP fallback. It also lint-checks PHP and Python files on the target, then restarts configd and the broker.
- Config syncs (Wi-Fi, system, firewall, DHCP, rpcd) push UCI config from a source router to targets via SSH. Wi-Fi sync includes a verification window with rollback on failure.
- The broker reads tuning parameters from OPNsense's `/conf/config.xml` at startup.
