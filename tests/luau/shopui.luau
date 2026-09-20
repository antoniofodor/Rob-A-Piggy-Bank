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
local Theme = setmetatable({HUE=setmetatable({},{__index=function() return colour end}),acornPrice=function(o,text) o.Text=text end,
	-- `coinPrice` is `acornPrice` for coins and `readable` solves a text tone
	-- against its ground; the stub keeps the text and hands the tone back, since
	-- neither contrast nor a drawn glyph is what these checks are about.
	coinPrice=function(o,text) o.Text=text end,readable=function(tone) return tone end},{__index=function() return colour end})
Theme.SHOP_COLOURS=setmetatable({},{__index=function() return colour end})
Theme.coin=function(parent) local f=instance("Frame");f.Parent=parent;return f end
Theme.acorn=Theme.coin
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
	task={defer=function() end,delay=function(_, fn) table.insert(delays,fn) end},
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
W.preview=function() previews+=1 end
local Facts=load("ShopUpgradeFacts")
local Upgrades=load("ShopUpgrades")
load("ShopMarks")
load("ShopAchievements")
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
local economy={coins=1e9,incomeLevel=4,capacityLevel=3,maxIncome=50,maxCapacity=50,incomeCost=200,capacityCost=300,rebirths=2,friendBonus=0,rate=Config.getIncomeRate(4,2,0)*1.2}
ui:setEconomy(economy)
check(ui.title.Text=="Earn Faster","earn selected on first load")
check(ui.tiles.income.check.Visible and not ui.tiles.capacity.check.Visible,"selected upgrade has an explicit checkmark")
check(ui.model:FindFirstChild("ShopIcon"):GetAttribute("IconKey")=="income","income uses approved rendered art")
check(ui.model:FindFirstChild("ShopIcon").Image==Icons.ids.income,"rendered art references uploaded Roblox image")
local supplyHolder=instance("Frame")
check(Icons.supply(supplyHolder,"gum"):GetAttribute("IconKey")=="bubblegum-bomb","gum maps to the bomb artwork")
check(Icons.supply(supplyHolder,"golden"):GetAttribute("IconKey")=="golden-bone","golden bone has its own artwork")
check(Icons.supply(supplyHolder,"steak")==nil,"supplies without artwork keep their model preview")
local count=previews;ui:setEconomy(economy);check(previews==count,"coin updates reuse previews")
ui.buy.Activated:fire();ui.buy.Activated:fire();check(#bought==1 and bought[1]=="income","upgrade double tap debounced")
delays[1]()
economy.coins=0;ui:setEconomy(economy);ui.buy.Activated:fire();check(#bought==1,"unaffordable upgrade does not send")
economy.coins=1e9;ui:setEconomy(economy)
ui.groupButtons[3].Activated:fire();check(ui.tiles.sack.button.Visible,"Rob group exposes Bigger Sack")
ui.tiles.sack.button.Activated:fire();check(ui.selected=="sack","selection changes detail target")
ui.buy.Activated:fire();check(bought[2]=="sack","purchase sends selected key")
for key, spec in pairs(Config.UPGRADES) do
	for level=0,spec.max do
		local rows=Facts.rows(key,level,math.min(level+1,spec.max),economy)
		check(#rows>0,"upgrade has concrete stats: "..key)
		if level==spec.max then for _,row in ipairs(rows) do check(row.now==row.after,"max level never invents another improvement") end end
	end
end
local rows=Facts.rows("income",4,5,economy)
check(rows[1].now==Config.formatCoins(economy.rate),"income comparison includes live bonuses")
check(rows[1].after==Config.formatCoins(Config.getIncomeRate(5,2,0)*1.2),"next income keeps live bonus")
ui.busy=false;ui.groupButtons[1].Activated:fire()
local gatedEconomy=table.clone(economy);gatedEconomy.incomeLevel=42;gatedEconomy.maxIncome=42
ui:setEconomy(gatedEconomy)
check(ui.tiles.income.lock.Visible and ui.tiles.income.level.Text=="LEVEL 42 / 42","rebirth requirement has a lock and actual level")
check(ui.buy.Text=="REBIRTH TO UNLOCK MORE" and not ui.buy.Active,"rebirth gate remains non-purchasable")
local requestsBefore=#bought;ui.buy.Activated:fire();check(#bought==requestsBefore,"locked card never sends a purchase")
ui:setEconomy(economy);check(not ui.tiles.income.lock.Visible,"unlockable card removes its requirement lock")
ui.tiles.capacity.button.Activated:fire()
check(ui.tiles.capacity.check.Visible and not ui.tiles.income.check.Visible,"selection check follows the selected card")
check(ui.model:FindFirstChild("ShopIcon"):GetAttribute("IconKey")=="capacity","detail artwork follows selection")
local iconCount=0;for _,child in ipairs(ui.model:GetChildren()) do if child.Name=="ShopIcon" then iconCount+=1 end end
check(iconCount==1,"changing selection replaces rather than stacks artwork")
for group,keys in pairs({[2]={"locks","fences"},[3]={"lockpicks","sack","boots","tiptoe"}}) do
	ui.groupButtons[group].Activated:fire()
	for _,key in ipairs(keys) do
		ui.tiles[key].button.Activated:fire()
		local image=ui.model:FindFirstChild("ShopIcon")
		check(image and image.Image==Icons.ids[key],"detail uses uploaded art for "..key)
		check(ui.tiles[key].model:FindFirstChild("ShopIcon").Image==Icons.ids[key],"card uses matching art for "..key)
		check(image.ImageRectSize.X>0 and image.ImageRectSize.X<768,"upgrade artwork has measured crop for "..key)
	end
end
local route=0
local panel=sized(1040,660)
local header=instance("Frame");header.Parent=panel;header.Size=dim(1,-20,0,52)
local tabs={};for i=1,8 do tabs[i]={view=instance("Frame")};tabs[i].view.Parent=panel end
local shell
local at={home=3,rides=4,items=5,worn=6,crates=7,companions=8}
shell=Shell.new({panel=panel,header=header,rail=instance("Frame"),coins=instance("TextLabel"),title=instance("TextLabel"),close=instance("TextButton"),tabs=tabs,at=at,startView=tabs[1].view,
	selectTab=function(i) route=i;shell:select(i) end})
for i, expected in ipairs({2,3,8,4,5,7}) do shell.links[i].Activated:fire();check(route==expected,"category route "..i) end
shell:select(6);check(shell.style.Visible and shell.title.Text=="Style & Crates","outfits remain accessible within style")
shell.back.Activated:fire();check(route==1,"back returns to shop")
check(shell.footer==nil and shell.achievements==nil,"shop has no bag or achievement section")
local entries={}
for tier,pool in pairs(Config.chestPool("og")) do for _,key in ipairs(pool) do table.insert(entries,{kind="skin",key=key,name=Config.SKINS[key].name,tier=tier}) end end
local opened={}
local listVisible=true
local contents=Contents.new(tabs[7].view,{stockOf=function() return entries end,iconFor=function() end,open=function(key) table.insert(opened,key) end,showList=function(v) listVisible=v end})
local state={chests={og={cost=15,currency="loot",owned=1,total=#entries,odds={common=51.25,rare=44.75,legendary=4}}}}
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
contents.open.Activated:fire();contents.open.Activated:fire();check(#opened==1 and opened[1]=="og","crate open sends only key and debounces")
contents.pending=false;contents:update(state,0,cosmetics,nil);contents.open.Activated:fire();check(#opened==1,"unaffordable crate does not send")
contents:close();check(listVisible,"back restores crate and buyback list")
local function contained(child,parent,message)
	local p,s=pos(child),size(child);local pp,ps=pos(parent),size(parent)
	check(s.X>0 and s.Y>0 and p.X>=pp.X-1 and p.Y>=pp.Y-1 and p.X+s.X<=pp.X+ps.X+1 and p.Y+s.Y<=pp.Y+ps.Y+1,message)
end
for _,screen in ipairs({{1480,920},{1040,660},{776,335},{627,287},{345,640},{920,470}}) do
	panel._size={X=screen[1],Y=screen[2]};shell:select(1)
	check(not shell.sidebar.Visible,"home devotes full width to illustrated cards")
	local close=shell.deps.close
	check(close.AnchorPoint.X==1 and close.Position.X.Offset>0 and close.Position.Y.Offset<0,"close overlaps the upper-right modal corner")
	check(close.Size.X.Offset>=44 and close.Size.Y.Offset>=44,"close retains a phone-sized tap target")
	check(shell.title.Size.X.Offset+shell.title.Position.X.Offset<=-shell.banner.Size.Y.Offset/2+.01,"heading leaves room for the sign's angled end")
	check(shell.categories[2].title=="Home","home category has the shorter title")
	contained(shell.home,tabs[1].view,"categories use the full landing")
	contained(shell.coinBadge,header,"coin badge stays in header")
	contained(shell.acornBadge,header,"acorn badge stays in header")
	check(shell.grid.CellSize.Y.Offset>=96,"category cards retain readable art and captions")
	contained(shell.coinIcon,shell.coinBadge,"coin fits inside its balance badge")
	contained(shell.acornIcon,shell.acornBadge,"acorn fits inside its balance badge")
	panel._size={X=screen[1],Y=screen[2]};shell:select(2)
	ui.view=tabs[2].view;ui.root.Parent=ui.view;ui.mobileDetail=true;ui:layout()
	contained(ui.buy,ui.detail,"upgrade purchase remains in detail at "..screen[1])
	contained(ui.stats,ui.detail,"upgrade stats remain in detail at "..screen[1])
	check(size(ui.stats).Y>=55,"upgrade comparison retains scroll space")
	shell:select(7);contents:show("og");contents:layout()
	contained(contents.open,contents.summary,"crate purchase in summary")
	contained(contents.list,contents.root,"collection scroll in viewport")
	check(size(contents.list).Y>=65,"collection retains usable scroll space")
	if size(contents.view).Y<430 and size(contents.view).X>=460 then
	 local oddsBottom=contents.oddsHolder.Position.Y.Offset+size(contents.oddsHolder).Y
	 local buyTop=size(contents.summary).Y+contents.open.Position.Y.Offset
	 check(oddsBottom<=buyTop,"compact crate odds stay above the purchase button")
	end
	contained(shell.style,panel,"style navigation in panel")
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
print(("PASS: %d shop UI checks; routes, purchase gates, preview reuse, actual stats, collection filters, server odds and responsive bounds. Rendering needs Studio."):format(checks))
