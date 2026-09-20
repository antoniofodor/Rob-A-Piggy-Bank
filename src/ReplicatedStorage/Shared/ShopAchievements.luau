--!strict
-- Read-only trophy progress from the existing CosmeticState payload.
local Shared=game:GetService("ReplicatedStorage").Shared
local Config=require(Shared.Config)
local Theme=require(Shared.Theme)
local W=require(Shared.ShopWidgets)
local Marks=require(Shared.ShopMarks)
local Achievements={}
Achievements.__index=Achievements
function Achievements.new(parent: Instance)
	local self=setmetatable({rows={},snapshot=nil},Achievements) :: any
	self.view=W.scroll(parent,"Achievements");self.view.Visible=false
	local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,12);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=self.view
	self.loading=W.text(self.view,"Loading","Loading your achievements…",18);self.loading.Size=UDim2.new(1,-14,0,50)
	-- AN EMPTY STATE THAT NAMES WHERE THE RECORD WENT, because this page is
	-- opened from a PERMANENT button in the landing footer. `Config.TROPHIES`
	-- is an empty table now, so the walk below finds nothing and the page drew
	-- a heading over blank space -- and nothing about the footer hinted the
	-- feature had moved. That is the same failure the retired parked cars left
	-- behind, where a header sat over an empty grid and read as a catalogue
	-- that had failed to load.
	--
	-- It says the HOUSE rather than "nothing here yet", because the counters
	-- were not deleted: `data.trophies` still records every one and the wall
	-- reads four of them. A player who tapped this has asked a fair question
	-- and there is a real answer to give them.
	self.empty=W.frame(self.view,"NoAchievements",Theme.PAPER)
	self.empty.Size=UDim2.new(1,-14,0,132);self.empty.LayoutOrder=1;W.round(self.empty,14)
	self.empty.Visible=false
	local mark=Marks.draw(self.empty,"trophy",54);mark.Position=UDim2.fromOffset(10,14)
	local heading=W.text(self.empty,"Heading","Your record is on your wall",20)
	heading.Position=UDim2.fromOffset(76,14);heading.Size=UDim2.new(1,-88,0,28)
	local body=W.text(self.empty,"Body",
		"Skins robbed, coins stolen and patrols outrun are kept inside your house. Top the Most Wanted board and a poster goes up with the biggest bounty you ever carried.",13)
	body.Font=Enum.Font.GothamMedium;body.TextColor3=Theme.MUTED
	body.Position=UDim2.fromOffset(76,46);body.Size=UDim2.new(1,-92,0,74)
	body.TextWrapped=true;body.TextTruncate=Enum.TextTruncate.None
	return self
end
function Achievements:setCosmetics(snapshot: any)
	self.snapshot=snapshot
	if self.view.Visible then self:render() end
end
function Achievements:render()
	self.loading.Visible=self.snapshot==nil
	if not self.snapshot then return end
	local shown=0
	for key,info in pairs(self.snapshot.decor or {}) do
		if not info.trophy then continue end
		shown+=1
		local row=self.rows[key]
		if not row then
			local f=W.frame(self.view,key,Theme.PAPER);f.Size=UDim2.new(1,-14,0,128);f.LayoutOrder=info.order or 0;W.round(f,14)
			local icon=Marks.draw(f,"trophy",54);icon.Position=UDim2.fromOffset(10,12)
			local name=W.text(f,"Name",info.name,20);name.Position=UDim2.fromOffset(76,9);name.Size=UDim2.new(1,-88,0,28)
			local detail=W.text(f,"Requirement",info.trophy.requirement or "",14);detail.Position=UDim2.fromOffset(76,39);detail.Size=UDim2.new(1,-88,0,36);detail.TextWrapped=true;detail.TextTruncate=Enum.TextTruncate.None
			local track=W.frame(f,"Track",Theme.SAND_DEEP);track.Position=UDim2.fromOffset(14,85);track.Size=UDim2.new(1,-28,0,12);W.round(track,6,false)
			local fill=W.frame(track,"Progress",Theme.GOOD);fill.Size=UDim2.fromScale(0,1);W.round(fill,6,false)
			local state=W.text(f,"Status","",13);state.Position=UDim2.fromOffset(14,102);state.Size=UDim2.new(1,-28,0,20)
			row={frame=f,fill=fill,status=state};self.rows[key]=row
		end
		local have,need=info.trophy.have or 0,math.max(1,info.trophy.need or 1)
		row.fill.Size=UDim2.fromScale(if info.owned then 1 else math.clamp(have/need,0,1),1)
		row.status.Text=if info.owned then "EARNED • Trophy for your house" else Config.formatCoins(have).." / "..Config.formatCoins(need)
	end
	-- Counted from what the payload actually carried rather than from
	-- `next(self.rows)`: rows are cached and never destroyed, so a snapshot
	-- that stops carrying trophies would leave the old ones standing and this
	-- reading as full.
	self.empty.Visible=shown==0
end
return Achievements
