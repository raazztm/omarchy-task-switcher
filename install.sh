#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="oma.task-switcher"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
BINDS="$HOME/.config/hypr/bindings.lua"
BEGIN="-- >>> $PLUGIN_ID >>>"
END="-- <<< $PLUGIN_ID <<<"

say()  { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v python3 >/dev/null || die "python3 is required"
[ -d "$HOME/.config/omarchy" ] || die "Omarchy config not found at ~/.config/omarchy"
[ -f "$SHELL_JSON" ] || die "$SHELL_JSON not found; is this Omarchy?"
[ -f "$BINDS" ] || die "$BINDS not found; this installer targets the current Omarchy Hyprland config"
if ! hyprctl version >/dev/null 2>&1; then
	warn "hyprctl did not answer; the plugin will load but the keybindings will not fire"
fi

# 1. plugin files
if [ "$(realpath "$SRC")" = "$(realpath "$DEST" 2>/dev/null || echo "$DEST")" ]; then
	say "plugin files already in place at $DEST"
else
	mkdir -p "$DEST/qml"
	cp -a "$SRC/manifest.json" "$DEST/manifest.json"
	cp -a "$SRC/qml/." "$DEST/qml/"
	# Remove QML left in the plugin root by older installs.
	for stale in "$DEST"/*.qml "$DEST"/*.js; do
		[ -f "$stale" ] || continue
		base="$(basename "$stale")"
		[ -f "$DEST/qml/$base" ] && rm -f "$stale"
	done
	say "plugin files -> $DEST"
fi

# 2. register in shell.json
python3 - "$SHELL_JSON" "$PLUGIN_ID" <<'PY'
import json, shutil, sys, glob, os, time

path, plugin_id = sys.argv[1], sys.argv[2]
with open(path) as fh:
    cfg = json.load(fh)

plugins = cfg.setdefault("plugins", [])
if any(isinstance(p, dict) and p.get("id") == plugin_id for p in plugins):
    print("    shell.json already registers the plugin")
else:
    if not glob.glob(path + ".bak-*"):
        shutil.copy2(path, f"{path}.bak-{time.strftime('%Y%m%d%H%M%S')}")
        print(f"    backed up {path}")
    plugins.append({"id": plugin_id})
    with open(path, "w") as fh:
        json.dump(cfg, fh, indent=2)
        fh.write("\n")
    print("    registered in shell.json")
PY

# 3. keybindings
python3 - "$BINDS" "$BEGIN" "$END" "$SRC/hypr/task-switcher-binds.lua" "$PLUGIN_ID" <<'PY'
import glob, re, shutil, sys, time

path, begin, end, source, plugin_id = sys.argv[1:6]
with open(path) as fh:
    text = fh.read()

block = open(source).read().strip()

pattern = re.compile(
    r"^[ \t]*" + re.escape(begin) + r".*?" + re.escape(end) + r"[ \t]*\n?",
    re.DOTALL | re.MULTILINE,
)
text, removed = pattern.subn("", text)

# Drop our own block and any pre-marker bind mentioning the plugin, so a
# hand-made install cannot leave two binds on one key.
kept, buf, depth, legacy = [], [], 0, 0
for line in text.splitlines(keepends=True):
    buf.append(line)
    depth += line.count("(") - line.count(")")
    if depth > 0:
        continue
    statement = "".join(buf)
    buf, depth = [], 0
    if plugin_id in statement:
        legacy += 1
        continue
    kept.append(statement)
text = "".join(kept)

if not (removed or legacy) and not glob.glob(path + ".bak-*"):
    shutil.copy2(path, f"{path}.bak-{time.strftime('%Y%m%d%H%M%S')}")
    print(f"    backed up {path}")

if not text.endswith("\n"):
    text += "\n"

with open(path, "w") as fh:
    fh.write(text + "\n" + block + "\n")

if legacy:
    print(f"    removed {legacy} leftover bind statement(s) from an older install")
print("    keybindings installed" if not removed else "    keybindings refreshed")
PY

hyprctl reload >/dev/null 2>&1 || warn "hyprctl reload failed; bindings need a Hyprland reload"
say "restarting the shell"
omarchy restart shell || warn "'omarchy restart shell' failed; log out and back in"

cat <<EOF

$(say "done")

  ALT + TAB                 this workspace
  SUPER + TAB               every window
  SUPER + ALT + TAB         grouped by workspace
  hold the modifier, tap Tab to cycle, release to focus

  uninstall: $SRC/uninstall.sh
EOF
