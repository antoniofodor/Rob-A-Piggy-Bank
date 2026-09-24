local HttpService=game:GetService("HttpService")
local Editor=game:GetService("ScriptEditorService")
local payload=HttpService:JSONDecode(HttpService:GetAsync("http://127.0.0.1:8841/og-refresh-v2/studio-sync.json"))
local shared=game.ReplicatedStorage.Shared
for _,name in ipairs({"SpectralScanData","SpectralFX"}) do
	local module=shared:FindFirstChild(name)
	if not module then module=Instance.new("ModuleScript");module.Name=name;module.Parent=shared end
	Editor:UpdateSourceAsync(module,function()return payload.modules[name] end)
end
local function patch(script,run)
	Editor:UpdateSourceAsync(script,function(source)return run(source:gsub("\r\n","\n")) end)
end
patch(shared.Config,function(source)
	for _,row in ipairs({{"ghost","\n\tcharcoal = {"},{"hologram","\n\t-- THE STRIPED"}}) do
		local start=assert(source:find("\t"..row[1].." = {",assert(source:find("Config.SKINS = {",1,true)),true))
		local finish=assert(source:find(row[2],start,true))
		source=source:sub(1,start-1)..payload.skins[row[1]]..source:sub(finish)
	end
	local a=assert(source:find("\twisp = {",assert(source:find("Config.SKIN_AURAS = {",1,true)),true))
	local b=assert(source:find("\n\t},",a,true))+4
	return source:sub(1,a-1)..payload.wisp..source:sub(b)
end)
patch(shared.PiggyModel,function(source)
	if not source:find("local SpectralFX =",1,true) then
		local at=assert(source:find("local ArcadeAnimator = require(script.Parent.ArcadeAnimator)",1,true))
		local finish=at+#"local ArcadeAnimator = require(script.Parent.ArcadeAnimator)"
		source=source:sub(1,finish-1).."\nlocal SpectralFX = require(script.Parent.SpectralFX)"..source:sub(finish)
	end
	if not source:find("SpectralFX.attach(model, body, key)",1,true) then
		local line="function PiggyModel.applyAccessories(model: Instance, body: BasePart, key: string?, anchored: boolean)"
		local at=assert(source:find(line,1,true))+#line
		source=source:sub(1,at-1).."\n\tSpectralFX.attach(model, body, key)"..source:sub(at)
	end
	if not source:find("if tier.spectral == true then",1,true) then
		local line="\tsa.Name = SURFACE_NAME\n\tsa.Parent = part"
		local at=assert(source:find(line,1,true))+#line
		source=source:sub(1,at-1).."\n\tif tier.spectral == true then\n\t\tpart.Color = Color3.new(1, 1, 1)\n\tend"..source:sub(at)
	end
	if not source:find('"SpectralCoat"',1,true) then
		local line="function PiggyModel.applySurface(part: BasePart, tier: any, isTrim: boolean?)"
		local at=assert(source:find(line,1,true))+#line
		source=source:sub(1,at-1)..'\n\tif part:GetAttribute("SpectralCoat") == true and tier.spectral ~= true then\n\t\tpart.Transparency = tier.transparency or 0\n\t\tpart:SetAttribute("SpectralCoat", nil)\n\tend'..source:sub(at)
		local a=assert(source:find("if tier.spectral == true then",1,true))
		local b=assert(source:find("\n\tend",a,true))
		source=source:sub(1,b-1)..'\n\t\tpart.Transparency = 0.02\n\t\tpart:SetAttribute("SpectralCoat", true)'..source:sub(b)
	end
	return source
end)
patch(shared.SkinFX,function(source)
	if source:find("require(script.Parent.SpectralFX).start()",1,true) then return source end
	local line="\trequire(script.Parent.ArcadeAnimator).start()"
	local at=assert(source:find(line,1,true))+#line
	return source:sub(1,at-1).."\n\trequire(script.Parent.SpectralFX).start()"..source:sub(at)
end)
for name,properties in pairs(payload.packs) do
	local sa=assert(shared.SurfacePacks:FindFirstChild(name))
	sa.AlphaMode=Enum.AlphaMode.Transparency
	for property,value in pairs(properties) do
		if property=="EmissiveMaskContent" then sa[property]=Content.fromUri(value)
		elseif property~="AlphaMode" then sa[property]=value end
	end
	sa:SetAttribute("ApprovedRevision","og-v2-layered")
end
return "Installed the two approved layered coats and scoped spectral runtime."
