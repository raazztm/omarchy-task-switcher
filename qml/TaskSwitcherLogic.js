.pragma library

const APP_NAMES = {
    "foot": "Terminal",
    "foot.client": "Terminal",
    "kitty": "Terminal",
    "alacritty": "Terminal",
    "alacritty-direct": "Terminal",
    "ghostty": "Terminal",
    "wezterm": "Terminal",
    "konsole": "Terminal",
    "org.gnome.terminal": "Terminal",
    "io.github.cosinekitty.cli": "Kitty",
    "org.gnome.Nautilus": "Files",
    "nautilus": "Files",
    "org.gnome.Files": "Files",
    "thunar": "Files",
    "ranger": "Files",
    "chromium": "Chromium",
    "chromium-browser": "Chromium",
    "google-chrome": "Chrome",
    "firefox": "Firefox",
    "org.mozilla.firefox": "Firefox",
    "brave": "Brave",
    "org.brave.Browser": "Brave",
    "org.omarchy.agent": "Agent",
    "org.omarchy.quickshell": "Omarchy",
    "io.github.dmitry-solomadin.omastocks": "Stocks",
    "libreoffice calc": "LibreOffice Calc",
    "libreoffice writer": "LibreOffice Writer",
    "libreoffice impress": "LibreOffice Impress",
    "libreoffice draw": "LibreOffice Draw",
    "libreoffice": "LibreOffice",
    "obs": "OBS Studio",
    "obs-studio": "OBS Studio",
    "com.obsproject.Studio": "OBS Studio",
    "discord": "Discord",
    "spotify": "Spotify",
    "steam": "Steam",
    "steamwebhelper": "Steam",
    "code": "VS Code",
    "codium": "VSCodium",
    "cursor": "Cursor",
    "zed": "Zed",
    "neovim": "Neovim",
    "nvim": "Neovim",
    "emacs": "Emacs",
    "gimp": "GIMP",
    "inkscape": "Inkscape",
    "blender": "Blender",
    "lutris": "Lutris",
    "heroic": "Heroic",
    "xwayland": "App"
}

const ACRONYMS = ["obs", "mpv", "vlc", "aws", "gimp", "ide", "ui", "os", "nix", "wsl"]

function prettyApp(appClass) {
    if (!appClass || appClass.length === 0) return "App"
    if (APP_NAMES[appClass]) return APP_NAMES[appClass]

    const raw = String(appClass).trim()
    if (APP_NAMES[raw.toLowerCase()]) return APP_NAMES[raw.toLowerCase()]

    const parts = raw.split(".")
    const words = parts[parts.length - 1].split(/[-_\s]+/).filter((word) => word.length > 0)
    if (words.length === 0) return "App"

    let name = words.map((word) => {
        const lower = word.toLowerCase()
        if (ACRONYMS.includes(lower)) return lower.toUpperCase()
        if (word.length <= 2) return word.toUpperCase()
        if (word === word.toLowerCase()) return word.charAt(0).toUpperCase() + word.slice(1)
        return word
    }).join(" ")

    if (name === name.toLowerCase()) name = name.charAt(0).toUpperCase() + name.slice(1)
    return name
}

function cleanTitle(title, appName) {
    if (!title) return ""
    let value = String(title).replace(/\s+/g, " ").trim()
    if (!appName) return value

    const suffixes = [" - " + appName, " – " + appName, " — " + appName,
        " | " + appName, " — " + appName.toLowerCase(), " - " + appName.toLowerCase()]
    for (let i = 0; i < suffixes.length; i++) {
        if (value.length > suffixes[i].length && value.endsWith(suffixes[i])) {
            value = value.slice(0, value.length - suffixes[i].length).trim()
            break
        }
    }
    return value
}

function appInitial(appClass) {
    const name = prettyApp(appClass)
    return name.length > 0 ? name.charAt(0).toUpperCase() : "?"
}

function windowSize(raw) {
    if (!raw) return [0, 0]

    const width = Number(raw[0])
    const height = Number(raw[1])
    if (isNaN(width) || isNaN(height)) return [0, 0]
    return [width, height]
}

function buildEntries(toplevels, mode, focusedWorkspaceId) {
    const out = []

    for (let i = 0; i < toplevels.length; i++) {
        const toplevel = toplevels[i]
        const ipc = toplevel.lastIpcObject || {}

        let workspaceId = null
        if (ipc.workspace && ipc.workspace.id !== undefined) workspaceId = ipc.workspace.id
        else if (toplevel.workspace) workspaceId = toplevel.workspace.id
        if (workspaceId === null) continue
        if (ipc.hidden === true) continue
        if (mode === "workspace" && workspaceId !== focusedWorkspaceId) continue

        const size = windowSize(ipc.size)
        const appClass = String(ipc.class || ipc.initialClass || "")
        const history = typeof ipc.focusHistoryID === "number" ? ipc.focusHistoryID : Number.MAX_SAFE_INTEGER

        out.push({
            address: String(toplevel.address),
            toplevel: toplevel,
            title: String(toplevel.title || ipc.initialTitle || "Window"),
            appClass: appClass,
            appName: prettyApp(appClass),
            workspaceId: workspaceId,
            workspaceName: ipc.workspace && ipc.workspace.name ? String(ipc.workspace.name) : String(workspaceId),
            monitorId: ipc.monitor !== undefined ? ipc.monitor : 0,
            focusHistoryID: history,
            width: size[0],
            height: size[1],
            floating: ipc.floating === true,
            fullscreen: ipc.fullscreen || 0,
            pinned: ipc.pinned === true,
            urgent: toplevel.urgent === true,
            activated: history === 0
        })
    }

    out.sort(function (a, b) { return a.focusHistoryID - b.focusHistoryID })
    return out
}

function buildGroups(entries, workspaceOrder) {
    const buckets = {}
    for (let i = 0; i < entries.length; i++) {
        const id = entries[i].workspaceId
        if (!buckets[id]) buckets[id] = []
        buckets[id].push(entries[i])
    }

    const groups = []
    for (let i = 0; i < workspaceOrder.length; i++) {
        const workspace = workspaceOrder[i]
        if (!buckets[workspace.id]) continue
        groups.push({ id: workspace.id, name: workspace.name, entries: buckets[workspace.id] })
        delete buckets[workspace.id]
    }

    const leftovers = Object.keys(buckets)
    for (let i = 0; i < leftovers.length; i++) {
        const id = parseInt(leftovers[i], 10)
        groups.push({ id: id, name: buckets[id][0].workspaceName, entries: buckets[id] })
    }

    return groups
}

function flattenGroups(groups) {
    const out = []
    for (let i = 0; i < groups.length; i++) {
        for (let j = 0; j < groups[i].entries.length; j++) {
            groups[i].entries[j].groupId = groups[i].id
            out.push(groups[i].entries[j])
        }
    }
    return out
}

function groupStartIndex(groups, groupIndex) {
    let start = 0
    for (let i = 0; i < groupIndex && i < groups.length; i++) start += groups[i].entries.length
    return start
}

function groupIndexOfEntry(groups, flatIndex) {
    let start = 0
    for (let i = 0; i < groups.length; i++) {
        const length = groups[i].entries.length
        if (flatIndex < start + length) return i
        start += length
    }
    return groups.length - 1
}

function previewSize(entry, boxWidth, boxHeight) {
    const width = entry && entry.width > 0 ? entry.width : boxWidth
    const height = entry && entry.height > 0 ? entry.height : boxHeight
    const ratio = width / height

    if (ratio >= boxWidth / boxHeight) {
        return { width: Math.round(boxWidth), height: Math.max(1, Math.round(boxWidth / ratio)) }
    }
    return { width: Math.max(1, Math.round(boxHeight * ratio)), height: Math.round(boxHeight) }
}

function buildRail(entries, groups, mode) {
    const cells = []

    if (mode === "grouped" && groups && groups.length > 0) {
        for (let g = 0; g < groups.length; g++) {
            cells.push({
                kind: "header",
                group: g,
                id: groups[g].id,
                name: groups[g].name,
                count: groups[g].entries.length,
                start: groupStartIndex(groups, g)
            })
            for (let i = 0; i < groups[g].entries.length; i++) {
                cells.push({
                    kind: "row",
                    group: g,
                    index: groupStartIndex(groups, g) + i,
                    entry: groups[g].entries[i]
                })
            }
        }
    } else {
        for (let i = 0; i < entries.length; i++) {
            cells.push({ kind: "row", group: -1, index: i, entry: entries[i] })
        }
    }

    return cells
}

function summarize(count) {
    return count === 1 ? "1 window" : count + " windows"
}
