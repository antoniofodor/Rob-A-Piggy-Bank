#!/usr/bin/env python3
"""Progression simulator. Discrete 10-second steps of the real formulas.

POLICY (stated, deterministic):
  * Income drips into the pig up to capacity; robbery gains may overflow.
  * Each step, while a purchase is affordable: buy the cheaper of the two
    economy upgrades whose level is below maxLevel(rb) (ties: capacity).
  * Then the next unowned house, cheapest first, if affordable AND both trees
    are at this rebirth's ceiling OR its price <= 25% of current capacity.
    (A player does not skip every upgrade to buy a house; late in a rebirth
    they do.)
  * Rebirth when coins >= threshold and both trees are at the ceiling.
  * Robbery is modelled as an extra rate f * cold(L, rb) per hour while
    playing (f = fraction of the perfect-play ceiling), and hot spree at
    f_hot when the archetype says so. Residents' pigs scale with the thief's
    income in the live game, so this scaling is faithful.
  * Offline: coins += rate * min(gap, 8h), capped at capacity (as code).
"""
import math
from econ import *

CYCLE_HOUSE, CYCLE_SHOP = 22.25, 17.68344374975273
SHOP_PIG_SECONDS = 111.2666123579947
CRACK_TOTAL_BARE = 0.218912
HEIST_PAYOUT, SPREE_MAX_PAYOUT = 2.0, 2.0
RES_PIG_SECONDS = 200
N_HOUSES, N_SHOPS = 2, 4   # resident floor at a full server

def cold_per_hour(p, L, rb, hot=False):
    rate = income(p, L, rb)
    payout = HEIST_PAYOUT * (SPREE_MAX_PAYOUT if hot else 1.0)
    take = CRACK_TOTAL_BARE * payout
    n = N_HOUSES + N_SHOPS
    haul = (RES_PIG_SECONDS * rate * take * N_HOUSES + SHOP_PIG_SECONDS * rate * take * N_SHOPS) / n
    cycle = (CYCLE_HOUSE * N_HOUSES + CYCLE_SHOP * N_SHOPS) / n
    per_hour = 3600 * min(1 / cycle, n / 60)
    return haul * per_hour

HOUSES_PROPOSED = [0, 35e3, 120e3, 250e3, 400e3, 750e3, 1.4e6, 2.5e6, 5e6, 8e6,
                   15e6, 25e6, 40e6, 80e6, 150e6, 300e6, 600e6, 1e9]
HOUSES_CURRENT = [0, 35e3, 120e3, 400e3, 1.4e6, 5e6, 15e6, 40e6, 80e6]

STEP = 10.0

class Sim:
    def __init__(self, p, houses, f_rob=0.0, f_hot=0.0, hot_share=0.0):
        self.p, self.houses = p, houses
        self.f_rob, self.f_hot, self.hot_share = f_rob, f_hot, hot_share
        self.coins = 0.0; self.L_i = 1; self.L_c = 1; self.rb = 0
        self.owned = {0}; self.t = 0.0   # seconds of wall-clock
        self.first_bought = {0: 0.0}; self.rebirth_at = []; self.play = 0.0

    def rate(self):
        return income(self.p, self.L_i, self.rb)

    def rob_rate(self):  # coins per second while playing
        cold = cold_per_hour(self.p, self.L_i, self.rb) / 3600
        hot = cold_per_hour(self.p, self.L_i, self.rb, hot=True) / 3600
        return self.f_rob * cold * (1 - self.hot_share) + self.f_hot * hot * self.hot_share

    def buy(self):
        p = self.p; mx = max_level(p, self.rb)
        while True:
            opts = []
            if self.L_i < mx: opts.append((income_cost(p, self.L_i), "i"))
            if self.L_c < mx: opts.append((capacity_cost(p, self.L_c), "c"))
            if not opts: break
            opts.sort(key=lambda o: (o[0], o[1] != "c"))
            cost, kind = opts[0]
            if self.coins < cost: break
            self.coins -= cost
            if kind == "i": self.L_i += 1
            else: self.L_c += 1
        cap = capacity(p, self.L_c)
        maxed = self.L_i >= mx and self.L_c >= mx
        for i, price in enumerate(self.houses):
            if i in self.owned: continue
            if self.coins >= price and (maxed or price <= 0.25 * cap):
                self.coins -= price; self.owned.add(i); self.first_bought[i] = self.t
            break  # cheapest unowned only
        if maxed and self.coins >= rebirth_threshold(p, self.rb):
            self.rebirth_at.append(self.t)
            self.rb += 1; self.coins = 0.0; self.L_i = 1; self.L_c = 1

    def play_seconds(self, seconds):
        cap = capacity(self.p, self.L_c)
        steps = int(seconds / STEP)
        for _ in range(steps):
            cap = capacity(self.p, self.L_c)
            if self.coins < cap:
                self.coins = min(cap, self.coins + self.rate() * STEP)
            self.coins += self.rob_rate() * STEP
            self.t += STEP; self.play += STEP
            self.buy()

    def offline(self, seconds):
        cap = capacity(self.p, self.L_c)
        counted = min(seconds, 8 * 3600)
        self.coins = min(cap, max(self.coins, self.coins + self.rate() * counted)) if self.coins < cap else self.coins
        self.t += seconds

def run(p, houses, schedule, f_rob=0.0, f_hot=0.0, hot_share=0.0, max_days=400, stop_house=None):
    """schedule: list of (day_offset_seconds, session_seconds) per week, repeating."""
    s = Sim(p, houses, f_rob, f_hot, hot_share)
    stop_house = len(houses) - 1 if stop_house is None else stop_house
    day = 0
    while day < max_days:
        for (start, length) in schedule:
            target = day * 86400 + start
            if target > s.t: s.offline(target - s.t)
            s.play_seconds(length)
            if stop_house in s.owned: return s
        day += 7
    return s

def days(sec): return sec / 86400
def hrs(sec): return sec / 3600

# weekly schedules (second offsets within the week)
def daily(hours, n_days=7):
    return [(d * 86400 + 17 * 3600, hours * 3600) for d in range(n_days)]
CASUAL = [(d * 86400 + 17 * 3600, 20 * 60) for d in (0, 2, 4, 6)]  # 4 x 20 min
REGULAR = daily(1.0)
ACTIVE = daily(2.0)
CONTINUOUS = [(0, 7 * 86400)]

def report(label, s, houses):
    print(f"\n== {label}: rebirths={s.rb} L={s.L_i}/{s.L_c} wall={days(s.t):.1f}d play={hrs(s.play):.1f}h")
    for i, price in enumerate(houses):
        if i in s.first_bought and i > 0:
            print(f"   house {i:2d} {price/1e6:9.3f}M  first bought at day {days(s.first_bought[i]):6.1f}  ({hrs(s.first_bought[i]):7.1f} h wall)")
    for k, t in enumerate(s.rebirth_at[:25]):
        print(f"   rebirth {k+1:2d} at day {days(t):6.1f}")

if __name__ == "__main__":
    import sys
    p = current()
    s = run(p, HOUSES_CURRENT, CONTINUOUS, max_days=60)
    report("CURRENT pure idle continuous (plan says ~1.4 days to RB10/L40)", s, HOUSES_CURRENT)
