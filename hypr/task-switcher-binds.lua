-- >>> nayan.task-switcher >>>
-- Installed by omarchy-task-switcher. Remove with ./uninstall.sh
-- Hold the modifier, tap Tab to cycle, release to focus the selection.
hl.unbind("ALT + TAB")
hl.unbind("ALT + SHIFT + TAB")
hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
hl.unbind("SUPER + ALT + TAB")
hl.unbind("SUPER + ALT + SHIFT + TAB")

o.bind("ALT + TAB", "Task switcher: next window on this workspace",
  hl.dsp.global("nayan.task-switcher:workspace-next"),
  { repeating = true })
o.bind("ALT + SHIFT + TAB", "Task switcher: previous window on this workspace",
  hl.dsp.global("nayan.task-switcher:workspace-prev"),
  { repeating = true })
o.bind("SUPER + TAB", "Task switcher: next window on any workspace",
  hl.dsp.global("nayan.task-switcher:global-next"),
  { repeating = true })
o.bind("SUPER + SHIFT + TAB", "Task switcher: previous window on any workspace",
  hl.dsp.global("nayan.task-switcher:global-prev"),
  { repeating = true })
o.bind("SUPER + ALT + TAB", "Task switcher: next window grouped by workspace",
  hl.dsp.global("nayan.task-switcher:grouped-next"),
  { repeating = true })
o.bind("SUPER + ALT + SHIFT + TAB", "Task switcher: previous window grouped by workspace",
  hl.dsp.global("nayan.task-switcher:grouped-prev"),
  { repeating = true })

o.bind("ALT + ALT_L", "Task switcher: focus the selection",
  hl.dsp.global("nayan.task-switcher:commit"), { release = true })
o.bind("ALT + ALT_R", "Task switcher: focus the selection",
  hl.dsp.global("nayan.task-switcher:commit"), { release = true })
o.bind("SUPER + SUPER_L", "Task switcher: focus the selection",
  hl.dsp.global("nayan.task-switcher:commit"), { release = true })
o.bind("SUPER + SUPER_R", "Task switcher: focus the selection",
  hl.dsp.global("nayan.task-switcher:commit"), { release = true })
-- <<< nayan.task-switcher <<<
