#!/usr/bin/env bash
# Install/update the Open Design Linux AppImage built by this repository's
# GitHub Actions workflow (rolling release tag "linux-latest").
#
# Usage:
#   install.sh [install] [--yes] [--check] [--force]
#   install.sh uninstall
#   curl -fsSL .../install.sh | bash -s -- [--yes] [--check] [--force]
#
# Behavior:
#   - Not installed            -> installs the latest build.
#   - Installed, latest         -> refreshes the launcher wrapper and menu
#                                  entry; the ~550 MB AppImage is NOT
#                                  re-downloaded.
#   - Installed, outdated      -> asks for confirmation before updating,
#                                  unless --yes (or OPEN_DESIGN_ASSUME_YES=1).
#   - --check                   -> only reports installed vs latest version
#                                  (exit 0 = up to date, 1 = update available
#                                  or not installed). Downloads nothing big.
#   - --force                   -> skips the version check, reinstalls anyway.
#
# Layout (matches the upstream `tools-pack linux install` namespace "linux"):
#   ~/.local/bin/Open-Design.linux.AppImage
#   ~/.local/bin/Open-Design.linux.version   (installed version marker)
#   ~/.local/share/applications/open-design-linux.desktop
#   ~/.local/share/icons/hicolor/512x512/apps/open-design-linux.png
set -Eeuo pipefail

REPO="${OPEN_DESIGN_LINUX_REPO:-pixel3design-hub/open-design-linux}"
RELEASE_TAG="linux-latest"
# Upstream 0.26.1 is broken, so the rolling release is pinned to 0.26.0.
# Refuse to install anything else, even if the release asset is stale.
PINNED_VERSION="${OPEN_DESIGN_PINNED_VERSION:-0.26.0}"
NAMESPACE="linux"
APPIMAGE_NAME="Open-Design.${NAMESPACE}.AppImage"
VERSION_FILENAME="Open-Design.${NAMESPACE}.version"
ASSET_APPIMAGE="Open-Design-linux-x64.AppImage"
ASSET_ICON="open-design-icon.png"
ASSET_VERSION="VERSION"

BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/512x512/apps"
APPIMAGE_PATH="${BIN_DIR}/${APPIMAGE_NAME}"
VERSION_PATH="${BIN_DIR}/${VERSION_FILENAME}"
WRAPPER_PATH="${BIN_DIR}/open-design-wrapper.sh"
DESKTOP_PATH="${DESKTOP_DIR}/open-design-${NAMESPACE}.desktop"
ICON_PATH="${ICON_DIR}/open-design-${NAMESPACE}.png"

info() { printf '\033[1;34m[OpenDesign]\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m[OpenDesign]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[OpenDesign]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<USAGE
Usage:
  install.sh [install] [--yes] [--check] [--force]
  install.sh uninstall

  install   install if missing, prompt to update if outdated (default)
  uninstall remove the installed app
  --yes, -y    never prompt; assume "yes" for updates
  --check      only report installed vs latest version, change nothing
  --force, -f  skip the version check and reinstall anyway
  --help, -h   show this help

Env:
  OPEN_DESIGN_LINUX_REPO   GitHub repo to download from (default: pixel3design-hub/open-design-linux)
  OPEN_DESIGN_ASSUME_YES=1 same as --yes
  OPEN_DESIGN_PINNED_VERSION  expected release version (default: 0.26.0)
USAGE
}

require() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

COMMAND="install"
ASSUME_YES=0
CHECK_ONLY=0
FORCE=0
[[ "${OPEN_DESIGN_ASSUME_YES:-0}" == "1" ]] && ASSUME_YES=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    install) COMMAND="install"; shift ;;
    uninstall) COMMAND="uninstall"; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    --check) CHECK_ONLY=1; shift ;;
    -f|--force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1 (use: install.sh [--help] for usage)" ;;
  esac
done

[[ "$COMMAND" == "uninstall" && "$CHECK_ONLY" == "1" ]] && \
  fail "--check cannot be combined with uninstall"
[[ "$COMMAND" == "uninstall" && "$FORCE" == "1" ]] && \
  fail "--force cannot be combined with uninstall"
[[ "$CHECK_ONLY" == "1" && "$FORCE" == "1" ]] && \
  fail "--check cannot be combined with --force"

uninstall() {
  local removed=0
  for f in "$APPIMAGE_PATH" "$VERSION_PATH" "$WRAPPER_PATH" "$DESKTOP_PATH" "$ICON_PATH"; do
    if [[ -e "$f" ]]; then
      rm -f -- "$f"
      info "Removed $f"
      removed=1
    fi
  done
  rm -rf /tmp/open-design-run 2>/dev/null || true
  ((removed)) || info "Nothing installed."
  command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  ok "Uninstall complete."
}

write_wrapper() {
  mkdir -p "$BIN_DIR"
  info "Installing launcher wrapper..."
  # The AppImage's built-in --appimage-extract-and-run always extracts to the
  # same deterministic /tmp/appimage_extracted_<hash> directory. If a run is
  # killed mid-extraction (e.g. /tmp fills up — the tree is ~2G), the corrupt
  # tree is silently reused on every later launch and the app dies on missing
  # chunks. The wrapper extracts to a fresh directory and atomically swaps it
  # in instead.
  cat > "$WRAPPER_PATH" <<'WRAPPER'
#!/usr/bin/env bash
# Open Design launcher: fresh AppImage extraction with atomic swap.
set -euo pipefail

APPIMAGE="${OPEN_DESIGN_APPIMAGE:-$HOME/.local/bin/Open-Design.linux.AppImage}"
BASE="/tmp/open-design-run"
STAMP="$(date +%s%N)"
NEW="$BASE/new-$STAMP"
CUR="$BASE/current"
OLD="$BASE/old-$STAMP"

[[ -x "$APPIMAGE" ]] || { echo "Open Design AppImage not found at $APPIMAGE" >&2; exit 1; }

# Identity of the installed AppImage (size + mtime). The extracted tree is
# cached across launches, so the cache must be invalidated whenever this
# changes — otherwise an updated AppImage keeps launching the stale tree.
appimage_stamp() {
  stat -Lc '%s.%Y' "$APPIMAGE" 2>/dev/null
}

intact() {
  local dir="$1" expected stored
  [[ -x "$dir/AppRun" ]] || return 1
  [[ -s "$dir/snapshot_blob.bin" ]] || return 1
  [[ -s "$dir/v8_context_snapshot.bin" ]] || return 1
  [[ -s "$dir/Open Design" ]] || return 1
  expected="$(appimage_stamp)" || return 1
  [[ -f "$dir/.od-stamp" ]] || return 1
  stored="$(cat "$dir/.od-stamp" 2>/dev/null)" || return 1
  [[ "$stored" == "$expected" ]]
}

if intact "$CUR"; then
  exec env -u ELECTRON_RUN_AS_NODE OD_PACKAGED_NAMESPACE=linux \
    "$CUR/AppRun" --no-sandbox "$@"
fi

# Refuse to extract into a nearly-full /tmp: a truncated tree breaks the app.
avail_kb="$(df -Pk /tmp | awk 'NR==2 {print $4}')"
need_kb="$(( $(stat -Lc %s "$APPIMAGE") * 3 / 1024 + 512 * 1024 ))"
if (( avail_kb < need_kb )); then
  echo "Not enough space in /tmp (need ~$((need_kb / 1024))M free, have $((avail_kb / 1024))M)." >&2
  echo "Free /tmp (rm -rf /tmp/open-design-run /tmp/appimage_extracted_*) and retry." >&2
  exit 1
fi

mkdir -p "$NEW"
( cd "$NEW" && "$APPIMAGE" --appimage-extract >/dev/null )
appimage_stamp > "$NEW/squashfs-root/.od-stamp" 2>/dev/null || true
if ! intact "$NEW/squashfs-root"; then
  rm -rf "$NEW"
  echo "Extraction produced an incomplete tree (disk full?). Free /tmp and retry." >&2
  exit 1
fi

if [[ -d "$CUR" ]]; then
  mv "$CUR" "$OLD"
fi
mv "$NEW/squashfs-root" "$CUR"
rm -rf "$NEW" "$OLD" "$BASE"/new-* "$BASE"/old-* 2>/dev/null || true

exec env -u ELECTRON_RUN_AS_NODE OD_PACKAGED_NAMESPACE=linux \
  "$CUR/AppRun" --no-sandbox "$@"
WRAPPER
  chmod +x "$WRAPPER_PATH"
}

write_desktop_entry() {
  mkdir -p "$DESKTOP_DIR"
  cat > "${DESKTOP_PATH}.tmp" <<EOF
[Desktop Entry]
Type=Application
Name=Open Design
GenericName=Open Design
Comment=Open Design packaged build
Exec=${WRAPPER_PATH} %U
Icon=open-design-${NAMESPACE}
Categories=Development;Utility;
StartupWMClass=Open Design
StartupNotify=true
Terminal=false
MimeType=x-scheme-handler/od;
EOF
  mv -f "${DESKTOP_PATH}.tmp" "$DESKTOP_PATH"

  # Best-effort desktop integration hooks (absent tools are harmless).
  command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  command -v xdg-mime >/dev/null 2>&1 && \
    xdg-mime default "open-design-${NAMESPACE}.desktop" x-scheme-handler/od >/dev/null 2>&1 || true
}

[[ "$COMMAND" != "uninstall" ]] || { uninstall; exit 0; }

require curl
require install

[[ "$(uname -m)" == "x86_64" ]] || fail "This build is x86_64 only (found: $(uname -m))."

base_url="https://github.com/${REPO}/releases/download/${RELEASE_TAG}"

# Human-readable byte count, e.g. 555970594 -> "531MiB".
human_size() {
  local bytes="$1"
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec-i --suffix=B "$bytes"
  else
    printf '%s bytes' "$bytes"
  fi
}

# Ask the release CDN for the AppImage size via HTTP HEAD (a few hundred
# bytes); echoes the byte count, or returns non-zero if it can't be read.
fetch_remote_size() {
  local headers
  headers="$(curl -fsIL --retry 2 --retry-delay 2 \
    "${base_url}/${ASSET_APPIMAGE}" 2>/dev/null)" || return 1
  printf '%s' "$headers" | grep -i '^content-length:' | tail -n 1 | tr -dc '0-9'
}

# Fetch the latest published version using the tiny VERSION asset, falling
# back to the GitHub release metadata (release `name` is "Open Design Linux
# <version>") for releases built before the VERSION asset existed.
fetch_remote_version() {
  local out name
  if out="$(curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors \
      "${base_url}/${ASSET_VERSION}" 2>/dev/null)"; then
    out="$(printf '%s' "$out" | tr -d '[:space:]')"
    if [[ -n "$out" ]]; then
      printf '%s' "$out"
      return 0
    fi
  fi
  if name="$(curl -fsSL --retry 3 --retry-delay 2 \
      "https://api.github.com/repos/${REPO}/releases/tags/${RELEASE_TAG}" \
      2>/dev/null | grep -o '"name": *"[^"]*"' | head -n 1)"; then
    out="${name##* }"
    out="${out%\"}"
    out="$(printf '%s' "$out" | tr -d '[:space:]')"
    if [[ -n "$out" ]]; then
      printf '%s' "$out"
      return 0
    fi
  fi
  return 1
}

info "Checking latest version from github.com/${REPO} (${RELEASE_TAG})..."
remote_version="$(fetch_remote_version)" \
  || fail "Could not determine the latest version. Check your network and try again."

# Upstream 0.26.1 is broken; a stale release asset must not be installed.
if [[ "$remote_version" != "$PINNED_VERSION" ]]; then
  fail "Release ${RELEASE_TAG} serves ${remote_version}, but this installer is pinned to ${PINNED_VERSION} (0.26.1 is broken). Re-run the 'Build Open Design Linux' workflow, or set OPEN_DESIGN_PINNED_VERSION=${remote_version} to override."
fi

installed_version=""
if [[ -f "$APPIMAGE_PATH" ]]; then
  if [[ -f "$VERSION_PATH" ]]; then
    installed_version="$(tr -d '[:space:]' < "$VERSION_PATH")"
  fi
  [[ -n "$installed_version" ]] || installed_version="unknown"
fi

# Resolve the real download size for the messages below (--check exits before
# this point, so it stays metadata-only).
size_note=""
if (( CHECK_ONLY == 0 )); then
  appimage_size="$(fetch_remote_size || true)"
  if [[ "$appimage_size" =~ ^[0-9]+$ ]]; then
    size_note=" ($(human_size "$appimage_size") download)"
  fi
fi

if (( FORCE == 0 )); then
  if [[ -z "$installed_version" ]]; then
    if (( CHECK_ONLY == 1 )); then
      info "Open Design is not installed. Latest available: ${remote_version}."
      exit 1
    fi
    info "No existing installation found — installing Open Design ${remote_version}${size_note}..."
  elif [[ "$installed_version" == "$remote_version" ]]; then
    # Refresh the launcher and menu entry without re-downloading anything, so
    # wrapper fixes land even when the AppImage itself is already current.
    write_wrapper
    write_desktop_entry
    ok "Open Design ${remote_version} is already installed. Launcher refreshed — no download needed."
    exit 0
  else
    if (( CHECK_ONLY == 1 )); then
      info "Update available: ${installed_version} -> ${remote_version}."
      exit 1
    fi
    info "Update available: ${installed_version} -> ${remote_version}${size_note}."
    if (( ASSUME_YES == 0 )); then
      # stdin may be a pipe (curl ... | bash), so prompt on /dev/tty.
      if [[ -r /dev/tty ]]; then
        IFS= read -r -p "Proceed with update? [y/N] " answer < /dev/tty \
          || { info "Update cancelled."; exit 0; }
        [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]] || { info "Update cancelled."; exit 0; }
      else
        info "No interactive terminal detected — proceeding with update (use --yes to silence this)."
      fi
    fi
    info "Updating ${installed_version} -> ${remote_version}..."
  fi
else
  if [[ -n "$installed_version" ]]; then
    info "Force mode — reinstalling ${remote_version} (installed: ${installed_version})..."
  else
    info "Force mode — installing ${remote_version}..."
  fi
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

info "Downloading Open Design ${remote_version}..."
curl -fL --retry 5 --retry-delay 2 --retry-all-errors -o "${work_dir}/${ASSET_APPIMAGE}" \
  "${base_url}/${ASSET_APPIMAGE}" || fail "Download failed. Has the first Actions build finished?"
curl -fL --retry 5 --retry-delay 2 --retry-all-errors -o "${work_dir}/${ASSET_ICON}" \
  "${base_url}/${ASSET_ICON}" || fail "Icon download failed."

chmod +x "${work_dir}/${ASSET_APPIMAGE}"

mkdir -p "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"

info "Installing AppImage to ${APPIMAGE_PATH}..."
mv -f "${work_dir}/${ASSET_APPIMAGE}" "$APPIMAGE_PATH"
printf '%s\n' "$remote_version" > "$VERSION_PATH"

info "Installing launcher wrapper..."
write_wrapper

info "Installing icon and menu entry..."
mv -f "${work_dir}/${ASSET_ICON}" "$ICON_PATH"

write_desktop_entry

ok "Installed Open Design ${remote_version}. 'Open Design' now appears in your app launcher."
ok "Re-run this script any time to check for updates; your data is not touched."
ok "First launch can take ~60s (the launcher extracts the ~2G tree to /tmp); later launches are faster."
