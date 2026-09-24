#!/usr/bin/env python3
"""Run isolated economy tests with the official Luau CLI; no Studio or saves.
Usage: python3 tests/run-crates.py --luau /path/to/luau [--suite lasso|lassopose|speeds|crates|rebirth|theft|buyback|objective|audits|saves|residents|handoff|settlement|deliveryui|badges|ranks|shopdrops|robberyui|ladder|houses|piggies|interior|doors|herds|police|pathfollower|wanted|lobbyboard]
Roblox value constructors are inert stubs; these tests assert economy logic,
not engine rendering, input, replication or DataStore persistence.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def literal(text):
    equals = "="
    while "]" + equals + "]" in text:
        equals += "="
    return "[" + equals + "[" + text + "]" + equals + "]"

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", default="luau")
    parser.add_argument("--suite", choices=("crates", "rebirth", "theft", "buyback", "objective", "audits", "saves", "residents", "handoff", "settlement", "deliveryui", "badges", "ranks", "shopdrops", "robberyui", "ladder", "houses", "shopui", "guardians", "piggies", "interior", "doors", "herds", "walk", "grassland", "trees", "police", "pathfollower", "speeds", "wanted", "lobbyboard", "combine", "lasso", "lassopose"), default="crates")
    args = parser.parse_args()
    prelude = r'''
local valueMeta = {__mul = function(a, b) return a end, __index = {Lerp = function(a) return a end}}
local function value(...) return setmetatable({...}, valueMeta) end
local function vector(x, y, z) return {X=x, Y=y, Z=z} end
local env = setmetatable({
 Color3 = {fromRGB = value}, Vector3 = {new = vector}, Vector2 = {new = vector},
 CFrame = {new = value, Angles = value},
 ColorSequence = {new = value}, ColorSequenceKeypoint = {new = value},
 NumberRange = {new = value},
 Enum = setmetatable({}, {__index = function(_, group)
  return setmetatable({}, {__index = function(_, name) return group .. "." .. name end})
 end}),
}, {__index = getfenv()})
local function loadConfig(source)
 local run = assert(loadstring(source, "Config"));setfenv(run, env);return run()
end
'''
    config = (ROOT / "src/ReplicatedStorage/Shared/Config.luau").read_text(encoding="utf-8")
    service = (ROOT / "src/ServerScriptService/Services/ChestService.luau").read_text(encoding="utf-8")
    tests = (ROOT / "tests/luau" / (args.suite + ".luau")).read_text(encoding="utf-8")
    bundle = prelude + "\nlocal Config = loadConfig(" + literal(config) + ")\n"
    if args.suite == "crates":
        # ChestService and the file that owns the Robux route into it: the
        # ProcessReceipt callback, the receipt ledger and the PolicyService
        # gate. Both, because the two halves of a paid crate are "did it open"
        # and "may it have been sold at all", and a suite that stubs the second
        # cannot see a receipt paid out twice.
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ServerScriptService/Services" / (name + ".luau")).read_text(encoding="utf-8")) for name in ("ChestService", "ProductService")) + "}"
    elif args.suite == "guardians":
        # The palette, the kennel and the disabled follower -- plus the
        # rebirth gate, which spans the server refusal (CosmeticsService),
        # the save it reads (DataService), the card that declines to ask
        # (ShopGuardianCards over ShopImageCards) and the three files read
        # as SOURCE for what they must not do: ClientMain's Activated
        # handler, AdminService's unlockall and ProgressionService's wipe.
        guardian_paths = {
            "GuardCatalog": "src/ReplicatedStorage/Shared/GuardCatalog.luau",
            "GuardRig": "src/ReplicatedStorage/Shared/GuardRig.luau",
            "KennelModel": "src/ReplicatedStorage/Shared/KennelModel.luau",
            "Pets": "src/ReplicatedStorage/Shared/Pets.luau",
            "ShopImageCards": "src/ReplicatedStorage/Shared/ShopImageCards.luau",
            "ShopGuardianCards": "src/ReplicatedStorage/Shared/ShopGuardianCards.luau",
            "DataService": "src/ServerScriptService/Services/DataService.luau",
            "SetService": "src/ServerScriptService/Services/SetService.luau",
            "CosmeticsService": "src/ServerScriptService/Services/CosmeticsService.luau",
            "AdminService": "src/ServerScriptService/Services/AdminService.luau",
            "ProgressionService": "src/ServerScriptService/Services/ProgressionService.luau",
            "ClientMain": "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in guardian_paths.items()) + "}"
    elif args.suite == "shopui":
        # `Rebirth` is read as SOURCE only, for the one pure function on it:
        # `unlocksAt`, which names what the next rebirth puts on sale. The rest
        # of that module is page geometry this harness does not draw.
        #
        # SO ARE THE LAST THREE, AND THEY ARE HERE FOR THE FENCE CARD. That
        # card drew its own primitives fence because a client cannot call
        # `CreateMeshPartAsync`, so the lawn and the shop ended up with two
        # descriptions of one object and they drifted. `Shared/FencePanel` is
        # the one builder now; these three are what prove all three ends are
        # wired to it -- the card clones it, PlotService stopped building its
        # own, and Main warms it. A module nobody wires is the silent failure
        # this project records more than any other.
        shop_paths = {name: "src/ReplicatedStorage/Shared/" + name + ".luau" for name in (
            "Theme", "ShopIcons", "ShopWidgets", "ShopUpgradeFacts", "ShopUpgrades",
            "ShopMarks", "ShopRevamp", "CrateContents", "RidePicker", "HUDLayout",
            "ShopCatalogueLayout", "Rebirth", "UpgradePreview", "FencePanel",
            # The crates shelf and the Robux shop, for the two ways into one
            # paid-random shelf: the coin buy-backs only a counter shows.
            "Crates", "PremiumShop")}
        shop_paths["PlotService"] = "src/ServerScriptService/Services/PlotService.luau"
        shop_paths["Main"] = "src/ServerScriptService/Main.server.luau"
        # AND ClientMain AS SOURCE, for the two routing rules that decide
        # whether a shop DOOR is a door or a picture of one: the basket in the
        # HUD rail opens the Robux shelf and nothing else, and every category
        # `Config` gives a door has a view here to open. Neither is reachable
        # from a harness -- one is a click handler on a ScreenGui and the other
        # is a table inside a `do` block -- and both fail silently, which is the
        # combination this project keeps paying for.
        shop_paths["ClientMain"] = "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in shop_paths.items()) + "}"
    elif args.suite == "ladder":
        inputs = "{}"
    elif args.suite == "interior":
        # Both builders behind one contract, plus the service that dispatches
        # between them: the generic hall's geometry, the wrapper that turns the
        # authored per-house kits round, and InteriorService read as SOURCE for
        # the wiring rules -- one dispatch point, the estate pitch clearing the
        # widest hall, and the fallback when a kit is not on the server. A
        # wrapper nobody wires is the silent failure this project records most.
        # Plus the indoor PLACEMENTS: the pedestal, the collect pad and the
        # cash sign that stand on an unlocked plot, the one question that
        # finds a placement at a slot (PlotService), and the three haul verbs
        # that reach through it. A pedestal nobody wires is the silent failure
        # this project records more than any other.
        interior_paths = {
            "LowPoly": "src/ReplicatedStorage/Shared/LowPoly.luau",
            "HouseInterior": "src/ReplicatedStorage/Shared/HouseInterior.luau",
            "IndoorPedestal": "src/ReplicatedStorage/Shared/IndoorPedestal.luau",
            "ThemedInterior": "src/ServerScriptService/Services/ThemedInterior.luau",
            "InteriorService": "src/ServerScriptService/Services/InteriorService.luau",
            "PlotService": "src/ServerScriptService/Services/PlotService.luau",
            "PiggyHaulService": "src/ServerScriptService/Services/PiggyHaulService.luau",
            # THE TWO COUNTERS IN THE HALL, which since 2026-09-23 are the ONLY
            # way to the supplies and guardians shelves -- the HUD basket sells
            # Robux and nothing else. A counter that does not build is not a
            # missing ornament any more, it is a shelf no player can reach.
            "BaseShopStand": "src/ReplicatedStorage/Shared/BaseShopStand.luau",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in interior_paths.items()) + "}"
    elif args.suite == "combine":
        # THE COMBINE MACHINE ON THE VERGE. The two modules with a pure half
        # are LOADED and driven; the rest are read as SOURCE for the rules
        # they have to keep -- NeighborhoodService for the two verge vetoes
        # and the side argument they need, SocialService for the board gap
        # this must not stand in (its `boardX` body is lifted out and RUN,
        # so the two orderings are compared rather than restated),
        # ChestService for the one property the station cannot enforce
        # itself (every refusal before the consume loop), and Main and
        # ClientMain for the two hooks -- a module nobody wires is the
        # silent failure this project records more than any other.
        combine_paths = {
            "Theme": "src/ReplicatedStorage/Shared/Theme.luau",
            "LowPoly": "src/ReplicatedStorage/Shared/LowPoly.luau",
            "CombineStation": "src/ReplicatedStorage/Shared/CombineStation.luau",
            "CombinePanel": "src/ReplicatedStorage/Shared/CombinePanel.luau",
            "Remotes": "src/ReplicatedStorage/Shared/Remotes.luau",
            "CombineService": "src/ServerScriptService/Services/CombineService.luau",
            "ChestService": "src/ServerScriptService/Services/ChestService.luau",
            "NeighborhoodService": "src/ServerScriptService/Services/NeighborhoodService.luau",
            "SocialService": "src/ServerScriptService/Services/SocialService.luau",
            "Main": "src/ServerScriptService/Main.server.luau",
            "ClientMain": "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in combine_paths.items()) + "}"
    elif args.suite == "grassland":
        # The builder alone is not the feature: NeighborhoodService is what
        # hands it the grove's trunks and Main is what registers its veto
        # with the herd, and a module nobody wires is the silent failure
        # this project records more than any other.
        grass_paths = {
            "Grassland": "src/ReplicatedStorage/Shared/Grassland.luau",
            "NeighborhoodService": "src/ServerScriptService/Services/NeighborhoodService.luau",
            "Main": "src/ServerScriptService/Main.server.luau",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in grass_paths.items()) + "}"
    elif args.suite == "trees":
        # The trunk colliders and the herd veto they feed: NeighborhoodService
        # builds both, SceneryTrees is the first route a tree takes (and falls
        # back under the stub, which is the live fallback exercised), and Main
        # is what registers `treeBlocks` with the herd -- a veto nobody wires
        # is a trunk the pack walks through.
        tree_paths = {
            "NeighborhoodService": "src/ServerScriptService/Services/NeighborhoodService.luau",
            "MeadowPlan": "src/ReplicatedStorage/Shared/MeadowPlan.luau",
            "SceneryTrees": "src/ServerScriptService/Services/SceneryTrees.luau",
            "Main": "src/ServerScriptService/Main.server.luau",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in tree_paths.items()) + "}"
    elif args.suite == "police":
        # The officer's walks, wired: the service that drives them, the
        # follower it drives them through, the model it is measured against
        # and the grassland whose ponds carry the modifier the spec's Water
        # cost honours -- no one file can be read for "the officer goes round
        # things", and a follower nobody wires is the old straight line.
        police_paths = {
            "PoliceService": "src/ServerScriptService/Services/PoliceService.luau",
            "PathFollower": "src/ReplicatedStorage/Shared/PathFollower.luau",
            "PoliceModel": "src/ReplicatedStorage/Shared/PoliceModel.luau",
            "Grassland": "src/ReplicatedStorage/Shared/Grassland.luau",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in police_paths.items()) + "}"
    elif args.suite == "wanted":
        # The wanted stars, both ends: SocialService owns the count, the
        # server-time stamp, the Most Wanted pin and the arrest; Wanted draws
        # the drain from the stamp. PoliceService is read for the order it
        # wipes the sheet and the stars in, PiggyPanel for the column width.
        wanted_paths = {
            "SocialService": "src/ServerScriptService/Services/SocialService.luau",
            "Wanted": "src/ReplicatedStorage/Shared/Wanted.luau",
            "PoliceService": "src/ServerScriptService/Services/PoliceService.luau",
            "PiggyPanel": "src/ReplicatedStorage/Shared/PiggyPanel.luau",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in wanted_paths.items()) + "}"
    elif args.suite == "speeds":
        # Every speed is a ratio of BASE_WALK_SPEED (designer, 2026-09-21).
        # The suite reads Config's own SOURCE as well as the loaded table,
        # because "no absolute speed literal survives" is a claim about the
        # text, and it scans every service that drives a speed for the same.
        speed_paths = {
            "Config": "src/ReplicatedStorage/Shared/Config.luau",
            "HeistService": "src/ServerScriptService/Services/HeistService.luau",
            "PoliceService": "src/ServerScriptService/Services/PoliceService.luau",
            "ResidentService": "src/ServerScriptService/Services/ResidentService.luau",
            "TrafficService": "src/ServerScriptService/Services/TrafficService.luau",
            "HerdService": "src/ServerScriptService/Services/HerdService.luau",
            "GuardDog": "src/ServerScriptService/Services/GuardDog.luau",
            "GadgetService": "src/ServerScriptService/Services/GadgetService.luau",
            "StealthService": "src/ServerScriptService/Services/StealthService.luau",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in speed_paths.items()) + "}"
    elif args.suite == "lobbyboard":
        # The street leaderboard is Roblox's own player list (2026-09-23), so
        # the panel this suite used to drive is gone. What it spans now is the
        # save field, the one place it is incremented, the service that fills
        # `leaderstats` from it, and the three files that have to STOP saying
        # the old thing: Remotes (no channel), ClientMain (no disable, no
        # require) and HUDLayout (no published width). A retired feature whose
        # copy survives is the stale-in-the-dangerous-direction failure this
        # project records as often as the silent one.
        board_paths = {
            "DataService": "src/ServerScriptService/Services/DataService.luau",
            "PiggyHaulService": "src/ServerScriptService/Services/PiggyHaulService.luau",
            "LobbyBoardService": "src/ServerScriptService/Services/LobbyBoardService.luau",
            "Remotes": "src/ReplicatedStorage/Shared/Remotes.luau",
            "HUDLayout": "src/ReplicatedStorage/Shared/HUDLayout.luau",
            "Main": "src/ServerScriptService/Main.server.luau",
            "ClientMain": "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau",
            # The one neighbour that outlived the board: the card that has to
            # stay clear of the corner the list holds.
            "FirstJob": "src/ReplicatedStorage/Shared/FirstJob.luau",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in board_paths.items()) + "}"
    elif args.suite == "pathfollower":
        # The follower on its own, against a canned PathfindingService.
        inputs = "{PathFollower=" + literal((ROOT / "src/ReplicatedStorage/Shared/PathFollower.luau").read_text(encoding="utf-8")) + "}"
    elif args.suite == "doors":
        # The front door spans four files and no one of them can be read for
        # it: the service decides the crossing, the mask draws over it, the
        # remote is the channel between them, and Main and ClientMain are what
        # start the two halves -- a module nobody starts is the silent failure
        # this project records more than any other.
        door_paths = {
            "InteriorService": "src/ServerScriptService/Services/InteriorService.luau",
            "DoorMask": "src/ReplicatedStorage/Shared/DoorMask.luau",
            "Remotes": "src/ReplicatedStorage/Shared/Remotes.luau",
            "Main": "src/ServerScriptService/Main.server.luau",
            "ClientMain": "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in door_paths.items()) + "}"
    elif args.suite in ("theft", "handoff", "settlement", "shopdrops"):
        inputs = literal((ROOT / "src/ServerScriptService/Services/HeistService.luau").read_text(encoding="utf-8"))
    elif args.suite == "herds":
        inputs = "{" + "HerdService=" + literal((ROOT / "src/ServerScriptService/Services/HerdService.luau").read_text(encoding="utf-8")) + "}"
    elif args.suite == "lasso":
        # The lasso spans the service that throws it, the herd that answers for
        # the animal, the haul that carries a catch home and the product that
        # sells the Elite tier -- plus Main, AdminService and the hot bar's
        # allowlist read as SOURCE for the wiring. A module nobody wires is the
        # silent failure this project records more than any other.
        lasso_paths = {
            "LassoService": "src/ServerScriptService/Services/LassoService.luau",
            "HerdService": "src/ServerScriptService/Services/HerdService.luau",
            "PiggyHaulService": "src/ServerScriptService/Services/PiggyHaulService.luau",
            "ProductService": "src/ServerScriptService/Services/ProductService.luau",
            "GadgetService": "src/ServerScriptService/Services/GadgetService.luau",
            "SettingsService": "src/ServerScriptService/Services/SettingsService.luau",
            "AdminService": "src/ServerScriptService/Services/AdminService.luau",
            "Main": "src/ServerScriptService/Main.server.luau",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in lasso_paths.items()) + "}"
    elif args.suite == "lassopose":
        inputs = "{" + ",".join(n + "=" + literal((ROOT / "src/ReplicatedStorage/Shared" / (n + ".luau")).read_text(encoding="utf-8")) for n in ("LassoPose", "CarryPose")) + "}"
    elif args.suite == "walk":
        # The herd walk spans the publisher (HerdService), the client that
        # poses from it (PiggyWalk), the curve in Config and the one line in
        # ClientMain that starts the module -- a module nobody starts is the
        # silent failure this project records more than any other.
        walk_paths = {
            "HerdService": "src/ServerScriptService/Services/HerdService.luau",
            "PiggyWalk": "src/ReplicatedStorage/Shared/PiggyWalk.luau",
            "ClientMain": "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau",
            # And the bake itself, so Config's copy of the curve is held to
            # what Blender wrote rather than to what somebody last typed.
            "Curve": "blender/pig/anim/walk_curve.lua",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in walk_paths.items()) + "}"
    elif args.suite == "robberyui":
        inputs = literal((ROOT / "src/ReplicatedStorage/Shared/RobberyLoot.luau").read_text(encoding="utf-8"))
    elif args.suite == "ranks":
        inputs = literal((ROOT / "src/ServerScriptService/Services/PlotService.luau").read_text(encoding="utf-8"))
    elif args.suite == "badges":
        inputs = literal((ROOT / "src/ReplicatedStorage/Shared/RobBadge.luau").read_text(encoding="utf-8"))
    elif args.suite == "deliveryui":
        inputs = literal((ROOT / "src/ReplicatedStorage/Shared/CarryDelivery.luau").read_text(encoding="utf-8"))
    elif args.suite == "residents":
        # The haul service too: a neighbour's snatch runs the player's own
        # snatch core over there (cooldown, shield, slot, alarm, put-back),
        # and a registry nobody exercises is the silent failure this project
        # records more than any other.
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ServerScriptService/Services" / (name + ".luau")).read_text(encoding="utf-8")) for name in ("ResidentService", "PiggyHaulService")) + "}"
    elif args.suite == "saves":
        inputs = literal((ROOT / "src/ServerScriptService/Services/DataService.luau").read_text(encoding="utf-8"))
    elif args.suite == "audits":
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ServerScriptService/Services" / (name + ".luau")).read_text(encoding="utf-8")) for name in ("EventService", "SetService", "DataService", "CosmeticsService", "PiggyBank")) + "}"
        inputs = inputs[:-1] + ",Main=" + literal((ROOT / "src/ServerScriptService/Main.server.luau").read_text(encoding="utf-8")) + "}"
    elif args.suite == "piggies":
        # The whole collect path, because the guarantees worth asserting here
        # span it: PiggyPedestal owns the pad builders, PiggyBank builds the
        # SEVENTH pad (the till), PlotService routes a collect to the pad that
        # banked it, and EconomyService is what fires. A property like "every
        # pad goes through one builder" is invisible to any one of them.
        piggy_paths = {
            "PiggyPedestal": "src/ReplicatedStorage/Shared/PiggyPedestal.luau",
            "PiggyBank": "src/ServerScriptService/Services/PiggyBank.luau",
            "PlotService": "src/ServerScriptService/Services/PlotService.luau",
            "EconomyService": "src/ServerScriptService/Services/EconomyService.luau",
            # And the grass, because what stands on a pedestal is not the
            # only thing standing on the lawn: the veto that stops a tuft
            # growing through a collect pad is a lawn rule with no suite of
            # its own, and the pads are what reported it.
            "GrassTuft": "src/ReplicatedStorage/Shared/GrassTuft.luau",
            # The police loop and the board, because what a robbery is
            # MEASURED IN and what it COSTS are now two different units and
            # neither has a suite of its own.
            "PoliceService": "src/ServerScriptService/Services/PoliceService.luau",
            "SocialService": "src/ServerScriptService/Services/SocialService.luau",
            # And the three verbs that move a piggy between pedestals. The
            # guarantees worth asserting there are the same shape as the
            # collect path's: they span PiggyPedestal (which builds the two
            # prompts), PlotService (which switches them) and the service
            # itself, so no one file can be read for them.
            "PiggyHaulService": "src/ServerScriptService/Services/PiggyHaulService.luau",
            # And the hallway, as SOURCE: the five-second secure has a second
            # room now, and which service registers it with which is a
            # dependency-direction fact no one file states.
            "InteriorService": "src/ServerScriptService/Services/InteriorService.luau",
            # And the repaint the swap leans on: the bank is dressed from the
            # till there, and a bank dressed from anything else is a swap
            # that changed the rate and not the pig.
            "CosmeticsService": "src/ServerScriptService/Services/CosmeticsService.luau",
            # And the renderer, because the half of "three verbs on one key"
            # that keeps them exclusive is a CLIENT rule: an attribute nobody
            # reads is a refusal that never happens, and it fails silently.
            "PromptUI": "src/ReplicatedStorage/Shared/PromptUI.luau",
            # The supply side. What a neighbour keeps on their plinths is the
            # only thing a solo player can steal, so its rules are asserted
            # beside the rules for taking it.
            "ResidentService": "src/ServerScriptService/Services/ResidentService.luau",
            # And what a piggy DOES when a pad banks. The collect reaction's
            # length is the pad's own cooldown, so the clip and the button are
            # one number in two files -- which is exactly the shape this suite
            # exists to hold together.
            "PiggyIdle": "src/ReplicatedStorage/Shared/PiggyIdle.luau",
            # And the mini itself, with the three files that scale or animate
            # it: the pedestal, the herd and the client animator each apply
            # something the row asks for, and "a mini looks exactly like it
            # was built" is a claim about all four at once.
            "PiggyModel": "src/ReplicatedStorage/Shared/PiggyModel.luau",
            "HerdService": "src/ServerScriptService/Services/HerdService.luau",
            "ClientMain": "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau",
            "SkinFX": "src/ReplicatedStorage/Shared/SkinFX.luau",
        }
        inputs = "{" + ",".join(name + "=" + literal((ROOT / path).read_text(encoding="utf-8")) for name, path in piggy_paths.items()) + "}"
    elif args.suite == "objective":
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ReplicatedStorage/Shared" / (name + ".luau")).read_text(encoding="utf-8")) for name in ("FirstJob", "HUDLayout")) + "}"
    else:
        names = (("ChestService", "DataService", "SetService") if args.suite == "buyback"
                 else ("ChestService", "ProgressionService", "DataService", "CosmeticsService"))
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ServerScriptService/Services" / (name + ".luau")).read_text(encoding="utf-8")) for name in names) + "}"
    if args.suite == "buyback":
        inputs = inputs[:-1] + ",Crates=" + literal((ROOT / "src/ReplicatedStorage/Shared/Crates.luau").read_text(encoding="utf-8")) + "}"
    # The carry pose as a THIRD argument, for the one suite that reads it.
    # Appended rather than folded into `inputs` because theft, settlement and
    # shopdrops share that branch and each take a bare HeistService string.
    extra = ""
    if args.suite == "handoff":
        carry_pose = ROOT / "src/ReplicatedStorage/Shared/CarryPose.luau"
        extra = ", " + literal(carry_pose.read_text(encoding="utf-8"))
    bundle += "assert(loadstring(" + literal(tests) + ', "economy tests"))(Config, ' + inputs + extra + ")\n"
    with tempfile.TemporaryDirectory(prefix="piggy-crates-") as folder:
        script = Path(folder) / "crates.luau"
        script.write_text(bundle, encoding="utf-8")
        return subprocess.run([args.luau, str(script)], check=False).returncode

if __name__ == "__main__":
    raise SystemExit(main())
