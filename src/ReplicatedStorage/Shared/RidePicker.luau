--!strict
-- Owned-ride quick selection. Server snapshots own selection and stance state.
local Theme=require(script.Parent.Theme)
local Config=require(script.Parent.Config)
local Actions=require(script.Parent.ActionButtons)
local Layout=require(script.Parent.HUDLayout)
local RideModel=require(script.Parent.RideModel)
local W=require(script.Parent.ShopWidgets)
local Picker={}
Picker.__index=Picker
local MINT=Color3.fromRGB(109,219,184)

-- Fit the actual silhouette in a static three-quarter view, without the
-- generous spherical camera margin used by the old tiny thumbnails.
local function preview(parent: GuiObject,key: string)
 local v=Instance.new("ViewportFrame")
 v.Name="RidePreview";v.BackgroundTransparency=1;v.Size=UDim2.fromScale(1,1)
 v.Ambient=Color3.fromRGB(165,165,165);v.LightColor=Color3.new(1,1,1)
 v.LightDirection=Vector3.new(-1,-1,-1);v.Parent=parent
 local world=Instance.new("WorldModel");world.Parent=v
 local model=RideModel.build(key);model.Parent=world
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") then part.Anchored=true;part.CanCollide=false end
 end
 local cf,bounds=model:GetBoundingBox()
 local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=v;v.CurrentCamera=camera
 local direction=Vector3.new(1,.6,.85).Unit
 local orientation=CFrame.lookAt(cf.Position+direction,cf.Position)
 local function fit()
  local aspect=math.max(.25,v.AbsoluteSize.X/math.max(1,v.AbsoluteSize.Y))
  local tangent=math.tan(math.rad(15));local distance=0
  for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
   local corner=Vector3.new(x*bounds.X,y*bounds.Y,z*bounds.Z)*.5
   local depth=corner:Dot(direction)
   distance=math.max(distance,depth+math.abs(corner:Dot(orientation.RightVector))/(tangent*aspect),
    depth+math.abs(corner:Dot(orientation.UpVector))/tangent)
  end end end
  camera.CFrame=CFrame.lookAt(cf.Position+direction*math.max(1,distance*1.07),cf.Position)
 end
 v:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit);fit()
 return v
end

function Picker.new(deps: any)
 local self=setmetatable({deps=deps,tiles={},latest=nil,owned=0,equipped=nil,open=false},Picker) :: any
 self.slot=Actions.make("GarageSlot","RIDE","RIDES","V",deps.gui)
 self.slot.Visible=false;Layout.bindAction(self.slot,deps.gui,2)
 self.root=W.frame(deps.gui,"GaragePicker",Theme.PAPER)
 self.root.Visible=false;self.root.Active=true;self.root.ZIndex=30;W.round(self.root,18)
 local header=W.frame(self.root,"Header",MINT);header.Size=UDim2.new(1,0,0,42);W.round(header,18,false)
 self.header=header
 local join=W.frame(header,"Join",MINT);join.Position=UDim2.fromOffset(0,22);join.Size=UDim2.new(1,0,0,20)
 self.headerJoin=join
 local title=W.text(header,"Title","YOUR RIDES",19);title.Position=UDim2.fromOffset(14,0);title.Size=UDim2.new(1,-60,1,0)
 self.title=title
 self.close=W.button(header,"Close","×",Theme.STOP,function() self:setOpen(false) end)
 self.close.TextSize=28;self.close.TextColor3=Theme.PAPER
 Theme.floatClose(self.close)
 self.list=W.scroll(self.root,"OwnedRides");self.list.Position=UDim2.fromOffset(8,47);self.list.Size=UDim2.new(1,-16,1,-87)
 self.list.ScrollingDirection=Enum.ScrollingDirection.X;self.list.AutomaticCanvasSize=Enum.AutomaticSize.X
 local flow=Instance.new("UIListLayout");flow.FillDirection=Enum.FillDirection.Horizontal;flow.Padding=UDim.new(0,10)
 flow.SortOrder=Enum.SortOrder.LayoutOrder;flow.Parent=self.list
 self.hint=W.text(self.root,"Hint","Tap a ride to equip",12);self.hint.Font=Theme.FONT_BODY
 self.hint.Position=UDim2.new(0,14,1,-30);self.hint.Size=UDim2.new(1,-175,0,22)
 self.stance=W.button(self.root,"StancePill","STYLE",Theme.PAPER,function() self:cycleStance() end)
 self.stance.Position=UDim2.new(1,-153,1,-33);self.stance.Size=UDim2.fromOffset(139,26);self.stance.TextSize=11
 -- Gated so a thumb sliding off the stick onto the slot does not open it.
 local slotPressed=require(script.Parent.TouchOrigin).guard(self.slot)
 self.slot.Activated:Connect(function() if slotPressed() then self:setOpen(not self.open) end end)
 self.connection=deps.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
 task.spawn(Layout.watchJump,function() self:layout() end)
 self.root.Destroying:Connect(function() self.connection:Disconnect() end)
 if deps.shop then
  deps.shop:GetPropertyChangedSignal("Visible"):Connect(function() if deps.shop.Visible then self:setOpen(false) end end)
 end
 deps.gui:GetAttributeChangedSignal("BagOpen"):Connect(function() if deps.gui:GetAttribute("BagOpen") then self:setOpen(false) end end)
 self:layout()
 return self
end

function Picker:layout()
 local view=self.deps.gui.AbsoluteSize
 local compact=Layout.metrics(view).compact
 local height=if compact then 138 else 234
 self.root.AnchorPoint=Vector2.new(1,1)
 self.root.Position=UDim2.new(1,-14,1,if compact then -170 else -182)
 -- Clear of Roblox's big tablet jump button, which this used to open behind.
 local jumpAt=Layout.jumpRect(self.deps.gui)
 if jumpAt then self.root.Position=UDim2.new(1,-14,0,math.min(jumpAt.Y-10,view.Y-170)) end
 self.root.Size=UDim2.fromOffset(math.min(if compact then 330 else 510,view.X-28),height)
 self.header.Size=UDim2.new(1,0,0,if compact then 32 else 42)
 self.headerJoin.Position=UDim2.fromOffset(0,if compact then 16 else 22)
 self.headerJoin.Size=UDim2.new(1,0,0,if compact then 16 else 20)
 self.title.Text=if compact then "RIDES" else "YOUR RIDES"
 self.title.TextSize=if compact then 14 else 19
 self.title.Position=UDim2.fromOffset(if compact then 10 else 14,0)
 self.title.Size=if compact then UDim2.new(1,-190,1,0) else UDim2.new(1,-60,1,0)
 Theme.floatClose(self.close)
 self.hint.Visible=not compact
 -- Keep styles accessible in the title row instead of reserving a whole footer.
 self.stance.Position=if compact then UDim2.new(1,-181,0,3) else UDim2.new(1,-153,1,-33)
 self.stance.Size=UDim2.fromOffset(139,26)
 self.list.Position=UDim2.fromOffset(if compact then 4 else 8,if compact then 34 else 47)
 self.list.Size=UDim2.new(1,if compact then -8 else -16,1,if compact then -38 else -87)
 for _,tile in pairs(self.tiles) do self:layoutTile(tile,height) end
end

function Picker:layoutTile(tile: any,height: number)
 local short=height<190
 tile.button.Size=UDim2.new(0,if short then 94 else 138,1,-12)
 tile.name.TextSize=if short then 11 else 12
 tile.name.Position=UDim2.fromOffset(5,2);tile.name.Size=UDim2.new(1,-10,0,if short then 22 else 27)
 tile.art.Position=UDim2.fromOffset(5,if short then 24 else 29);tile.art.Size=UDim2.new(1,-10,1,if short then -49 else -54)
 tile.state.Position=UDim2.new(0,5,1,-23);tile.state.Size=UDim2.new(1,-10,0,20)
end

function Picker:tile(key: string,info: any)
 if self.tiles[key] then return self.tiles[key] end
 local b=W.button(self.list,key,"",Theme.PAPER,function()
  local current=self.latest and self.latest.rides and self.latest.rides[key]
  if not current or not current.owned then return end
  self.deps.requestRide(key);self:setOpen(false)
 end)
 b.LayoutOrder=info.order or 99
 local name=W.text(b,"Name",info.name or (Config.RIDES[key] and Config.RIDES[key].name) or key,12)
 name.TextXAlignment=Enum.TextXAlignment.Center;name.TextWrapped=true
 local art=W.frame(b,"Art",MINT:Lerp(Theme.PAPER,.75));W.round(art,9,false)
 local state=W.text(b,"State","",11);state.TextXAlignment=Enum.TextXAlignment.Center
 local tile={button=b,name=name,art=art,state=state,preview=nil};self.tiles[key]=tile
 self:layoutTile(tile,self.root.Size.Y.Offset)
 return tile
end

function Picker:ensurePreviews()
 for key,tile in pairs(self.tiles) do
  if tile.button.Visible and not tile.preview then tile.preview=preview(tile.art,key) end
 end
end

function Picker:setOpen(open: boolean)
 self.open=open and self.owned>0
 self.root.Visible=self.open
 self.slot:FindFirstChildOfClass("UIStroke").Color=if self.open then Theme.GOLD_DEEP else Theme.INK
 if self.open then
  self:ensurePreviews()
  task.defer(function()
   local tile=self.equipped and self.tiles[self.equipped]
   if not self.open or not tile then return end
   local x=tile.button.AbsolutePosition.X-self.list.AbsolutePosition.X+self.list.CanvasPosition.X
   self.list.CanvasPosition=Vector2.new(math.clamp(x-(self.list.AbsoluteSize.X-tile.button.AbsoluteSize.X)/2,
    0,math.max(0,self.list.AbsoluteCanvasSize.X-self.list.AbsoluteSize.X)),0)
  end)
 end
end

function Picker:render(snapshot: any)
 self.latest=snapshot;if not snapshot then return end
 self.owned=0;self.equipped=nil
 -- Do not briefly hide every card on each snapshot: that shrinks the automatic
 -- canvas and resets an in-progress swipe back to the first ride.
 for key,tile in pairs(self.tiles) do
  local info=snapshot.rides and snapshot.rides[key]
  tile.button.Visible=info~=nil and info.owned==true
 end
 for key,info in pairs(snapshot.rides or {}) do
  if info.owned then
   self.owned+=1
   if info.equipped then self.equipped=key end
   local tile=self:tile(key,info);tile.button.Visible=true
   tile.state.Text=if info.equipped then "✓ PUT AWAY" else ("+%d%% SPEED"):format(info.boost or 0)
   tile.state.TextColor3=if info.equipped then Theme.GOOD_INK else Theme.INK
   tile.button.BackgroundColor3=if info.equipped then MINT else Theme.PAPER
   tile.button:FindFirstChildOfClass("UIStroke").Thickness=if info.equipped then 3 else 2
  end
 end
 self.slot.Visible=self.owned>0
 if self.owned==0 then self:setOpen(false) end
 self.slot.Label.Text=if snapshot.riding then "RIDING" else "RIDES"
 self.hint.Text=if self.equipped then "Tap selected ride to put away" else "Tap a ride to equip"
 local list=snapshot.stances or {}
 self.stance.Visible=self.equipped~=nil and #list>1
 local current="Classic";local available=0
 for _,entry in ipairs(list) do
  if entry.key==snapshot.stance then current=entry.name end
  if not entry.locked then available+=1 end
 end
 self.stance.Text=if available<=1 then "UNLOCK STYLES ›" else "STYLE: "..string.upper(current).." ›"
 if self.open then self:ensurePreviews() end
end

function Picker:cycleStance()
 if not self.latest or not self.equipped then return end
 local list=self.latest.stances or {};if #list<2 then return end
 local available={}
 for _,entry in ipairs(list) do if not entry.locked then table.insert(available,entry) end end
 if #available<2 then self:setOpen(false);self.deps.openStyles();return end
 local at=1
 for i,entry in ipairs(available) do if entry.key==self.latest.stance then at=i end end
 self.deps.requestStance(self.equipped,available[(at%#available)+1].key)
end
return Picker
