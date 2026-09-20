--!strict
-- Static action symbols on chunky, colour-coded thumb buttons.
local Theme = require(script.Parent.Theme)
local Input = game:GetService("UserInputService")
local ActionButtons = {}
local C = Color3.fromRGB
local colours = { DODGE=C(116,205,255), SNEAK=C(196,164,247), RIDE=C(109,219,184), TRICK=C(255,205,84) }

local function piece(parent: Instance, name: string, x: number, y: number, w: number, h: number,
 colour: Color3, radius: number, rotation: number?, outline: number?): Frame
 local f=Instance.new("Frame")
 f.Name=name;f.Size=UDim2.fromOffset(w,h);f.Position=UDim2.fromOffset(x,y)
 f.BackgroundColor3=colour;f.BorderSizePixel=0;f.Rotation=rotation or 0;f.Parent=parent
 Theme.corner(f,radius)
 if outline then Theme.outline(f,outline,Theme.INK) end
 return f
end

function ActionButtons.icon(parent: Instance, kind: string): Frame
 local icon=Instance.new("Frame")
 icon.Name="Icon";icon.Size=UDim2.fromOffset(68,48);icon.BackgroundTransparency=1;icon.ZIndex=3;icon.Parent=parent
 if kind=="SNEAK" then
  -- A broad bandit mask separates stealth from the running shoe at a glance.
  piece(icon,"LeftTie",10,25,12,7,Theme.INK,2,-24)
  piece(icon,"RightTie",47,25,12,7,Theme.INK,2,24)
  local mask=piece(icon,"Mask",16,19,38,22,Theme.INK,9,-7)
  piece(mask,"LeftEye",6,7,10,6,Theme.PAPER,3,-12)
  piece(mask,"RightEye",23,7,10,6,Theme.PAPER,3,12)
 elseif kind=="RIDE" then
  for _,x in {16,46} do
   local wheel=piece(icon,"Wheel",x,33,13,13,Theme.INK,7)
   piece(wheel,"Hub",4,4,5,5,Theme.PAPER,3)
  end
  piece(icon,"Deck",22,31,27,7,Theme.PAPER,3,0,2)
  piece(icon,"Stem",44,13,5,24,Theme.INK,2,-12)
  piece(icon,"Handlebar",36,12,20,5,Theme.INK,2)
 elseif kind=="TRICK" then
  local board=piece(icon,"Board",15,25,43,10,Theme.PAPER,5,-23,2)
  for _,x in {7,30} do piece(board,"Wheel",x,9,8,8,Theme.INK,4) end
  piece(icon,"LiftMark",12,12,5,12,Theme.INK,2,25)
 else
  -- One clean boot silhouette, white sole and two bold speed lines.
  local boot=piece(icon,"Boot",29,15,17,23,Theme.PAPER,5,-16,2)
  piece(boot,"Cuff",2,1,13,6,colours.DODGE,2)
  piece(icon,"Toe",27,31,29,10,Theme.PAPER,5,-7,2)
  piece(icon,"Sole",25,39,33,4,Theme.INK,2,-7)
  piece(icon,"SpeedLine",9,23,14,4,Theme.INK,2)
  piece(icon,"SpeedLine",13,32,10,4,Theme.INK,2)
 end
 return icon
end

function ActionButtons.surface(button: TextButton, kind: string?)
 button.AutoButtonColor=false
 button.BackgroundColor3=colours[kind or "RIDE"] or Theme.PAPER
 Theme.corner(button,18)
 Theme.outline(button,2.5,Theme.INK)
 local rim=piece(button,"InsetRim",4,4,60,60,Theme.PAPER,14)
 rim.BackgroundTransparency=1;rim.ZIndex=1
 Theme.outline(rim,1,Theme.PAPER)
end

function ActionButtons.make(name: string, kind: string, text: string, key: string, parent: Instance): TextButton
 local button=Instance.new("TextButton")
 button.Name=name;button.Size=UDim2.fromOffset(68,68);button.Text="";button.BorderSizePixel=0;button.Parent=parent
 button:SetAttribute("AccessibleLabel",text);button:SetAttribute("StaticIcon",true)
 ActionButtons.surface(button,kind)
 ActionButtons.icon(button,kind)
 local label=Instance.new("TextLabel")
 label.Name="Label";label.Size=UDim2.new(1,-4,0,17);label.Position=UDim2.fromOffset(2,47)
 label.BackgroundTransparency=1;label.Font=Theme.FONT;label.TextSize=11;label.TextColor3=Theme.INK
 label.Text=text;label.ZIndex=4;label.Parent=button
 local chip=label:Clone()
 chip.Name="Key";chip.Size=UDim2.fromOffset(19,15);chip.Position=UDim2.fromOffset(46,3)
 chip.BackgroundTransparency=0;chip.BackgroundColor3=Theme.PAPER;chip.Text=key;chip.TextSize=10;chip.Parent=button
 Theme.corner(chip,5)
 local function fitKey()
  chip.Visible=(not Input.TouchEnabled and chip.Text~="") or chip.Text=="ON"
  chip.BackgroundColor3=if chip.Text=="ON" then Theme.GOOD else Theme.PAPER
 end
 local keyConnection=chip:GetPropertyChangedSignal("Text"):Connect(fitKey)
 local inputConnection=Input:GetPropertyChangedSignal("TouchEnabled"):Connect(fitKey)
 button.Destroying:Connect(function() keyConnection:Disconnect();inputConnection:Disconnect() end)
 fitKey()
 return button
end
return ActionButtons
