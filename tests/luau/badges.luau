-- Real badge decisions: priority, clock boundaries and private recovery tags.
local Config, source = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local names = setmetatable({}, {__index=function(_, key) return key end})
local modules = {Config=Config, Theme={}, Remotes={}}
local env = setmetatable({game={GetService=function(_, name) return {Shared=names} end},
 require=function(name) return assert(modules[name], name) end}, {__index=getfenv()})
local run = assert(loadstring(source, "RobBadge"));setfenv(run, env)
local B = run()
local facts = {vault=12345, shield=160, firstJob=true, cooldown=180, capped=2500}
check(B.describe(facts,100).text=="NEW HERE", "first-visit shield wins over all other gates")
facts.firstJob=false
local state=B.describe(facts,100)
check(state.text=="SHIELD" and state.timer=="1m", "returning player shield correctly named")
state=B.describe(facts,130)
check(state.timer=="0:30", "short shield timer reads in seconds")
state=B.describe(facts,160)
check(state.text=="ROBBED" and state.timer=="0:20", "shield expiry reveals reader's coin cooldown")
facts.vault=0
check(B.describe(facts,180).text=="EMPTY", "empty takes precedence over cap like server")
facts.vault=12345
state=B.describe(facts,180)
check(state.text=="CAPPED" and state.timer=="39m", "live cap replaces value")
state=B.describe(facts,2500)
check(state.available and state.text==Config.formatCoins(12345), "exact expiry restores value locally")
facts.multiplier=2
check(B.describe(facts,2500).text==Config.formatCoins(24690), "rush worth preserved")
check(not B.describe({vault=0.9},100).available, "fractional sub-coin balance is empty like server")
-- THE FIGURE IS ABOUT THE TARGET AND HAS NO READER IN IT. It was capped at
-- the room in the reader's own pig (4c.6) and said PIG FULL when there was
-- none, which printed one fact about YOUR pig over every pig on the street.
local clean=Config.getCrackFraction(Config.CRACK.maxSteps,0)
local full=math.floor(math.floor(100000*clean)*Config.HEIST_PAYOUT)
check(B.homeFigure(100000,0,1)==full,"the badge quotes a whole clean-crack payout")
check(B.homeFigure(100000,0,2)==math.floor(math.floor(100000*clean*2)*Config.HEIST_PAYOUT),"the rush multiplier is in the take")
local sack=Config.UPGRADES.sack.max
check(B.homeFigure(100000,sack,1)>full,"a bigger sack shows a bigger take")
check(B.homeFigure(0,0,1)==0,"an empty target is worth nothing")
-- One expression, two callers: the badge and the two prompt cards.
check(B.homeFigure(100000,0,1)==Config.homeWorth(100000,clean,1),"badge and prompt cards read one function")
check(Config.homeWorth(100000,clean,1)==math.floor(100000*clean)*Config.HEIST_PAYOUT,"homeWorth is the take, paid out, uncapped")
-- The reader's own balance can no longer change what hangs over a neighbour.
local home={vault=100000,home=50}
check(B.describe(home,100).text==Config.formatCoins(50) and B.describe(home,100).available,"badge prints the home figure")
home.home=0
check(B.describe(home,100).text==Config.formatCoins(0),"a zero take is still a figure, never PIG FULL")
home.vault=0
check(B.describe(home,100).text=="EMPTY","an empty target reads EMPTY")
local claims={claims={{key="bronze",robberId=12,stage="recover",expiresAt=200},
 {key="goldleaf",robberId=12,stage="recover",expiresAt=300}}}
check(B.recoverable(claims,12,100), "owner sees recovery tag for actual target")
check(not B.recoverable(claims,13,100), "unrelated plot receives no private tag")
check(not B.recoverable(nil,12,100), "bystander has no private recovery state")
check(B.recoverable(claims,12,200), "one expiry preserves another stacked claim")
check(not B.recoverable(claims,12,300), "last expiry clears tag without packet")
for _, stage in {"chase","home","buyback"} do
 check(not B.recoverable({claims={{robberId=12,stage=stage,expiresAt=300}}},12,100), "non-plot objective doesn't promise skin at pig: "..stage)
end
print(("PASS: %d badge checks; refusal priority, timer boundaries, rush worth and private stacked recovery tags."):format(checks))
