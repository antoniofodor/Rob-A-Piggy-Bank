-- Actual Config, reconciliation, ChestService, SetService and Crates UI logic.
-- Inert engine/persistence doubles; no Studio account, DataStore or RNG.
local Config, sources = ...
local checks=0
local function check(ok,message) assert(ok,message);checks+=1 end
local function copy(v)
 if type(v)~="table" then return v end
 local out={};for k,x in v do out[k]=copy(x) end;return out
end
local function load(name,env,source)
 local run=assert(loadstring(source or sources[name],name))
 setfenv(run,setmetatable(env,{__index=getfenv()}));return run()
end
local function noop() end
local names=setmetatable({},{__index=function(_,key) return key end})
local replicated={Shared=names}
local now=Config.seasonEndsAt()-60
local actualSeason=Config.seasonIndex
Config.seasonIndex=function(when) return actualSeason(when or now) end
local season=Config.seasonIndex()
local boundary=Config.seasonEndsAt()
check(Config.seasonIndex(boundary-1)==season and Config.seasonIndex(boundary)==season+1,"exact five-week boundary")
check(Config.seasonEndsAt(boundary)==boundary+5*7*86400,"four active weeks plus rest")
local keys={}
for key,skin in Config.SKINS do
 local cost=Config.buybackCost(key)
 if cost then keys[skin.rarity]=key end
end
-- IN COINS, DERIVED FROM WHAT LETTING THE SKIN GO PAYS. It used to be the
-- source crate's acorn price times a step per rung; a crate has no price now.
for _,tier in {"common","rare","legendary"} do
 local key=keys[tier]
 check(key~=nil and Config.buybackCost(key)==math.floor(Config.sellValue("skin",key)*Config.BUYBACK.markup),
  tier.." price derived from its own sell value")
 check(Config.buybackCost(key)>Config.sellValue("skin",key),tier.." buy-back always costs more than selling")
end
local common,rare,legendary=keys.common,keys.rare,keys.legendary
for _,key in {"classic","bullion","martian","nonexistent"} do
 check(Config.buybackCost(key)==nil,"ineligible skin "..key)
end
local basis=Config.SKINS[common].sellBasis
Config.SKINS[common].sellBasis=4000
check(Config.buybackCost(common)==math.floor(Config.sellValue("skin",common)*Config.BUYBACK.markup),
 "tracks the skin's own value rather than a copied constant")
Config.SKINS[common].sellBasis=basis
local dataSource,n=sources.DataService:gsub("return DataService%s*$","return {defaults=defaultData,reconcile=reconcile}");assert(n==1)
local Data=load("DataService",{game={JobId="isolated-buyback-tests",GetService=function(_,name)
 return if name=="ReplicatedStorage" then replicated else {}
end},require=function(name) assert(name=="Config");return Config end},dataSource)
check(next(Data.defaults().claims)==nil,"fresh empty claims")
local old=Data.defaults();old.claims=nil
check(type(Data.reconcile(old).claims)=="table","generic reconcile fills claim field")
old=Data.defaults();old.claims=false
check(next(Data.reconcile(old).claims)==nil,"malformed table repaired")
old=Data.defaults();old.claims={[common]=season,[rare]=season-1,[legendary]=season+1,nonexistent=season,classic=season,[1]=season}
local migrated=Data.reconcile(old)
check(migrated.claims[common]==season and next(migrated.claims,common)==nil,"load keeps only current valid claim")
check(Data.reconcile(copy(migrated)).claims[common]==season,"claim survives rejoin")
local data, messages, saved, saves, threads={}, {}, {},0,{}
local player={UserId=1,DisplayName="Victim"}
local robber={UserId=2,DisplayName="Robber"}
local handlers={}
local modules={Config=Config}
modules.Remotes={get=function(name) return {
 FireClient=function(_,p,payload) messages[p]=messages[p] or {};messages[p][name]=payload end,
 OnServerEvent={Connect=function(_,fn) handlers[name]=fn end},
} end}
modules.DataService={get=function(p) return data[p] end,save=function(p)
 saves+=1;saved[p]=copy(data[p]);return true
end}
local fakeMath=table.clone(math);fakeMath.random=function() error("buy-back must never roll RNG") end
local env={game={GetService=function(_,name)
 if name=="Players" then return {GetPlayers=function() return {player,robber} end} end
 return replicated
end},script={Parent=names},require=function(name) return assert(modules[name],name) end,
 math=fakeMath,task={spawn=function(fn)
 local thread=coroutine.create(fn);table.insert(threads,thread);assert(coroutine.resume(thread));return thread
end,wait=function() return coroutine.yield() end}}
-- THE ROBUX ROUTE IS DOUBLED HERE AND EXERCISED IN THE `crates` SUITE, which
-- loads the real ProductService. What this suite needs from it is only that
-- `ChestService.push` can ask whether a player may be offered a paid random
-- item -- and the honest default for a double is PERMITTED, so nothing here
-- accidentally passes because a card was hidden.
local productDouble = {
 restricted=function() return false end,
 crateRobux=function() return 0 end,
 crateProduct=function() return 0 end,
 onCrateReceipt=function() end,
 onPolicy=function() end,
 start=function() end,
}
modules.ProductService=productDouble
modules.SetService=load("SetService",env)
local Chest=load("ChestService",env)
local balancePushes=0
Chest.registerBalancePusher(function() balancePushes+=1 end)
local function reset(key,balance)
 data[player]=Data.defaults();data[player].coins=balance or 1e12
 data[robber]=Data.defaults();data[robber].cosmetics.owned[key or common]=true
 if key then data[player].claims[key]=Config.seasonIndex() end
 messages={};saved={};saves=0;balancePushes=0
end
for _,key in {common,rare,legendary} do
 reset(key);local price=Config.buybackCost(key)
 Chest.push(player);local offer=messages[player].ChestState.buybacks[key]
 check(offer.cost==price and offer.name==Config.SKINS[key].name and offer.chest==Config.SKINS[key].chest,"exact claimed skin offer")
 Chest.buyback(player,key)
 check(data[player].coins==1e12-price,"exact coin charge")
 check(data[player].cosmetics.owned[key] and next(data[player].spares)==nil,"direct exact grant, no spare")
 check(data[robber].cosmetics.owned[key],"robber keeps their copy")
 check(saved[player].coins==1e12-price and saved[player].cosmetics.owned[key] and saves==1,"same save includes charge and skin")
 check(data[player].claims[key]==season and not messages[player].ChestState.buybacks[key],"claim retained but owned skin hidden")
 check(messages[player].ChestResult==nil and balancePushes==1,"no crate reel; balance refresh")
 Chest.buyback(player,key)
 check(data[player].coins==1e12-price and saves==1 and next(data[player].spares)==nil,"repeated request cannot charge or mint spare")
end
local commonPrice=Config.buybackCost(common)
reset(common,commonPrice-1);Chest.buyback(player,common)
check(data[player].coins==commonPrice-1 and not data[player].cosmetics.owned[common] and saves==0,"a one-coin shortfall refuses")
check(messages[player].Notify:find("more coins",1,true)~=nil,"the shortfall names coins")
reset();Chest.push(player)
check(next(messages[player].ChestState.buybacks)==nil,"unclaimed skins absent")
for _,key in {common,"nonexistent","classic"} do Chest.buyback(player,key) end
Chest.buyback(player,{});Chest.buyback({},common)
check(data[player].coins==1e12 and saves==0,"unclaimed invalid and unloaded requests refuse")
reset(common);data[player].claims[rare]=season;Chest.push(player)
check(messages[player].ChestState.buybacks[common] and messages[player].ChestState.buybacks[rare],"multiple claims offered independently")
-- Ownership is committed before pushers/save can yield or reenter.
local reentered=false
modules.SetService.registerPusher("skin",function(p)
 if not reentered then reentered=true;Chest.buyback(p,common) end
 Chest.push(p)
end)
Chest.buyback(player,common)
check(reentered and data[player].coins==1e12-Config.buybackCost(common) and saves==1,"reentrant double request charges once")
check(not messages[player].ChestState.buybacks[common] and messages[player].ChestState.buybacks[rare],"purchase removes only matching card")
modules.SetService.registerPusher("skin",noop)
reset(common)
local grant=modules.SetService.grant;modules.SetService.grant=function() return false end
Chest.buyback(player,common);modules.SetService.grant=grant
check(data[player].coins==1e12 and not data[player].cosmetics.owned[common] and saves==0,"failed grant refunds full cost")
Chest.start()
check(type(handlers.SkinBuyback)=="function","buy-back remote wired")
reset(legendary);handlers.SkinBuyback(player,legendary,0,season+10)
check(data[player].coins==1e12-Config.buybackCost(legendary),"forged price/season arguments ignored")
reset(common);now=boundary
handlers.SkinBuyback(player,common)
check(data[player].coins==1e12 and next(data[player].claims)==nil and saves==0,"expired remote refused at exact boundary")
check(next(messages[player].ChestState.buybacks)==nil,"expired state clears offers")
-- The periodic rollover also clears/saves idle players without a request.
now=boundary-1;reset(common);data[robber].claims[rare]=season
now=boundary;assert(coroutine.resume(threads[1],30))
check(next(data[player].claims)==nil and next(data[robber].claims)==nil and saves==2,"rollover clears and saves each idle player's claims")
check(next(messages[player].ChestState.buybacks)==nil and next(messages[robber].ChestState.buybacks)==nil,"rollover refreshes both players")
local rejoined=Data.defaults();rejoined.claims[common]=season
check(next(Data.reconcile(rejoined).claims)==nil,"offline rollover pruned on rejoin")

-- UI behavior only, using inert Instances; this is not a visual engine test.
local objects={}
local function event()
 local callbacks={}
 return {Connect=function(_,fn) table.insert(callbacks,fn) end,
 fire=function(_,...) for _,fn in callbacks do fn(...) end end}
end
local function instance(class)
 local object={ClassName=class,Activated=event(),AbsoluteSize={X=1000,Y=600},
 GetPropertyChangedSignal=function() return event() end,
 Destroy=function(self) self.destroyed=true end}
 table.insert(objects,object);return object
end
local function find(name)
 for _,o in objects do if o.Name==name and not o.destroyed then return o end end
end
local function child(parent,class)
 for _,o in objects do if o.Parent==parent and o.ClassName==class and not o.destroyed then return o end end
end
local heartbeat=event()
local frames=0
-- Colours are inert here; the crates tab only mixes and passes them along.
local colour=setmetatable({},{__index=function() return function(c) return c end end})
local style={round=noop,outline=noop,gloss=noop,deepen=function(c) return c end,
 chip=function(parent) local c=instance("TextLabel");c.Parent=parent;return c end}
local uiModules={Config=Config,ShopStyle=style,SpinWheel={},ShopIcons={mount=function() end},
 ShopWidgets={button=function(parent,name) local b=instance("TextButton");b.Name=name;b.Parent=parent;return b end},
 Theme={PAPER=colour,INK=colour,MUTED=colour,HUE={crates=colour}}}
uiModules.CrateContents={new=function() return {update=noop,close=noop,loadVisible=noop} end}
-- THE ROBUX MARK COMES FROM `PremiumShop`, so the crates tab and the Robux tab
-- print the same one. Doubled here rather than loaded: that module builds a
-- rider on a ride in a ViewportFrame, which is a 3D stub this suite has no
-- business growing.
uiModules.PremiumShop={ROBUX_ICON="rbxasset://robux"}
uiModules.ShopCatalogueLayout={bindCard=noop} -- Geometry is covered by shopui.
local uiNow=boundary-10
local function val(...) return {...} end
-- WHAT THE BUY BUTTON WOULD PROMPT, recorded rather than prompted. The card
-- may only reach here when the SERVER said it could: a product id of 0 throws
-- on a real prompt and a restricted player may not be offered one at all, so
-- what this asserts is that the client declines to ask.
local prompted={}
local marketplaceDouble={PromptProductPurchase=function(_,_,id) table.insert(prompted,id) end}
local UI=load("Crates",{game={GetService=function(_,name)
 if name=="RunService" then return {Heartbeat=heartbeat,RenderStepped={Wait=function() frames+=1 end}} end
 if name=="MarketplaceService" then return marketplaceDouble end
 if name=="Players" then return {LocalPlayer={UserId=1}} end
 return replicated
end},require=function(name) return assert(uiModules[name],name) end,
 Instance={new=instance},UDim2={new=val,fromOffset=val},UDim={new=val},
 Vector2={new=function(x,y) return {X=x,Y=y} end},task={spawn=function(fn) fn() end},
 Enum=setmetatable({},{__index=function() return names end}),
 workspace={GetServerTimeNow=function() return uiNow end}})
local requested,previews={},{}
UI.init(instance("Frame"),{buyback=function(key) table.insert(requested,key) end,
 format=function(n) return tostring(math.floor(n)) end,
 iconFor=function(kind,key,parent) previews[key]={kind,parent} end})
UI.render({chests={},buybacks={},buybacksExpireAt=boundary})
check(not find("Buyback_"..common),"UI hides unclaimed skin")
local offers={}
for _,key in {common,rare,legendary} do
 local spec=Config.SKINS[key];offers[key]={name=spec.name,chest=spec.chest,tier=spec.rarity,cost=Config.buybackCost(key),order=spec.order}
end
UI.render({chests={},buybacks=offers,buybacksExpireAt=boundary})
for _,key in {common,rare,legendary} do
 local card=find("Buyback_"..key);local button=child(card,"TextButton")
 check(card and previews[key][1]=="skin" and previews[key][2].Parent==card,"exact skin preview for "..key)
 check(button.Text:find(tostring(offers[key].cost),1,true)~=nil,"UI displays server price")
end
local commonCard=find("Buyback_"..common)
local button=child(commonCard,"TextButton")
local scroll=find("CrateGrid")
scroll.CanvasPosition={X=0,Y=0};scroll.AbsolutePosition={Y=50}
scroll.AbsoluteCanvasSize={Y=1200};scroll.AbsoluteWindowSize={Y=300}
setmetatable(commonCard,{__index=function(_,key)
 if key=="AbsolutePosition" then return {Y=654-scroll.CanvasPosition.Y} end
end})
UI.focusBuyback(common)
check(scroll.CanvasPosition.Y==600 and frames==8,"objective navigation settles on exact buy-back card")
UI.focusBuyback("nonexistent")
check(scroll.CanvasPosition.Y==600,"missing focus target leaves scroll unchanged")
UI.setBalance(1e12,200);button.Activated:fire()
check(#requested==1 and requested[1]==common,"button sends only exact skin key")
UI.render({chests={},buybacks={[rare]=offers[rare]},buybacksExpireAt=boundary})
check(not find("Buyback_"..common) and not find("Buyback_"..legendary) and find("Buyback_"..rare),"new ownership snapshot removes stale cards")
button.Activated:fire();check(#requested==1,"stale removed button cannot request")
local rareButton=child(find("Buyback_"..rare),"TextButton")
uiNow=boundary;rareButton.Activated:fire()
UI.focusBuyback(rare)
check(scroll.CanvasPosition.Y==600,"expired focus never reads stale card geometry")
check(#requested==1,"expired click cannot request")
heartbeat:fire(1)
check(not find("Buyback_"..rare),"UI expires idle card at boundary")

-- ============================================================
-- THE CRATE TILE: PRICE, DISCLOSED ODDS, AND FIVE REFUSALS
-- ============================================================
--
-- A crate is bought with Robux now (designer, 2026-09-23), which makes it a
-- PAID RANDOM ITEM under Roblox's rule -- so the card that carries the price
-- carries the odds, and every state in which it may not be pressed SAYS SO on
-- the button rather than greying out in silence.
--
-- THE CLIENT DECLINES TO ASK FOR A KNOWN NO, which is the half that matters
-- most here: a prompt for a product id of 0 THROWS, and a prompt for a
-- restricted player is the one thing that rule forbids outright.
local function named(parent,name)
 for _,o in objects do if o.Parent==parent and o.Name==name and not o.destroyed then return o end end
end
local tile=find("Crate_og")
local openButton=named(tile,"Open")
local buyLabel=named(openButton,"Label")
local buyMark=named(openButton,"Robux")
local priceChip=named(tile,"Price")
local tierRow=named(tile,"Tier")
local oddsTrack=named(tile,"Odds")
check(tile and openButton and buyLabel and buyMark and priceChip and oddsTrack,
 "the crate tile carries a price chip, an odds bar and a Robux button")

local function renderCrate(info,restricted)
 UI.render({chests={og=info},buybacks={},buybacksExpireAt=boundary,restricted=restricted})
end
local shipped={owned=2,total=20,robux=20,productId=0,complete=false,
 odds={common=52,rare=32,epic=12,legendary=4},canCombine=true}
local function with(extra)
 local out={}
 for k,v in shipped do out[k]=v end
 for k,v in extra or {} do out[k]=v end
 return out
end

-- COMING SOON while the developer product does not exist, which is the same
-- wording and the same reason as a pass with no id.
renderCrate(with(),false)
check(buyLabel.Text=="COMING SOON" and not openButton.Active,"no product id reads COMING SOON")
check(priceChip.Visible and priceChip.Text:find("20",1,true)~=nil,"and the price is still shown")
openButton.Activated:fire()
check(#prompted==0,"a COMING SOON card never prompts")

-- THE ODDS, DRAWN TO SCALE. Each segment is its own share of the bar, and the
-- ones wide enough print their percentage -- a 4% sliver does not, which is
-- why the best tier's exact figure is printed beside the crate's name.
local seg={}
for _,tier in Config.RARITY_ORDER do seg[tier]=named(oddsTrack,"Odds_"..tier) end
check(seg.common.Visible and seg.common.Size[1]==0.52,"the common segment is 52% of the bar")
check(seg.rare.Position[1]==0.52,"and the next one starts where it ends")
check(seg.common.Text=="52%" and seg.legendary.Text=="","a wide segment prints its number and a sliver does not")
check(tierRow.Text:find("4%% LEGENDARY")~=nil,"so the best tier's exact chance is printed beside the name")

-- WITH A REAL PRODUCT ID the button is the purchase, and pressing it prompts
-- for that id and nothing else.
renderCrate(with({productId=777}),false)
check(buyLabel.Text=="20" and buyMark.Visible and openButton.Active,"a live product shows the Robux mark and the price")
openButton.Activated:fire()
check(#prompted==1 and prompted[1]==777,"and prompts for exactly that product")

-- COLLECTION COMPLETE, which is the state that must never take Robux for
-- nothing.
renderCrate(with({productId=777,complete=true}),false)
check(buyLabel.Text=="COLLECTION COMPLETE" and not openButton.Active,"a finished collection says so")
openButton.Activated:fire()
check(#prompted==1,"and cannot be bought")

-- THE POLICY GATE, in words as well as in a dead button: "refused rather than
-- meeting a button that does nothing" is the requirement, and a greyed button
-- with no sentence beside it IS a button that does nothing.
renderCrate(with({productId=777}),true)
check(buyLabel.Text=="NOT AVAILABLE HERE" and not openButton.Active,"a restricted player is refused")
check(tierRow.Text:find("OFF FOR THIS ACCOUNT",1,true)~=nil,"and told why on the card")
openButton.Activated:fire()
check(#prompted==1,"a restricted card never prompts")

-- ANY OTHER SERVER REFUSAL, IN THE SERVER'S OWN WORDS, so the card and the
-- toast cannot disagree about why.
renderCrate(with({productId=777,refusal="Your lawn is full."}),false)
check(buyLabel.Text=="YOUR LAWN IS FULL." and not openButton.Active,"the server's refusal is printed")
openButton.Activated:fire()
check(#prompted==1,"and holds the purchase back")

-- EARNED RATHER THAN SOLD: the event cache carries no price, so the button
-- names where it comes from instead.
renderCrate(with({robux=0,productId=0}),false)
check(buyLabel.Text=="EARN THIS CRATE" and not priceChip.Visible,"an unpriced crate advertises no price")
openButton.Activated:fire()
check(#prompted==1,"and is never promptable")

-- AND THE COMBINE ROW HAS LEFT THIS TAB, which is a deletion rather than a
-- hidden control: a physical station on the street owns it now.
check(find("Combine")==nil and find("Combine_common")==nil,"no combine row or chip is built")
print(("PASS: %d buy-back checks; prices, persisted claims, direct grants, reentry, remotes, seasonal rollover, and the crate tile's price, disclosed odds and five refusals. No player saves or visual-rendering claim."):format(checks))
