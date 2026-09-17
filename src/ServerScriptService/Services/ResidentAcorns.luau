--!strict
-- One stock record per residential plot for this server's lifetime. It stays
-- alive while a player occupies the plot, so reseating cannot mint another seed
-- and an older carry receipt can still refund the same resident stock.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local ResidentAcorns = {}
export type Stock = {
	acorns: number, treeAcorns: number, groundAcorns: number,
	acornsGrownAt: number, acornsDroppedAt: number,
	harvestReadyAt: number, collectingUntil: number,
	pausedAt: number?,
}
local stocks: { [number]: Stock } = {}

function ResidentAcorns.attach(index: number, shop: boolean, now: number): Stock?
	if shop then return nil end
	local stock = stocks[index]
	if not stock then
		stock = {
			acorns = Config.ACORNS.resident.seedStored,
			treeAcorns = Config.ACORNS.resident.seedRipe,
			groundAcorns = 0, acornsGrownAt = now, acornsDroppedAt = 0,
			harvestReadyAt = now + Config.ACORNS.resident.harvestSeconds,
			collectingUntil = 0,
		}
		stocks[index] = stock
	elseif stock.pausedAt then
		-- No second tree grows underneath the player's own tree. Preserve the
		-- resident's partial growth hour and time left before harvesting.
		local paused = math.max(0, now - stock.pausedAt)
		stock.acornsGrownAt += paused
		stock.harvestReadyAt += paused
		stock.pausedAt = nil
	end
	-- Loose-ground expiry follows real elapsed time, even during player
	-- occupancy. Only production/harvesting is suspended.
	Config.expireGroundAcorns(stock, now)
	return stock
end

function ResidentAcorns.suspend(index: number, now: number)
	local stock = stocks[index]
	if stock and not stock.pausedAt then stock.pausedAt = now end
end

function ResidentAcorns.tick(stock: Stock, now: number, atHome: boolean): boolean
	if stock.pausedAt then return false end
	local changed = Config.expireGroundAcorns(stock, now)
	local before = stock.treeAcorns
	local grown = Config.growAcorns(stock, now)
	if grown > 0 then
		changed = true
		if before == 0 then stock.harvestReadyAt = now + Config.ACORNS.resident.harvestSeconds end
	end
	-- Leave each new crop on the tree for at least fifteen minutes. Residents
	-- bank it only while home, and never move stock out of an active round.
	if atHome and stock.treeAcorns > 0 and stock.groundAcorns == 0
		and now >= stock.harvestReadyAt and now >= stock.collectingUntil then
		stock.acorns += stock.treeAcorns
		stock.treeAcorns = 0
		changed = true
	end
	return changed
end

return ResidentAcorns
