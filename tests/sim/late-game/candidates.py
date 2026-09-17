#!/usr/bin/env python3
"""Compare late-game curve candidates and player archetypes."""
from econ import *
from sim import *

def option_A():  # band C: levels 41-60, +2 per rebirth to RB20
    return replace(current(), abs_max=60, band2_top=40, cap_gc=1.136, inc_gc=1.10,
                   cap_cost_gc=1.16, inc_cost_gc=1.26)

def option_A2():  # band C + tapered rebirth multiplier beyond RB10
    return replace(option_A(), mult_band_rb=10, rebirth_mult_b=0.08)

def option_B():  # steepen band B so L40 ~ 1.25B, no new levels
    g = (1.25e9 / 5000 / 1.4**19) ** (1/20)
    return replace(current(), cap_gb=g, inc_gb=1.24)

def option_C():  # rebirth multiplies capacity too; 40 levels, RB to 20 opens nothing new
    return replace(current())  # handled analytically below

def ladder_table(p, label):
    print(f"\n### {label}")
    print("rb | maxL | cap@max | inc@max /s | fill min | gate | gate/inc h")
    for rb in range(0, 21):
        L = max_level(p, rb)
        cap = capacity(p, L); inc = income(p, L, rb)
        print(f"{rb:2d} | {L:3d} | {cap/1e6:9.2f}M | {inc:11.0f} | {cap/inc/60:6.1f} | {rebirth_threshold(p, rb)/1e6:9.2f}M | {rebirth_threshold(p, rb)/inc/3600:5.2f}")
        if L >= p.abs_max and rb >= 10 and max_level(p, rb) == max_level(p, rb - 1): break

def levels_table(p, lo, hi, rb_for_income):
    print("L | capacity | income(rb) | incCost | capCost | capCost/cap | clamp?")
    for L in range(lo, hi + 1):
        cap = capacity(p, L)
        print(f"{L:2d} | {cap/1e6:9.2f}M | {income(p, L, rb_for_income):10.0f} | {income_cost(p, L)/1e6:8.2f}M | {capacity_cost(p, L)/1e6:8.2f}M | {capacity_cost(p, L)/cap:.2f}")

if __name__ == "__main__":
    import sys
    which = sys.argv[1] if len(sys.argv) > 1 else "ladders"
    if which == "ladders":
        ladder_table(current(), "CURRENT")
        ladder_table(option_A(), "OPTION A: band C to L60 / RB20 (cap 1.136, inc 1.10)")
        ladder_table(option_A2(), "OPTION A2: band C + rebirth mult 0.08 past RB10")
        ladder_table(option_B(), "OPTION B: steep band B to ~1.25B at L40")
        print("\nOption A band C levels (income at RB20):")
        levels_table(option_A(), 40, 60, 20)
    elif which == "arche":
        for label, p, houses in (("CURRENT", current(), HOUSES_CURRENT), ("OPTION A", option_A(), HOUSES_PROPOSED), ("OPTION A2", option_A2(), HOUSES_PROPOSED)):
            for name, sched, f, fh, hs in (
                ("casual solo f=0.10", CASUAL, 0.10, 0, 0),
                ("regular solo f=0.25", REGULAR, 0.25, 0, 0),
                ("active solo f=0.50", ACTIVE, 0.50, 0, 0),
                ("active multi hot 50%", ACTIVE, 0.50, 1.0, 0.5),
                ("pure idle 2h/day", ACTIVE, 0.0, 0, 0),
            ):
                s = run(p, houses, sched, f, fh, hs, max_days=730)
                report(f"{label} / {name}", s, houses)
