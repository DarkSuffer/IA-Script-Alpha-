# 🎭 Item Asylum Hub
> **Game:** [Item Asylum](https://www.roblox.com/games/5670218884) | **Gamemode Focus:** Murder Party (MU)
> **Author:** @jo2527 presleyyyyyyy
> **Last Updated:** 5/13/26

## Features

### 🎯 Combat
- **Aimbot** — Camera-based aimbot with customizable hold keybind (default MB2), FOV circle, smoothness, max distance, target part selection, and optional team check
- **Kill Aura** — Auto-activates equipped tool on nearby players within a configurable stud range

### 👁️ ESP & Visuals
- **Separation ESP** — Billboard labels above all players showing their name and detected role, color-coded per role (Murderer / Sheriff / Innocent / Dead) with individual visibility filters
- **Clue ESP** — Billboard markers on active interactable clues with live distance display, auto-removes when clue is consumed
- **Gun Drop ESP** — Pins a world-space marker at the location a Sheriff died and dropped their gun, auto-removes when gun is picked up
- **Chams ESP** — Highlight overlay on all other players' characters with customizable fill color, always visible through walls
- **Head Expander** — Scales other players' heads to a configurable multiplier (1x–15x) with a transparent highlight overlay, does not affect local player

### 🗺️ Murder Party (Item Asylum)
- **Role Detection** — Identifies Murderer via `mu_` tool prefix, Sheriff via exact match on `Mad Sheriff` / `Mad Handgun`, covers both equipped and backpack slots
- **Instant Collect** — Auto-fires proximity prompts on active clues within a configurable range (3–80 studs)

### 💡 Visuals / World
- **Fullbright** — Softens ambient lighting for visibility in dark maps without being blinding, auto-re-applies if game resets lighting
- **No Fog** — Removes Lighting fog values and neutralizes Atmosphere density, haze, offset, and glare, restores originals on disable

### 🏃 Movement
- **Fly** — Physics-based flight using `LinearVelocity` and `AlignOrientation`, WASD + E (up) / Q (down), configurable speed
- **Custom Walk Speed** — Overrides Humanoid WalkSpeed every Heartbeat while enabled, restores default on disable

### 🌐 Server
- **Rejoin** — Teleports back into the same server instance
- **Server Hop** — Fetches public server list via Roblox API and teleports to a different non-full server
- **Auto Rejoin on Kick** — Detects disconnect/kick screen and automatically rejoins
- **Auto Server Hop on Kick** — Detects disconnect/kick screen and automatically hops to a new server

### ⚙️ Settings
- **Customizable Menu Keybind** — Toggle UI visibility with any key (default RightShift)
- **Theme Manager** — Full LinoriaLib theme customization
- **Save Manager** — Config save/load with autoload support via LinoriaLib's SaveManager
- **Unload Script** — Full cleanup of all ESP, connections, physics modifications, lighting restores, and drawings before unloading the UI
