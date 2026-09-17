-- Actual rank calculation and plot renderer, using inert label/model doubles.
local Config, source = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local body = assert(source:match("function PlotService.updateRank%((.-)\nend\n"))
local load = assert(loadstring("return function(" .. body .. "\nend", "PlotService.updateRank"))
setfenv(load, setmetatable({Config=Config}, {__index=getfenv()}))
local update = load()
local attrs = {}
local plot = {signRank={Text="",Visible=false},model={SetAttribute=function(_,key,value) attrs[key]=value end}}
local cases = {{0,0},{24,0},{25,1},{99,1},{100,2},{399,2},{400,3},{1599,3},{1600,4},{1000000,4}}
for _, row in cases do
 local count, rank = row[1], row[2]
 check(Config.getRapSheetRank(count)==rank, "threshold " .. count)
 update(plot,count)
 check(plot.signRank.Visible and attrs[Config.PLOT_RAP_RANK_ATTRIBUTE]==rank, "replicated rank " .. count)
 local _, stars = plot.signRank.Text:gsub("★", "")
 check(stars==rank, "earned stars on a save with " .. count .. " robberies")
end
check(Config.getRapSheetRank(nil)==0, "legacy missing counter")
for _, invalid in {-1,-math.huge,math.huge,0/0} do
 check(Config.getRapSheetRank(invalid)==0, "invalid counts never grant rank")
end
update(plot,1600)
update(plot,nil)
check(not plot.signRank.Visible and plot.signRank.Text=="", "departed player's stars cleared")
check(attrs[Config.PLOT_RAP_RANK_ATTRIBUTE]==nil, "departed player's replicated rank cleared")
update(plot,0)
check(plot.signRank.Visible and attrs[Config.PLOT_RAP_RANK_ATTRIBUTE]==0, "new owner cannot inherit rank")
update({model={SetAttribute=function() error("shop was given a robbery rank") end}},100)
check(true, "shop sign has no rank row")
print(("PASS: %d rank checks; thresholds, exact star counts, invalid saves and owner reset."):format(checks))
