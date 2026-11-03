# Open Design Linux (RPM)

Automated RPM builds of [nexu-io/open-design](https://github.com/nexu-io/open-design) for
x86_64 Linux.

We only build the RPM package. If you are looking for AppImage package go to:
[`AppImage` release](https://github.com/pourmirzai/open-design-linux/release/tag/linux-latest)

A GitHub Actions workflow fetches the upstream source (the pinned
`open-design-v0.26.0` tag by default, or any tag/branch you pick), assembles
the app with the upstream packaging recipe (`tools-pack linux build --portable
--to dir --containerized --require-vela-cli`), and packages that tree with
electron-builder's rpm target. The result is published on the
rolling [`linux-latest` release](https://github.com/pixel3design-hub/open-design-linux/releases/tag/linux-latest).

> **Pinned to upstream 0.26.0.** Upstream 0.26.1 is broken, so this fork builds
> `open-design-v0.26.0`. Pass `upstream_ref` on a manual run to build something
> else.

The Vela CLI is bundled (`--require-vela-cli` makes it a hard requirement), so
cloud login works out of the box — no system-wide `vela` install needed.

## Install

Download `Open-Design-linux-x64.rpm` from the
[latest release](https://github.com/pixel3design-hub/open-design-linux/releases/tag/linux-latest)
and install it:

```bash
sudo dnf install ./Open-Design-linux-x64.rpm     # Fedora / RHEL family
sudo zypper install ./Open-Design-linux-x64.rpm  # openSUSE
```

Or install straight from the release URL:

```bash
sudo dnf install https://github.com/pixel3design-hub/open-design-linux/releases/download/linux-latest/Open-Design-linux-x64.rpm
```

The package is called `open-design`, installs to `/opt/Open Design`, and adds
a menu entry that registers the `od://` scheme. Upgrade by installing a newer
rpm over it; user data lives under the app's XDG config/data roots and is never
touched.

Uninstall:

```bash
sudo dnf remove open-design
```

## What's in the package

- `/opt/Open Design/` — the assembled app (Electron payload, bundled Vela CLI,
  bundled web/daemon/sidecar)
- `/usr/share/applications/Open Design.desktop` — menu entry
- `/usr/share/icons/hicolor/1024x1024/apps/Open Design.png` — icon

Non-x64 runtime blobs, extra UI locales, and source maps are pruned during the
build, so the download stays ~366 MB.

## Build triggers

- **Pinned upstream ref**: `open-design-v0.26.0` (see `UPSTREAM_REF_DEFAULT` in
  the workflow).
- **Scheduled**: daily at 04:00 UTC — rebuilds the pinned ref.
- **Manual**: *Actions → Build Open Design RPM → Run workflow*, with an
  optional upstream tag or branch in `upstream_ref` (empty = pinned ref).

The package is not GPG-signed.
