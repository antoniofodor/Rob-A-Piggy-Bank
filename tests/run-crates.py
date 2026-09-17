#!/usr/bin/env python3
"""Run isolated economy tests with the official Luau CLI; no Studio or saves.
Usage: python3 tests/run-crates.py --luau /path/to/luau [--suite crates|rebirth|theft|buyback|objective|audits|saves|oak|growth|fill|shake|basket|shakeui|residents|handoff|settlement|deliveryui|badges|ranks|shopdrops|robberyui|ladder|houses|tree|midnight|season]
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
    parser.add_argument("--suite", choices=("crates", "rebirth", "theft", "buyback", "objective", "audits", "saves", "oak", "growth", "fill", "shake", "basket", "shakeui", "residents", "handoff", "settlement", "deliveryui", "badges", "ranks", "shopdrops", "robberyui", "ladder", "houses", "tree", "midnight", "season"), default="crates")
    args = parser.parse_args()
    prelude = r'''
local valueMeta = {__mul = function(a, b) return a end}
local function value(...) return setmetatable({...}, valueMeta) end
local function vector(x, y, z) return {X=x, Y=y, Z=z} end
local env = setmetatable({
 Color3 = {fromRGB = value}, Vector3 = {new = vector},
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
    elif args.suite == "ladder":
        inputs = "{}"
    elif args.suite in ("theft", "basket", "handoff", "settlement", "shopdrops"):
        inputs = literal((ROOT / "src/ServerScriptService/Services/HeistService.luau").read_text(encoding="utf-8"))
    elif args.suite == "robberyui":
        inputs = literal((ROOT / "src/ReplicatedStorage/Shared/RobberyLoot.luau").read_text(encoding="utf-8"))
    elif args.suite == "ranks":
        inputs = literal((ROOT / "src/ServerScriptService/Services/PlotService.luau").read_text(encoding="utf-8"))
    elif args.suite == "badges":
        inputs = literal((ROOT / "src/ReplicatedStorage/Shared/RobBadge.luau").read_text(encoding="utf-8"))
    elif args.suite == "deliveryui":
        inputs = literal((ROOT / "src/ReplicatedStorage/Shared/CarryDelivery.luau").read_text(encoding="utf-8"))
    elif args.suite == "shakeui":
        inputs = literal((ROOT / "src/ReplicatedStorage/Shared/Shake.luau").read_text(encoding="utf-8"))
    elif args.suite == "residents":
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ServerScriptService/Services" / (name + ".luau")).read_text(encoding="utf-8")) for name in ("ResidentAcorns", "ResidentService")) + "}"
    elif args.suite == "shake":
        inputs = literal((ROOT / "src/ServerScriptService/Services/ShakeService.luau").read_text(encoding="utf-8"))
    elif args.suite == "fill":
        inputs = literal((ROOT / "src/ReplicatedStorage/Shared/AcornFill.luau").read_text(encoding="utf-8"))
    elif args.suite == "growth":
        inputs = literal((ROOT / "src/ServerScriptService/Services/EconomyService.luau").read_text(encoding="utf-8"))
    elif args.suite == "saves":
        inputs = literal((ROOT / "src/ServerScriptService/Services/DataService.luau").read_text(encoding="utf-8"))
    elif args.suite == "oak":
        inputs = "{AcornTree=" + literal((ROOT / "src/ReplicatedStorage/Shared/AcornTree.luau").read_text(encoding="utf-8"))
        inputs += ",AcornBasket=" + literal((ROOT / "src/ReplicatedStorage/Shared/AcornBasket.luau").read_text(encoding="utf-8"))
        inputs += ",AcornStorage=" + literal((ROOT / "src/ReplicatedStorage/Shared/AcornStorage.luau").read_text(encoding="utf-8"))
        for name in ("DataService", "PlotService"):
            inputs += "," + name + "=" + literal((ROOT / "src/ServerScriptService/Services" / (name + ".luau")).read_text(encoding="utf-8"))
        inputs += "}"
    elif args.suite == "audits":
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ServerScriptService/Services" / (name + ".luau")).read_text(encoding="utf-8")) for name in ("EventService", "SetService", "DataService", "CosmeticsService", "PiggyBank")) + "}"
        inputs = inputs[:-1] + ",Main=" + literal((ROOT / "src/ServerScriptService/Main.server.luau").read_text(encoding="utf-8")) + "}"
    elif args.suite == "midnight":
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ServerScriptService/Services" / (name + ".luau")).read_text(encoding="utf-8")) for name in ("EventService", "WorldService")) + "}"
    elif args.suite == "season":
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ServerScriptService/Services" / (name + ".luau")).read_text(encoding="utf-8")) for name in ("DataService", "SetService", "TrophyService", "SeasonService", "SocialService")) + ",SeasonBoard=" + literal((ROOT / "src/ReplicatedStorage/Shared/SeasonBoard.luau").read_text(encoding="utf-8")) + "}"
    elif args.suite == "tree":
        inputs = "{" + ",".join(name + "=" + literal((ROOT / "src/ServerScriptService/Services" / (name + ".luau")).read_text(encoding="utf-8")) for name in ("DataService", "TreeService")) + ",TreeClock=" + literal((ROOT / "src/ReplicatedStorage/Shared/TreeClock.luau").read_text(encoding="utf-8")) + "}"
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
