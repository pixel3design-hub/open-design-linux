# Open Design Linux

Automated, updatable Linux builds of [nexu-io/open-design](https://github.com/nexu-io/open-design).

A GitHub Actions workflow fetches the upstream source (the pinned
`open-design-v0.26.0` tag by default, or any tag/branch you pick), builds the official packaged AppImage
with the upstream release-lane recipe (`tools-pack linux build --portable
--to appimage --containerized --require-vela-cli`), and publishes it on a
rolling [`linux-latest` release](https://github.com/pixel3design-hub/open-design-linux/releases/tag/linux-latest).

> **Pinned to upstream 0.26.0.** Upstream 0.26.1 is broken, so this fork builds
> `open-design-v0.26.0` and `install.sh` refuses any other release version.
> Override with `upstream_ref` on a manual run, or
> `OPEN_DESIGN_PINNED_VERSION=<v>` for the installer.

The Vela CLI is bundled in the AppImage (`--require-vela-cli` makes it a hard
requirement), so cloud login works out of the box — no system-wide `vela`
install needed.

## Install / update

```bash
curl -fsSL https://raw.githubusercontent.com/pixel3design-hub/open-design-linux/main/install.sh | bash
```

Or clone and run `./install.sh`. The script is version-aware:

- **Not installed** → installs the latest build.
- **Already latest** → refreshes the launcher wrapper and menu entry without
  re-downloading the ~550 MB AppImage.
- **Update available** → asks for confirmation before downloading, and shows
  the real download size (queried from the release CDN).
  Pass `--yes` (or set `OPEN_DESIGN_ASSUME_YES=1`) to update
  non-interactively, e.g.
  `curl -fsSL .../install.sh | bash -s -- --yes`.

Check without changing anything (exit 0 = up to date, 1 = update
available or not installed):

```bash
./install.sh --check
```

Force a reinstall even when already latest: `./install.sh --force`.

Re-running the script updates the app in place; user data lives under the
app's XDG config/data roots and is never touched.

This installs:

- `~/.local/bin/Open-Design.linux.AppImage`
- `~/.local/bin/Open-Design.linux.version` (installed version marker)
- `~/.local/share/applications/open-design-linux.desktop` (launcher entry,
  registers the `od://` scheme)
- `~/.local/share/icons/hicolor/512x512/apps/open-design-linux.png`

First launch can take ~60 seconds because the AppImage self-extracts to
`/tmp` (a ~2 GB tree; `--appimage-extract-and-run`; direct FUSE mounts make
the daemon time out — see upstream `tools/pack/README.md`).

## Uninstall

```bash
./install.sh uninstall
```

## Build triggers

- **Pinned upstream ref**: `open-design-v0.26.0` (see `UPSTREAM_REF_DEFAULT` in
  the workflow). Upstream 0.26.1 is broken, so it is not built; `install.sh`
  refuses to install any other version unless `OPEN_DESIGN_PINNED_VERSION` is
  set. Bump both pins when a fixed release lands.
- **Scheduled**: daily at 04:00 UTC — rebuilds the pinned ref.
- **Manual**: *Actions → Build Open Design Linux → Run workflow*, with an
  optional upstream tag or branch in `upstream_ref` (empty = pinned ref).

Requirements for the local install: x86_64 Linux. `desktop-file-utils` and
`gtk-update-icon-cache` are optional (only refresh caches).
