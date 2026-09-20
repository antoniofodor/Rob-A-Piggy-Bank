# Orphaned mesh uploads — snapshot of 17 September 2026

These 169 mesh assets sit on the developer's own Roblox account and NOTHING IN
THIS REPO POINTS AT THEM ANY MORE. They were uploaded by house imports whose
revision has since been superseded, and the templates that used to reference them
have been regenerated against the newer geometry.

**This file is the only record.** The ids came from each import's
`studio-import.json`, and those folders were deleted with the superseded art, so
`tools/groom_uploads.py` cannot rediscover them -- it will now report zero
orphans, which means "no evidence left", not "none exist".

**ARCHIVE RATHER THAN DELETE, and check before either.** An id absent from `src/`
is not proof it is dead: a template that has not been regenerated, a place-file
reference or a peer's uncommitted work would all look identical from here. There
is no API in this toolchain that removes an upload, so this is a by-hand list.

---

## Verified dead, 18 September 2026 -- and `:archive` refuses most of them

**ALL 169 WERE CHECKED AGAINST BOTH PLACES AN ID COULD BE HIDING**, which is
the check this file says cannot be made from the repo alone. Zero appear in
`src/` under a deliberately permissive match (any run of 9+ digits, 8,272
distinct numbers). Zero appear on any `MeshId`, `TextureID`, `Texture`,
`Image`, `SoundId`, `ColorMap`, `NormalMap`, `MetalnessMap`, `RoughnessMap` or
`AnimationId` across all 9,899 instances of the live place, which carries 1,567
distinct ids. They are dead.

**AND THEY STILL CANNOT BE REMOVED FROM HERE, FOR A NEW REASON.** Open Cloud
does have `POST /assets/v1/assets/{id}:archive` and it does work -- tested,
`state` comes back `Archived`, and `:restore` puts it back. It only accepts
SOME types:

| type | `:archive` |
| --- | --- |
| Decal | **works** |
| Mesh | `INVALID_ARGUMENT: not an archivable asset type` |
| Image | `INVALID_ARGUMENT: not an archivable asset type` |

Every id in the tables below is a **Mesh**, so the whole list is refused. This
file's opening sentence is therefore still true, and now has a measurement
under it rather than an assumption: removal is a Creator Dashboard job.

## Three more, from the Rainbow Tiger idle import

Importing `rainbowtiger-idle.fbx` as its own display model -- which its README
says not to do, an idle belongs on the main model's rig -- created eight new
assets, where dragon's and phoenix's idle imports created none. Five are shared
with `dragon-complete` and are live. These three are not:

| asset id | what it was |
| --- | --- |
| `120583026630362` | rainbowtiger-beard-flow-color (Image) |
| `128594361405470` | rainbowtiger-beard-flow-normal (Image) |
| `71135650601587` | rainbowtiger-tail-gradient (Image) |

Archived: **no** -- Image, refused as above.

## The duplicate texture batch

58 animal-crate maps were uploaded twice: once by hand through Studio's Asset
Manager, then again through Open Cloud to capture their ids -- because the
Assets API has **no list endpoint**, so there is no way to read back the ids of
an upload somebody made in the UI.

**THE LIVE SET IS THE SECOND ONE**, recorded in `import/asset-ids.csv`, and the
two are separable by CLOCK rather than by id: the Open Cloud batch ran
`2026-09-18T17:49:30Z` to `17:52:39Z`, so a same-named Image created before
17:49 that day is the dead copy.

One `Decal` from the same session IS archived -- `128744979356687`, a test that
proved a Decal id does NOT resolve as a `SurfaceAppearance.ColorMap` while an
Image id does. That is the whole reason the second batch exists.



## cardboard-fort-v1 — 17 meshes

| asset id | mesh it was |
| --- | --- |
| `95778706529674` | Approach_CardLight |
| `105537955512172` | BoxFlaps_CardDark |
| `111331503296103` | BoxFlaps_CardLight |
| `75165910430441` | BoxWindows_CardLight |
| `99731875300486` | BoxWindows_DarkGlass |
| `101358663341113` | BoxWindows_Ink |
| `134877586743113` | BoxWindows_Tape |
| `84999614504404` | CrayonEntrance_Card |
| `102201840850784` | CrayonEntrance_CardDark |
| `130164467564187` | CrayonEntrance_Crayon |
| `116375296763676` | Doodles_RedPencil |
| `88357774296925` | Foundation_CardDark |
| `78545393067887` | MainBox_Card |
| `100604389153282` | MainBox_CardLight |
| `80285673720061` | MainBox_Tape |
| `113484637737790` | Patches_CardDark |
| `131859578573975` | Patches_Tape |

## crystal-spire-v1 — 21 meshes

| asset id | mesh it was |
| --- | --- |
| `79250666397393` | Crystals_Violet |
| `96176081279940` | Crystals_VioletDeep |
| `122760770737251` | Crystals_VioletLight |
| `105513107060326` | Entry_Brass |
| `126009638994782` | Entry_Door |
| `96719264251459` | Entry_Frame |
| `134854648328138` | Entry_Ink |
| `134748480800981` | Entry_RockShade |
| `70930995076977` | Entry_Stone |
| `128967051140460` | Foundation_RockShade |
| `102542728437376` | HouseFX_CrystalAccent_1_Glow |
| `129934118671561` | HouseFX_CrystalAccent_2_Glow |
| `138603265766170` | HouseFX_CrystalAccent_3_Glow |
| `128151285486322` | RockShell_Rock |
| `135880028120677` | RockShell_RockLight |
| `81470583099124` | RockShell_RockShade |
| `94885193224628` | Windows_Amber |
| `73707301724675` | Windows_Frame |
| `91326127122889` | Windows_Ink |
| `98176203650539` | Windows_RockShade |
| `74597401586125` | Windows_VioletDeep |

## fishbowl-house-v1 — 24 meshes

| asset id | mesh it was |
| --- | --- |
| `118480227793314` | Approach_Stone |
| `81557390565756` | AquariumShell_DomeGlass |
| `72092414684294` | CoralGarden_CoralOrange |
| `108926537126652` | CoralGarden_CoralPink |
| `91580828726843` | CoralGarden_Seaweed |
| `71937114346944` | CoralGarden_Stone |
| `86273197206969` | DomeRim_DomeRim |
| `76827039297095` | EntranceSleeve_Pod |
| `133122175767251` | EntranceSleeve_PodTrim |
| `83146062751081` | Entrance_DarkGlass |
| `87418313252564` | Entrance_Gold |
| `98472934398853` | Entrance_Ink |
| `70494746600982` | Entrance_Pod |
| `116469931044668` | Entrance_PodTrim |
| `132983140572934` | Foundation_Sand |
| `118716946721918` | Foundation_Stone |
| `106957858928528` | HouseFX_Bubble_1_BubbleGlass |
| `91969279851629` | HouseFX_Bubble_2_BubbleGlass |
| `106680049673649` | HouseFX_Bubble_3_BubbleGlass |
| `122639856438422` | HouseFX_Bubble_4_BubbleGlass |
| `124915674436264` | PodShell_Pod |
| `118321711878367` | PodShell_PodTrim |
| `124415103960017` | PodWindows_DarkGlass |
| `87824594294636` | PodWindows_PodTrim |

## gloop-house-v2 — 17 meshes

| asset id | mesh it was |
| --- | --- |
| `118472115644377` | Chimney_WallLight |
| `82885444767110` | Door_Purple |
| `106581435468377` | Door_PurpleLight |
| `90481773326564` | Door_PurpleShade |
| `127314582346633` | EntryFrame_Frame |
| `101763173789279` | Floor_Floor |
| `84095618929277` | Floor_Stone |
| `134980025927602` | FrontWindows_Amber |
| `132574511849667` | FrontWindows_Frame |
| `117904957723033` | HouseFX_Pulse_1_Roof |
| `109644144683045` | HouseFX_Pulse_2_Roof |
| `116728680274938` | HouseFX_Pulse_3_Roof |
| `107538945116238` | Puddles_Puddle |
| `126688640833680` | Roof_Roof |
| `101233288097687` | SideWindows_Amber |
| `93981587874673` | SideWindows_Frame |
| `107837966536011` | Walls_Wall |

## golden-piggy-v1 — 27 meshes

| asset id | mesh it was |
| --- | --- |
| `108331754896042` | Approach_PigLight |
| `82362346912295` | BellyEntrance_PigGold |
| `119006814359932` | CoinSlot_Ink |
| `117618123735891` | CoinSlot_PigShade |
| `129382830170059` | EarBalconies_PigShade |
| `78874420223377` | EarBalconies_Timber |
| `110196614433200` | Ears_EarPink |
| `122916599116340` | Ears_PigLight |
| `75565939665699` | Entrance_Gold |
| `139146259569472` | Entrance_Ink |
| `107672075363309` | Entrance_PigShade |
| `124508766698879` | Entrance_Timber |
| `104057721735537` | Foundation_PigShade |
| `97682207265748` | HouseFX_FlankAccent_1_PigLight |
| `80400265847150` | HouseFX_FlankAccent_2_PigLight |
| `108464338344621` | HouseFX_SlotCoin_PigLight |
| `105945822477535` | HouseFX_SlotCoin_PigShade |
| `132775638646662` | PigBody_PigGold |
| `74746697505085` | PigBody_PigShade |
| `124386495556944` | RoundWindows_Amber |
| `138908685028842` | RoundWindows_PigShade |
| `78653435659633` | Snout_Amber |
| `114455321176672` | Snout_Ink |
| `135722366634406` | Snout_PigShade |
| `85670330020696` | Snout_Snout |
| `113704333723723` | TailChimney_PigGold |
| `134147211842029` | TailChimney_PigShade |

## treehouse-v2 — 63 meshes

| asset id | mesh it was |
| --- | --- |
| `83624636025816` | Bridge_Rope |
| `109644870224843` | Bridge_Wood |
| `122927999983098` | Bridge_WoodLight |
| `80499377676936` | Cabin_Amber |
| `98502471480445` | Cabin_Amber.001 |
| `126302079869636` | Cabin_Plaster |
| `97074671767102` | Cabin_Plaster.001 |
| `92493794802264` | Cabin_Timber |
| `119054526099579` | Cabin_Timber.001 |
| `137348761473121` | Cabin_Wood |
| `84488757246859` | Cabin_Wood.001 |
| `138536449516093` | Cabin_WoodShade |
| `132100696481066` | Cabin_WoodShade.001 |
| `77196963899196` | Canopy_Leaf |
| `131987347738570` | Canopy_LeafDark |
| `135155572227146` | Canopy_LeafLight |
| `93477671818965` | Deck_Timber |
| `74100615392705` | Deck_Wood |
| `115995813991077` | Deck_WoodLight |
| `121880401879210` | Deck_WoodShade |
| `86605917251904` | GroundDetails_Leaf |
| `107772993958485` | GroundDetails_LeafLight |
| `109460789777815` | GroundDetails_Stone |
| `128234365225793` | GroundDetails_StoneLight |
| `120417822877714` | Interior_Amber |
| `127463403783053` | Interior_Iron |
| `82659316151965` | Interior_Leaf |
| `102213867611188` | Interior_LeafLight |
| `76487284749202` | Interior_Wood |
| `114774808878722` | Interior_WoodLight |
| `113454081768883` | Interior_WoodShade |
| `70841761204406` | Ladder_Rope |
| `110754256165058` | Ladder_Wood |
| `128854608379978` | Lookout_Bark |
| `121210490966619` | Lookout_BarkDark |
| `132002988936236` | Lookout_BarkLight |
| `102920503249150` | Lookout_Iron |
| `115331590535234` | Lookout_Roof |
| `112098843183232` | Lookout_Rope |
| `130389338543861` | Lookout_Timber |
| `136950759302274` | Lookout_Wood |
| `71405744895568` | Lookout_WoodLight |
| `81815734109983` | Lookout_WoodShade |
| `132012731510011` | Oak_Bark |
| `87366692726864` | Oak_BarkDark |
| `139159532677688` | Oak_BarkLight |
| `131659968073640` | Railings_Wood |
| `86664839001902` | Railings_WoodLight |
| `136605694352087` | Railings_WoodShade |
| `110187172281654` | Roof_PlasterLight |
| `119666900145184` | Roof_Roof |
| `129220696058967` | Roof_RoofDark |
| `104189583575036` | Roof_RoofLight |
| `111262281514132` | Roof_Timber |
| `108599114227975` | Roof_WindowBlue |
| `103182290584304` | Roof_Wood |
| `114874920911043` | Roof_WoodShade |
| `137278255237474` | Stairs_Amber |
| `114347067063155` | Stairs_Iron |
| `134288820131472` | Stairs_Timber |
| `134607549262647` | Stairs_Wood |
| `112569171808943` | Stairs_WoodLight |
| `99301003385283` | Stairs_WoodShade |
