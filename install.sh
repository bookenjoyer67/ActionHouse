#!/usr/bin/env bash
# Install ActionHouse from this checkout into the WoW Forever client.
# The file set mirrors what the release workflow packages: .pkgmeta's
# `ignore:` list is the single source of truth for what ships.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_root="/home/computing/Games/battlenet/pfx/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"
root="${WOW_FOREVER_ADDONS:-$default_root}"
dst="$root/ActionHouse"

# Build rsync excludes from .pkgmeta (fallback below if it is missing).
excludes=()
if [[ -f "$src/.pkgmeta" ]]; then
    while IFS= read -r item; do
        [[ -n "$item" ]] && excludes+=("--exclude=$item")
    done < <(awk '/^ignore:/{f=1;next} f&&/^[[:space:]]*-[[:space:]]/{print $2; next} f&&/^[^[:space:]]/{f=0}' "$src/.pkgmeta")
fi
if [[ ${#excludes[@]} -eq 0 ]]; then
    excludes=(--exclude=.git --exclude=.github --exclude=.gitignore --exclude=.pkgmeta
              --exclude=.selene.toml --exclude=stylua.toml --exclude=install.sh
              --exclude=tests --exclude=dist --exclude=.release)
fi
excludes+=(--exclude=.git)

if [[ "${1:-}" == "--link" ]]; then
    mkdir -p "$root"
    rm -rf "$dst"
    ln -s "$src" "$dst"
    echo "Linked $dst -> $src"
    echo "Note: --link exposes dev files (tests, .git) to the client; only the TOC is read."
else
    if [[ ! -d "$root" ]]; then
        echo "AddOns directory not found: $root" >&2
        echo "Set WOW_FOREVER_ADDONS to the _forever_/Interface/AddOns path." >&2
        exit 1
    fi
    rm -rf "$dst"
    mkdir -p "$dst"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a "${excludes[@]}" "$src/" "$dst/"
    else
        tar -C "$src" -cf - "${excludes[@]/#/--exclude=}" . | tar -C "$dst" -xf -
    fi
    echo "Installed to $dst"
fi

echo "Then /reload (a new folder is picked up by the UI reload) or restart the client, and enable ActionHouse if needed. Run /ahv status."
