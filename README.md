# 🎭 Item Asylum Hub
> **Game:** [Item Asylum](https://www.roblox.com/games/5670218884) | **Gamemode Focus:** Murder Party
> **UI Library:** [Rayfield](https://sirius.menu/rayfield) | **Author:** @jo2527 presleyyyyyyy

---

## ⚠️ Requirements
- A supported Roblox executor (Synapse X, KRNL, Fluxus, etc.)
- Must be executed inside **Item Asylum** (any gamemode/sub-place)

---

## 🔪 Murder Party

### 👥 Separation ESP
- Displays a role label above every player's head
- Color-coded by role:
  - 🔴 **Murderer**
  - 🔵 **Sheriff**
  - 🟢 **Innocent**
  - ⚫ **Dead**
- Individual role toggles — choose exactly who you want to see:
  - Show / Hide Innocents
  - Show / Hide Sheriff
  - Show / Hide Murderer
  - Show / Hide Dead players
- Role detection based on equipped tools:
  - Murderer identified by `mu_` tool prefix (covers all random knife variants)
  - Sheriff identified by `Mad Sheriff` / `Mad Handgun` exact name match
- Role updates every 2 seconds — accurate mid-round

---

### 🔫 Gun Drop ESP
- Automatically watches every player for a Sheriff death event
- When a Sheriff dies, pins a **gold billboard marker** at the exact death position
- Marker displays:
  - `🔫 GUN DROPPED HERE`
  - Name of the Sheriff who died
- **Auto-removes** when the gun is picked up by an Innocent (watches `AncestryChanged`)
- 30-second fallback removal if gun is not found
- Manual **Clear All Markers** button
- Only fires for confirmed Sheriffs — Innocents and Murderers never trigger it

---

### 📁 Clue ESP
- Scans workspace for **active, collectable clues only**
- Detection criteria: part must have both a `Highlight` AND a `UsePrompt` (ProximityPrompt) child
- Inactive or decorative clue spots are ignored
- Displays distance label on each clue billboard
- Auto-removes when a clue is collected or deactivated
- Reacts instantly to newly spawned clues via `DescendantAdded`

---

### 🎯 Clue Collection — Two Modes (Mutually Exclusive)

#### 🚶 Auto Walk & Collect
- Automatically walks your character to each active clue on the map using `Humanoid:MoveTo()`
- Fires the `UsePrompt` ProximityPrompt when within configurable range (default: 8 studs)
- Skips clues that are collected mid-route
- 5-second timeout per clue to skip unreachable ones
- Adjustable **Fire Range** slider (3–20 studs)

#### ⚡ Instant Collect (Near)
- Passive mode — no movement required
- Automatically fires the `UsePrompt` ProximityPrompt on any active clue within range
- Walk manually and clues collect themselves as you pass by
- Adjustable **range slider** (3–200 studs, default: 200)

---

## ☀️ Visuals

### 💡 Fullbright
- Overrides all `Lighting` service properties to maximum brightness
- Counters the **electricity cut** event where the murderer darkens the map
- Re-enforces values every 1 second to fight server-side lighting resets
- Restores original lighting values on disable
- Properties overridden:
  - `Brightness`, `ClockTime`, `GlobalShadows`
  - `Ambient`, `OutdoorAmbient`
  - `FogEnd`, `FogStart`

### 🌫️ No Fog
- Removes all client-side fog effects
- Targets both `Lighting` fog properties and the `Atmosphere` instance
- Re-enforces every 1 second to fight server-side fog resets
- Properties cleared:
  - `Lighting.FogEnd` / `Lighting.FogStart`
  - `Atmosphere.Density`, `Haze`, `Offset`, `Glare`
- Restores original values on disable

---

## ✈️ Movement

### Fly Mode
- Free-fly with `WASD` for direction, `E` to go up, `Q` to go down
- Uses modern `LinearVelocity` + `AlignOrientation` constraints
- Camera-relative direction
- Adjustable speed (10–200)
- Auto-restores on character respawn

### Custom Walk Speed
- Overrides `Humanoid.WalkSpeed` in real time via `Heartbeat`
- Adjustable (16–200)
- Resets to default 16 on disable

---

## ⚔️ Combat

### Kill Aura
- Automatically activates your equipped tool when a player enters range
- Adjustable range slider (5–50 studs)
- Works on any tool via `Tool:Activate()`
> ⚠️ Server-side detectable depending on the game's anti-cheat

---

## 🌐 Server Management

| Feature | Description |
|---|---|
| **Rejoin** | Reconnects to the same server instance |
| **Server Hop** | Finds and joins a different server via the Roblox public API |
| **Auto Rejoin on Kick** | Automatically rejoins the same server when a disconnect/kick is detected |
| **Auto ServerHop on Kick** | Automatically hops to a new server on kick (takes priority over Auto Rejoin) |

- Kick detection monitors `CoreGui` for `ErrorPrompt` / `DisconnectedScreen` frames every 0.5s

---

## 💾 Config System

| Feature | Description |
|---|---|
| **Save Config** | Saves all current settings to a named `.json` file |
| **Load Config** | Loads and applies a saved config, syncing all UI toggles and sliders |
| **AutoRun** | Designate a config to auto-load every time the script executes |
| **Delete Config** | Removes a saved config file permanently |

- Configs stored in: `ItemAsylum_Configs/` folder
- All dropdowns refresh automatically after save/delete
- UI fully syncs on config load (no visual mismatch between state and toggle position)
- Saved values include all ESP toggles, collect modes, visuals, movement, and server settings

---

## 🛠️ Technical Notes

- **No game validation check** — runs in any sub-place under Item Asylum's universe
- Role detection reads tools **at the moment of death** (not cached) — no false gun markers
- Clue detection uses a dual-condition check (Highlight + UsePrompt) to avoid false positives
- Fullbright and No Fog both use a 1-second re-enforcement loop to survive server-side lighting events
- All ESP uses `BillboardGui` with `AlwaysOnTop = true` — visible through walls
- Character respawn is handled for Fly, with automatic constraint cleanup and re-initialization
