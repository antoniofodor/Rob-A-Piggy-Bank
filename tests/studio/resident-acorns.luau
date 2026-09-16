-- Client-only display fixture. Real resident/player stock is never edited.
local plots = assert(workspace:FindFirstChild("Plots"))
local template
for _, plot in ipairs(plots:GetChildren()) do
 if plot:GetAttribute("ResidentName") and plot:FindFirstChild("AcornOak") then template=plot; break end
end
assert(template,"resident tree missing")
local fixture=Instance.new("Model");fixture.Name="_ResidentAcornCountdownCheck"
local tree,crate=template.AcornOak:Clone(),template.AcornStorage:Clone()
for _, part in ipairs({tree,crate}) do
 for _, item in ipairs(part:GetDescendants()) do
  if item.Name=="AcornFill" or item.Name=="RipeAcorns" or item.Name=="GroundAcorns" then item:Destroy() end
 end
 part:PivotTo(CFrame.new(10000,20,10000));part.Parent=fixture
end
fixture:SetAttribute("ResidentName","Fixture")
fixture:SetAttribute("TreeAcorns",2);fixture:SetAttribute("AcornAmount",2)
fixture:SetAttribute("AcornRaidReadyAt",workspace:GetServerTimeNow()+2)
fixture.Parent=plots
local results={}
local ok,err=pcall(function()
 task.wait(.15)
 local shake=tree.TrunkCollider.ShakePrompt
 local raid=crate.Storage.StorageRaidPrompt
 -- Resolve the project's attribute via the live prompt: only one string
 -- starts with RESTING, and it is shared by the two source prompts.
 local key
 for name,value in pairs(shake:GetAttributes()) do if type(value)=="string" and value:find("RESTING",1,true) then key=name;break end end
 assert(key,"resident cooldown not displayed")
 results.before=shake:GetAttribute(key)
 assert(raid:GetAttribute(key)==results.before,"tree/crate timers disagree")
 task.wait(3)
 results.afterTree=shake:GetAttribute(key);results.afterCrate=raid:GetAttribute(key)
 assert(results.afterTree=="2 RIPE" and results.afterCrate=="2 STORED","deadline did not restore source counts")
 fixture:SetAttribute("AcornRaidReadyAt",workspace:GetServerTimeNow()+900)
 fixture:SetAttribute("OwnerUserId",game.Players.LocalPlayer.UserId)
 task.wait(.12)
 assert(shake.Enabled and not raid.Enabled and shake:GetAttribute(key)=="2 RIPE","player inherited old resident cooldown")
 results.handover=true
end)
fixture:Destroy()
assert(ok,err)
return results
