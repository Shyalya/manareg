# ManaReg - WoW 3.3.5 Addon

A World of Warcraft 3.3.5 (WotLK) addon that tracks mana regeneration (5-second rule) and energy tick timing.

## Features

- **5-Second Rule Tracking**: Displays a timer showing when mana regeneration will resume after casting a spell
- **Energy Tick Tracking**: Shows countdown to next energy tick for energy-based classes (Rogues, Druids in cat form)
- **Customizable Display**: Draggable status bar with progress indicator
- **Simple Commands**: Easy slash commands to configure the addon

## Installation

1. Download or clone this repository
2. Copy the `ManaReg` folder to your `World of Warcraft/Interface/AddOns/` directory
3. Restart WoW or reload UI (`/reload`)

## Usage

The addon will automatically display:
- For mana users (Mage, Priest, Warlock, Paladin, Druid, Shaman): A timer showing how long until mana regeneration resumes after casting
- For energy users (Rogue, Druid in cat form): A countdown to the next energy tick

### Commands

- `/manareg` - Show help and available commands
- `/manareg toggle` - Enable/disable the addon
- `/manareg mana` - Toggle mana regeneration tracking
- `/manareg energy` - Toggle energy tick tracking
- `/manareg reset` - Reset all settings to defaults

### Customization

- **Move the bar**: Click and drag the status bar to reposition it anywhere on screen
- The position is automatically saved

## The 5-Second Rule

In WoW, mana regeneration from Spirit stops for 5 seconds after you cast a spell that costs mana. This addon helps you track when you can start regenerating mana again, which is crucial for efficient mana management.

## Energy Ticks

Energy regenerates in discrete ticks every 2 seconds. This addon shows you when the next tick will occur, helping you time your abilities better.

## License

Free to use and modify.
