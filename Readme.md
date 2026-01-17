# Guild Loot Distribution

A World of Warcraft guild addon for managing loot distribution queues, tracking player eligibility, and organizing raid loot fairly.

## Features

### Core Functionality
- **Loot Queue Management**: Add items to a queue and manage distribution order
- **Player Eligibility Tracking**: Track armor type preferences, weapon preferences, and class specifications
- **Vote System**: Cast votes on loot distribution (pass, need, greed)
- **Attendance Tracking**: Monitor raid attendance and player participation

### Admin Features
- **Test Panel**: Simulate loot distributions with test data before live rolls
- **Raid History**: Track historical sessions with loot tracking and vote details
- **Player Specification Sync**: Automatic detection and caching of player specs via inspect API
- **Administrative Overrides**: Fine-tune eligibility and vote outcomes

### Test System
- **Separated Test Data**: Experimentation without affecting main records
- **Test History UI**: Full history of test sessions with filtering and details
- **Visual Graphs**: Class-colored win rate graphs for analyzing distribution patterns

## Installation

1. Download the latest release from [CurseForge](https://www.curseforge.com/wow/addons/guild-loot-distribution)
2. Extract to your `Interface/AddOns` directory
3. Restart World of Warcraft
4. Type `/gld` in-game to open the main interface

## Usage

### Guild Officers (Admins)
- Open the admin panel to configure loot distribution rules
- Use the test panel to simulate distributions before going live
- Review raid history and player statistics

### Guild Members
- View available loot in the queue
- Cast votes on loot distribution (pass, need, greed)
- Check your attendance and eligibility status

## Configuration

The addon stores configuration in your SavedVariables:
- `GuildLootDB`: Guild-wide settings and loot history
- `GuildLootShadow`: Per-character settings

## Requirements

- World of Warcraft 12.0.1+ (WoW expansion compatible)
- Ace3 libraries (bundled)

## Development

### File Structure
```
Core.lua              - Addon initialization and event handling
Utils.lua             - Utility functions for player/item management
ClassData.lua         - Class/spec/weapon preference database
DB.lua                - Database schema and initialization
Authority.lua         - Permission and role management
Queue.lua             - Loot queue management
Attendance.lua        - Raid attendance tracking
Spec.lua              - Player specification detection and sync
Comms.lua             - Guild communication handling
Item.lua              - Item eligibility checking
Loot.lua              - Loot distribution logic
Config.lua            - Configuration UI and settings
UnitPopup.lua         - Unit right-click menu extensions
GuildUI.lua           - Guild management UI
Minimap.lua           - Minimap button
TestData.lua          - Test data structures
UI/Main.lua           - Main roster and queue UI
UI/Admin.lua          - Admin panel
UI/TestUI.lua         - Test panel and graphs
UI/HistoryUI.lua      - Raid history viewer
```

### Class/Spec System

The addon includes a comprehensive database of all WoW classes with their specs, armor types, and weapon preferences:

- **Armor Types**: Cloth, Leather, Mail, Plate
- **Weapon Preferences**: Per-spec weapon type mappings (2H, 1H+Shield, 1H+Offhand, etc.)
- **Role Detection**: Automatic role assignment from talent specs

### Spec Synchronization

Player specifications are automatically detected via:
- Inspect API queue with rate limiting (0.3s between calls)
- Caching to reduce API calls
- Event listeners for mid-session spec changes
- Integration with raid group roster updates

## Version History

### v0.2.0
- ✅ Separated test sessions with dedicated database
- ✅ Test history UI with filtering and session details
- ✅ Experimental test graphs with class-colored win rates
- ✅ Centralized class/spec/role/weapon preference database
- ✅ Automatic player spec detection and sync
- ✅ Spec display in both main and test rosters
- ✅ Loot choice panel toggle in admin test panel
- ✅ Admin panel layout polish and spacing fixes

### v0.1.0
- Initial release with core loot queue management

## Support

For bug reports, feature requests, or questions:
- GitHub Issues: [GitHub Repository](https://github.com/yourgithub/GuildLootDistribution)
- CurseForge Comments: [CurseForge Page](https://www.curseforge.com/wow/addons/guild-loot-distribution)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Credits

- Built with Ace3 framework
- WoW API documentation from Warcraft Wiki
