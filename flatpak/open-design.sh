#!/bin/sh
# Flatpak entry point. The unpacked AppImage tree carries its own libs and an
# AppRun launcher, so run that directly. --no-sandbox for the same reason the
# AppImage wrapper passes it: Chromium's own sandbox needs user namespaces.
exec /app/open-design/AppRun --no-sandbox "$@"
