# Troubleshooting

| Problem | Fix |
|---|---|
| Linux: `not` not found, or “Swift not found” | Run `~/NotDefteri/scripts/linux-kur.sh` again |
| Linux: the app does not open or crashes | Read the newest `.log` in `~/.local/state/NotDefteri/` |
| Linux: the first launch takes long | The first build is a full build (a few minutes); later launches take about 1.5 s |
| A second launch does nothing | The app runs as one window; launching again brings it to the front |
| A note did not open or save | The app warns and blocks quitting. Your text stays in the window, so copy it somewhere safe |
| Keep on top does nothing on Wayland | Start without `GDK_BACKEND=wayland` so the app uses XWayland |

Still stuck? [Open an issue](https://github.com/olcayalkan/NotDefteri/issues/new/choose) with
your OS version and the steps to reproduce.
