# GOTO — Co-op Turn-Based Action Programmer

## Overview

**GOTO** is a cooperative Robo-Rally-inspired game where 1–4 players program robots with instructions to complete mission objectives on an isometric voxel map.

## Core Concept

Players control up to 4 robots on the same team. Each round, players receive a shared pool of random instructions and must communicate to distribute them optimally across the robots. When the round starts, all entities (robots + enemies) execute their instructions sequentially in randomized turn order.

## Robots

- Each robot has a maximum of **5 health points**
- Health = maximum instruction buffer size
- Taking damage destroys the next queued instruction and reduces buffer capacity
- Robots have a **facing direction** (N/E/S/W) that determines forward/backward/strafe
- All four robots are always on the same team

## Instructions

Instructions are single-use commands placed in a robot's buffer. Each round, empty buffer slots are filled with random instructions from the catalog.

### Common Instructions (12)
| Name | Effect |
|------|--------|
| Move Forward | Move 1 square in facing direction |
| Move Backward | Move 1 square opposite facing direction |
| Turn Left | Rotate 90° counter-clockwise |
| Turn Right | Rotate 90° clockwise |
| U-Turn | Rotate 180° |
| Strafe Left | Slide 1 square left without turning |
| Strafe Right | Slide 1 square right without turning |
| Shove Forward | Push entity in facing direction 2 squares |
| Shove All | Push all adjacent entities 1 square outward |
| Fire Laser | Shoot beam forward until hitting something |
| Sprint | Move 2 squares forward |
| Wait | Do nothing (skip turn) |

### Rare Instructions (8)
| Name | Effect |
|------|--------|
| Jump | Leap 2 squares forward (skips gaps) |
| Shield | Block next incoming damage (persists until used) |
| Fire Shotgun | Cone blast (3 squares, spread) |
| Self Destruct | Destroy self, deal 3 damage in radius |
| EMP | Disable adjacent enemy for 1 turn |
| Overclock | Execute next instruction twice |
| Repair | Heal 1 HP |
| Teleport | Random valid tile within 5 squares |

## Turn Flow

1. **PLANNING** — Players drag instructions from the shared pool into robot buffers. Turn order is displayed for all entities. Players can swap their robots' turn order using up/down.
2. **COUNTDOWN** — Any player presses "Start Round." A 5-second countdown begins. Pressing again cancels.
3. **EXECUTION** — Each entity executes one instruction in turn order. Animations play between each action.
4. **ROUND END** — Check win/loss conditions. Destroyed entities removed. Instruction pool refilled for next round.

## Turn Order

- Each round, turn order between all entities (robots + enemies) is randomized
- Turn order numbers displayed on-screen next to each entity
- Players can swap adjacent robot turn positions before the round starts

## Level Design

- Isometric view of a voxel-based map (up to 100×100 squares)
- Two voxel layers:
  - **Floor layer** — walkable tiles; gaps are fatal falls
  - **Wall layer** — obstacles that block movement and line of sight
- Outer perimeter is always walls or gaps (no open edges)
- Gaps cluster together in certain areas
- Levels contain mission objectives: exits, keys, doors, etc.

## Enemies

- Enemies have a repeating instruction set (e.g., Move, Move, Shoot, Turn Left)
- They execute in the same turn order system as robots
- Enemies can fall into gaps and be destroyed
- Placed around the level during generation

## Camera & Visibility

- **Rotate**: right-click drag
- **Zoom**: scroll wheel
- **Pan**: middle-click drag
- **Visibility**: 15-square radius line-of-sight from robots. Voxels/enemies obstructed by walls are hidden.

## HUD Layout

```
┌──────────────────────────────────────────────────┐
│  [Shared Instruction Pool - drag from here]      │
├────────────┬────────────┬────────────┬────────────┤
│ Robot 1    │ Robot 2    │ Robot 3    │ Robot 4    │
│ [1][2][3]  │ [1][2][X]  │ [1][2][3]  │ [1][X][X]  │
│ [4][5]     │ [3][X][X]  │ [4][5]     │ [2][X][X]  │
└────────────┴────────────┴────────────┴────────────┘
```

- Bottom of screen: 4 robot panels showing instruction buffers
- Damaged slots shown as X'd out
- Row above: shared instruction pool
- Click robot header to select/deselect control
- Drag instructions from pool to buffer; click buffer to return

## Multiplayer

- Players can join at any time
- A player can control 0 or more robots
- Multiple players can control the same robot
- Server discovery for LAN play
- Targets PC and Web via Godot's ENet networking

## Mission Objectives

- Simple: find the exit
- Multi-step: find key → unlock door → reach exit
- Future: escort, survive X rounds, destroy target
