# 🎯 Project-R
**A High-Speed, Low-Latency 4-Player Maze Battle Royale**

## 📖 The Blueprint
**Project-R** is a fast-paced, close-quarters 3D maze shooter built in Godot 4. Four players drop into a claustrophobic, skill-based environment where positioning, resource management, and parkour determine the winner. 

The game relies on a **Client-Server Authoritative** networking model to ensure ultra-low latency and perfectly synced combat.

### ⚙️ Core Mechanics
* **The Player Cap:** 4 Players per match. Intimate, tense, and tactical.
* **The Stamina System (The Leash):** Movement is heavily tied to a stamina bar (similar to Genshin Impact). Sprinting, dashing, or attempting to vault drains stamina quickly. 
	* *Why?* To prevent players from endlessly running away to escape fights. If you get caught out of position with no stamina, you have to fight your way out.
* **The Stamina System (The Leash):** Movement is tied to a stamina bar. Sprinting, dashing, or vaulting drains it. If you're out of position with no stamina, you're a sitting duck.
* **The Arsenal:** * **Pistol:** Reliable sidearm.
  * **Shotgun:** King of the maze corners.
  * **Sniper:** High risk/reward for long-sightline parkour spots.
  * **Unique Melee:** Each hero features a distinct melee weapon/style.
* **Scavenging (Loot):** Items are scattered throughout the maze and on top of inner walls:
  * **Ammo:** Essential for the three primary weapon types.
  * **Grappling Hook:** Key for verticality and escaping the maze center.
  * **Consumables:** Bandages for HP and Armor for protection.

---

## 🏗️ The World Layout
### Map System
* **High Outer Wall:** Encapsulates the arena. Peak is unreachable, preventing players from leaving the combat zone.
* **Uneven Inner Walls:** Designed for parkour. Players can climb and vault these to gain a height advantage or find loot.
* **The Central Maze:** A dense, high-occlusion ground-level area where most close-quarters combat occurs.

### Zone System
* **Sphere-Type Shrinking:** A natural, spherical contraction that forces players from the outer walls toward the maze center (or specific points). This creates a more organic "enclosing" feel than traditional linear borders.

---

## 🛰️ Technical Architecture (The Brain)
* **Engine:** Godot 4.x
* **Networking:** `ENetMultiplayerPeer` (Raw UDP)
* **Topology:** Headless Authoritative Server -> Dumb Clients
* **Latency Compensation:** * Client-Side Prediction (Local instant movement)
	* Server Reconciliation (The "Rubber Band" correction)
	* Entity Interpolation (Smooth enemy rendering)
  * Server Reconciliation (The "Rubber Band" correction)
  * Entity Interpolation (Smooth enemy rendering)

---

## 📁 Project Structure
To prevent merge conflicts and maintain strict separation of concerns, stick to your domain:

```text
Project-R/
├── assets/         # Raw files (3D Models, Textures, Audio, Fonts)
├── prefabs/        # Reusable instanced scenes
│   ├── player/     # Player capsule, Hitboxes
│   ├── weapons/    # Gun models, Muzzle flashes
│   ├── world/      # Maze walls, Floor tiles, Zone node
│   └── ui/         # Stamina bar, Killfeed, HUD
├── scripts/        # The code
│   ├── network/    # ENet bootstrapper, RPCs
│   ├── player/     # Movement, Stamina, Prediction
│   └── world/      # Zone math, Loot spawning
└── resources/      # Godot Custom Resources (.tres)
```

## 🗺️ Development Roadmap
* **🛡️ M1: The Network Skeleton** - Headless server boot and UDP binding.
* **🏃‍♂️ M2: The Leash** - Stamina UI and server-side drain calculation.
* **🔫 M3: The Arsenal** - Implementation of the Pistol, Shotgun, Sniper, and Hero-specific Melee.
* **🌋 M4: Requiem of the Maze** - Map generation (Inner/Outer walls) and the spherical shrinking zone.
* **📡 M5: The Match Loop** - 4-player lobby and loot spawning logic.
* **🎨 M6: The Polish** - Weapon sway, parkour feel, and UI juice.

## 📜 The Guild Codex
Before you write a single line of code, read the laws:
- [Git Protocol](./docs/GIT_PROTOCOL.md)
- [Godot Survival Guide](./docs/GODOT_SURVIVAL.md)
