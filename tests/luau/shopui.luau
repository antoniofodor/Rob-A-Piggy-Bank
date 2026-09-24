-- Isolated UI state and rectangle checks. Does not emulate Roblox rendering/layout.
local Config, sources = ...
local checks = 0
local function check(ok, message) checks += 1; assert(ok, message) end
local function signal()
	local callbacks = {}
	return { Connect = function(_, fn) table.insert(callbacks, fn); return {Disconnect=function() end} end,
		fire = function(_, ...) for _, fn in ipairs(callbacks) do fn(...) end end }
end
local objects = {}
local function dim(a,b,c,d) return {X={Scale=a or 0,Offset=b or 0},Y={Scale=c or 0,Offset=d or 0}} end
local function size(o)
	if o._size then return o._size end
	local p = if o.Parent then size(o.Parent) else {X=1000,Y=600}
	return {X=p.X*o.Size.X.Scale+o.Size.X.Offset,Y=p.Y*o.Size.Y.Scale+o.Size.Y.Offset}
end
local function pos(o)
	local p = if o.Parent then pos(o.Parent) else {X=0,Y=0}
	local s = if o.Parent then size(o.Parent) else {X=1000,Y=600}
	return {X=p.X+s.X*o.Position.X.Scale+o.Position.X.Offset,Y=p.Y+s.Y*o.Position.Y.Scale+o.Position.Y.Offset}
end
local function instance(class)
	local o = {ClassName=class,ZIndex=1,Size=dim(),Position=dim(),Visible=true,Text="",Activated=signal(),Destroying=signal(),CanvasPosition={X=0,Y=0}}
	o._signals={};o._attributes={}
	function o:GetPropertyChangedSignal(key) self._signals[key]=self._signals[key] or signal();return self._signals[key] end
	function o:GetAttributeChangedSignal(key) return self:GetPropertyChangedSignal("attr:"..key) end
	function o:GetAttribute(key) return self._attributes[key] end
	function o:SetAttribute(key,value) self._attributes[key]=value end
	function o:IsA(c) return c == self.ClassName or c == "GuiObject" end
	function o:GetChildren()
		local out = {}; for _, x in ipairs(objects) do if x.Parent == self and not x.destroyed then table.insert(out,x) end end; return out
	end
	function o:GetDescendants()
		local out = {}; for _, child in ipairs(self:GetChildren()) do table.insert(out,child); for _,x in ipairs(child:GetDescendants()) do table.insert(out,x) end end; return out
	end
	function o:FindFirstChild(name) for _, x in ipairs(self:GetChildren()) do if x.Name == name then return x end end end
	function o:FindFirstChildOfClass(name) for _, x in ipairs(self:GetChildren()) do if x.ClassName == name then return x end end end
	function o:Destroy() self.destroyed=true;self.Parent=nil end
	o.DescendantAdded=signal()
	setmetatable(o,{__index=function(_, key)
		if key == "AbsoluteSize" then return size(o) elseif key == "AbsolutePosition" then return pos(o)
		-- A COARSE ESTIMATE AND NOT A MEASUREMENT. This harness does not
		-- emulate text shaping, and code that seats one element against the
		-- measured width of another needs something monotonic in the string
		-- length to run at all. Never assert a pixel width against it.
		-- No layout runs here, so a scroll canvas is assumed to be exactly its
		-- window: code that asks "is there more below the fold" gets NO, which is
		-- the answer that asserts nothing.
		elseif key == "AbsoluteCanvasSize" then return size(o)
		elseif key == "TextBounds" then return {X=#tostring(o.Text)*(o.TextSize or 14)*.5,Y=o.TextSize or 14} end
	end})
	table.insert(objects,o);return o
end
local colour = {Lerp=function(self) return self end}
for _, rarity in pairs(Config.RARITIES) do rarity.colour=colour end
-- Chest hues get the same treatment: the crate page tints its summary panel
-- with `CHESTS[key].colour`, and Config builds those through its own Color3
-- stub, which has no Lerp on it.
for _, chest in pairs(Config.CHESTS) do if chest.colour then chest.colour=colour end end
local Theme = setmetatable({HUE=setmetatable({},{__index=function() return colour end}),
	-- `coinPrice` seats a coin against a price string and `readable` solves a
	-- text tone against its ground; the stub keeps the text and hands the tone
	-- back, since neither contrast nor a drawn glyph is what these checks are
	-- about.
	coinPrice=function(o,text) o.Text=text end,readable=function(tone) return tone end},{__index=function() return colour end})
Theme.SHOP_COLOURS=setmetatable({},{__index=function() return colour end})
Theme.coin=function(parent) local f=instance("Frame");f.Parent=parent;return f end
local names=setmetatable({},{__index=function(_,key) return key end})
local modules={Config=Config,Theme=Theme,UpgradePreview={build=function() return {} end},PiggyModel={build=function() return {} end}}
-- The tier dressing paints gradients this harness cannot draw; stubbed to the
-- palette shape its callers read, so the layout checks still run over it.
modules.ShopSkinCards={dressCard=function() return {colour=colour,deep=colour} end,
	onTierText=function() end,backdrop=function() end,mount=function() end}
local delays={}
local environment=setmetatable({
	game={GetService=function() return {Shared=names} end},script={Parent=names},require=function(name) return assert(modules[name],name) end,
	Instance={new=instance},UDim2={new=dim,fromOffset=function(x,y) return dim(0,x,0,y) end,fromScale=function(x,y) return dim(x,0,y,0) end},
	UDim={new=function(s,o) return {Scale=s,Offset=o} end},Vector2={zero={X=0,Y=0},new=function(x,y) return {X=x,Y=y} end},
	Enum=setmetatable({},{__index=function() return names end}),
	Color3={new=function() return colour end,fromRGB=function() return colour end},
	ColorSequence={new=function(a,b) return {a,b} end},
	-- `spawn` runs the thread at once: `HUDLayout.bindAction` spawns the
	-- jump-button watcher, which returns on the first line here because a
	-- harness has no LocalPlayer to find a PlayerGui under.
	task={defer=function() end,delay=function(_, fn) table.insert(delays,fn) end,spawn=function(fn,...) fn(...) end},
},{__index=getfenv()})
local function load(name)
	local fn=assert(loadstring(sources[name],name));setfenv(fn,environment);modules[name]=fn();return modules[name]
end
-- Run the real placement helper while leaving Theme's illustration builders stubbed.
local floatClose=assert(loadstring("return function"..assert(sources.Theme:match("function Theme%.floatClose(.-)\nend")).."\nend"))
setfenv(floatClose,environment);Theme.floatClose=floatClose()
local Icons=load("ShopIcons")
local W=load("ShopWidgets")
local previews=0
-- THE STUB HAS TO CLEAR THE ICON, BECAUSE THE REAL ONE DOES. `W.preview`
-- destroys any `ShopIcon` in the holder before it seats its ViewportFrame --
-- that is what makes the two art routes exclusive. A stub that only counted
-- left the previously selected row's render sitting in the holder, so a card
-- that had correctly fallen through to its model still answered a probe with
-- somebody else's artwork: a test double lagging the thing it doubles, which
-- accuses the code under test rather than itself.
W.preview=function(holder)
	previews+=1
	local icon=holder and holder:FindFirstChild("ShopIcon")
	if icon then icon:Destroy() end
end
local Facts=load("ShopUpgradeFacts")
local Upgrades=load("ShopUpgrades")
load("ShopMarks")
-- `ShopAchievements` went on 2026-09-23. It was a complete, unreachable
-- page: nothing in `src/` required it, `Config.TROPHIES` is empty so its
-- own walk could never find a row, and the trophy record moved INSIDE the
-- house (the kit vestibule's `Achievements` wall anchor). This suite was
-- its only reader, and all it proved was that the file loaded.
local Shell=load("ShopRevamp")
local Catalogue=load("ShopCatalogueLayout")
local columns,cardHeight=Catalogue.metrics(590,210,{X=156,Y=182})
check(columns==4 and cardHeight==144,"phone catalogue shows more compact cards per row")
local desktopColumns,desktopHeight=Catalogue.metrics(1000,600,{X=156,Y=182})
check(desktopColumns==6 and desktopHeight==182,"desktop catalogue retains its card size")
local sample=instance("Frame");sample._size={X=140,Y=144}
local name=W.text(sample,"Name","Sample",15);name.Position=dim(0,8,0,110);name.Size=dim(1,-16,0,20)
local price=W.text(sample,"Price","100 coins",13);price.Position=dim(0,8,0,150);price.Size=dim(1,-16,0,24)
Catalogue.bindCard(sample,182)
check(name.TextSize==13 and name.Position.Y.Offset+name.Size.Y.Offset<=price.Position.Y.Offset,"compact card text stays legible and separated")
check(price.Position.Y.Offset+price.Size.Y.Offset<=144,"compact price stays within card")
sample._size={X=156,Y=182};sample:GetPropertyChangedSignal("AbsoluteSize"):fire()
check(name.Position.Y.Offset==110 and name.TextSize==15,"resizing back restores original card geometry")
local empty=instance("Frame");check(not Catalogue.hasItems(empty),"empty shelf has no visible items")
local item=instance("TextButton");item.Parent=empty
check(Catalogue.hasItems(empty),"populated shelf keeps its header")
item.Visible=false;check(not Catalogue.hasItems(empty),"hidden stock does not leave an empty header")
local Contents=load("CrateContents")
local function sized(w,h) local f=instance("Frame");f._size={X=w,Y=h};return f end
local view=sized(820,550)
local bought={}
local ui=Upgrades.new(view,function(key) table.insert(bought,key) end)
local upgrades={}
for key, spec in pairs(Config.UPGRADES) do upgrades[key]={name=spec.name,level=0,max=spec.max,cost=Config.getUpgradeCost(key,0),blurb=spec.blurb} end
ui:setUpgrades(upgrades)
-- `coins` is the ONLY field this browser reads off the economy push now. It
-- took `incomeLevel`, `maxIncome` and `incomeCost` for the Earn Faster row,
-- which is off the shelf (designer, 2026-09-23): the rate a piggy pays is
-- raised by the permanent coin multiplier, which is bought with a rebirth.
local economy={coins=1e9,incomeLevel=4,maxIncome=50,incomeCost=200,rebirths=2,friendBonus=0,rate=Config.getIncomeRate(4,2,0)*1.2}
ui:setEconomy(economy)
check(#ui.groupButtons==2,"the upgrade tab is the two sides of a robbery and nothing else")
check(ui.title.Text=="Vault Lock","the first Defend row is selected on first load")
check(ui.tiles.locks.check.Visible,"selected upgrade has an explicit checkmark")
-- NO EARN GROUP AND THEREFORE NO WAY TO REACH THE ROW: the tile is never
-- built, `info` no longer answers for the key, and the stat comparison that
-- priced it is gone. Three checks rather than one, because a tab that merely
-- hid the button would still sell it to anything that called in.
check(ui.tiles.income==nil and ui:info("income")==nil and Facts.rows("income",4,5,economy)[1]==nil,
	"there is no Earn Faster tile, info row or fact row")
check(ui.tiles.capacity==nil and Facts.rows("capacity",1,2,economy)[1]==nil,"there is no Bigger Piggy Bank tile or fact row: the pig has no ceiling")
-- EVERY ROW LEFT HAS A FIXED CEILING. `gated` was income's alone -- the six
-- tree rows carry a `max` no rebirth lifts -- so MAX LEVEL is the truth about
-- all of them and nothing in here may print NEEDS REBIRTH.
for key,tile in pairs(ui.tiles) do
	check(ui:info(key).gated==nil and not tile.lock.Visible,"no upgrade in this tab is rebirth-gated: "..key)
end
-- THE DEFEND PAIR IS DRAWN FROM THE MODEL AND MUST NOT GAIN A RENDER BACK.
-- Their uploads showed a bank safe and a white picket -- an object no player
-- owns, and one tier of five -- so both rows fall through `showArt` to
-- `UpgradePreview`, which builds the dial in the tier's own metal and the
-- fence actually being bought. Asserted at BOTH ends: no icon mounted on the
-- card, and no id for either key, because putting a row back in `ShopIcons`
-- silently wins over the model.
check(ui.model:FindFirstChild("ShopIcon")==nil,"the vault dial is drawn from the model rather than a render")
check(Icons.ids.locks==nil and Icons.ids.fences==nil,"neither Defend row has uploaded art to prefer over its model")
local supplyHolder=instance("Frame")
check(Icons.supply(supplyHolder,"gum"):GetAttribute("IconKey")=="bubblegum-bomb","gum maps to the bomb artwork")
check(Icons.supply(supplyHolder,"golden"):GetAttribute("IconKey")=="golden-bone","golden bone has its own artwork")
check(Icons.supply(supplyHolder,"steak")==nil,"supplies without artwork keep their model preview")
local count=previews;ui:setEconomy(economy);check(previews==count,"coin updates reuse previews")
ui.buy.Activated:fire();ui.buy.Activated:fire();check(#bought==1 and bought[1]=="locks","upgrade double tap debounced")
delays[1]()
economy.coins=0;ui:setEconomy(economy);ui.buy.Activated:fire();check(#bought==1,"unaffordable upgrade does not send")
economy.coins=1e9;ui:setEconomy(economy)
ui.groupButtons[2].Activated:fire();check(ui.tiles.sack.button.Visible,"Rob group exposes Bigger Sack")
ui.tiles.sack.button.Activated:fire();check(ui.selected=="sack","selection changes detail target")
local sackArt=ui.model:FindFirstChild("ShopIcon")
check(sackArt~=nil and sackArt:GetAttribute("IconKey")=="sack" and sackArt.Image==Icons.ids.sack,
	"a row that still has approved art mounts it rather than falling through to a model")
ui.buy.Activated:fire();check(bought[2]=="sack","purchase sends selected key")
-- A RUNG SHOWS WHAT IT CHANGES, AND NEVER A ROW THAT READS THE SAME TWICE.
-- That is the guarantee `ShopUpgradeFacts` is built to make structurally
-- rather than by anybody checking: it filters its candidates on whether the
-- value MOVES. It is worth a test because the ladder it protects against is
-- real and still in Config -- Lockpicks' spare picks go 0, 1, 1, 2, 2, so two
-- of its four rungs leave that number alone, and a fixed row would advertise
-- a four-million-coin purchase as doing nothing.
--
-- AND AT MOST TWO ROWS, which is the "much simpler" half of the same change:
-- Bigger Sack printed three views of one multiplier (`sackScale`) and now
-- prints the clean run alone.
for key, spec in pairs(Config.UPGRADES) do
	for level=0,spec.max do
		local rows=Facts.rows(key,level,math.min(level+1,spec.max),economy)
		check(#rows>0,"upgrade has concrete stats: "..key)
		check(#rows<=2,("%s at level %d shows at most two rows"):format(key,level))
		if level==spec.max then
			for _,row in ipairs(rows) do check(row.now==row.after,"max level never invents another improvement") end
		else
			for _,row in ipairs(rows) do
				check(row.now~=row.after,
					("%s level %d->%d prints only what the purchase changes (%s)"):format(key,level,level+1,row.label))
			end
		end
	end
end
-- NO STUDS ANYWHERE IN THIS TAB (designer, this session). The two movement
-- rungs printed "18.00 studs/s", which is a unit this audience has never met;
-- they are a percent against their own level 0 now, and level 0 reads
-- "Normal" rather than "+0%".
for _,key in ipairs({"boots","tiptoe"}) do
	for level=0,Config.UPGRADES[key].max do
		for _,row in ipairs(Facts.rows(key,level,math.min(level+1,Config.UPGRADES[key].max),economy)) do
			check(not string.find(row.now,"stud") and not string.find(row.after,"stud"),
				key.." never prints studs")
			check(row.now=="Normal" or string.find(row.now,"%%")~=nil,
				key.." prints a percent or Normal, never a raw number: "..row.now)
		end
	end
end
check(Facts.rows("boots",0,1,economy)[1].now=="Normal","no upgrade at all reads Normal rather than +0%")
-- NO RUNG MAY ADVERTISE ITSELF AS A DOWNGRADE, and the fence ladder is where
-- that is not hypothetical: `FENCE_TIERS` slows 20, 38, 58, 50, 50 per cent,
-- so the Electric Fence slows LESS than the Barbed Wire under it and buys a
-- 2.5-second stun instead. Ranked on the slow, its card read
-- "Slows thieves by: 58% -> 50%" on a purchase that costs 35.9M.
local slowSeen={}
for level=0,Config.UPGRADES.fences.max-1 do
	for _,row in ipairs(Facts.rows("fences",level,level+1,economy)) do
		if row.label=="Slows thieves by" then
			local a=tonumber(string.match(row.now,"%d+")) or 0
			local b=tonumber(string.match(row.after,"%d+")) or 0
			check(b>a,("the fence never sells a smaller slow (level %d: %s to %s)"):format(level,row.now,row.after))
			slowSeen[#slowSeen+1]=level
		end
	end
end
check(#slowSeen>0,"the fence does still sell its slow on the rungs that raise it")
local stunRung=Facts.rows("fences",3,4,economy)
check(stunRung[2]~=nil and stunRung[2].label=="Shocks them" and stunRung[2].after=="Yes",
	"the rung that buys the stun leads with the stun rather than with its smaller slow")

-- ONE FENCE, ONE BUILDER -- READ AS SOURCE, BECAUSE THE FAULT WAS NEVER A
-- WRONG NUMBER. The card drew its own primitives fence (a client cannot call
-- `CreateMeshPartAsync`) while the lawn tiled a generated MESH, so there were
-- two descriptions of one object drawn from the same brief, and they had
-- drifted far enough that the card showed a fence the buyer would not get.
-- Nothing measurable was wrong with either; only a picture said so. These
-- four checks are what stop it drifting back, and they are deliberately
-- WIRING checks rather than geometry ones.
local preview,panel,plot,main=sources.UpgradePreview,sources.FencePanel,sources.PlotService,sources.Main
check(preview:find("FencePanel.template(",1,true)~=nil,
	"the fence card clones the parked panel rather than drawing its own fence")
check(plot:find("FencePanel.template(",1,true)~=nil,
	"the lawn asks the same module for the same panel")
-- The card and the lawn have to SIZE it the same way too, or they are two
-- descriptions again with one mesh between them. Both solve the uniform
-- scale off the authored height so the panel lands on `decorTop`.
check(preview:find("tier.decorTop / spec.size.Y",1,true)~=nil
	and plot:find("tier.decorTop / spec.size.Y",1,true)~=nil,
	"both ends scale the panel off its authored height the same way")
-- PlotService may no longer build one itself: a second `CreateMeshPartAsync`
-- for a fence is a second template, which is how this started.
-- The CALL and not the word: the reason it no longer builds one is written
-- in a comment right there, and a check that cannot tell a call from the
-- sentence explaining it is a check that fails on its own documentation.
check(plot:find(":CreateMeshPartAsync(",1,true)==nil,
	"PlotService builds no fence mesh of its own any more")
check(main:find("FencePanel).prewarm()",1,true)~=nil,
	"the panels are warmed at boot, or neither end has one to clone")
-- AND THE PRIMITIVES SURVIVE AS THE FALLBACK. An empty or moderated
-- `Config.FENCE_MESH` row has to leave a fence on the card rather than a
-- blank well -- the same call `builders.sack` makes about its bag.
check(preview:find("primitive",1,true)~=nil and preview:find('style == "rickety"',1,true)~=nil,
	"a style with no mesh still draws the primitives fence it always drew")
-- THE INCOME COMPARISON AND THE REBIRTH-GATE BLOCK STOOD HERE. They drove the
-- one row with a ceiling a rebirth lifted -- lock chip, LEVEL 42 / 42, a
-- REBIRTH TO UNLOCK MORE buy strip that refused to send -- and there is no such
-- row any more. The invariant that replaces them is asserted above: no tile in
-- this tab is gated, so none of those states is reachable.
ui.busy=false;ui.groupButtons[1].Activated:fire()
local maxed=table.clone(upgrades);maxed.locks=table.clone(upgrades.locks);maxed.locks.level=maxed.locks.max
ui:setUpgrades(maxed);ui.tiles.locks.button.Activated:fire()
check(ui.tiles.locks.price.Text=="MAX LEVEL" and ui.buy.Text=="MAX LEVEL" and not ui.buy.Active,
	"a finished tree row reads MAX LEVEL rather than NEEDS REBIRTH")
local requestsBefore=#bought;ui.buy.Activated:fire();check(#bought==requestsBefore,"a maxed card never sends a purchase")
ui:setUpgrades(upgrades)
-- Only the open group's tiles are repainted, so the check is asserted on
-- the card that was selected rather than on a hidden tile's stale flag.
ui.groupButtons[2].Activated:fire();ui.tiles.sack.button.Activated:fire()
check(ui.selected=="sack" and ui.tiles.sack.check.Visible,"selection check follows the selected card")
check(ui.model:FindFirstChild("ShopIcon"):GetAttribute("IconKey")=="sack","detail artwork follows selection")
local iconCount=0;for _,child in ipairs(ui.model:GetChildren()) do if child.Name=="ShopIcon" then iconCount+=1 end end
check(iconCount==1,"changing selection replaces rather than stacks artwork")
-- TWO ART ROUTES, AND WHICH ROW TAKES WHICH IS THE ASSERTION. `showArt`
-- prefers an uploaded render and falls through to `UpgradePreview`, so the
-- Defend pair -- whose renders showed a bank safe and one picket of five
-- tiers -- has to reach the MODEL on both the card and the detail panel,
-- while the four Rob rows keep their art and their measured crops.
ui.groupButtons[1].Activated:fire()
for _,key in ipairs({"locks","fences"}) do
	ui.tiles[key].button.Activated:fire()
	check(ui.model:FindFirstChild("ShopIcon")==nil,"detail draws "..key.." from its model")
	check(ui.tiles[key].model:FindFirstChild("ShopIcon")==nil,"card draws "..key.." from its model")
end
ui.groupButtons[2].Activated:fire()
for _,key in ipairs({"lockpicks","sack","boots","tiptoe"}) do
	ui.tiles[key].button.Activated:fire()
	local image=ui.model:FindFirstChild("ShopIcon")
	check(image and image.Image==Icons.ids[key],"detail uses uploaded art for "..key)
	check(ui.tiles[key].model:FindFirstChild("ShopIcon").Image==Icons.ids[key],"card uses matching art for "..key)
	check(image.ImageRectSize.X>0 and image.ImageRectSize.X<768,"upgrade artwork has measured crop for "..key)
end
local route=0
local panel=sized(1040,660)
local header=instance("Frame");header.Parent=panel;header.Size=dim(1,-20,0,52)
local tabs={};for i=1,7 do tabs[i]={view=instance("Frame")};tabs[i].view.Parent=panel end
local shell
-- The real rail, as ClientMain numbers it: the Worn tab is gone (Most Wanted
-- gear lives in the bag and catch effects moved to Guardians), the old
-- "Everything" home page is gone (designer, 2026-09-23), and the Robux tab is
-- last. A suite that kept a retired tab would be routing to nothing.
-- `upgrades` IS IN HERE AND USED TO BE A LITERAL 2 INSIDE THE SHELL: the one
-- index a reorder could move with nothing to say so.
local at={upgrades=1,home=2,rides=3,items=4,crates=5,companions=6,premium=7}
shell=Shell.new({panel=panel,header=header,rail=instance("Frame"),coins=instance("TextLabel"),title=instance("TextLabel"),close=instance("TextButton"),tabs=tabs,at=at,
	selectTab=function(i) route=i;shell:select(i) end})
-- ============================================================
-- NO HOME PAGE, AND A BACK ARROW ONLY WHERE THERE IS A PARENT
-- ============================================================
--
-- The sidebar and the six landing cards were the two ways of reaching any
-- shelf from any other. The sidebar went first and the landing followed
-- (designer, 2026-09-23: "we don't need that original shop home page
-- anymore"). What is asserted here is the NEGATIVE, because that is the half
-- that can come back silently.
check(shell.sidebar==nil and shell.links==nil,"the shelf index down the left is gone")
check(shell.tiles==nil and shell.home==nil and shell.grid==nil and shell.featured==nil,
	"the landing grid and its Robux banner are gone")
for _,c in ipairs(shell.categories) do
	-- WHERE, AND IT HAS TO BE A REAL DOOR. `shopLocation` walks the two tables
	-- the street and the hallway are actually built from, so every coin shelf
	-- the sign can name is a shelf somebody can walk to.
	if c.key~="premium" then
		check(Config.shopLocation(c.key)~=nil,"every coin shelf has a door: "..c.key)
	end
end
-- A shelf opened by a door has nowhere to go back to, so it carries the
-- basket rather than an arrow into nothing.
shell:select(at.home)
check(not shell.back.Visible and shell.shopIcon.Visible,"a door's shelf shows no back arrow")
route=0;shell.back.Activated:fire()
check(route==0,"and a hidden arrow routes nowhere")

-- ============================================================
-- ONE DOOR PER SHELF, AND THE DOORS ARE `Config`'S
-- ============================================================
--
-- Read as SOURCE, because neither of these is reachable from a harness: the
-- basket is a click handler on a ScreenGui and the category-to-view table is
-- a local inside a `do` block. Both fail SILENTLY -- a door whose category
-- nothing matches opens nothing, and a basket wired back to a plain toggle
-- looks exactly like the shop working -- which is the combination this
-- project has paid for more than any other.
do
	local client=sources.ClientMain
	-- THE BASKET SELLS ROBUX AND NOTHING ELSE. The old line was a bare
	-- `panel.Visible = not panel.Visible`, which is one edit away from coming
	-- back and would put every shelf in the game two taps from the middle of a
	-- robbery again.
	local handler=client:match("shopToggle%.Activated:Connect%(function%(%)(.-)\nend%)")
	check(handler~=nil,"the shop button still has a handler")
	check(handler:find("selectTab(SHOP.at.premium)",1,true)~=nil,
		"the HUD basket opens the robux shelf")
	check(handler:find("panel.Visible = not panel.Visible",1,true)==nil,
		"the HUD basket no longer opens whatever tab was last shown")
	-- B IS THE SAME ROUTE. A keybind that opened a different page from the
	-- control beside it is two shops wearing one name, and the keyboard half
	-- is the one nobody would think to re-check.
	local key=client:match("if input%.KeyCode == Enum%.KeyCode%.B then(.-)elseif")
	check(key~=nil and key:find("selectTab(SHOP.at.premium)",1,true)~=nil,
		"B opens the robux shelf like the button beside it")

	-- AND NO SIDE DOOR. The basket was closed to the coin shelves while three
	-- other HUD routes went on calling `selectTab` on one: the bag's
	-- collection log (Crates), the first-session buy-back card (Crates) and
	-- the ride picker's locked STYLES pill (Rides). The buy-back card answers
	-- through `SHOP.pointTo` -- a toast naming the building, since a buy-back
	-- costs coins. The pill and the bag's crate button open Robux shelves,
	-- because the Style Pack and a crate are both Robux sales (designer,
	-- 2026-09-23: "keep the crates in the robux shop").
	local bagCrate=client:match("openCrate = function%(_chestKey: string%)(.-)\n\t\tend,")
	check(bagCrate~=nil and bagCrate:find("SHOP.openRobuxCrates()",1,true)~=nil
			and bagCrate:find("setBag(false)",1,true)~=nil
			and bagCrate:find("selectTab",1,true)==nil,
		"the bag's collection log opens the crates through the Robux route")
	local robux=client:match("function SHOP.openRobuxCrates%(%)(.-)\nend")
	check(robux~=nil and robux:find("Crates.setBuybacks(false)",1,true)~=nil
			and robux:find("SHOP.doorAt = nil",1,true)~=nil
			and robux:find("selectTab(SHOP.at.crates)",1,true)~=nil,
		"the Robux route hides the coin buy-backs and carries no counter leash")
	check(client:find("openCrates = function() SHOP.openRobuxCrates() end",1,true)~=nil,
		"the Robux shop's crates card goes through the same route")
	local door=client:match('Remotes.get%("ShopDoor"%).OnClientEvent:Connect%(function%(tab%)(.-)\n\tend%)')
	check(door~=nil and door:find("Crates.setBuybacks(true)",1,true)~=nil
			and door:find("SHOP.doorAt = root and root.Position",1,true)~=nil,
		"a counter shows the buy-backs and records where it was opened")
	-- Several things watch the panel; the closer is the one that goes home.
	local closer
	for body in client:gmatch('panel:GetPropertyChangedSignal%("Visible"%):Connect%(function%(%)(.-)\nend%)') do
		if body:find("SHOP.doorAt = nil",1,true) then closer=body end
	end
	check(closer~=nil and closer:find("SHOP.doorAt = nil",1,true)~=nil
			and closer:find("Crates.setBuybacks(false)",1,true)~=nil,
		"closing the panel drops the leash and hides the buy-backs")
	-- THE LEASH: a counter's shop closes when you walk away from the counter,
	-- and lets go of the two tabs the HUD opens from anywhere.
	local leash=client:match("SHOP.LEASH = %d+\n\tRunService.Heartbeat:Connect%(function%(%)(.-)\n\tend%)")
	check(leash~=nil and leash:find("SHOP.doorAt",1,true)~=nil
			and leash:find("SHOP.selected == SHOP.at.premium",1,true)~=nil
			and leash:find("panel.Visible = false",1,true)~=nil,
		"walking away from a counter closes its shop, and the Robux shelf is exempt")
	check(client:find("SHOP.selected = index",1,true)~=nil,
		"selectTab records what is open for the leash")
	check(sources.Crates:find("section.buybacks.Visible = any and showBuybacks",1,true)~=nil
			and sources.Crates:find("local showBuybacks = false",1,true)~=nil,
		"coin buy-backs are hidden unless a counter opened the shelf")
	check(sources.PremiumShop:find("deps.openCrates()",1,true)~=nil
			and sources.PremiumShop:find("Crates show their real odds",1,true)~=nil,
		"the Robux shop carries the crates and says their odds are shown")
	local buyback=client:match("openCrates = function%(_key: string%)(.-)\n\tend,")
	check(buyback~=nil and buyback:find('SHOP.pointTo("style"',1,true)~=nil
			and buyback:find("selectTab",1,true)==nil,
		"the buy-back card names PIGGY OUTFITTERS rather than opening Crates")
	check(client:find("openStyles = function() panel.Visible = true; selectTab(SHOP.at.premium) end",1,true)~=nil,
		"the locked styles pill opens the Style Pack's own shelf, the Robux one")
	check(client:find("function SHOP.pointTo(category: string, what: string)",1,true)~=nil
			and client:find("Config.shopLocation(category)",1,true)~=nil,
		"and the toast's sentence is the directory's own, from Config.shopLocation")
	check(client:find("SHOP.toast = show",1,true)~=nil,
		"the notification builder hands pointTo its toast")
	-- THE OLD FRONT PAGE IS GONE, AND SO IS ITS VIEW (designer, 2026-09-23:
	-- "we don't need that original shop home page anymore"). Its shelf cards
	-- opened coin tabs directly, so a copy of it coming back puts eight side
	-- doors back at once.
	check(client:find("buildFrontPage",1,true)==nil and client:find("frontUI",1,true)==nil
			and client:find("StartView",1,true)==nil and client:find("selectTab(1)",1,true)==nil,
		"the old front page, its refresh plumbing and its view are all gone")
	check(client:find("SHOP.shell:setBack(SHOP.at.premium)",1,true)~=nil,
		"crates reached through the Robux shop point their back arrow at it")

	-- EVERY DOOR RESOLVES TO A VIEW. `Config` says which shelf a door serves
	-- and this file is the only place that knows a shelf is a Frame with a
	-- name; the join between them is the thing that can go quietly wrong.
	local table_=client:match("local VIEW_OF: { %[string%]: string } = {(.-)}")
	check(table_~=nil,"the client still maps a shop category to a view")
	local views={}
	for key_,view in table_:gmatch("(%w+) = \"(%w+)\"") do views[key_]=view end
	local seen={}
	local doors={}
	for _,placement in ipairs(Config.SHOPS) do table.insert(doors,placement) end
	for _,counter in ipairs(Config.BASE_COUNTERS) do table.insert(doors,counter) end
	for _,entry in ipairs(doors) do
		check(views[entry.category]~=nil,
			"the "..entry.tab.." door's shelf ("..tostring(entry.category)..") has a view")
		-- ONE NAMESPACE, BECAUSE `Remotes.ShopDoor` CARRIES ONE STRING. A street
		-- unit and a hallway counter sharing a key would have the second one
		-- silently open the first one's shelf -- the `"LockLevel"` trap again, an
		-- interface with no compiler behind it.
		check(not seen[entry.tab],"door key "..entry.tab.." is used once")
		seen[entry.tab]=true
	end
	-- AND NO SHELF HAS TWO. Two doors onto one tab is a shop nobody needs to
	-- walk to, which is the whole of what this change was about.
	local byCategory={}
	for _,entry in ipairs(doors) do
		check(not byCategory[entry.category],
			"shelf "..tostring(entry.category).." has one door, not two")
		byCategory[entry.category]=entry.tab
	end
	-- A COUNTER'S SECTION IS A SECTION. `SHOP.openSection` returns in silence
	-- for a name it does not know, so a typo here is a counter whose prompt
	-- fires and whose panel never opens.
	for _,counter in ipairs(Config.BASE_COUNTERS) do
		check(client:find("sections."..counter.section.." = ",1,true)~=nil,
			"the "..counter.tab.." counter jumps to a section that exists: "..counter.section)
	end
end
-- There is no style sub-view any more: outfits live in the bag, and the crates
-- category is signed Style & Crates. Reached through the Robux shop, its arrow
-- goes back THERE -- the only route with a parent -- and nowhere else.
shell:select(at.crates);check(shell.title.Text=="Style & Crates" and not shell.back.Visible,"crates category is signed Style & Crates with no arrow of its own")
shell:setBack(at.premium);check(shell.back.Visible and not shell.shopIcon.Visible,"crates through the Robux shop carry a back arrow")
shell.back.Activated:fire();check(route==at.premium and shell.title.Text=="Robux","back returns to the Robux shop")
check(not shell.back.Visible,"and the Robux shop itself has no arrow")
check(shell.footer==nil and shell.achievements==nil,"shop has no bag or achievement section")
local entries={}
for tier,pool in pairs(Config.chestPool("og")) do for _,key in ipairs(pool) do table.insert(entries,{kind="skin",key=key,name=Config.SKINS[key].name,tier=tier}) end end
local opened={}
local listVisible=true
local contents=Contents.new(tabs[at.crates].view,{stockOf=function() return entries end,iconFor=function() end,open=function(key) table.insert(opened,key) end,showList=function(v) listVisible=v end})
-- No `cost` and no `currency`: a crate is earned or bought with Robux and
-- never with in-game currency, which is the rule `auditRandomOutcomes` keeps.
local state={chests={og={owned=1,total=#entries,odds={common=51.25,rare=44.75,legendary=4}}}}
local cosmetics={skins={}};for _,e in ipairs(entries) do cosmetics.skins[e.key]={unlocked=false} end
cosmetics.skins[entries[1].key].unlocked=true
contents:update(state,20,cosmetics,nil);contents:show("og")
check(#contents.tiles==#entries and not listVisible,"collection shows entire actual crate pool")
-- Per tier and per ROW now that the odds are drawn as rows rather than one
-- wrapped label, and asserted as the whole number the row prints. Still proves
-- the server drove it: Config's own `og` common is 52, so 51 cannot come from
-- the fallback.
check(contents.oddsRows.common.pct.Text=="51%","displays server odds without replacing with config defaults")
contents.filters.Owned.Activated:fire()
local visible=0;for _,tile in ipairs(contents.tiles) do if tile.frame.Visible then visible+=1 end end
check(visible==1,"owned filter uses authoritative ownership")
contents.filters["Not owned"].Activated:fire()
visible=0;for _,tile in ipairs(contents.tiles) do if tile.frame.Visible then visible+=1 end end
check(visible==#entries-1,"not-owned filter excludes owned entries")
-- THE OPEN BUTTON SENDS NOTHING. Crates are earned or bought with Robux, so
-- the button on this surface is a signpost, not a purchase: pressing it never
-- reaches the server, and it says where a crate comes from instead.
contents.open.Activated:fire();contents.open.Activated:fire();check(#opened==0,"crate surface never sends an open request")
check(not contents.open.Active and contents.open.Text=="EARN THIS CRATE","crate button is an inert signpost naming how a crate is got")
contents:close();check(listVisible,"back restores crate and buyback list")
local function contained(child,parent,message)
	local p,s=pos(child),size(child);local pp,ps=pos(parent),size(parent)
	check(s.X>0 and s.Y>0 and p.X>=pp.X-1 and p.Y>=pp.Y-1 and p.X+s.X<=pp.X+ps.X+1 and p.Y+s.Y<=pp.Y+ps.Y+1,message)
end
for _,screen in ipairs({{1480,920},{1040,660},{776,335},{627,287},{345,640},{920,470}}) do
	panel._size={X=screen[1],Y=screen[2]};shell:select(at.premium)
	check(shell.deps.tabs[at.crates].view.Position.X.Offset==16,
		"a shelf starts at the panel edge now the sidebar's strip is free")
	local close=shell.deps.close
	check(close.AnchorPoint.X==1 and close.Position.X.Offset>0 and close.Position.Y.Offset<0,"close overlaps the upper-right modal corner")
	check(close.Size.X.Offset>=44 and close.Size.Y.Offset>=44,"close retains a phone-sized tap target")
	check(shell.title.Size.X.Offset+shell.title.Position.X.Offset<=-shell.banner.Size.Y.Offset/2+.01,"heading leaves room for the sign's angled end")
	check(shell.categories[2].title=="Home","home category has the shorter title")
	contained(shell.coinBadge,header,"coin badge stays in header")

	contained(shell.coinIcon,shell.coinBadge,"coin fits inside its balance badge")

	panel._size={X=screen[1],Y=screen[2]};shell:select(at.upgrades)
	ui.view=tabs[at.upgrades].view;ui.root.Parent=ui.view;ui.mobileDetail=true;ui:layout()
	contained(ui.buy,ui.detail,"upgrade purchase remains in detail at "..screen[1])
	contained(ui.stats,ui.detail,"upgrade stats remain in detail at "..screen[1])
	check(size(ui.stats).Y>=55,"upgrade comparison retains scroll space")
	shell:select(at.crates);contents:show("og");contents:layout()
	contained(contents.open,contents.summary,"crate purchase in summary")
	contained(contents.list,contents.root,"collection scroll in viewport")
	check(size(contents.list).Y>=65,"collection retains usable scroll space")
	if size(contents.view).Y<430 and size(contents.view).X>=460 then
	 local oddsBottom=contents.oddsHolder.Position.Y.Offset+size(contents.oddsHolder).Y
	 local buyTop=size(contents.summary).Y+contents.open.Position.Y.Offset
	 check(oddsBottom<=buyTop,"compact crate odds stay above the purchase button")
	end
end
-- Garage contract: only owned rides can issue the existing toggle request;
-- style cycling excludes locked stances and shop/bag navigation closes the panel.
modules.ActionButtons={make=function(name,kind,label,key,parent)
 local b=W.button(parent,name,"",colour);b.Label=W.text(b,"Label",label,11);return b
end}
modules.RideModel={}
load("HUDLayout")
environment.Color3={fromRGB=function() return colour end}
-- Touch-origin gating is a live-input concern; a harness tap always starts on its button.
modules.TouchOrigin={guard=function() return function() return true end end,beganElsewhere=function() return false end}
local RidePicker=load("RidePicker")
RidePicker.ensurePreviews=function() end -- Actual 3D framing is checked in Studio.
local screen=instance("ScreenGui");screen._size={X=736,Y=414}
local shop=instance("Frame");shop.Visible=false
local requests,stances,offers={},{},0
local garage=RidePicker.new({gui=screen,shop=shop,requestRide=function(key) table.insert(requests,key) end,
 requestStance=function(key,stance) table.insert(stances,{key,stance}) end,openStyles=function() offers+=1 end})
garage:setOpen(true);check(not garage.open,"empty garage cannot open")
local snapshot={rides={skateboard={name="Skateboard",owned=true,equipped=true,boost=35},scooter={name="Scooter",owned=false}},
 stances={{key="classic",name="Classic"},{key="locked",name="Locked",locked=true},{key="onehand",name="One Hand"}},stance="classic"}
garage:render(snapshot);garage:setOpen(true)
check(garage.open and garage.tiles.scooter==nil,"picker only builds owned rides")
garage:cycleStance();check(stances[1][1]=="skateboard" and stances[1][2]=="onehand","stance request skips locked pose")
check(snapshot.stance=="classic","stance does not optimistically change server state")
garage.tiles.skateboard.button.Activated:fire()
check(requests[1]=="skateboard" and not garage.open,"selected card uses existing toggle and closes")
snapshot.rides.skateboard.owned=false;garage:render(snapshot)
garage.tiles.skateboard.button.Activated:fire();check(#requests==1 and not garage.slot.Visible,"stale tile cannot equip removed ownership")
snapshot.rides.skateboard.owned=true;snapshot.stances[3].locked=true;garage:render(snapshot);garage:setOpen(true)
garage:cycleStance();check(offers==1 and not garage.open,"only default pose routes to style offer")
garage:setOpen(true);shop.Visible=true;shop:GetPropertyChangedSignal("Visible"):fire();check(not garage.open,"shop closes garage")
garage:setOpen(true);screen:SetAttribute("BagOpen",true);screen:GetAttributeChangedSignal("BagOpen"):fire();check(not garage.open,"bag closes garage")
for _,viewport in {{1366,768},{736,414},{667,375},{640,360},{390,844}} do
 screen._size={X=viewport[1],Y=viewport[2]};garage:layout()
 local w,h=garage.root.Size.X.Offset,garage.root.Size.Y.Offset
 local bottom=viewport[2]+garage.root.Position.Y.Offset
 check(w<=viewport[1]-28 and bottom-h>=0,"garage stays inside viewport")
 if viewport[2]<400 then check(viewport[1]-14-w>=176,"short phone header clears Roblox controls") end
 check(size(garage.list).Y>=70,"garage keeps a usable horizontal card strip")
end
-- ============================================================
-- THE REBIRTH GATE ON A CATALOGUE CARD (designer, 2026-09-23)
-- ============================================================
--
-- Houses, rides and guardians all carry `unlockRebirths` now, and all three
-- shelves read ONE treatment: `ShopWidgets.gate` for the wash and the verdict,
-- `ShopWidgets.gateRank` for the order. Checked here rather than three times
-- in three suites, because the whole point of the shared function is that a
-- second copy cannot disagree about which rebirth opens what.
--
-- An assertion that needs the Config edit (the `unlockRebirths` rows on
-- HOUSE_TIERS and RIDES, and the audit exemption) PRINTS rather than fails
-- while the edit is still landing -- the same shape the `guardians` suite
-- uses for the coats' own ladder.
local pending = 0
local function expect(ok, message)
	if ok then check(true, message) else pending += 1; print("PENDING: " .. message) end
end

-- 1. THE ORDER. An ungated row keeps its catalogue position exactly, which is
-- what makes this safe to put on every shelf rather than only the gated ones.
check(W.gateRank({order = 3}) == 3, "an ungated row ranks at its own order")
check(W.gateRank({}) == 99, "a row with no order falls to the back")
check(W.gateRank({order = 1, unlockRebirths = 2}) == 2001, "a gated row ranks behind every open one")
do
	local shelf = {
		{name = "dear open", order = 9},
		{name = "r2 first", order = 1, unlockRebirths = 2},
		{name = "cheap open", order = 2},
		{name = "r1", order = 7, unlockRebirths = 1},
		{name = "r2 second", order = 4, unlockRebirths = 2},
	}
	table.sort(shelf, function(a, b) return W.gateRank(a) < W.gateRank(b) end)
	local order = {}
	for _, row in ipairs(shelf) do table.insert(order, row.name) end
	check(table.concat(order, "|") == "cheap open|dear open|r1|r2 first|r2 second",
		"the shelf runs ungated in catalogue order, then by ascending gate: " .. table.concat(order, "|"))
end

-- 2. THE WASH. A gated card SHOWS, says what opens it, and keeps its price.
local function gateCard()
	local button = instance("TextButton")
	button._size = {X = 156, Y = 182}
	local sub = instance("TextLabel"); sub.Parent = button; sub.Text = "80.0M"
	local title = instance("TextLabel"); title.Parent = button
	return {button = button, sub = sub, title = title}
end
local card = gateCard()
check(W.gate(card, {order = 13, unlockRebirths = 6, locked = true}) == true, "a gated card reports locked")
check(card.button:GetAttribute("Locked") == true, "the button is marked Locked")
check(card.button.LayoutOrder == 6013, "a locked card is ordered by its gate as well")
local sheet = card.button:FindFirstChild("RebirthGate")
check(sheet ~= nil and sheet.Visible, "the card wears a gate sheet")
check(sheet.ClassName == "Frame", "the sheet is a Frame, so the press falls through to the card")
check(sheet.BackgroundTransparency > 0 and sheet.BackgroundTransparency < 1, "the sheet is translucent, not opaque")
local word = sheet:FindFirstChild("Requirement")
check(word ~= nil and word.Text == "Rebirth 6 required", "the sheet names the rebirth exactly: " .. tostring(word and word.Text))
check(card.sub.Text == "80.0M", "the price the loop painted is untouched")
check(card.sub.ZIndex > sheet.ZIndex, "the price pill is raised above the wash so it stays readable")
-- THE LABEL IS MEASURED IN STUDIO AND ITS CONTRACT IS CHECKED HERE. This
-- harness does not shape text -- its own note says never to assert a pixel
-- width against `TextBounds` -- so what is asserted is the geometry that makes
-- the measurement hold: no `TextScaled` (whose failure is silent shrinkage),
-- no truncation (silent clipping), wrapping on, and a box tall enough for the
-- two lines "Rebirth 20 required" wraps to below 114px.
check(not word.TextScaled, "the requirement never scales itself smaller")
check(word.TextWrapped == true, "the requirement wraps rather than overflowing")
-- Through `environment`, because the suite's own scope has no `Enum`: the
-- stub is injected into the MODULES' environment, not into this file's.
check(word.TextTruncate == environment.Enum.TextTruncate.None, "the requirement is never clipped at the end")
check(word.Size.X.Scale == 1 and word.Size.X.Offset == -18, "the label is the card less an 18px inset")
check(word.Size.Y.Offset >= word.TextSize * 2, "the box holds the two lines the widest gate wraps to")
check(word.TextSize == 14, "the requirement is set at the measured size")
-- The longest string this can ever print, since `rebirthsToMax()` is the top
-- of the ladder. 116px at 14px FredokaOne against a 138px box, measured live.
check(#W.GATE_TEXT:format(Config.rebirthsToMax()) == 19, "the widest label is 'Rebirth 20 required'")

-- 3. UNLOCKING, AND OWNING. Both clear the wash, and the sheet is REUSED
-- rather than stacked -- a card is painted on every coin tick.
W.gate(card, {order = 13, unlockRebirths = 6, locked = false})
check(card.button:GetAttribute("Locked") == false and not sheet.Visible, "reaching the gate clears the wash")
W.gate(card, {order = 13, unlockRebirths = 6, locked = true})
local sheets = 0
for _, child in ipairs(card.button:GetChildren()) do if child.Name == "RebirthGate" then sheets += 1 end end
check(sheets == 1 and sheet.Visible, "a repaint reuses the one sheet")
local ownedCard = gateCard()
check(W.gate(ownedCard, {order = 2, unlockRebirths = 9, locked = true, owned = true}) == false,
	"an owned item is never locked, whatever the rebirth count")
check(ownedCard.button:FindFirstChild("RebirthGate") == nil, "an owned card is never given a sheet at all")
check(ownedCard.button.LayoutOrder == 9002, "an owned gated item still sorts with its rung")
local plain = gateCard()
check(W.gate(plain, {order = 4}) == false and plain.button.LayoutOrder == 4,
	"an ungated card is untouched and keeps its own order")
W.gate(card, {order = 13, unlockRebirths = 20, locked = true})
check(word.Text == "Rebirth 20 required", "the top of the ladder prints in full")

-- 4. WHAT THE NEXT REBIRTH PUTS ON SALE, on the rebirth page.
--
-- THE WHOLE MODULE IS LOADED AND THE PAGE IS BUILT, which it was not before:
-- `unlocksAt` used to be pulled out of the source with a pattern, because "the
-- rest of that module is page geometry this harness cannot draw". It draws it
-- now, and that is the point -- the page went from five shapes and two
-- expanders to three bands of rows (designer, 2026-09-23) and had NO offline
-- coverage at all, so the one screen a nine-year-old has to understand before
-- an irreversible action was the one screen nothing asserted.
--
-- ITS OWN ENVIRONMENT rather than the shared one: it needs three services the
-- rest of this suite does not -- a tween, an input signal and a heartbeat --
-- and `Theme`'s drawing helpers as real functions rather than as colours.
local Rebirth, rebirthGui do
	local rc = {R = .5, G = .5, B = .5, Lerp = function(self) return self end}
	local rTheme = setmetatable({
		MENU_Z = 45, OUTLINE_THIN = 2,
		corner = function() return instance("UICorner") end,
		outline = function() return instance("UIStroke") end,
		gloss = function() return instance("UIGradient") end,
		shade = function() return instance("UIGradient") end,
		card = function(f) return f end,
		floatClose = Theme.floatClose,
		readable = function(tone) return tone end,
	}, {__index = function(_, key)
		-- The four drawn illustrations are frames with children; everything
		-- else asked of Theme in here is a colour.
		if key == "coin" or key == "snout" or key == "satchel" or key == "gear" then
			return function(parent) local f = instance("Frame"); f.Parent = parent; return f end
		end
		return rc
	end})
	local heartbeat, inputBegan = signal(), signal()
	local rEnv = setmetatable({
		game = {GetService = function(_, name)
			if name == "TweenService" then return {Create = function() return {Play = function() end} end} end
			if name == "UserInputService" then return {InputBegan = inputBegan} end
			if name == "RunService" then return {Heartbeat = heartbeat} end
			return {Shared = names}
		end},
		script = {Parent = names},
		require = function(name) return if name == "Theme" then rTheme else assert(modules[name], name) end,
		Instance = {new = instance},
		UDim2 = {new = dim, fromOffset = function(x, y) return dim(0, x, 0, y) end,
			fromScale = function(x, y) return dim(x, 0, y, 0) end},
		UDim = {new = function(sc, off) return {Scale = sc, Offset = off} end},
		Vector2 = {zero = {X = 0, Y = 0}, new = function(x, y) return {X = x, Y = y} end},
		Enum = setmetatable({}, {__index = function() return names end}),
		Color3 = {new = function() return rc end, fromRGB = function() return rc end},
		TweenInfo = {new = function() return {} end},
		task = {defer = function() end, delay = function() end, spawn = function(fn, ...) fn(...) end},
	}, {__index = getfenv()})
	local run = assert(loadstring(sources.Rebirth, "Rebirth")); setfenv(run, rEnv)
	Rebirth = run()
	rebirthGui = instance("ScreenGui"); rebirthGui._size = {X = 1000, Y = 700}
	Rebirth.init(rebirthGui, function() end)
	check(Rebirth.isOpen() == false, "the rebirth page builds closed")
end

do
	local unlocksAt = Rebirth.unlocksAt
	local cosmetics = {
		houses = {
			{name = "Cardboard Fort", unlockRebirths = 0},
			{name = "Fishbowl House", unlockRebirths = 2},
			{name = "Neon Tower", unlockRebirths = 3},
			{name = "Sky Castle", unlockRebirths = 6, owned = true},
		},
		dogCoats = { husky = {name = "Husky", unlockRebirths = 2} },
	}
	local rides = { rides = { scooter = {name = "E-Scooter", unlockRebirths = 2},
		bmx = {name = "BMX Bike", unlockRebirths = 1} } }
	check(table.concat(unlocksAt(2, cosmetics, rides), ", ") == "E-Scooter, Fishbowl House, Husky",
		"the line names every shelf's rung and sorts for stability")
	check(table.concat(unlocksAt(1, cosmetics, rides), ", ") == "BMX Bike", "a rung with one thing names it")
	check(#unlocksAt(6, cosmetics, rides) == 0, "an item already owned is not offered again")
	check(#unlocksAt(9, cosmetics, rides) == 0, "a rebirth that opens nothing yields an empty line")
	check(#unlocksAt(0, cosmetics, rides) == 0, "an ungated row is never named as an unlock")
	check(#unlocksAt(2, nil, nil) == 0, "no push yet is an empty line rather than a throw")
end

-- 4b. THE PAGE ITSELF: ONE LIST, GAIN then KEEP then STARTS OVER.
--
-- Read back row by row off the built page, because every fact on it is now a
-- ROW rather than a surface of its own, and the order the three bands are in
-- IS the feature: what the button buys, then what is safe, then what goes.
do
	-- SCOPED TO THE PAGE, never to every object this suite has ever made.
	-- `ShopWidgets.gate` builds its own label called "Requirement", so a sweep
	-- over `objects` found the widget's and reported the reading order wrong.
	local page = assert(rebirthGui:FindFirstChild("RebirthPage"), "the page is under the gui")
	local function band(name)
		for _, o in ipairs(page:GetDescendants()) do
			if o.Name == name and not o.destroyed then return o end
		end
	end
	local function rowsOf(name)
		local card = assert(band(name), name)
		local out = {}
		for _, child in ipairs(card:GetChildren()) do
			if child.Name:sub(1, 3) == "Row" then table.insert(out, child) end
		end
		table.sort(out, function(x, y) return x.LayoutOrder < y.LayoutOrder end)
		return out, card
	end
	local function cell(row, key)
		local label = row:FindFirstChild(key)
		return if label then label.Text else nil
	end

	Rebirth.onUpgrades({
		locks = {name = "Vault Lock", tree = "defense", order = 1, level = 3, max = 4},
		fences = {name = "Fence", tree = "defense", order = 2, level = 1, max = 5},
		sack = {name = "Bigger Sack", tree = "offense", order = 2, level = 2, max = 4},
		boots = {name = "Getaway Speed", tree = "offense", order = 3, level = 0, max = 4},
	})
	Rebirth.onCosmetics({skins = {}, dogCoats = {husky = {name = "Husky", unlockRebirths = 4}},
		houses = {{name = "Cardboard Fort", unlockRebirths = 0},
			{name = "Fishbowl House", unlockRebirths = 4}}})
	Rebirth.onRides({rides = {scooter = {name = "E-Scooter", unlockRebirths = 4}}})
	Rebirth.onEconomy({coins = 1234567, rebirths = 3, rebirthReady = true})
	Rebirth.open()
	check(Rebirth.isOpen(), "the page opens")

	-- THE ORDER IS THE DESIGN. `LayoutOrder` on the three bands and the
	-- requirement is what a `UIListLayout` reads, so this is the reading order.
	check(band("Gain").LayoutOrder == 1 and band("YouKeep").LayoutOrder == 2
		and band("Resets").LayoutOrder == 3 and band("Requirement").LayoutOrder == 4,
		"gain, then keep, then what starts over, then the coins needed")
	for _, name in ipairs({"Gain", "YouKeep", "Resets"}) do
		local card = band(name)
		check(card.Size.X.Scale == 1 and card.Size.X.Offset == 0,
			name .. " is full width: there is no second column to find")
	end
	-- NOTHING EXPANDS AND NOTHING REPEATS ITSELF. The grid, the strip, the two
	-- collapsibles and the footer reminder are all gone by name.
	for _, gone in ipairs({"Benefits", "Unlocks", "CrateDetails", "ViewRewards",
		"ViewUpgrades", "Reminder", "CoinBonus", "UpgradeLimit", "FreeCrate"}) do
		check(band(gone) == nil, "the page has no " .. gone .. " any more")
	end

	local gain = rowsOf("Gain")
	check(#gain == 3, "gain names the multiplier, the free crate and what goes on sale")
	check(cell(gain[1], "Name") == "Permanent coin multiplier", "the multiplier carries its name")
	-- A MULTIPLE, NOT A PERCENTAGE, and printed at the size of a headline: the
	-- note is the number here rather than a caption, which is what `loud` buys.
	-- Against `Config.rebirthMultipleText`, which is the one formatter the page
	-- and the server's own rebirth toast both read.
	check(cell(gain[1], "Note") == Config.rebirthMultipleText(3) .. " " .. utf8.char(0x2192)
		.. " " .. Config.rebirthMultipleText(4), "it reads as 1.36x going to 1.48x")
	check(Config.rebirthMultipleText(3) == "1.36x" and Config.rebirthMultipleText(4) == "1.48x",
		"and those really are the multiples the server pays")
	-- TRIMMED, AND TWO DECIMALS. A fresh save reads "1x", and the 0.08 taper
	-- rungs stay distinct -- at one decimal 2.36 and 2.44 both print "2.4".
	check(Config.rebirthMultipleText(0) == "1x" and Config.rebirthMultipleText(20) == "3x",
		"a whole multiple loses its trailing zeros")
	check(Config.rebirthMultipleText(12) ~= Config.rebirthMultipleText(13),
		"consecutive tapered rungs never print the same multiple")
	check(gain[1]:FindFirstChild("Note").TextSize > gain[1]:FindFirstChild("Name").TextSize,
		"and the number is bigger than the label above it")
	check(cell(gain[1], "Value") == nil,
		"it is not a value pill: 124px cannot hold that string beside a name on a phone")
	check(cell(gain[2], "Name") == "A free crate" and cell(gain[2], "Note") ~= nil,
		"the free crate names which crate")
	check(cell(gain[3], "Note") == "E-Scooter, Fishbowl House, Husky",
		"and the shop rung names every shelf it opens, sorted")

	local keep = rowsOf("YouKeep")
	check(#keep == 4, "keep is four rules rather than an inventory")
	check(cell(keep[4], "Note") == "You will have 4", "the rebirth count it leaves you on is real")

	local resets = rowsOf("Resets")
	check(#resets == 2, "coins and the bought upgrades, and nothing else resets")
	check(cell(resets[1], "Value") == Config.formatCoins(1234567) .. " " .. utf8.char(0x2192) .. " 0",
		"the coin row prints the balance the server pushed")
	-- SOMEBODY'S ACTUAL AFTERNOON, ON THE ROW. Three bought trees, defence
	-- first, each in the shop's own order -- no expander to open for them.
	check(cell(resets[2], "Note") == "Vault Lock, Fence, Bigger Sack"
		and cell(resets[2], "Value") == "3 " .. utf8.char(0x2192) .. " 0",
		"the upgrade row names the trees in shop order and counts them")

	-- A COIN TICK REPAINTS AND NEVER REBUILDS: the rows are the same instances.
	local firstRow = band("Gain"):FindFirstChild("Row1")
	Rebirth.onEconomy({coins = 2000000, rebirths = 3, rebirthReady = true})
	check(band("Gain"):FindFirstChild("Row1") == firstRow, "an economy push does not rebuild the list")
	check(cell(rowsOf("Resets")[1], "Value") == Config.formatCoins(2000000) .. " " .. utf8.char(0x2192) .. " 0",
		"but the coin row follows the balance")

	-- A FRESH SAVE: nothing bought is not a loss, no rung open is not a gain,
	-- and the multiplier trims to a clean "1x" rather than reading "1.00x".
	Rebirth.onUpgrades({locks = {name = "Vault Lock", tree = "defense", order = 1, level = 0, max = 4}})
	Rebirth.onCosmetics({skins = {}, houses = {}, dogCoats = {}})
	Rebirth.onRides({rides = {}})
	Rebirth.onEconomy({coins = 10, rebirths = 0, rebirthReady = false})
	Rebirth.open()
	check(cell(rowsOf("Gain")[1], "Note") == "1x " .. utf8.char(0x2192) .. " 1.12x",
		"a first rebirth reads 1x going to 1.12x")
	check(#rowsOf("Resets") == 1, "an upgrade never bought is not listed as a loss")
	check(#rowsOf("Gain") == 2, "a rung that opens no shop item names none")

	-- ONE COLUMN ON A PHONE HELD SIDEWAYS TOO, which is where the old page's
	-- two columns at least agreed with the reading order.
	rebirthGui._size = {X = 320, Y = 546}
	rebirthGui:GetPropertyChangedSignal("AbsoluteSize"):fire()
	for _, name in ipairs({"Gain", "YouKeep", "Resets"}) do
		check(band(name).Size.X.Scale == 1, name .. " stays full width on a phone")
	end
	check(band("Body").AbsoluteSize.X > 0 and band("Body").AbsoluteSize.Y > 0,
		"and the list still has a box to scroll in")
	rebirthGui._size = {X = 1000, Y = 700}
	rebirthGui:GetPropertyChangedSignal("AbsoluteSize"):fire()
	Rebirth.close()
end

-- 5. THE GATED CATALOGUES, once Config carries them. A gate must never be
-- the LAST thing refusing a house: `REBIRTH_CASH_GATE[r]` is the pig at
-- rebirth r, so a gate above the first rebirth whose pig holds the price
-- would hide a house the player could already pay for. Rides are
-- deliberately the other way round -- see the Config header.
do
	local gatedHouses, gatedRides = 0, 0
	for _, tier in ipairs(Config.HOUSE_TIERS) do
		if tier.unlockRebirths ~= nil then gatedHouses += 1 end
	end
	for _, spec in pairs(Config.RIDES) do
		if spec.unlockRebirths ~= nil then gatedRides += 1 end
	end
	if gatedHouses == 0 and gatedRides == 0 then
		pending += 1
		print("PENDING: no HOUSE_TIERS or RIDES row carries unlockRebirths yet; the ladder checks wait on the Config edit")
	else
		local top = Config.rebirthsToMax()
		local function pigAt(rebirth)
			return Config.REBIRTH_CASH_GATE[rebirth] or Config.REBIRTH_CASH_GATE[top]
		end
		local function firstAffordable(price)
			for r = 0, top do if pigAt(r) >= price then return r end end
			return math.huge
		end
		for _, tier in ipairs(Config.HOUSE_TIERS) do
			local gate = tier.unlockRebirths
			if gate ~= nil then
				expect(gate == math.floor(gate) and gate >= 1 and gate <= top,
					tier.id .. " gate is a whole rebirth on the ladder")
				expect(tier.earned == nil, tier.id .. " is bought rather than earned, so a sale gate applies")
				expect(gate <= firstAffordable(tier.cost or 0),
					tier.id .. " never locks a house the pig could already pay for")
				for _, other in ipairs(Config.HOUSE_TIERS) do
					if (other.cost or 0) > (tier.cost or 0) and other.earned == nil then
						expect((other.unlockRebirths or 0) >= gate,
							other.id .. " (dearer) unlocks no earlier than " .. tier.id)
					end
				end
			end
		end
		for key, spec in pairs(Config.RIDES) do
			local gate = spec.unlockRebirths
			if gate ~= nil then
				expect(gate == math.floor(gate) and gate >= 1 and gate <= top,
					key .. " gate is a whole rebirth on the ladder")
				expect(spec.cost ~= nil, key .. " is bought with coins, so a sale gate applies")
				for other, row in pairs(Config.RIDES) do
					if (row.cost or 0) > (spec.cost or 0) then
						expect((row.unlockRebirths or 0) >= gate,
							other .. " (dearer) unlocks no earlier than " .. key)
					end
				end
			end
		end
		-- THE ENTRY RIDE MAY NEVER BE GATED. `grantEntryRide` hands the
		-- cheapest ride to a Style Pack owner who owns none, so a gate there
		-- is a Robux purchase that visibly does nothing.
		local cheapest, cheapestCost = nil, math.huge
		for key, spec in pairs(Config.RIDES) do
			if (spec.cost or math.huge) < cheapestCost then cheapest, cheapestCost = key, spec.cost end
		end
		expect(Config.RIDES[cheapest].unlockRebirths == nil,
			"the entry ride (" .. tostring(cheapest) .. ") carries no gate, so the pass grant can never be refused")
		-- AND NOTHING A CRATE CAN ROLL MAY CARRY ONE. `catalogueFor` resolves
		-- `ride:` entries, so the Alien Cache genuinely reaches Config.RIDES.
		for chestKey in pairs(Config.CHESTS) do
			for _, keys in pairs(Config.chestPool(chestKey)) do
				for _, entry in ipairs(keys) do
					local kind, key = Config.chestEntry(chestKey, entry)
					local catalogue = Config.catalogueFor(kind)
					local spec = catalogue and catalogue[key]
					expect(spec == nil or spec.unlockRebirths == nil,
						chestKey .. " pool entry " .. entry .. " carries no rebirth gate")
				end
			end
		end
	end
end

-- THE ROBUX PAGE'S CRATES ARE THE SHELF'S OWN TILES, PAINTED BY ONE PAINTER
-- (designer, 2026-09-23: the common, rare and legendary crates sit on the
-- Robux page so a purchase is one tap). A paid random item must show its real
-- odds before the buy button and go through the policy refusal, so what is
-- asserted is that the two surfaces cannot disagree: the REAL `Crates` module
-- builds both, one state push paints both, and every field a buyer reads is
-- compared tile for tile.
do
	local services = {
		RunService = { Heartbeat = signal(), RenderStepped = signal() },
		Players = { LocalPlayer = {} },
		MarketplaceService = {},
	}
	local prompted = {}
	services.MarketplaceService.PromptProductPurchase = function(_, _, id) table.insert(prompted, id) end
	local crateEnv = setmetatable({
		game = { GetService = function(_, name) return services[name] or { Shared = names } end },
		workspace = { GetServerTimeNow = function() return 0 end },
	}, { __index = environment })
	modules.ShopStyle = modules.ShopStyle or setmetatable({
		round = function() end, outline = function() end, gloss = function() end,
		deepen = function() return colour end,
		chip = function(parent) local l = instance("TextLabel"); l.Parent = parent; return l end,
	}, { __index = function() return colour end })
	modules.SpinWheel = modules.SpinWheel or { play = function() end }
	modules.PremiumShop = modules.PremiumShop or { ROBUX_ICON = "robux" }
	local fn = assert(loadstring(sources.Crates, "Crates")); setfenv(fn, crateEnv)
	local Crates = fn(); modules.Crates = Crates

	-- The strip is mounted BEFORE the shelf exists, as ClientMain does it.
	local page = sized(1000, 600)
	local peeked = {}
	local strip = Crates.mount(page, function(key) table.insert(peeked, key) end)
	local shelfKeys = {}
	for _, def in ipairs(Config.CRATE_SECTIONS) do for _, key in ipairs(def.chests) do table.insert(shelfKeys, key) end end
	local stripTiles = {}
	for _, child in ipairs(strip:GetChildren()) do
		if child.Name and string.sub(child.Name, 1, 6) == "Crate_" then stripTiles[string.sub(child.Name, 7)] = child end
	end
	for i, key in ipairs(shelfKeys) do
		check(stripTiles[key] ~= nil and stripTiles[key].LayoutOrder == i, "the Robux page shows " .. key .. " in the shelf's order")
	end
	check(#shelfKeys == 4 and stripTiles.og and stripTiles.ograre and stripTiles.oglegendary and stripTiles.guardian,
		"the Robux page carries the Common, Rare and Legendary piggy crates and the Guardian Crate")

	local shelfView = sized(1000, 600)
	Crates.init(shelfView, { gui = instance("ScreenGui"), iconFor = function() end, format = tostring })
	local function shelfTile(key)
		for _, d in ipairs(shelfView:GetDescendants()) do if d.Name == "Crate_" .. key then return d end end
	end
	local odds = { common = 52, rare = 32, epic = 12, legendary = 4 }
	local state = { restricted = false, chests = {
		og = { odds = odds, robux = 20, productId = 1001, owned = 3, total = 67 },
		ograre = { odds = { rare = 60, epic = 30, legendary = 10 }, robux = 60, productId = 0, owned = 3, total = 67 },
		oglegendary = { odds = {}, robux = 240, productId = 1003, complete = true, owned = 67, total = 67 },
		guardian = { odds = { rare = 60, epic = 30, legendary = 10 }, robux = 49, productId = 1004, owned = 0, total = 5 },
	} }
	local function read(tile)
		local out = { tier = tile:FindFirstChild("Tier").Text, price = tile:FindFirstChild("Open"):FindFirstChild("Label").Text,
			chip = tile:FindFirstChild("Price").Text, segments = {} }
		for _, tier in ipairs(Config.RARITY_ORDER) do
			local seg = tile:FindFirstChild("Odds"):FindFirstChild("Odds_" .. tier)
			out.segments[tier] = (if seg.Visible then "shown " .. seg.Text else "hidden")
		end
		return out
	end
	local function same(key)
		local a, b = read(shelfTile(key)), read(stripTiles[key])
		check(a.tier == b.tier and a.price == b.price and a.chip == b.chip, key .. " reads the same on the Robux page as on the shelf: " .. b.tier .. " / " .. b.price)
		for tier, v in pairs(a.segments) do check(b.segments[tier] == v, key .. " odds segment " .. tier .. " matches the shelf") end
	end
	Crates.render(state)
	for _, key in ipairs(shelfKeys) do same(key) end
	local og = read(stripTiles.og)
	check(og.segments.common == "shown 52%" and og.segments.legendary == "shown ", "the Piggy Crate's odds are drawn on the Robux page before its buy button")
	check(string.find(og.tier, "4% LEGENDARY", 1, true) ~= nil, "the best tier's exact percentage is printed by the name")
	check(og.price == "20", "the Piggy Crate is priced on its button")
	check(read(stripTiles.ograre).price == "COMING SOON", "a crate with no developer product declines to prompt")
	check(read(stripTiles.oglegendary).price == "COLLECTION COMPLETE", "a finished pool is refused before the prompt")

	stripTiles.og:FindFirstChild("Open").Activated:fire()
	stripTiles.ograre:FindFirstChild("Open").Activated:fire()
	stripTiles.oglegendary:FindFirstChild("Open").Activated:fire()
	check(#prompted == 1 and prompted[1] == 1001, "one tap on the Robux page prompts exactly the crate's own product, and only a buyable one")

	stripTiles.guardian:FindFirstChild("Peek").Activated:fire()
	stripTiles.og:FindFirstChild("Icon").Activated:fire()
	check(#peeked == 2 and peeked[1] == "guardian" and peeked[2] == "og", "? and the crate picture open that crate's contents")

	state.restricted = true
	Crates.render(state)
	same("og")
	check(read(stripTiles.og).price == "NOT AVAILABLE HERE" and read(stripTiles.og).tier == "CRATE BUYING IS OFF FOR THIS ACCOUNT",
		"a restricted account is refused in words on the Robux page too")
	stripTiles.og:FindFirstChild("Open").Activated:fire()
	check(#prompted == 1, "and the refusal never reaches the purchase prompt")

	local leaked = false
	for _, d in ipairs(strip:GetDescendants()) do if d.Name == "BuyBacks" or (d.Name and string.sub(d.Name, 1, 8) == "Buyback_") then leaked = true end end
	check(not leaked, "no coin buy-back is ever drawn on the Robux page")
	check(sources.PremiumShop:find("deps.mountCrates(card", 1, true) ~= nil
		and sources.PremiumShop:find("deps.peekCrate(chestKey)", 1, true) ~= nil
		and sources.ClientMain:find("mountCrates = Crates.mount,", 1, true) ~= nil,
		"the Robux page mounts the shelf's tiles rather than drawing its own")
end

print(("PASS: %d shop UI checks; routes, purchase gates, the rebirth wash and its order, preview reuse, actual stats, collection filters, server odds and responsive bounds. %d pending on the Config edit. Rendering needs Studio."):format(checks, pending))
