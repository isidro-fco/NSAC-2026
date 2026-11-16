# Little Big Steps Martian Colony

> An educational resource-management game set on Mars for kids ages 7–12, powered by **real** NASA space weather data.

**NASA Space Apps Challenge 2026** · Challenge: [*Build a Junior Astronaut Mission Trainer*](https://www.spaceappschallenge.org/2026/challenges/junior-astronaut-mission-trainer/) · Team **CiberBugs** 🇲🇽

![Godot](https://img.shields.io/badge/Godot-4.5-478CBF?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-language-355570)
![NASA DONKI](https://img.shields.io/badge/data-NASA%20DONKI-E03C31)
![Languages](https://img.shields.io/badge/languages-ES%20%7C%20EN-success)

---

## Table of contents

- [Summary](#summary)
- [Description](#description)
- [Features](#features)
- [Real NASA data](#real-nasa-data)
- [How to play](#how-to-play)
- [Controls](#controls)
- [Installation and running](#installation-and-running)
- [Project structure](#project-structure)
- [Tech stack](#tech-stack)
- [Team](#team)
- [Credits and sources](#credits-and-sources)
- [AI disclosure](#ai-disclosure)
- [Future work](#future-work)
- [License](#license)

---

## Summary

**Little Big Steps Martian Colony** is a resource-management game for kids ages 7–12 in which they run a small outpost on Mars and make the decisions that keep their crew safe. Players assign colonists to tasks and missions, then decide how to use the oxygen, water, food, power and budget they bring back. Every choice has a cost: powering the radiation shelter leaves less energy for the greenhouse, and supplies, new colonists and funds from Earth arrive several sols late because of the communication delay.

The Sun in the game is real: solar flares, coronal mass ejections, particle events and geomagnetic storms come from NASA's **DONKI** space weather database, shown in the order they actually happened and clearly labeled *"Real NASA data"*, with what really happened kept separate from its effect on the colony. A guided tutorial, an interactive glossary and *"Did you know?"* facts linked to NASA sources turn each decision into a STEM lesson. The game is playable in **Spanish and English**.

---

## Description

*Little Big Steps Martian Colony* is a 2D top-down game made in **Godot 4.5** in which players found and manage a colony on Mars. Living off-Earth means balancing power, food, water, oxygen and radiation protection with limited resources, and these engineering trade-offs are hard to explain to a child with text alone. In our game, players learn them **by making them**: every module, task and event has a cost and a consequence measured in real units.

How it addresses the *Junior Astronaut Mission Trainer* challenge:

| Challenge topic | In the game |
|---|---|
| **Power** | A grid in kW with a 5,000 kWh battery. The base generates 100 kW and its first modules use 80 kW; each solar panel adds 20 kW and each new module adds consumption. If the battery runs out, the base shuts down. |
| **Food** | Agriculture module, rations (abundant, normal or strict) that change productivity and illness risk, a kitchen with recipes, and supply orders from Earth that take several sols to arrive. |
| **Shielding** | Each colonist accumulates a radiation dose; during a real solar storm, anyone inside the Shielded Shelter receives zero dose, but keeping it ready costs power. |
| **Life support** | 0.86 kg of O₂, 4 L of water and 1.3 kg of food per colonist per sol. Life Support produces 5.2 kg of O₂ per sol and recycles 80% of the water; the Ice Drill extracts 5 L per sol. |
| **Limited resources** | Every module costs money, materials and power; every event offers two choices with different costs. |

---

## Features

- **Time in sols** (Martian days) of 60 seconds, with pause and 1×/2×/4× speed.
- **11 buildable modules** on a grid map: Command, Storage & Kitchen, Quarters, Life Support, Agriculture, Solar Panel, Ice Drill, Workshop, Shielded Shelter, Corridor and Landing Pad. Rocks and craters must be cleared first.
- **Colonists** with four specialties (Engineering, Astroagronomy, Life Support, Science) who move around the base on their own and are assigned to **9 tasks** (cleaning solar panels, extracting regolith, tending crops, recycling water…).
- **Earth–Mars delay**: new colonists, supplies and funds arrive several sols late, like on a real mission.
- **9 incidents** with two-option decisions: water recycler leak, dust storm, crop blight, perchlorates in the water, MOXIE failure, meteorite strike, and more.
- **Real space weather** from NASA DONKI (see below).
- **Built-in learning**: guided tutorial, 31-term glossary (highlighted words open their definition), chainable tooltips, alerts with suggestions that jump to the problem, and 33 *"Did you know…?"* facts with links to NASA, JPL and other sources.
- **Spanish and English**, keyboard navigation, sound effects and adjustable volume.
- **Works offline**, because classrooms do not always have internet.

**Victory:** upgrade the Command Module to its maximum level.
**Defeat:** running out of power, or 5 sols without oxygen, water or food.

---

## Real NASA data

Solar activity comes from **NASA DONKI** (*Space Weather Database Of Notifications, Knowledge, Information*), run by the CCMC at NASA Goddard. The game reads 8 event types:

| Code | Event |
|---|---|
| FLR | Solar flares |
| CME | Coronal mass ejections (including the WSA-ENLIL arrival at Mars) |
| SEP | Solar energetic particles |
| GST | Geomagnetic storms |
| IPS | Interplanetary shocks |
| HSS | High-speed streams |
| MPC | Magnetopause crossings |
| RBE | Radiation belt enhancements |

- The game requests the **last 120 days** in 59-day chunks from the CCMC API (`ccmc.gsfc.nasa.gov/DONKI-API`), with `api.nasa.gov` as a fallback.
- Events appear **in the order they really happened**. Each window separates **"what actually happened"** (date, value, source and link) from **"what happens in the colony"**.
- CMEs take time to arrive based on their real speed (228 million km divided by their speed).
- **Without internet**, the game uses the last cached query or a pre-downloaded file. An indicator always shows whether the data is *live*, *cached* or *from a file*.

More details (in Spanish) in [`datos/nasa/LEEME.md`](datos/nasa/LEEME.md).

---

## How to play

1. The game starts in English; to play in Spanish, open **Options** from the start menu and switch the language (it is saved for next time). Then start a new game — the tutorial guides you through the first steps.
2. **Build modules** on the map, making sure the power you generate covers what you consume.
3. **Assign colonists** to tasks based on their specialty to produce oxygen, water, food and materials.
4. Adjust **rations**, place **orders from Earth** and plan ahead: everything arrives late.
5. When a **real solar event** hits, send the crew to the **Shielded Shelter**.
6. Resolve **incidents** by choosing between two options, and check the **logbook** to understand what happened.
7. Upgrade the **Command Module** to its maximum level to win.

## Controls

| Action | Key / mouse |
|---|---|
| Move the camera | `W` `A` `S` `D`, arrow keys, or drag with the mouse |
| Zoom | Mouse wheel |
| Pause / resume | `Space` |
| Build mode | `B` |
| Glossary | `G` |
| Logbook | `L` |
| Close menu / options | `Esc` |

---

## Installation and running

### Requirements

- [Godot Engine **4.5**](https://godotengine.org/download/) (standard version; the project uses the *GL Compatibility* renderer).
- Internet connection **optional** (for live solar data).
- Python 3 **optional** (only to download DONKI data without opening the game).

### Open and play from source

```bash
git clone https://github.com/isidro-fco/NSAC-2026.git
cd NSAC-2026
```

1. Open Godot 4.5 → **Import** → select the `project.godot` file.
2. Press **F5** (or the ▶ *Run Project* button). The main scene is `escenas/inicio/inicio.tscn`.

You can also run it from the terminal:

```bash
godot --path .
```

### NASA API key (optional)

The CCMC API **does not require a key**. The key is only used for the `api.nasa.gov` fallback; without it, `DEMO_KEY` is used. To use your own:

1. Generate a free key at <https://api.nasa.gov>.
2. Paste only the key into `datos/nasa/clave_api.txt` (this file should not be committed to the repository).

### Download DONKI data to play offline (optional)

```bash
python3 herramientas/descargar_donki.py                       # last 365 days
python3 herramientas/descargar_donki.py 2024-05-01 2024-05-31  # specific range
```

Events are saved to `datos/nasa/archivo_donki.json`, which the game uses when there is no connection.

### Export

In Godot: **Project → Export…**, add a preset (Windows, Linux, macOS or Web) and export. The Godot 4.5 *export templates* are required.

---

## Project structure

The source code and folder names are in Spanish.

```
NSAC-2026/
├── project.godot          # Godot project configuration
├── comun/                 # Shared enums, colonist data and language helpers
├── datos/                 # Editable data (balance, modules, glossary, facts, candidates)
│   ├── clases/            # Resource classes (.tres)
│   ├── modulos/           # Definition of each module
│   └── nasa/              # Optional API key, curated events and offline DONKI file
├── escenas/               # Scenes
│   ├── inicio/            # Start menu
│   ├── juego/             # Main game scene and camera
│   ├── mapa/              # Map, grid, pathfinding, obstacles, corridors
│   ├── colonos/           # Colonist behavior
│   ├── modulos/           # Module behavior
│   └── interfaz/          # HUD, menus, components, tooltips, tutorial and styling
├── globales/              # Autoloads
│   ├── gestor_tiempo.gd   # Sol clock, pause and speed
│   ├── gestor_audio.gd    # Music and sound effects
│   ├── estado_juego.gd    # Global game state
│   ├── nasa/              # DONKI client and NASA data service
│   └── sistemas/          # Game rules: one system per domain
├── herramientas/          # Python scripts (DONKI download, graphics generation)
├── recursos/              # Sprites, fonts and audio
└── traducciones/          # English translation (en.po)
```

**Architecture.** The code separates the **clock** (`GestorTiempo`), the **game rules** (10 systems in `globales/sistemas/`: storage, space weather, command, facts, economy, events, glossary, tasks, Earth and crew) and the **interface** (`escenas/interfaz/`). Balance values, modules, glossary and facts live in data files (`datos/*.tres`) that can be tuned without touching code.

---

## Tech stack

- **Godot Engine 4.5** and **GDScript**
- **NASA DONKI API** (CCMC) and **NASA Open APIs**
- **Python 3** to download DONKI data and generate some graphics
- **Aseprite** and **Paint Tool SAI** for pixel art
- **Figma** for ideation and prototyping
- **Canva** for the presentation
- **Git / GitHub** for version control and collaboration

---

## Team

**CiberBugs** — Mexico 🇲🇽

| Member | Space Apps username |
|---|---|
| Isidro Francisco Pérez Paz *(team owner)* | @isidro-fco |
| Héctor Alfredo Vásquez Carpio | @hectorvasquez |
| Ángel Rey Rodríguez | @tromil |
| Óscar Crespo Sánchez | @ocrespo |
| Jaaziel Arellano Romero | @jaaziel_arellano |
| Fernanda Itzel Flores Valenzuela | @pinapin |

---

## Credits and sources

### NASA data and resources

- [NASA DONKI – Space Weather Database (CCMC, NASA Goddard)](https://ccmc.gsfc.nasa.gov/DONKI/)
- [NASA DONKI API (CCMC web service)](https://ccmc.gsfc.nasa.gov/DONKI-API/)
- [NASA CCMC – DONKI tool page](https://ccmc.gsfc.nasa.gov/tools/DONKI/)
- [NASA Technology Transfer – DONKI (GSC-TOPS-223)](https://technology.nasa.gov/patent/GSC-TOPS-223)
- [NASA Open APIs](https://api.nasa.gov/)
- [NASA Science – Mars Facts](https://science.nasa.gov/mars/facts/)
- [NASA – The Human Body in Space](https://www.nasa.gov/humans-in-space/the-human-body-in-space/)
- [NASA – Risk of Spaceflight-Induced Bone Changes](https://www.nasa.gov/reference/risk-of-spaceflight-induced-bone-changes/)
- [NASA – Risk of Spaceflight Associated Neuro-ocular Syndrome](https://www.nasa.gov/reference/risk-of-spaceflight-associated-neuro-ocular-syndrome/)
- [NASA – ISS Research Explorer](https://www.nasa.gov/mission/station/research-explorer/)
- [NASA – X-class solar flares](https://www.nasa.gov/missions/science/f_xflare.html)
- [NASA – Apollo 11 astronauts leave quarantine](https://www.nasa.gov/history/50-years-ago-apollo-11-astronauts-leave-quarantine/)
- [NASA Science – Perseverance landing site](https://science.nasa.gov/mission/mars-2020-perseverance/landing-site/)
- [NASA JPL – Ingenuity helicopter mission ends](https://www.jpl.nasa.gov/news/after-three-years-on-mars-nasas-ingenuity-helicopter-mission-ends/)
- [NASA JPL – Perseverance microphone captures sounds of Mars](https://www.jpl.nasa.gov/news/nasas-perseverance-rover-microphone-captures-sounds-of-mars/)
- [NASA JPL – InSight: Mars at a glance](https://www.jpl.nasa.gov/news/press_kits/insight/launch/facts/mars-at-a-glance)
- [NASA JPL – Mars meteorites](https://www2.jpl.nasa.gov/snc/)
- [NASA Astrobiology – Opportunity rover mission comes to an end](https://astrobiology.nasa.gov/news/opportunity-rover-mission-comes-to-an-end/)

### Other sources

- [Godot Engine](https://godotengine.org/) (MIT license)
- [Australian Bureau of Meteorology – Space Weather report, May 9, 2024](https://listserver.ips.gov.au/pipermail/ips-dsgr/2024-May/008773.html)
- [Wikipedia – May 2024 solar storms](https://en.wikipedia.org/wiki/May_2024_solar_storms)
- [Phys.org – NASA watches Mars light up during epic solar storm](https://phys.org/news/2024-06-nasa-mars-epic-solar-storm.html)
- [SwRI – Radiation exposure of a trip to Mars](https://www.swri.org/newsroom/press-releases/swri-led-team-calculates-the-radiation-exposure-associated-trip-mars)
- [International Potato Center – Potatoes can grow on Mars](https://cipotato.org/press_room/press-releases/indicators-show-potatoes-can-grow-mars/)
- [The Planetary Society – How long does it take to get to Mars](https://www.planetary.org/articles/how-long-does-it-take-to-get-to-mars)
- [The Planetary Society – Perseverance](https://www.planetary.org/space-missions/perseverance)
- [Space.com – Proof of water ice on Mars](https://www.space.com/5546-proof-water-ice-mars.html)
- [Space.com – Mars blue sunset (Curiosity)](https://www.space.com/29368-mars-blue-sunset-curiosity-rover-video.html)
- [Space.com – ISS air leak](https://www.space.com/41684-international-space-station-air-leak.html)
- [Space.com – ISS 98% water recycling](https://www.space.com/astronaut-pee-iss-water-recycling-98-percent-milestone)
- [Space.com – Perseverance MOXIE oxygen experiment ends](https://www.space.com/perseverance-mars-rover-ends-moxie-oxygen-experiment)
- [EarthSky – InSight falls silent](https://earthsky.org/space/insight-falls-silent-nasa-declares-mission-end/)
- [Phys.org – Space-grown lettuce](https://phys.org/news/2015-08-space-grown-lettuce-awesome.html)
- [collectSPACE – 3D printing in space](https://www.collectspace.com/news/news-112514c-made-in-space-3d-printing.html)

### Fonts

- [Manrope](https://fonts.google.com/specimen/Manrope), [Press Start 2P](https://fonts.google.com/specimen/Press+Start+2P) and [Righteous](https://fonts.google.com/specimen/Righteous) — Google Fonts, SIL Open Font License 1.1.

---

## AI disclosure

Parts of the code, debugging and the English translation were made with the help of an AI coding assistant (Claude). All game design, data choices and testing were done by the team.

---

## Future work

- Save and load games.
- Calibrate radiation with measurements from the Curiosity rover's RAD instrument.
- Playtest with kids aged 7–12.
- Moon mode.

---

## License

Created for the **NASA Space Apps Challenge 2026**. NASA data is in the public domain; the fonts are distributed under the SIL OFL 1.1 and Godot Engine under the MIT license.
