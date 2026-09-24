# Wonky Townhouse interior — tier 3

Crooked teal and terracotta wall bays, mismatched windows and offset rafters above a level floor.

Room dimensions: **64 wide × 40 long × 34 high**, in studs. Six separate pedestal slots. The pedestal, cash plate and interaction mounts retain their usable size. Rooms connect through `Root.Entry` and `Root.Exit`; the Builder supports adding rooms and removing individual pedestals.

Open `wonky-townhouse-interior-preview.rbxlx` in Studio for a two-room walkthrough. The static review's first gate is open and terminal gate is closed. Reference block avatars disappear locally when Play starts. The default follow camera has an 11-stud zoom cap.

`wonky-townhouse-interior-kit.rbxmx` supplies `WonkyTownhouseInteriorKit` for ServerStorage. Its four templates are `RoomShell`, `Pedestal`, `RebirthGate` and `AchievementVestibule`. Collection buttons are separate `Collect.CollectionPlate` and `Collect.CollectionInset` parts, and may be replaced with your own. `Root.Collect` marks the interaction position. `Root.Piggy` marks the display top. The entrance alcove is reserved for future achievements.

`wonky-townhouse-interior.blend` contains the assembled review and reusable template scenes. `exports/` contains four FBX modules; static material groups are merged there, so use the native kit for individual part edits. `preview/hall.png` renders the delivered geometry; lighting differs from the game.

**468 Studio geometry checks passed.** The catalogue also verifies these kits through the game's ThemedInterior wrapper. See [catalogue instructions](../README.md) for build commands, integration and the tier-size rule.
