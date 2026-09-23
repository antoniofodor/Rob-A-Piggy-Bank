#!/usr/bin/env python3
"""Run isolated economy tests with the official Luau CLI; no Studio or saves.
Usage: python3 tests/run-crates.py --luau /path/to/luau [--suite speeds|crates|rebirth|theft|buyback|objective|audits|saves|residents|handoff|settlement|deliveryui|badges|ranks|shopdrops|robberyui|ladder|houses|piggies|interior|doors|herds|police|pathfollower|wanted|lobbyboard]
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
    parser.add_argument("--suite", choices=("crates", "rebirth", "theft", "buyback", "objective", "audits", "saves", "residents", "handoff", "settlement", "deliveryui", "badges", "ranks", "shopdrops", "robberyui", "ladder", "houses", "shopui", "guardians", "piggies", "interior", "doors", "herds", "walk", "grassland", "trees", "police", "pathfollower", "speeds", "wanted", "lobbyboard"), default="crates")
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
        inputs = literal(service)
    elif args.suite == "guardians":
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ReplicatedStorage/Shared" / (name + ".luau")).read_text(encoding="utf-8")) for name in ("GuardCatalog", "GuardRig", "KennelModel", "Pets")) + "}"
    elif args.suite == "shopui":
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ReplicatedStorage/Shared" / (name + ".luau")).read_text(encoding="utf-8")) for name in ("Theme", "ShopIcons", "ShopWidgets", "ShopUpgradeFacts", "ShopUpgrades", "ShopMarks", "ShopAchievements", "ShopRevamp", "CrateContents", "RidePicker", "HUDLayout", "ShopCatalogueLayout")) + "}"
    elif args.suite == "ladder":
        inputs = "{}"
    elif args.suite == "interior":
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ReplicatedStorage/Shared" / (name + ".luau")).read_text(encoding="utf-8")) for name in ("LowPoly", "HouseInterior")) + "}"
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
        # The street leaderboard spans a save field, the one place it is
        # incremented, the service that pushes it, the panel that draws it
        # and the two files that start both halves -- a module nobody
        # starts is the silent failure this project records more than any
        # other, and a counter nobody increments is a board of zeros.
        board_paths = {
            "DataService": "src/ServerScriptService/Services/DataService.luau",
            "PiggyHaulService": "src/ServerScriptService/Services/PiggyHaulService.luau",
            "LobbyBoardService": "src/ServerScriptService/Services/LobbyBoardService.luau",
            "LobbyBoard": "src/ReplicatedStorage/Shared/LobbyBoard.luau",
            "Remotes": "src/ReplicatedStorage/Shared/Remotes.luau",
            "HUDLayout": "src/ReplicatedStorage/Shared/HUDLayout.luau",
            "MenuIcons": "src/ReplicatedStorage/Shared/MenuIcons.luau",
            "Main": "src/ServerScriptService/Main.server.luau",
            "ClientMain": "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau",
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
    bundle += "assert(loadstring(" + literal(tests) + ', "economy tests"))(Config, ' + inputs + ")\n"
    with tempfile.TemporaryDirectory(prefix="piggy-crates-") as folder:
        script = Path(folder) / "crates.luau"
        script.write_text(bundle, encoding="utf-8")
        return subprocess.run([args.luau, str(script)], check=False).returncode

if __name__ == "__main__":
    raise SystemExit(main())
