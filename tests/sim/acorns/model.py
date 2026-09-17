#!/usr/bin/env python3
"""Acorn faucet model after 2.7 (tree ladder) and 6.4 (Midnight Heist), for the
19.5 re-solve. Pure arithmetic over the live Config numbers, reusing the
late-game simulator for WHEN each player type owns each house rarity and how
many rebirths they have.

Assumptions (stated, deterministic):
  * Tree levels: bought on the first day the gate allows (every rung costs less
    than the house that opens it). Level 1 from day 0.
  * Harvest: the player empties their tree during every session. Offline
    growth = min(cap, offline_rate * min(gap, 8h)); online growth =
    online_rate * session length (they harvest as it fills).
  * Pig-crack acorns: solo 0; multiplayer f_rob * the audited ceiling
    (Config.acornRates full crackPerHour = 2/h).
  * Midnight Heist (replaced the Harvest Moon, September 16): no acorn
    theft at all. It doubles the pig-crack acorn for cracks that end under
    it; it runs 59.1% of 900 s slots for 180 s, so ~11.8% of online time.
    Solo players get nothing from it (residents mint no pig-crack acorn).
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "late-game"))
from econ import *            # noqa
from sim import run, HOUSES_PROPOSED, CASUAL, REGULAR, ACTIVE  # noqa
from candidates import option_A2  # noqa

RATES = [1.0, 1.25, 1.5, 2.0, 2.5]
GATE = {"common": (1, 8), "rare": (2, 12), "epic": (3, 16), "legendary": (4, 24)}
BONUS_PER, BONUS_MAX = 0.03, 0.6
NIGHT_TIME_SHARE = 0.591 * 180 / 900
NIGHT_ACORN_MULT = 2
CRACK_CEILING = 2.0

def rarity(price):
    return "legendary" if price >= 10e6 else "epic" if price >= 1e6 else "rare" if price >= 1e5 else "common"

def timeline(schedule, f_rob, f_hot=0.0, hot_share=0.0):
    s = run(option_A2(), HOUSES_PROPOSED, schedule, f_rob, f_hot, hot_share, max_days=400)
    best = {"common": 0.0}
    for i, t in s.first_bought.items():
        r = rarity(HOUSES_PROPOSED[i])
        best[r] = min(best.get(r, 1e18), t)
    return best, s.rebirth_at

def state(day, best, rebirths):
    t = day * 86400
    r = "common"
    for name in ("rare", "epic", "legendary"):
        if best.get(name, 1e18) <= t:
            r = name
    level, cap = GATE[r]
    rb = sum(1 for x in rebirths if x <= t)
    return r, level, cap, rb

def daily(schedule_hours_per_day, sessions_per_day, day, best, rebirths, mp, f_rob):
    r, level, cap, rb = state(day, best, rebirths)
    on = RATES[level] * (1 + min(BONUS_MAX, rb * BONUS_PER))
    off = RATES[level]
    if sessions_per_day <= 0:
        return 0, r, level, rb
    session = schedule_hours_per_day / sessions_per_day
    gap = 24 / sessions_per_day - session
    tree = sessions_per_day * (min(cap, off * min(gap, 8)) + on * session)
    base_crack = (f_rob * CRACK_CEILING if mp else 0) * schedule_hours_per_day
    crack = base_crack * (1 - NIGHT_TIME_SHARE)
    night = base_crack * NIGHT_TIME_SHARE * NIGHT_ACORN_MULT
    return tree + crack + night, r, level, rb, tree, crack, night

ARCHETYPES = [
    # name, schedule, hours/day, sessions/day, f_rob, mp
    ("Casual solo", CASUAL, 80 / 60 / 7, 4 / 7, 0.10, False),
    ("Regular solo", REGULAR, 1.0, 1, 0.25, False),
    ("Active solo", ACTIVE, 2.0, 1, 0.50, False),
    ("Active multiplayer", ACTIVE, 2.0, 1, 0.50, True),
]

CRATES = {"og/animal": 5, "alien": 6, "rarecrate": 15, "legendarycrate": 40}

PRICE_SETS = {
    "old": {"common": 5, "rare": 15, "legendary": 40},
    "x3": {"common": 15, "rare": 45, "legendary": 120},
}

def main(prices="x3"):
    price = PRICE_SETS[prices]
    print(f"Midnight Heist (no acorn theft); crate prices {prices}: {price}")
    for name, sched, hours, sessions, f_rob, mp in ARCHETYPES:
        best, rebirths = timeline(sched, f_rob, 0.5 if mp else 0.0, 0.5 if mp else 0.0)
        per_week = sessions * 7
        print(f"\n== {name} ({hours*7:.1f} h/week, {per_week:.0f} sessions/week) -- rare day {best.get('rare',0)/86400:.1f}, "
              f"epic day {best.get('epic',1e18)/86400:.1f}, legendary day {best.get('legendary',1e18)/86400:.1f}")
        print(" day | house     | lv | rb | acorns/day (tree+crack+night) | common crates/session | days per rare | days per legendary")
        for day in (1, 3, 7, 14, 30, 60, 120):
            total, r, level, rb, tree, crack, moon = daily(hours, sessions, day, best, rebirths, mp, f_rob)
            per_session = total / sessions
            print(f" {day:3d} | {r:9s} | {level}  | {rb:2d} | {total:6.1f} ({tree:5.1f}+{crack:4.1f}+{moon:5.1f}) | "
                  f"{per_session/price['common']:5.2f} | {price['rare']/total:5.2f} | {price['legendary']/total:5.2f}")

if __name__ == "__main__" and (len(sys.argv) < 3 or sys.argv[2] != "season"):
    main(sys.argv[1] if len(sys.argv) > 1 else "x3")

# ---- SEASON TIERS (Phase 5.3) -----------------------------------------------
# Season rank is acorns EARNED this season (tree harvest + pig-crack acorns).
# Targets from MASTER-PLAN 12: a casual child's sixteen sessions land around
# tier five; a keen player reaches ten in the third week. The overnight fill
# flattens the gap between casual and keen, so one geometric ratio cannot hit
# both: the table is two segments, fast to tier 5 then 1.3x per tier.
SEASON_TIERS = [10, 20, 40, 75, 150, 210, 280, 370, 480, 620]

def season_projection(start_day=30):
    print(f"\nSeason projection starting on game day {start_day} (28 active days):")
    for name, sched, hours, sessions, f_rob, mp in ARCHETYPES:
        best, rebirths = timeline(sched, f_rob, 0.5 if mp else 0.0, 0.5 if mp else 0.0)
        earned, reached = 0.0, {}
        for d in range(28):
            total = daily(hours, sessions, start_day + d, best, rebirths, mp, f_rob)[0]
            earned += total
            for i, need in enumerate(SEASON_TIERS):
                if earned >= need and i not in reached:
                    reached[i] = d + 1
        top = max(reached) + 1 if reached else 0
        days = ", ".join(f"T{i + 1} d{reached[i]}" for i in sorted(reached))
        print(f"  {name:20s} season total {earned:6.0f} -> tier {top:2d}   ({days})")

if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[2] == "season":
    for start in (0, 30, 120):
        season_projection(start)
