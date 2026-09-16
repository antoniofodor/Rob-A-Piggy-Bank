-- Play CLIENT: cloned native UI only. No remotes, player balances or saves.
local gui = game.Players.LocalPlayer.PlayerGui
local card = assert(gui:FindFirstChild("CarryDestinations", true), "carry card missing")
local button = assert(gui:FindFirstChild("DeliverLoot", true), "delivery button missing")
local screen = Instance.new("ScreenGui")
screen.Name, screen.IgnoreGuiInset = "_DropoffLayoutCheck", true
screen.Parent = gui
local rows = {}
local ok, err = pcall(function()
 for _, size in ipairs({Vector2.new(1399,793),Vector2.new(750,361),Vector2.new(480,320),Vector2.new(320,568)}) do
  local frame = Instance.new("Frame")
  frame.Size = UDim2.fromOffset(size.X,size.Y)
  frame.Position = UDim2.fromOffset(10000,10000)
  frame.Parent = screen
  local panel, action = card:Clone(), button:Clone()
  panel.Parent, action.Parent = frame, frame
  panel.Visible, action.Visible = true, true
  panel.Keep.Text = "KEEP · Your crate\n123456789 Acorns + all items"
  panel.Return.Text = "RETURN · TwentyCharacterNameX's crate\n+12345678 Acorns bounty"
  action.Label.Text = "RETURN"
  task.wait(.15)
  local left, top = panel.AbsolutePosition.X-frame.AbsolutePosition.X, panel.AbsolutePosition.Y-frame.AbsolutePosition.Y
  local gap = action.AbsolutePosition.Y-(panel.AbsolutePosition.Y+panel.AbsoluteSize.Y)
  assert(left>=0 and top>=0 and left+panel.AbsoluteSize.X<=size.X,"card leaves viewport")
  assert(gap>=7,"card overlaps action button")
  assert(action.AbsolutePosition.Y-frame.AbsolutePosition.Y+action.AbsoluteSize.Y<=size.Y,"button leaves viewport")
  assert(panel.Keep.TextFits and panel.Return.TextFits and action.Label.TextFits,"drop-off text clipped")
  table.insert(rows,{width=size.X,height=size.Y,gap=gap,textFits=true})
  frame:Destroy()
 end
end)
screen:Destroy()
assert(ok,err)
return game.HttpService:JSONEncode({layouts=rows,localFixturesOnly=true})
