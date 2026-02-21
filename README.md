# GOTO

**GOTO** is a tactical, programmable movement game where you control a team of robots in a dangerous, grid-based arena.

## 🎮 Gameplay
- **Programmable Turns**: Plan your robots' actions (Move, Turn, Fire, Shove) and then execute them simultaneously with enemies.
- **Telegraphed AI**: Enemies announce their intentions! Use the **Execution Order** panel to reorder your robots and dodge incoming fire.
- **Tactical Combat**: Use lasers, shotguns, and shoves to manipulate the battlefield and destroy hostile entities.
- **Objectives**: Collect the key to unlock the gate and reach the exit.

## 🛠️ Technology
- **Engine**: Godot 4.4.1 (OpenGL Compatibility Renderer)
- **Language**: GDScript 2.0
- **Level Generation**: Procedural room-based floor and wall layout.

## 🚀 How to Run
1. Ensure you have the Godot 4.4.1 executable.
2. Run `run_game.ps1` in a PowerShell terminal.

## 🧪 Development
- Use `validate.ps1` to perform headless validation of all scripts.
- Scripts are organized in `/scripts`, and logic is orchestrated by `GameManager` (Autoload).
