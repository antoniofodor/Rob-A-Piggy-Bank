--!strict
-- The shop's frame: the masthead sign, the coin badge, the close button and
-- the back arrow, laid out around whichever shelf is open.
--
-- THERE IS NO LANDING PAGE ANY MORE (designer, 2026-09-23: "we don't need
-- that original shop home page anymore"). It was a six-card directory of
-- where every shop stands, left over from when the panel opened on a map of
-- itself. Every way in now picks its own shelf -- the HUD basket and B open
-- the Robux shop, a street door or a hallway counter opens its own -- so
-- there is no page to come home to and nothing for a card to point at.
--
-- SO THE BACK ARROW IS SHOWN ONLY WHEN THERE IS SOMEWHERE REAL TO GO BACK
-- TO. A route that has a parent says so through `setBack` after it selects
-- its shelf (today: the crates reached through the Robux shop point back at
-- the Robux shop), and `select` clears it, so every other way in shows the
-- shop basket on the sign instead of an arrow into nothing.
local Shared=game:GetService("ReplicatedStorage").Shared
local Theme=require(Shared.Theme)
local Config=require(Shared.Config)
local W=require(Shared.ShopWidgets)
local Shell={}
Shell.__index=Shell

function Shell.new(deps: any)
 local self=setmetatable({deps=deps,selected=0,backTo=nil},Shell) :: any
 -- What the sign says over each shelf, and in what colour. The colour is the
 -- same `W.colours` key the counter's own sign and card art use, so the sign
 -- over your head and the shop you walked into are one colour rather than two.
 self.categories={
  {key="upgrades",title="Upgrades",at=deps.at.upgrades},
  {key="home",title="Home",at=deps.at.home},
  {key="companions",title="Guardians",at=deps.at.companions},
  {key="rides",title="Rides",at=deps.at.rides},
  {key="supplies",title="Supplies",at=deps.at.items},
  {key="style",title="Style & Crates",at=deps.at.crates},
  {key="premium",title="Robux",at=deps.at.premium},
 }
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
 self.back=W.button(deps.header,"ShopBack",utf8.char(0x2039),Theme.GOLD,function()
  if self.backTo then deps.selectTab(self.backTo) end
 end)
 self.back.Visible=false
 self.coinBadge=W.frame(self.masthead,"CoinBadge",Theme.PAPER);W.round(self.coinBadge,15)
 self.coinBadge:FindFirstChildOfClass("UIStroke").Thickness=3
 self.coinIcon=W.frame(self.coinBadge,"CoinIcon");self.coinIcon.BackgroundTransparency=1
 self.coinScale=Instance.new("UIScale");self.coinScale.Parent=Theme.coin(self.coinIcon,34,"Coin")
 self.coins=W.text(self.coinBadge,"Coins","0",30);self.coins.Position=UDim2.fromOffset(52,0);self.coins.Size=UDim2.new(1,-60,1,0)
 deps.close.ZIndex=4
 deps.panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
 self:layout()
 return self
end

-- WHICH SHELF YOU ARE STANDING IN, AND THERE IS NOTHING LEFT TO CHOOSE.
-- This used to paint the sidebar as well: the selected entry took its own
-- colour, grew and showed a tick, on the two-channel rule the legendary
-- border keeps. That was answering "which one am I looking at" for a reader
-- with six to choose from. There is one now -- the door you came through --
-- so the sign is the whole answer.
function Shell:select(index: number)
 self.selected=index
 -- A new shelf has no parent until its route says so (see `setBack`).
 self.backTo=nil
 local title,hue="SHOP",W.colours.upgrades
 for _,c in ipairs(self.categories) do
  if c.at==index then title=c.title;hue=W.colours[c.key] end
 end
 -- THE SIGN WEARS THE CATEGORY'S COLOUR, so the sign over your head and the
 -- card that told you where this shop was are one colour rather than two.
 -- Ink is checked against
 -- it rather than assumed: `supplies` purple carries ink at about 3.5, which is
 -- fine for a 25px bold heading and under the body floor, so `readable` lifts
 -- the type instead of me trusting the hue.
 self.signFill.BackgroundColor3=hue;self.signTip.BackgroundColor3=hue
 self.title.TextColor3=Theme.readable(Theme.INK,hue)
 self.title.Text=title;self:layout()
end

-- Where the back arrow goes from the shelf that is open, or nil for no arrow.
-- Called AFTER `select`, which clears it.
function Shell:setBack(index: number?)
 self.backTo=index
 self:layout()
end

function Shell:layout()
 local d=self.deps
 local width,height=d.panel.AbsoluteSize.X,d.panel.AbsoluteSize.Y
 local narrow=width<560
 local compact=width<950 or height<500
 local hasBack=self.backTo~=nil
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
 self.shopIcon.Visible=not hasBack
 local iconSize=signH+8
 self.shopIcon.Size=UDim2.fromOffset(iconSize,iconSize)
 self.shopIcon.Position=UDim2.fromOffset(10,-6)
 self.back.Visible=hasBack
 -- CHEVRON ONLY, IN A SQUARE. The word SHOP was saying what the sign beside it
 -- already says, and this is the control the mockups draw. The title's own
 -- indent is derived from the button rather than typed, or the two disagree the
 -- first time the masthead height moves.
 local backW=if narrow then 40 else mastH-12
 self.back.Size=UDim2.fromOffset(backW,backW)
 self.back.Position=UDim2.fromOffset(3,-5);self.back.ZIndex=3
 self.back.TextSize=math.floor(backW*.55)
 local titleX=if hasBack then backW+22 else iconSize+17
 self.title.Position=UDim2.fromOffset(titleX,0);self.title.Size=UDim2.new(1,-titleX-signH/2,1,0)
 self.title.TextSize=if narrow then 19 else 25
 self.title.TextWrapped=true;self.title.TextTruncate=Enum.TextTruncate.None
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
 -- 190 ON A WIDE PANEL UNTIL THE SIDEBAR WENT, which was the 166 it took
 -- plus its gutter. Every shelf in the game is 174 pixels wider now, on
 -- every window big enough to have carried one -- so the card grids get a
 -- column back rather than the panel growing a margin nothing stands in.
 local left=16
 for _,tab in ipairs(d.tabs) do tab.view.Position=UDim2.fromOffset(left,top);tab.view.Size=UDim2.new(1,-left-16,1,-top-12) end
end
-- The second parameter is kept and ignored so existing callers do not change.
function Shell:setBalances(coins: number,_acorns: number?)
 self.coins.Text=Config.formatCoins(coins)
end
function Shell:rebuildPiggy() end -- Category illustrations do not use the purchasable skin mesh.
return Shell
