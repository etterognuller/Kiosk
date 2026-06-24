# Dev setup

How to get the **Kiosk** project running locally. The engine and language are fixed by
[ADR-0001](adr/0001-godot-4.7-gdscript.md): **Godot 4.7, GDScript** (the *standard* build —
not the .NET/C# one).

## Install Godot 4.7 via Steam (current setup)

1. In Steam, search **"Godot Engine"** (free, published by the Godot Foundation, app id
   `404790`) and **Install**. This is the standard GDScript build — it has no C#/.NET support,
   which is exactly what we want.
2. **Disable auto-update** so Steam can't move us off 4.7 mid-work. Right-click the app →
   **Properties → Updates → "Only update this game when I launch it"**. Optionally use
   **Properties → Betas** to pin a specific version branch.
   - Why: ADR-0001 pins the project to 4.7. Minor 4.x bumps are low-risk, but the upgrade
     should be a deliberate choice (and ideally its own commit), never a surprise.
3. *(Optional)* If the Steam Overlay interferes when running/debugging the game, turn it off
   for Godot specifically in the same **Properties** dialog.

> "GodotSteam" that turns up in searches is an unrelated third-party Steamworks add-on
> (achievements, etc.), **not** how you install the engine. Ignore it for now.

## Alternative: official download

If you ever want the editor outside Steam (e.g. on a machine without it), grab it from
**<https://godotengine.org/download>** → Windows → **Godot 4.7 – Standard** (not .NET).
It's a portable `.exe` in a zip; unzip and run, no installer.

## Open and run

1. Launch Godot (Steam must be running if you installed via Steam).
2. In the Project Manager: **Import** → select `project.godot` at the repo root →
   **Import & Edit**.
3. Press **F5** (or the ▶ button, top-right) to run.

You should see a top bar reading **Day 1 · 50 kr · PROCURE** and a button that steps the day
loop PROCURE → SERVE → UPGRADE → next day. Crossing into the next day writes a save, so day,
money, and stock persist across relaunches.

## First-run notes

- The first time the project opens, Godot generates a `.godot/` import cache and per-asset
  `.import` files. This is normal and already git-ignored.
- The save file lives at Godot's `user://` path (`%APPDATA%\Godot\app_userdata\Kiosk\` on
  Windows), **not** in the repo. Delete `savegame.json` there to start fresh.
- `project.godot` is owned by the Godot editor — it will reformat the file and strip hand-added
  comments when you change settings in-app. That's expected; edit project settings through the
  editor UI rather than by hand where possible.
