--!strict
-- Approved six-card landing, cream captions, floating shop sign and clean panel edges.
local Shared=game:GetService("ReplicatedStorage").Shared
local Theme=require(Shared.Theme)
local Config=require(Shared.Config)
local W=require(Shared.ShopWidgets)
local Shell={}
Shell.__index=Shell

function Shell.new(deps: any)
 local self=setmetatable({deps=deps,selected=1,links={},linkArt={},tiles={}},Shell) :: any
 self.categories={
  {key="upgrades",title="Upgrades",hint="Earn • Defend • Rob",at=2},
  {key="home",title="Home",hint="Build your place",at=deps.at.home},
  {key="companions",title="Guardians",hint="Protect your home",at=deps.at.companions},
  {key="rides",title="Rides",hint="Get around",at=deps.at.rides},
  {key="supplies",title="Supplies",hint="Ready for a robbery",at=deps.at.items},
  {key="style",title="Style & Crates",hint="Find your next piggy",at=deps.at.crates},
 }
 -- THE ROBUX TAB IS IN THE SIDEBAR AND NOT ON THE LANDING GRID. The six cards
 -- are the approved landing; the Robux shop gets a full-width banner under
 -- them instead (`featured`), which says "this is a different kind of shop"
 -- rather than posing as a seventh category of the same one. Last in the
 -- list, so every landing tile index still matches its category.
 if deps.at.premium then
  table.insert(self.categories,{key="premium",title="Robux",hint="Passes & perks",at=deps.at.premium,landing=false})
 end
 deps.rail.Visible=false;deps.coins.Visible=false;deps.title.Visible=false
 deps.panel.BackgroundColor3=Theme.PAPER
 self.masthead=W.frame(deps.header,"GreenMasthead",W.colours.home:Lerp(Theme.INK,.18));W.round(self.masthead,16,false)
 self.banner=W.frame(self.masthead,"GoldShopSign");self.banner.BackgroundTransparency=1
 -- Matching corner radii and shared arc centres give the body and tip a
 -- tangent join. Both inner pieces are inset by the same 3px border.
 self.signEdge=W.frame(self.banner,"SignOutline",Theme.INK);W.round(self.signEdge,16,false)
 self.signTipEdge=W.frame(self.banner,"PointOutline",Theme.INK);self.signTipEdge.Rotation=45;W.round(self.signTipEdge,16,false)
 self.signFill=W.frame(self.banner,"SignFace",W.colours.upgrades);W.round(self.signFill,13,false)
 self.signTip=W.frame(self.banner,"PointFace",W.colours.upgrades);self.signTip.Rotation=45;W.round(self.signTip,13,false)
 self.shopIcon=Instance.new("ImageLabel")
 self.shopIcon.Name="ShopBasket";self.shopIcon.BackgroundTransparency=1
 self.shopIcon.Image="rbxassetid://84889322242631" -- assets/shop-ui/shop-basket-v3.png
 self.shopIcon.ScaleType=Enum.ScaleType.Fit;self.shopIcon.Parent=self.banner
 self.title=W.text(self.banner,"ShopHeading","SHOP",42)
 self.title.Position=UDim2.fromOffset(92,9);self.title.Size=UDim2.new(1,-108,1,-18)
 self.back=W.button(deps.header,"ShopHome",utf8.char(0x2039),Theme.GOLD,function() deps.selectTab(1) end)
 self.back.Visible=false
 self.coinBadge=W.frame(self.masthead,"CoinBadge",Theme.PAPER);W.round(self.coinBadge,15)
 self.coinBadge:FindFirstChildOfClass("UIStroke").Thickness=3
 self.coinIcon=W.frame(self.coinBadge,"CoinIcon");self.coinIcon.BackgroundTransparency=1
 self.coinScale=Instance.new("UIScale");self.coinScale.Parent=Theme.coin(self.coinIcon,34,"Coin")
 self.coins=W.text(self.coinBadge,"Coins","0",30);self.coins.Position=UDim2.fromOffset(52,0);self.coins.Size=UDim2.new(1,-60,1,0)
 deps.close.ZIndex=4
 self.sidebar=W.scroll(deps.panel,"Categories")
 local list=Instance.new("UIListLayout");list.Padding=UDim.new(0,10);list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=self.sidebar
 -- AN ICON AND A LABEL: an empty button
 -- with the art and the words as children. A UIPadding would have been fewer
 -- lines and moves the CHILDREN as well as the text, so the icon would have
 -- been pushed out by its own indent.
 for i,c in ipairs(self.categories) do
  local b=W.button(self.sidebar,c.key,"",W.colours[c.key],function() deps.selectTab(c.at) end)
  b.Size=UDim2.new(1,-14,0,48);b.LayoutOrder=i
  local icon=W.frame(b,"Icon");icon.BackgroundTransparency=1
  icon.Position=UDim2.fromOffset(7,5);icon.Size=UDim2.fromOffset(38,38)
  local label=W.text(b,"Label",c.title,15)
  label.Position=UDim2.fromOffset(52,0);label.Size=UDim2.new(1,-60,1,0)
  label.TextWrapped=true;label.TextTruncate=Enum.TextTruncate.None
  local check=W.selection(b);check.Size=UDim2.fromOffset(18,18);check.TextSize=14
  check.Position=UDim2.new(1,-4,0,3);check.Visible=false
  -- `links[i]` stays the BUTTON, which is what a link is and what everything
  -- reading this already expects; the art it carries goes in a table beside it.
  self.links[i]=b;self.linkArt[i]={icon=icon,label=label,check=check}
 end
 self.home=W.scroll(deps.startView,"ShopCategories")
 self.grid=W.grid(self.home,12)
 for i,c in ipairs(self.categories) do
  if c.landing==false then continue end
  local b=W.button(self.home,c.key,"",Theme.PAPER,function() deps.selectTab(c.at) end)
  b.LayoutOrder=i;b.ClipsDescendants=true
  b:FindFirstChildOfClass("UIStroke").Thickness=3
  b:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(0,18)
  local preview=W.frame(b,"Illustration",W.colours[c.key]);preview.Size=UDim2.new(1,0,1,-78)
  W.round(preview,18,false)
  W.hero(preview,W.colours[c.key])
  local artJoin=W.frame(preview,"SquareBottomCorners",W.colours[c.key]);artJoin.Position=UDim2.new(0,0,1,-18);artJoin.Size=UDim2.new(1,0,0,18)
  local caption=W.frame(b,"CreamCaption",Theme.PAPER);caption.Position=UDim2.new(0,0,1,-78);caption.Size=UDim2.new(1,0,0,78)
  W.round(caption,18,false)
  local captionJoin=W.frame(caption,"SquareTopCorners",Theme.PAPER);captionJoin.Size=UDim2.new(1,0,0,18)
  local title=W.text(caption,"Category",c.title,28);title.Position=UDim2.fromOffset(14,4);title.Size=UDim2.new(1,-80,0,38)
  local hint=W.text(caption,"Description",c.hint,18);hint.Font=Enum.Font.GothamMedium;hint.TextColor3=Theme.MUTED
  hint.Position=UDim2.fromOffset(14,43);hint.Size=UDim2.new(1,-80,0,27)
  local arrow=W.frame(caption,"ArrowDisc",W.colours[c.key]);arrow.Position=UDim2.new(1,-64,0,14);arrow.Size=UDim2.fromOffset(50,50);W.round(arrow,25)
  local chevron=W.text(arrow,"Chevron","›",44);chevron.Size=UDim2.fromScale(1,1);chevron.TextXAlignment=Enum.TextXAlignment.Center
  self.tiles[i]={button=b,preview=preview,caption=caption,title=title,hint=hint,arrow=arrow,chevron=chevron}
 end
 -- THE FEATURED OFFER: one wide button under the landing grid, in the Robux
 -- tab's own colour, naming the first pass the player does not own. Robux's
 -- own mark rather than a drawing of it.
 if deps.at.premium then
  local hue=W.colours.premium
  local f=W.button(deps.startView,"FeaturedOffer","",hue,function() deps.selectTab(deps.at.premium) end)
  f:FindFirstChildOfClass("UIStroke").Thickness=3
  f:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(0,18)
  W.gradient(f,hue)
  local mark=Instance.new("ImageLabel");mark.Name="Robux";mark.BackgroundTransparency=1
  mark.Image="rbxasset://textures/ui/common/robux.png";mark.ImageColor3=Theme.INK
  mark.ScaleType=Enum.ScaleType.Fit;mark.Parent=f
  local heading=W.text(f,"Heading","ROBUX SHOP",28)
  local line=W.text(f,"Offer","VIP, Starter Pack and Style Pack",17);line.Font=Enum.Font.GothamBold
  local arrow=W.frame(f,"ArrowDisc",Theme.PAPER);W.round(arrow,25)
  local chevron=W.text(arrow,"Chevron",utf8.char(0x203A),40);chevron.Size=UDim2.fromScale(1,1);chevron.TextXAlignment=Enum.TextXAlignment.Center
  self.featured={button=f,mark=mark,heading=heading,line=line,arrow=arrow,chevron=chevron}
 end
 deps.panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
 self:select(1)
 task.defer(function()
  local Scenes=require(Shared.ShopScenes)
  for i,c in ipairs(self.categories) do
   if c.key=="premium" then
    local mark=Instance.new("ImageLabel");mark.Name="Robux";mark.BackgroundTransparency=1
    mark.Image="rbxasset://textures/ui/common/robux.png";mark.ImageColor3=Theme.INK
    mark.ScaleType=Enum.ScaleType.Fit;mark.Size=UDim2.fromScale(0.8,0.8)
    mark.Position=UDim2.fromScale(0.1,0.1);mark.Parent=self.linkArt[i].icon
    continue
   end
   if not W.icon(self.tiles[i].preview,c.key) then
    local ok,scene=pcall(Scenes.build,c.key)
    if ok then W.preview(self.tiles[i].preview,scene) else warn("[Shop] Category illustration",c.key,scene) end
   end
   -- Pcalled separately so a sidebar icon that fails costs its own icon rather
   -- than the landing tile built a line above it.
   if not W.icon(self.linkArt[i].icon,c.key) then
    local marked,mark=pcall(Scenes.icon,c.key)
    if marked then W.preview(self.linkArt[i].icon,mark) else warn("[Shop] Sidebar icon",c.key,mark) end
   end
  end
 end)
 return self
end

function Shell:select(index: number)
 self.selected=index
 local title,hue="SHOP",W.colours.upgrades
 for i,c in ipairs(self.categories) do
  local selected=c.at==index
  local link=self.links[i]
  link.BackgroundColor3=if selected then W.colours[c.key] else W.colours[c.key]:Lerp(Theme.PAPER,.65)
  self.linkArt[i].check.Visible=selected
  -- THE ACTIVE ONE PROTRUDES AND STANDS TALLER, which is the two-channel rule
  -- the selected tab and the legendary border already keep: colour alone
  -- separates six of these only for a player who can see six.
  link.Size=if selected then UDim2.new(1,-4,0,52) else UDim2.new(1,-14,0,48)
  if selected then title=c.title;hue=W.colours[c.key] end
 end
 -- THE SIGN WEARS THE CATEGORY'S COLOUR, so the sign, the tile you tapped and
 -- the sidebar entry are one colour rather than three. Ink is checked against
 -- it rather than assumed: `supplies` purple carries ink at about 3.5, which is
 -- fine for a 25px bold heading and under the body floor, so `readable` lifts
 -- the type instead of me trusting the hue.
 self.signFill.BackgroundColor3=hue;self.signTip.BackgroundColor3=hue
 self.title.TextColor3=Theme.readable(Theme.INK,hue)
 self.title.Text=title;self:layout()
end

function Shell:layout()
 local d=self.deps
 local width,height=d.panel.AbsoluteSize.X,d.panel.AbsoluteSize.Y
 local narrow=width<560
 local compact=width<950 or height<500
 local landing=self.selected==1
 local mastH=if narrow then 100 elseif height<420 then 54 else math.clamp(height*.105,70,98)
 d.header.Position=UDim2.fromOffset(0,0);d.header.Size=UDim2.new(1,0,0,mastH)
 self.masthead.Size=UDim2.fromScale(1,1)
 local closeSize=if narrow or height<420 then 44 else math.min(64,mastH-12)
 Theme.floatClose(d.close,closeSize);d.close.TextSize=math.floor(closeSize*.72)
 local signH=if narrow then 54 else mastH+6
 local signW=if narrow then width-closeSize-18 else width*.43
 self.banner.Size=UDim2.fromOffset(signW,signH)
 self.banner.Position=UDim2.fromOffset(-8,-12)
 local radius,border=16,3
 local shoulderX=signW-signH/2
 local bodyWidth=shoulderX+radius
 self.signEdge.Size=UDim2.fromOffset(bodyWidth,signH)
 self.signFill.Position=UDim2.fromOffset(3,3)
 self.signFill.Size=UDim2.fromOffset(bodyWidth-2*border,signH-2*border)
 -- Rounding a rotated square shortens its diagonal silhouette. Compensate
 -- for that cut so its top/bottom arcs meet the body's arcs at the same point.
 local tipSide=(signH+2*radius*(math.sqrt(2)-1))/math.sqrt(2)
 for _,spec in {{self.signTipEdge,tipSide},{self.signTip,tipSide-2*border}} do
  local tip,side=spec[1],spec[2]
  tip.AnchorPoint=Vector2.new(.5,.5)
  tip.Position=UDim2.fromOffset(shoulderX,signH/2)
  tip.Size=UDim2.fromOffset(side,side)
 end
 self.shopIcon.Visible=landing
 local iconSize=signH+8
 self.shopIcon.Size=UDim2.fromOffset(iconSize,iconSize)
 self.shopIcon.Position=UDim2.fromOffset(10,-6)
 self.back.Visible=not landing
 -- CHEVRON ONLY, IN A SQUARE. The word SHOP was saying what the sign beside it
 -- already says, and this is the control the mockups draw. The title's own
 -- indent is derived from the button rather than typed, or the two disagree the
 -- first time the masthead height moves.
 local backW=if narrow then 40 else mastH-12
 self.back.Size=UDim2.fromOffset(backW,backW)
 self.back.Position=UDim2.fromOffset(3,-5);self.back.ZIndex=3
 self.back.TextSize=math.floor(backW*.55)
 local titleX=if landing then iconSize+17 else backW+22
 self.title.Position=UDim2.fromOffset(titleX,0);self.title.Size=UDim2.new(1,-titleX-signH/2,1,0)
 self.title.TextSize=if landing then (if narrow then 30 else math.floor(mastH*.64)) else (if narrow then 19 else 25)
 self.title.TextWrapped=not landing;self.title.TextTruncate=Enum.TextTruncate.None
 -- ONE BADGE. The acorn balance stood beside the coins and went with the
 -- currency, so what was a pair now takes the width the pair shared.
 if narrow then
  self.coinBadge.Position=UDim2.fromOffset(10,53);self.coinBadge.Size=UDim2.new(1,-20,0,40)
 else
  local badgeW=math.floor(width*.54-closeSize-26)
  self.coinBadge.Size=UDim2.fromOffset(badgeW,mastH-18)
  self.coinBadge.Position=UDim2.new(1,-closeSize-20-badgeW,0,9)
 end
 self.coins.TextSize=if width<900 or height<420 then 20 else math.floor(mastH*.40)
 -- Scale the complete drawing, including the coin's fixed-size inner rim.
 local badgeH=self.coinBadge.Size.Y.Offset
 local currencySize=math.min(if compact then 24 else 34,badgeH-14)
 self.coinScale.Scale=currencySize/34
 self.coinIcon.Size=UDim2.fromOffset(currencySize,currencySize)
 self.coinIcon.Position=UDim2.new(0,8,.5,-currencySize/2)
 local balanceX=currencySize+16
 self.coins.Position=UDim2.fromOffset(balanceX,0);self.coins.Size=UDim2.new(1,-balanceX-8,1,0)
 local top=mastH+10
 local left=if landing or compact then 16 else 190
 self.sidebar.Visible=not landing and not compact
 self.sidebar.Position=UDim2.fromOffset(12,top);self.sidebar.Size=UDim2.new(0,166,1,-top-12)
 for _,tab in ipairs(d.tabs) do tab.view.Position=UDim2.fromOffset(left,top);tab.view.Size=UDim2.new(1,-left-16,1,-top-12) end
 local columns=if width<560 then 2 else 3
 local rows=6/columns
 local gap=if compact then 8 else 12
 self.grid.CellPadding=UDim2.fromOffset(gap,gap)
 local bannerH=if self.featured then (if compact then 58 else 86) else 0
 local available=height-top-24-(rows-1)*gap-(if bannerH>0 then bannerH+gap else 0)
 -- A LANDING TILE STOPS GROWING AT THE SIZE IT WAS DRAWN FOR, AND ON DESKTOP
 -- IT USED TO HAVE NO CEILING AT ALL.
 --
 -- The compact branch clamps to 96..150, which is why this reads well on a
 -- phone; the desktop branch was `math.max(152, available/rows)`, bounded only
 -- from BELOW. So the six cards took whatever a window gave them: measured on a
 -- 1366x768 laptop, 404 x 275 each, and on a 1512x850 one, 450 x 309 -- six
 -- cards filling a screen, with the artwork, the captions and the type all
 -- stretched past anything they were authored against.
 --
 -- THE CEILING IS DERIVED FROM THE TILE'S OWN HARDCODED OFFSETS rather than
 -- picked, which is what stops it being one more number to re-tune. The
 -- constructor authors a 78-tall caption, a 38 title row, a 27 hint row, a 50
 -- arrow and 28/18 type; this function derives the caption as `cellH * .29` and
 -- the title as `cardW * .084`, so the size at which the two agree IS the
 -- design point: 78 / .29 = 269 tall, 28 / .084 = 333 wide. Above that the
 -- layout is inventing a tile nobody drew.
 local MAX_TILE=Vector2.new(333,269)
 local cellH=if compact
  then math.clamp(math.floor(available/rows),96,150)
  else math.clamp(math.floor(available/rows),152,MAX_TILE.Y)
 self.grid.CellSize=UDim2.new(1/columns,-(14+(columns-1)*gap)/columns,0,cellH)
 -- THE GRID IS CENTRED IN WHAT IS LEFT, because capping the HEIGHT alone would
 -- leave three 450-wide cards in a row. The cap is on the whole grid rather
 -- than per cell so the cells stay a fraction of their parent -- which is what
 -- lets a UIGridLayout wrap on its own on a narrow window.
 local viewW=width-left-16
 local gridW=if compact then viewW
  else math.min(viewW,columns*MAX_TILE.X+(columns-1)*gap+14)
 self.home.Position=UDim2.fromOffset(math.floor((viewW-gridW)/2),0)
 self.home.Size=UDim2.new(0,gridW,1,-(if bannerH>0 then bannerH+gap else 0))
 if self.featured then
  local fb=self.featured
  -- Under the grid's LAST ROW rather than at the panel's floor: the grid is
  -- capped, so on a big window the floor is a long way below the cards.
  local gridH=rows*cellH+(rows-1)*gap
  local bannerW=gridW-14
  fb.button.Visible=landing
  fb.button.Position=UDim2.fromOffset(math.floor((viewW-gridW)/2),math.min(gridH+gap,height-top-24-bannerH))
  fb.button.Size=UDim2.fromOffset(bannerW,bannerH)
  local markSize=bannerH-(if compact then 18 else 26)
  fb.mark.Size=UDim2.fromOffset(markSize,markSize);fb.mark.Position=UDim2.new(0,14,0.5,-markSize/2)
  local x=markSize+26
  fb.heading.TextSize=if compact then 18 else 28
  fb.heading.Position=UDim2.fromOffset(x,if compact then 6 else 10)
  fb.heading.Size=UDim2.new(1,-x-70,0,if compact then 22 else 34)
  fb.line.TextSize=if compact then 12 else 17
  fb.line.Position=UDim2.fromOffset(x,if compact then 30 else 46)
  fb.line.Size=UDim2.new(1,-x-70,0,if compact then 18 else 24)
  fb.line.TextTruncate=Enum.TextTruncate.AtEnd
  local arrowSize=if compact then 34 else 52
  fb.arrow.Size=UDim2.fromOffset(arrowSize,arrowSize);fb.arrow.Position=UDim2.new(1,-arrowSize-14,0.5,-arrowSize/2)
  fb.chevron.TextSize=arrowSize*.8
 end
 local captionH=if compact then 44 elseif cellH<210 then 60 else math.clamp(cellH*.29,72,96)
 -- Measured off the grid it is actually in, not off the panel: those were the
 -- same number until the grid stopped filling the width.
 local cardW=(gridW-14-(columns-1)*gap)/columns
 for _,tile in ipairs(self.tiles) do
  tile.preview.Size=UDim2.new(1,0,1,-captionH)
  tile.caption.Position=UDim2.new(0,0,1,-captionH);tile.caption.Size=UDim2.new(1,0,0,captionH)
  local arrowSize=if narrow then 28 else math.clamp(captionH*.61,32,54)
  tile.arrow.Size=UDim2.fromOffset(arrowSize,arrowSize);tile.arrow.Position=UDim2.new(1,-arrowSize-10,.5,-arrowSize/2)
  tile.arrow.Visible=not compact
  tile.chevron.TextSize=arrowSize*.85
  tile.title.TextSize=if compact then 14 else math.clamp(cardW*.084,16,40)
  tile.title.Position=UDim2.fromOffset(if compact then 8 else 14,4);tile.title.Size=UDim2.new(1,if compact then -16 else -arrowSize-28,0,captionH*.51)
  tile.title.TextWrapped=false;tile.title.TextTruncate=Enum.TextTruncate.AtEnd
  tile.hint.TextSize=if compact then 11 else math.clamp(cardW*.050,13,23)
  tile.hint.Position=UDim2.new(0,if compact then 8 else 14,.56,0);tile.hint.Size=UDim2.new(1,if compact then -16 else -arrowSize-28,0,captionH*.34)
 end
end
-- The banner names the cheapest pass the player does not own yet, or says
-- they have everything. `info` is one entry of the server's pass payload.
function Shell:setFeatured(info: any?)
 if not self.featured then return end
 self.featured.line.Text=if info
  then (if info.id then ("%s %s %d Robux"):format(info.name or "",utf8.char(0x00B7),info.robux or 0) else (info.name or "").." "..utf8.char(0x00B7).." coming soon")
  else "You own every pass. Thank you!"
end
-- The second parameter is kept and ignored so existing callers do not change.
function Shell:setBalances(coins: number,_acorns: number?)
 self.coins.Text=Config.formatCoins(coins)
end
function Shell:rebuildPiggy() end -- Category illustrations do not use the purchasable skin mesh.
return Shell
