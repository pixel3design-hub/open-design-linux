# Open Design Linux (RPM + DEB)

Automated RPM and DEB builds of [nexu-io/open-design](https://github.com/nexu-io/open-design)
for x86_64 Linux.

We only build the RPM and DEB packages. If you are looking for an AppImage,
the upstream fork still publishes one:
[`AppImage` release](https://github.com/pourmirzai/open-design-linux/releases/tag/linux-latest)

A GitHub Actions workflow resolves the newest upstream
`open-design-v<semver>` tag, fetches it, assembles the app with the upstream
packaging recipe (`tools-pack linux build --portable --to dir --containerized
--require-vela-cli`), and packages that tree with electron-builder's rpm and deb
targets. Each build is published as a release tagged `v<VERSION>` (e.g.
[`v0.27.0`](https://github.com/pixel3design-hub/open-design-linux/releases/tag/v0.27.0));
`releases/latest` always points at the newest one.

> **Newest upstream version is built automatically.** A scheduled run only
> *checks* upstream; it builds when the newest tag has no release here yet.
> Pass `upstream_ref` on a manual run to pin a specific tag, tick `force` to
> rebuild a version that already has a release, or add a version to
> `UPSTREAM_SKIP` (currently `0.26.1`) to blacklist a broken point release.
>
> A newer upstream tag that changes the packaging files needs
> `patches/open-design-linux-pack.patch` regenerated (it applies with
> `git apply --check` on the pristine upstream tag); until then the run fails
> loudly and you get notified.

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
build, so the downloads stay around 402 MB (rpm) / 461 MB (deb) — measured on
the 0.27.x builds.

The deb depends on the usual Electron runtime libraries, listing
`libgtk-3-0 | libgtk-3-0t64` so it resolves on both Debian 12/Ubuntu 22.04 and
Ubuntu 24.04+.

## Build triggers

- **Push to `main`**: builds the newest upstream version, but only if there is
  no release for it yet.
- **Scheduled**: daily at 04:00 UTC — version check only; builds when a new
  upstream `open-design-v<semver>` tag has no release here yet.
- **Manual**: *Actions → Build Open Design Linux packages → Run workflow*, with
  an optional upstream tag or branch in `upstream_ref` (empty = newest upstream
  release tag) and an optional `force` to rebuild an already published version.

## Failure notifications

When a run fails (patch no longer applies, build error, …) a Telegram message is
sent with the version and the run URL. Set two repository secrets
(*Settings → Secrets and variables → Actions*):

- `TELEGRAM_BOT_TOKEN` — from [@BotFather](https://t.me/BotFather)
- `TELEGRAM_CHAT_ID` — message the bot first, then read the id from
  `https://api.telegram.org/bot<TOKEN>/getUpdates` (group ids are negative)

Without those secrets the notification step just logs and succeeds (forks keep
working). GitHub additionally emails whoever triggered the failed run — enable
it under *Settings → Notifications → Actions*.

The package is not GPG-signed.
