## [3.2](https://github.com/ZelionGG/KeystonePolaris/releases/tag/3.2) (2026-01-17)

[Full Changelog](https://github.com/ZelionGG/KeystonePolaris/compare/3.1.1...3.2) [Previous Releases](https://github.com/ZelionGG/KeystonePolaris/releases)

> 🚀 Big one. Probably the biggest Keystone Polaris update shipped “under the hood” so far: tons of performance/loading work and internal cleanups, plus visible wins like Group Reminder and Season start/end warnings.
> Please send feedback and bug reports, with a release this big, your reports really help.

### Important
- Added the **Commands** section to the **General options** and a new **Help** command.

### New
- Addon name is now using gradient coloring in chat and UI headers.
- ❗ Added the **Group Reminder** module, showing a popup on group invite with an optional chat recap (dungeon, group name, role).
- Added a **Minimap icon** with a toggle in the **General options**.
- Added a **Compartment icon** toggle in the **General options**.
- Added full support for all **Legion** Dungeons.
- Introduced the new **Remix** options category (yes, I know, it's a bit late...).
- Season start dates (and end dates) are now displayed directly in the **Options** menu.
- Automated the retrieval of boss names using Blizzard's API for better accuracy.
- Initial preparation for the upcoming **Midnight Season 1**.
- Added a **Modules** section to the right panel of the **Modules** menu.

### Bugfixes
- Fixed **Import All Dungeons** returning **Invalid import string**.

### Improvements
- ❗ Massive code reorganization and cleanup for better performance and easier maintenance.
- Added informative placeholders in the options menu for dungeons that are not yet implemented.
- Optimized locale initialization to reduce load times.
- Russian locale updated (thank you again **Hollicsh**).

