#!/usr/bin/env python3
"""Python mirror of Config.luau's economy formulas, parameterised so that
alternative late-game curves can be modelled. `current()` reproduces the
live game and is cross-checked against dump.py before anything else is
believed."""
from dataclasses import dataclass, replace
import math

@dataclass
class Params:
    base_income: float = 10
    base_capacity: float = 5000
    inc_g: float = 1.35
    cap_g: float = 1.40
    inc_gb: float = 1.16
    cap_gb: float = 1.19
    inc_cost_g: float = 1.55
    cap_cost_g: float = 1.60
    inc_cost_gb: float = 1.26
    cap_cost_gb: float = 1.16
    band_top: int = 20
    abs_max: int = 40
    per_rebirth: int = 2
    inc_base_cost: float = 400
    cap_base_cost: float = 600
    ceil_income: float = 0.55
    ceil_capacity: float = 0.80
    rebirth_mult: float = 0.12
    rebirth_cap_multiple: float = 1.0
    # ---- proposed third band (inactive when band2_top >= abs_max) ----
    band2_top: int = 40          # where band C starts
    inc_gc: float = 1.16
    cap_gc: float = 1.19
    inc_cost_gc: float = 1.26
    cap_cost_gc: float = 1.16
    # rebirth-mult second band (mult per rebirth beyond `mult_band_rb`)
    mult_band_rb: int = 999
    rebirth_mult_b: float = 0.12

def banded(p, base, gA, gB, gC, level):
    top, top2 = p.band_top, p.band2_top
    if level <= top:
        return base * gA ** (level - 1)
    if level <= top2:
        return base * gA ** (top - 1) * gB ** (level - top)
    return base * gA ** (top - 1) * gB ** (top2 - top) * gC ** (level - top2)

def max_level(p, rb):
    return min(p.abs_max, p.band_top + p.per_rebirth * rb)

def rebirth_factor(p, rb):
    a = min(rb, p.mult_band_rb)
    b = max(0, rb - p.mult_band_rb)
    return 1 + a * p.rebirth_mult + b * p.rebirth_mult_b

def income(p, L, rb, friend=0.0):
    return banded(p, p.base_income, p.inc_g, p.inc_gb, p.inc_gc, L) * rebirth_factor(p, rb) * (1 + friend)

def capacity(p, L):
    return math.floor(banded(p, p.base_capacity, p.cap_g, p.cap_gb, p.cap_gc, L))

def income_cost(p, L):
    curve = banded(p, p.inc_base_cost, p.inc_cost_g, p.inc_cost_gb, p.inc_cost_gc, L)
    return math.floor(min(curve, p.ceil_income * capacity(p, L)))

def capacity_cost(p, L):
    curve = banded(p, p.cap_base_cost, p.cap_cost_g, p.cap_cost_gb, p.cap_cost_gc, L)
    return math.floor(min(curve, p.ceil_capacity * capacity(p, L)))

def rebirth_threshold(p, rb):
    return math.floor(capacity(p, max_level(p, rb)) * p.rebirth_cap_multiple)

def current():
    return Params()

if __name__ == "__main__":
    p = current()
    for L in (1, 10, 17, 20, 21, 30, 40):
        print(L, capacity(p, L), round(income(p, L, 0), 3), income_cost(p, L), capacity_cost(p, L))
    for rb in range(0, 11):
        print("rb", rb, max_level(p, rb), rebirth_threshold(p, rb))
