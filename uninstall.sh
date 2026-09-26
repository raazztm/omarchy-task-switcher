#!/usr/bin/env bash
# Removes the plugin, its shell.json entry and its keybindings.
# Original files are restored from the .bak-* the installer created.

set -euo pipefail

PLUGIN_ID="nayan.task-switcher"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
BINDS="$HOME/.config/hypr/bindings.lua"
BEGIN="-- >>> $PLUGIN_ID >>>"
END="-- <<< $PLUGIN_ID <<<"

say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v python3 >/dev/null || die "python3 is required"

if [ -d "$DEST" ]; then
	rm -rf "$DEST"
	say "removed $DEST"
else
	say "plugin directory already gone"
fi

if [ -f "$SHELL_JSON" ]; then
	python3 - "$SHELL_JSON" "$PLUGIN_ID" <<'PY'
import json, sys

path, plugin_id = sys.argv[1], sys.argv[2]
with open(path) as fh:
    cfg = json.load(fh)

plugins = cfg.get("plugins", [])
kept = [p for p in plugins if not (isinstance(p, dict) and p.get("id") == plugin_id)]
if len(kept) == len(plugins):
    print("    shell.json had no entry")
else:
    cfg["plugins"] = kept
    with open(path, "w") as fh:
        json.dump(cfg, fh, indent=2)
        fh.write("\n")
    print("    removed from shell.json")
PY
fi

if [ -f "$BINDS" ]; then
	python3 - "$BINDS" "$BEGIN" "$END" "$PLUGIN_ID" <<'PY'
import re, sys

path, begin, end, plugin_id = sys.argv[1:5]
with open(path) as fh:
    text = fh.read()

pattern = re.compile(
    r"^[ \t]*" + re.escape(begin) + r".*?" + re.escape(end) + r"[ \t]*\n?",
    re.DOTALL | re.MULTILINE,
)
text, n = pattern.subn("", text)

# Catch a hand-made install that never had the marker comments.
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

if n == 0 and legacy == 0:
    print("    no keybinding block found")
else:
    with open(path, "w") as fh:
        fh.write(text)
    print(f"    keybindings removed{'' if legacy == 0 else f' (plus {legacy} legacy statement(s))'}")
PY
fi

# The keybindings live in the Hyprland config, which "omarchy restart shell"
# does not reload.
hyprctl reload >/dev/null 2>&1 || warn "hyprctl reload failed; bindings need a Hyprland reload"
say "restarting the shell"
omarchy restart shell || warn "log out and back in instead"

cat <<EOF

$(say "uninstalled")

  Backups, if you want your original files back:
    $(ls -1 "$SHELL_JSON".bak-* 2>/dev/null | tail -1 || echo "none")
    $(ls -1 "$BINDS".bak-* 2>/dev/null | tail -1 || echo "none")
EOF
