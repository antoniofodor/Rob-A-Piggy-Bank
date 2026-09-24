# Uploaded ids whose only copy is an untracked batch folder

Written 2026-09-23 by the `assets/` cleanup pass, as insurance. **Read this before
deleting anything under `arcade-build-v1/`, `og-refresh-v2/` or
`approved-imports-20260923/`.**

CLAUDE.md records that the Roblox Assets API has no list endpoint, so an uploaded id
written down nowhere is unrecoverable -- and that 58 sheets were uploaded twice for
exactly that reason. Every id below was found in one of those three folders and
appears in **no** file under `src/`, `docs/`, `import/`, `CLAUDE.md` or any per-key
folder under `<tier>/<key>/`.

None of those folders is proposed for deletion -- all three are live tooling, and
`BATCH-FOLDERS.md` beside this file says why. This ledger exists so the ids survive
the folders if anybody ever changes that.

## The arcade legendary mesh imports

Per-part MESH uploads from the arcade builds. **The game does not read them:**
`Config.SKINS.finalboss`, `.jackpot` and `.mechaplayer` each carry `authoredCoat =
true` and a `surface` pack, so the shipped skin is a baked coat painted onto the
ordinary pig body and has no per-part geometry at all. These are orphaned uploads in
the sense of `docs/ORPHANED-UPLOADS.md`, which is where they belong; whoever merges
them there can delete this section.

### finalboss, v1 import -- 22 meshes

Source: `arcade-build-v1/imported-finalboss.json`

| part | asset id |
| --- | --- |
| `BossEnergy_-1_0` | 110891580845771 |
| `BossEnergy_-1_1` | 135513803499025 |
| `BossEnergy_-1_2` | 128360910361468 |
| `BossEnergy_1_0` | 130546389699567 |
| `BossEnergy_1_1` | 115342646226174 |
| `BossEnergy_1_2` | 116157885956902 |
| `BossGuard_-1_0` | 116337871218221 |
| `BossGuard_-1_1` | 107397301239823 |
| `BossGuard_1_0` | 129823214176345 |
| `BossGuard_1_1` | 93779544199604 |
| `BossHinge_-1_0` | 83560466806989 |
| `BossHinge_-1_1` | 109682582563938 |
| `BossHinge_1_0` | 98254058508175 |
| `BossHinge_1_1` | 109682582563938 |
| `BossInset_-1_0` | 83461396588441 |
| `BossInset_-1_1` | 70439227023656 |
| `BossInset_1_0` | 87621923836575 |
| `BossInset_1_1` | 111133082427453 |
| `OrbitPrism_Boss_-1_0` | 88827977018669 |
| `OrbitPrism_Boss_-1_1` | 140184639168347 |
| `OrbitPrism_Boss_1_0` | 119555584094447 |
| `OrbitPrism_Boss_1_1` | 120072540069750 |

### finalboss, v2 import -- 45 meshes

Source: `arcade-build-v1/imported-finalboss-v2.json`

| part | asset id |
| --- | --- |
| `BossBackGem` | 123494543036610 |
| `BossBackInset` | 95202442845835 |
| `BossBackSpine` | 73002662267982 |
| `BossHipPlate_-1_0` | 124600232318449 |
| `BossHipPlate_-1_1` | 94098010233814 |
| `BossHipPlate_1_0` | 108083453332665 |
| `BossHipPlate_1_1` | 114148420727293 |
| `BossHipRim_-1_0` | 120031993671993 |
| `BossHipRim_-1_1` | 79214161619246 |
| `BossHipRim_1_0` | 89485468851916 |
| `BossHipRim_1_1` | 98002933946369 |
| `BossPauldronGem_-1` | 122073188869845 |
| `BossPauldronGem_1` | 96700017164111 |
| `BossPauldronPlate_-1` | 86322001708252 |
| `BossPauldronPlate_1` | 75604028499967 |
| `BossPauldronRim_-1` | 102097888339042 |
| `BossPauldronRim_1` | 107234208165441 |
| `BossPivotCore_-1_0` | 135800916056427 |
| `BossPivotCore_-1_1` | 71887554932462 |
| `BossPivotCore_1_0` | 127687612141107 |
| `BossPivotCore_1_1` | 77543844331673 |
| `BossPivot_-1_0` | 127638699557824 |
| `BossPivot_-1_1` | 74181446008964 |
| `BossPivot_1_0` | 100935989439588 |
| `BossPivot_1_1` | 111484790845422 |
| `BossRearCrystal_-1_0` | 102518395988712 |
| `BossRearCrystal_-1_1` | 85260997717556 |
| `BossRearCrystal_1_0` | 89198963214284 |
| `BossRearCrystal_1_1` | 100648883366026 |
| `BossRearSocket_-1_0` | 98211659509928 |
| `BossRearSocket_-1_1` | 76460863376110 |
| `BossRearSocket_1_0` | 98211659509928 |
| `BossRearSocket_1_1` | 76460863376110 |
| `BossShellBorder_-1_0` | 108988555816523 |
| `BossShellBorder_-1_1` | 82309599026273 |
| `BossShellBorder_-1_2` | 97083455330078 |
| `BossShellBorder_1_0` | 126657065884910 |
| `BossShellBorder_1_1` | 121514362389435 |
| `BossShellBorder_1_2` | 72313350600148 |
| `BossShellPanel_-1_0` | 101731310131333 |
| `BossShellPanel_-1_1` | 94328731673878 |
| `BossShellPanel_-1_2` | 114824644085163 |
| `BossShellPanel_1_0` | 113249844057020 |
| `BossShellPanel_1_1` | 81103715092081 |
| `BossShellPanel_1_2` | 119186198470637 |

### jackpot, v1 import -- 7 meshes

Source: `arcade-build-v1/imported-jackpot.json`

| part | asset id |
| --- | --- |
| `GoldToken_0` | 131150719113481 |
| `GoldToken_1` | 134014157030484 |
| `GoldToken_2` | 105376922489306 |
| `GoldToken_3` | 114859959872856 |
| `GoldToken_4` | 124244537965494 |
| `GoldToken_5` | 102151997034237 |
| `ReelSaddle` | 88813089965980 |

### jackpot, v2 import -- 16 meshes

Source: `arcade-build-v1/imported-jackpot-v2.json`

| part | asset id |
| --- | --- |
| `GoldToken_0` | 131150719113481 |
| `GoldToken_1` | 134014157030484 |
| `GoldToken_2` | 105376922489306 |
| `GoldToken_3` | 114859959872856 |
| `GoldToken_4` | 124244537965494 |
| `GoldToken_5` | 102151997034237 |
| `JackpotLampSocket_-1_5` | 129869300997152 |
| `JackpotLampSocket_1_0` | 121311795721067 |
| `JackpotLampSocket_1_4` | 89178880040284 |
| `JackpotLamp_-1_1` | 98144345564635 |
| `JackpotLamp_1_0` | 85650676077851 |
| `JackpotRivet_-1_1` | 134955079939131 |
| `JackpotRivet_-1_2` | 140658920997365 |
| `JackpotRivet_1_1` | 80487591720239 |
| `JackpotRivet_1_2` | 140658920997365 |
| `JackpotRivet_1_3` | 90704630591633 |

### mechaplayer, v1 import -- 26 meshes

Source: `arcade-build-v1/imported-mechaplayer.json`

| part | asset id |
| --- | --- |
| `BootSignal_-1_0` | 79203875259707 |
| `BootSignal_-1_1` | 119001272538929 |
| `BootSignal_1_0` | 79203875259707 |
| `BootSignal_1_1` | 119001272538929 |
| `MechBoot_-1_0` | 93100700755547 |
| `MechBoot_-1_1` | 135468377190091 |
| `MechBoot_1_0` | 82035927974265 |
| `MechBoot_1_1` | 109297868699736 |
| `MechGuardInset_-1` | 133711444401235 |
| `MechGuardInset_1` | 126725845254973 |
| `MechGuard_-1` | 97244053457686 |
| `MechGuard_1` | 74522327906671 |
| `MechWarning_-1` | 107385094503299 |
| `MechWarning_1` | 131932409290418 |
| `ThrusterBracket_-1` | 92922835722227 |
| `ThrusterBracket_1` | 137219821251393 |
| `ThrusterHousing_-1` | 83859325549951 |
| `ThrusterHousing_1` | 133639692990964 |
| `ThrusterPlume_-1` | 113767080882945 |
| `ThrusterPlume_1` | 139753875514955 |
| `ThrusterVent_-1_0` | 82714036485170 |
| `ThrusterVent_-1_1` | 89553100791500 |
| `ThrusterVent_-1_2` | 89553100791500 |
| `ThrusterVent_1_0` | 128071767356857 |
| `ThrusterVent_1_1` | 113341363729783 |
| `ThrusterVent_1_2` | 115222422423220 |

### mechaplayer, v2 import -- 69 meshes

Source: `arcade-build-v1/imported-mechaplayer-v2.json`

| part | asset id |
| --- | --- |
| `MechBootBand_-1_0` | 118321074838871 |
| `MechBootBand_-1_1` | 116170840975167 |
| `MechBootBand_1_0` | 74594474824918 |
| `MechBootBand_1_1` | 134538897252074 |
| `MechBootHazard_-1_0_0` | 91307596098454 |
| `MechBootHazard_-1_0_1` | 83275768551401 |
| `MechBootHazard_-1_0_2` | 102748986089059 |
| `MechBootHazard_-1_1_0` | 122397089654370 |
| `MechBootHazard_-1_1_1` | 112897438682809 |
| `MechBootHazard_-1_1_2` | 112897438682809 |
| `MechBootHazard_1_0_0` | 112897438682809 |
| `MechBootHazard_1_0_1` | 84690558994882 |
| `MechBootHazard_1_0_2` | 102748986089059 |
| `MechBootHazard_1_1_0` | 129897215693735 |
| `MechBootHazard_1_1_1` | 112897438682809 |
| `MechBootHazard_1_1_2` | 84690558994882 |
| `MechBootScreen_-1_0` | 135926635486120 |
| `MechBootScreen_-1_1` | 121086102706869 |
| `MechBootScreen_1_0` | 77420316217499 |
| `MechBootScreen_1_1` | 131960208482050 |
| `MechBootSignal_-1_0` | 80489778533481 |
| `MechBootSignal_-1_1` | 93197042487556 |
| `MechBootSignal_1_0` | 138768269342418 |
| `MechBootSignal_1_1` | 93814254396831 |
| `MechBootSole_-1_0` | 140096052620257 |
| `MechBootSole_-1_1` | 81201634259535 |
| `MechBootSole_1_0` | 92492422252684 |
| `MechBootSole_1_1` | 101491712791313 |
| `MechBootUpper_-1_0` | 103111272288632 |
| `MechBootUpper_-1_1` | 86835614808260 |
| `MechBootUpper_1_0` | 95259740294047 |
| `MechBootUpper_1_1` | 110282568887139 |
| `MechBrow_-1` | 128735353819582 |
| `MechBrow_1` | 130474966538845 |
| `MechDorsalSpine` | 140560860168917 |
| `MechHingePin_-1` | 100302712895043 |
| `MechHingePin_1` | 114281935204505 |
| `MechHinge_-1` | 112190986230395 |
| `MechHinge_1` | 77877212518264 |
| `MechLowerGuard_-1` | 76013508568584 |
| `MechLowerGuard_1` | 123349509771741 |
| `MechRearSignal_0` | 133645326015630 |
| `MechRearSignal_1` | 137005846425611 |
| `MechRearSignal_2` | 101945588595575 |
| `MechRearVent` | 102288034763165 |
| `MechShell_-1_0` | 76787747917516 |
| `MechShell_-1_1` | 109902241375241 |
| `MechShell_-1_2` | 113088941283708 |
| `MechShell_1_0` | 106155493658474 |
| `MechShell_1_1` | 78377915151173 |
| `MechShell_1_2` | 129950665524648 |
| `MechShoulderFrame_-1` | 123652012599346 |
| `MechShoulderFrame_1` | 125181073237002 |
| `MechShoulderHazard_-1_0` | 91259586833548 |
| `MechShoulderHazard_-1_1` | 137542810407785 |
| `MechShoulderHazard_-1_2` | 87304176911914 |
| `MechShoulderHazard_1_0` | 107434067513017 |
| `MechShoulderHazard_1_1` | 137113216429065 |
| `MechShoulderHazard_1_2` | 98028229512998 |
| `MechShoulderNavy_-1` | 136020359857545 |
| `MechShoulderNavy_1` | 87769133942513 |
| `MechVentLight_-1_0` | 102559338609561 |
| `MechVentLight_-1_1` | 100274231193376 |
| `MechVentLight_-1_2` | 100274231193376 |
| `MechVentLight_1_0` | 113993265447826 |
| `MechVentLight_1_1` | 83020931834744 |
| `MechVentLight_1_2` | 83020931834744 |
| `MechVentRecess_-1` | 94070460079920 |
| `MechVentRecess_1` | 88739287393664 |

## approved-imports-20260923 upload receipts

Each `<skin>/roblox-uploads.json` is the receipt for that skin's `og-v2` sheets,
which live under `<tier>/<skin>/revisions/og-v2/sheets/`. Listed here are the ids
from those receipts that are recorded nowhere else.

| skin | role | asset id | moderation | uploaded from |
| --- | --- | --- | --- | --- |
| finalboss | `accessories` | 84387968684596 | Approved | `finalboss-spellcaster-v5-accessories.fbx` |
| jackpot | `accessories` | 100219423503277 | Approved | `jackpot-jackpot-v3-accessories.fbx` |
| mechaplayer | `accessories` | 85016724214909 | Approved | `mechaplayer-arcade-v4-accessories.fbx` |
| quartz | `accessories` | 77211551492762 | Approved | `quartz-og-v2-accessories.fbx` |
| rockslide | `accessories` | 71409346006751 | Approved | `rockslide-og-v2-accessories.fbx` |

## A second copy, not a second set

`og-refresh-v2/runtime-check.rbxlx` is a Studio check place carrying many of the
arcade mesh ids above. It duplicates them; it adds none.

**Total ids recorded here: 190.**
