# Harkwood

Harkwood is a Godot 4.5.1 hand-drawn 2D RPG prototype built around a compact loop: leave the Lantern Hearth, auto-battle through dangerous regions, bring materials home, craft and upgrade equipment, then push deeper into the woods.

## Prototype status — 0.2

The current build includes:

- Lantern Hearth hub with walk/click navigation and interactive stations.
- Hand-drawn hub, overworld, forest, quarry, Elder Hollow, actor, and item art.
- Three expedition regions with auto-combat, stances, healing draughts, bosses, rewards, and persistent clears.
- Four equipment slots, three crafting tiers, upgrades, storage, salvage, random quality, and random affixes.
- Enchanted gear now rolls two distinct affixes and enemy gear drops use a soft-pity system.
- Quest journal, player leveling, materials, gold, save backups, and recovery handling.
- Local simulated exchange remains available by default.
- Optional Supabase-backed player marketplace client and database schema are included for the live Exchange.

## Resolution scaling

The original prototype authored its UI at 1440×900 and relied on Godot stretch settings. On a 1920×1080 window this could leave the game surface pinned to the upper-left with a large unused area.

Version 0.2 uses a dedicated `resolution_scaler.gd` wrapper instead. The 1440×900 design surface is uniformly scaled and centered inside the actual window. This keeps the hand-positioned HUD/world layout intact while supporting common desktop sizes.

Recommended checks:

| Window | Expected result |
| --- | --- |
| 1280×720 | Full UI visible, small centered side margins |
| 1366×768 | Full UI visible, centered |
| 1600×900 | Full UI visible, centered |
| 1920×1080 | Full UI visible, centered with small side margins |
| 2560×1440 | Full UI visible, centered with small side margins |
| 1440×900 / 1920×1200 | Fills the 16:10 window closely |

Settings now exposes 1280×720, 1600×900, and 1920×1080 presets plus fullscreen. F11 still toggles fullscreen.

## Live player Exchange

The game automatically uses the live Exchange when `res://online_config.json` exists. Without it, the existing local simulated market remains active so the prototype is still fully playable offline.

The included live-market MVP uses Supabase anonymous authentication, Row Level Security, and transaction-safe purchase RPCs. A purchase locks the listing before moving gold so two buyers cannot purchase the same listing simultaneously.

### Backend setup

1. Create a dedicated Supabase project for Harkwood.
2. Enable **Anonymous Sign-Ins** in Supabase Auth.
3. Run `backend/harkwood_exchange.sql` in that project's SQL editor.
4. Copy `online_config.example.json` to `online_config.json`.
5. Fill in the project's API URL and publishable key.
6. Run Harkwood. The Exchange screen will switch from the local simulation to the shared player market.

The publishable key is intended for client applications; never place a Supabase secret/service-role key in the Godot project.

### Current trust boundary

This is still a prototype economy. Marketplace purchases are atomic on the server, but combat/crafting rewards are generated locally and wallet deltas are synchronized from the client. A player who edits their local save could therefore cheat the economy. Before a public release, progression rewards and item ownership should become server-authoritative.

## Project layout

- `scenes/main.tscn` — responsive outer shell and fixed design surface.
- `scripts/main.gd` — original game/screens/combat presentation coordinator.
- `scripts/harkwood_game.gd` — v0.2 integration layer for display settings, richer progression, and online Exchange.
- `scripts/core/` — catalog, state, battle simulation, and v0.2 progression state.
- `scripts/ui/` — palette, sound, responsive scaler, and world rendering.
- `scripts/online/marketplace_client.gd` — Supabase Auth/REST marketplace client.
- `backend/harkwood_exchange.sql` — online-market tables, RLS, and atomic RPC functions.
- `assets/art/` — hand-drawn environment, actor, and item sheets.

## Controls

WASD / arrows or click to move in the Hearth. E interacts with a nearby station. I opens the pack, M the wilds, C the forge, J the journal, and H returns to the Hearth. In combat, Q uses a healing draught and Space pauses. F11 toggles fullscreen.
