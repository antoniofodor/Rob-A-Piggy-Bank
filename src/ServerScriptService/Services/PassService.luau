--!strict
--[[
	PassService

	Who owns which Robux game pass, and the one place that asks Roblox.

	WHY A GAME PASS AND NOT A DEVELOPER PRODUCT.

	A pass is a permanent entitlement held by ROBLOX, not by this game's
	DataStore, so `UserOwnsGamePassAsync` is re-checkable forever. If a save is
	ever lost -- and saves are lost -- the player still owns what they paid real
	money for, and it comes back the moment they rejoin. A developer product is
	a consumable: the receipt arrives once, and if the write that recorded it
	fails, the purchase is simply gone. That is not an acceptable failure for a
	nine year old who spent their birthday Robux.

	It costs one thing, and the whole design has to answer for it: a pass is
	buyable from the EXPERIENCE'S STORE PAGE, outside this game's UI entirely.
	No button can be hidden to prevent a purchase, so nothing may assume the
	buyer had a particular thing first. See `entryRide` in Config.PASSES.

	OWNERSHIP IS CACHED PER SESSION, NEVER PER CALL.

	`UserOwnsGamePassAsync` is a web call that yields and can throw, and it gets
	asked on every stance change, every push and every shop render. Asking it
	each time would put a network round trip inside the HUD. It is asked once
	when a player joins, and again the moment a purchase completes -- which are
	the only two times the answer can change.

	A FAILED CHECK IS NOT A "NO".

	If the call throws, the entry is left ABSENT rather than written as false,
	so the next ask retries. Writing false on a network blip would take a paid
	feature away from somebody who owns it and leave it away for the whole
	session, which looks exactly like being robbed.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PassService = {}

-- Fired with (player, passKey) when a pass is confirmed owned, at join or on
-- purchase. A BindableEvent rather than a direct call into RideService,
-- because the thing that GRANTS on a purchase is not this file's business and
-- a require in that direction would be a cycle.
local granted = Instance.new("BindableEvent")
PassService.Granted = granted.Event

-- [player][passKey] = true/false. Absent means "not asked yet, or the ask
-- failed" -- see the note above about why that is not false.
local cache: { [Player]: { [string]: boolean } } = {}

local function passOf(key: string): any
	return Config.PASSES and Config.PASSES[key]
end

-- Whether a pass is REALLY owned. Never true while the id is unset, which is
-- what keeps the entry-ride grant from firing for everybody during
-- development -- see `unlocked` for the difference.
function PassService.owns(player: Player, key: string): boolean
	local pass = passOf(key)
	if not pass or pass.id == 0 then
		return false
	end
	local mine = cache[player]
	return mine ~= nil and mine[key] == true
end

-- Whether the content a pass gates is USABLE.
--
-- The same thing as `owns`, except that an unconfigured pass unlocks
-- everything instead of locking it. That default is deliberate and it is the
-- safer of the two: a pass id nobody has filled in yet would otherwise lock
-- content that no purchase on earth could reach, and there is no way to tell
-- that apart from the feature being broken. Shipping something free by
-- accident is a smaller failure than shipping something unreachable, and the
-- startup warning below is what stops it being a silent one.
function PassService.unlocked(player: Player, key: string): boolean
	local pass = passOf(key)
	if not pass then
		return false
	end
	if pass.id == 0 then
		return true
	end
	return PassService.owns(player, key)
end

-- The id the client needs in order to open the purchase prompt, or nil while
-- there is nothing to open.
function PassService.idOf(key: string): number?
	local pass = passOf(key)
	if not pass or pass.id == 0 then
		return nil
	end
	return pass.id
end

local function remember(player: Player, key: string, value: boolean)
	local mine = cache[player]
	if not mine then
		mine = {}
		cache[player] = mine
	end
	local was = mine[key]
	mine[key] = value
	if value and was ~= true then
		granted:Fire(player, key)
	end
end

local function ask(player: Player, key: string)
	local pass = passOf(key)
	if not pass or pass.id == 0 then
		return
	end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
	end)
	if not ok then
		-- Left absent on purpose. See the header.
		warn(("[PassService] could not check '%s' for %s: %s"):format(
			key, player.Name, tostring(result)))
		return
	end
	remember(player, key, result == true)
end

function PassService.onPlayerReady(player: Player)
	for key in pairs(Config.PASSES or {}) do
		task.spawn(ask, player, key)
	end
end

function PassService.start()
	-- Says out loud when a paid thing is reachable for nothing.
	--
	-- Without this the id being 0 is invisible from inside the game: every
	-- player simply has the content, which is exactly what it looks like when
	-- the feature is working. The one place that could notice is here.
	for key, pass in pairs(Config.PASSES or {}) do
		if pass.id == 0 then
			warn(("[PassService] '%s' has no game pass id, so everything it "
				.. "gates is FREE. Create the pass in the Creator Dashboard "
				.. "and put its id in Config.PASSES.%s.id."):format(key, key))
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if not purchased then
				return
			end
			for key, pass in pairs(Config.PASSES or {}) do
				if pass.id == passId then
					-- Recorded from the event rather than re-asked. The web
					-- call can lag a purchase by a second or two, and the one
					-- moment a player is definitely looking at the screen is
					-- the moment they just paid.
					remember(player, key, true)
				end
			end
		end)

	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
end

return PassService
