-- Run on the Play CLIENT after boot. Only local display fixtures are changed;
-- never require game modules, send currency remotes, or edit a player save.
local plots = assert(workspace:FindFirstChild("Plots"), "plots missing")
local template
for _, plot in ipairs(plots:GetChildren()) do
 if plot:FindFirstChild("AcornStorage") and plot:FindFirstChild("AcornOak") then template = plot; break end
end
assert(template, "tree/storage missing")
local fixture = Instance.new("Model")
fixture.Name = "_AcornStorageCheck"
local storage, tree = template.AcornStorage:Clone(), template.AcornOak:Clone()
for _, item in ipairs({storage:FindFirstChild("AcornFill"), tree:FindFirstChild("RipeAcorns"), tree:FindFirstChild("GroundAcorns")}) do item:Destroy() end
storage:PivotTo(CFrame.new(10005, 10, 10000)); tree:PivotTo(CFrame.new(10000, 10, 10000))
storage.Parent, tree.Parent = fixture, fixture
fixture.Parent = plots
local results = {}
local function count(folder)
 assert(folder, "display folder missing")
 local n, meshes = 0, 0
 for _, item in ipairs(folder:GetDescendants()) do
  if item:IsA("Model") and item.Name == "Acorn" then n += 1 end
  if item:IsA("BasePart") then
   assert(item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch, "display affects physics")
   if item:IsA("MeshPart") then meshes += 1; assert(item.Color == Color3.new(1,1,1), "import tint changed") end
  end
 end
 assert(meshes == n * 3, "imported three-part Acorns not used")
 return n
end
local ok, err = pcall(function()
 for _, amount in ipairs({0,3,8,24,200,0}) do
  fixture:SetAttribute("AcornAmount", amount); task.wait(.12)
  local fill = storage:FindFirstChild("AcornFill")
  local drawn = count(fill)
  local text = fill.StoredCount:FindFirstChildOfClass("TextLabel").Text
  assert(drawn == math.min(amount,8) and text == tostring(amount).." Acorns" and not fill:FindFirstChild("Packed"), "storage display mismatch")
  table.insert(results, {stored=amount,drawn=drawn,text=text})
 end
 fixture:SetAttribute("AcornAmount",8); fixture:SetAttribute("TreeAcorns",8); task.wait(.12)
 assert(count(storage.AcornFill)==8 and count(tree.RipeAcorns)==8 and count(tree.GroundAcorns)==0, "tree/storage not separate")
 fixture:SetAttribute("TreeAcorns",0); fixture:SetAttribute("GroundAcorns",8)
 fixture:SetAttribute("AcornShakeAt",workspace:GetServerTimeNow()); task.wait(.12)
 assert(count(tree.GroundAcorns)==8 and count(tree.RipeAcorns)==0 and count(storage.AcornFill)==8, "shake display mismatch")
 task.wait(.5)
 fixture:SetAttribute("GroundAcorns",3); task.wait(.12)
 assert(count(tree.GroundAcorns)==3 and count(storage.AcornFill)==8, "catch wrongly changes stored display")
 fixture:SetAttribute("GroundAcorns",0); task.wait(.12)
 assert(count(tree.GroundAcorns)==0, "ground expiry display failed")
 local old = storage.AcornFill
 fixture.Parent=nil; task.wait(.12)
 assert(old.Parent==nil and not tree:FindFirstChild("GroundAcorns"),"plot removal did not clean displays")
 fixture.Parent=plots; task.wait(.12)
 assert(count(storage.AcornFill)==8 and tree:FindFirstChild("RipeAcorns"),"re-entry did not restore display")
end)
fixture:Destroy()
assert(ok,err)
return {storage=results,treeGroundSeparation=true,cleanup=true}
