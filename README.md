# Open Design Linux (RPM + DEB)

Automated RPM and DEB builds of [nexu-io/open-design](https://github.com/nexu-io/open-design)
for x86_64 Linux.

We only build the RPM and DEB packages. If you are looking for an AppImage,
the upstream fork still publishes one:
[`AppImage` release](https://github.com/pourmirzai/open-design-linux/releases/tag/linux-latest)

A GitHub Actions workflow fetches the upstream source (the pinned
`open-design-v0.27.0` tag by default, or any tag/branch you pick), assembles
the app with the upstream packaging recipe (`tools-pack linux build --portable
--to dir --containerized --require-vela-cli`), and packages that tree with
electron-builder's rpm and deb targets. Each build is published as a release
tagged `v<VERSION>` (e.g. [`v0.27.0`](https://github.com/pixel3design-hub/open-design-linux/releases/tag/v0.27.0));
`releases/latest` always points at the newest one.

> **Pinned to upstream 0.27.0.** Pass `upstream_ref` on a manual run to build
> something else. A newer pin needs
> `patches/open-design-linux-pack.patch` regenerated (it applies with
> `git apply --check` on the pristine upstream tag).

The Vela CLI is bundled (`--require-vela-cli` makes it a hard requirement), so
cloud login works out of the box — no system-wide `vela` install needed.

## Install

Download the package for your distro from the
[latest release](https://github.com/pixel3design-hub/open-design-linux/releases/latest)
and install it:

```bash
# Debian / Ubuntu
sudo apt install ./Open-Design-linux-x64.deb

# Fedora / RHEL family
sudo dnf install ./Open-Design-linux-x64.rpm

# openSUSE
sudo zypper install ./Open-Design-linux-x64.rpm
```

Or straight from the release URL (always the newest build):

```bash
sudo apt install https://github.com/pixel3design-hub/open-design-linux/releases/latest/download/Open-Design-linux-x64.deb
sudo dnf install https://github.com/pixel3design-hub/open-design-linux/releases/latest/download/Open-Design-linux-x64.rpm
```

The package is called `open-design` in both cases, installs to
`/opt/Open Design`, and adds a menu entry that registers the `od://` scheme.
Upgrade by installing a newer package over it; user data lives under the app's
XDG config/data roots and is never touched.

Uninstall:

```bash
sudo apt remove open-design
sudo dnf remove open-design
```

## What's in the package

- `/opt/Open Design/` — the assembled app (Electron payload, bundled Vela CLI,
  bundled web/daemon/sidecar)
- `/usr/share/applications/Open Design.desktop` — menu entry
- `/usr/share/icons/hicolor/1024x1024/apps/Open Design.png` — icon

Non-x64 runtime blobs, extra UI locales, and source maps are pruned during the
build, so the downloads stay around 402 MB (rpm) / 461 MB (deb).

The deb depends on the usual Electron runtime libraries, listing
`libgtk-3-0 | libgtk-3-0t64` so it resolves on both Debian 12/Ubuntu 22.04 and
Ubuntu 24.04+.

## Build triggers

- **Push to `main`**: rebuilds the pinned upstream ref.
- **Pinned upstream ref**: `open-design-v0.27.0` (see `UPSTREAM_REF_DEFAULT` in
  the workflow).
- **Scheduled**: daily at 04:00 UTC — rebuilds the pinned ref.
- **Manual**: *Actions → Build Open Design Linux packages → Run workflow*, with an
  optional upstream tag or branch in `upstream_ref` (empty = pinned ref).

The package is not GPG-signed.
