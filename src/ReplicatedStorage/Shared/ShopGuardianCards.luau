--!strict
-- Native guardian renders: assets/guards/<rig>/shop-cards/<coat>.png.
-- Source models, palettes, hashes and upload IDs: assets/shop-ui/guardian-images.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Presentation = require(ReplicatedStorage.Shared.ShopImageCards)
local ShopStyle = require(ReplicatedStorage.Shared.ShopStyle)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Widgets = require(ReplicatedStorage.Shared.ShopWidgets)
local Cards = {}
-- ONE CARD PER ROW OF `Config.DOG_COATS`, AND FIVE CAME OUT ON 2026-09-23.
--
-- Chocolate, Golden Boy, Spotless Dalmatian, Shadow and Glacier were five
-- colours of the SHEPHERD body, retired when the catalogue went to one coat
-- per rig (designer: "get rid of all the different colour dogs that are the
-- same model"). Their renders are still uploaded and are NOT lost by coming
-- out of here -- every id is recorded twice in the repo, in
-- `assets/shop-ui/guardian-images/roblox-uploads.json` and in that folder's
-- `manifest.json` beside its hash and palette -- which is the distinction
-- `docs/ORPHANED-UPLOADS.md` exists for: an id with no other record.
--
-- WHAT THEY MAY NOT DO IS STAY HERE. This table is what the shop points at,
-- so a row for a coat the catalogue no longer holds is art for something
-- nobody can buy, and the next person to read it learns a wrong catalogue.
-- BEGIN GUARDIAN IMAGE IDS
Cards.images = {
	terrier = "rbxassetid://126143860962341",
	husky = "rbxassetid://117441561046801",
	mastiff = "rbxassetid://79883493152667",
	gorilla = "rbxassetid://75445866786877",
	raptor = "rbxassetid://139324732339969",
	triceratops = "rbxassetid://109345948759219",
	direwolf = "rbxassetid://110670035166700",
	cerberus = "rbxassetid://112271849554979",
} :: { [string]: string }
-- END GUARDIAN IMAGE IDS

function Cards.image(parent: GuiObject, id: string): ImageLabel?
	return Presentation.image(parent, "Guardian", id, Cards.images[id])
end

function Cards.decorate(entry: any, id: string)
	Presentation.decorate(entry, "Guardian", id)
end

-- THE REBIRTH GATE IS THE SHOP'S SHARED ONE, `ShopWidgets.gate`.
--
-- WHAT STOOD HERE, AND WHY BOTH HALVES OF IT ARE GONE. It read: the gate goes
-- ON THE PILL, "REBIRTH 4" AND NOT THE PRICE, because "a price on a card the
-- server will refuse is the silent-failure rule wearing a button" -- and
-- `Locked` was read by the Activated handler in ClientMain, "which declines
-- to fire a request it knows the server will refuse".
--
-- The designer's call is that a gated item still SHOWS its price, under a
-- wash, so the shelf gives a reason to press the rebirth button; and the
-- handler no longer declines, because the SERVER's refusal is the one thing
-- a player pressing a gated card actually needs -- it names the rebirth.
-- `buyDogCoat` refuses above the price, so nothing is spent.
--
-- The houses, the rides and the guardians all carry a rebirth ladder, so the
-- wash, the padlock, the "Rebirth N required" line, the `Locked` attribute
-- and the open-items-first `LayoutOrder` are ONE expression rather than
-- three -- three shelves each deciding what "gated" looks like is three
-- things that can disagree. It returns whether the card ended up locked.
--
-- THE PILL KEEPS ITS PRICE UNDER THE WASH, which is the designer's rule and
-- the reason this no longer paints "REBIRTH 4" over it: a gated item still
-- SHOWS, with what it will cost readable underneath, and `W.gate` raises the
-- pill above the sheet so it stays legible.
--
-- NIL-GUARDED, AND THE FALLBACK IS THIS FILE'S OWN PILL. Both halves of this
-- landed in the same session from two directions, so the guard is what keeps
-- a guardian card correct whichever order they merge in -- and the fallback
-- is the vocabulary the card shipped in, not a blank.
local function applyGate(entry: any, info: any): boolean
	local shared = (Widgets :: any).gate
	if type(shared) == "function" then
		return shared(entry, info) == true
	end
	local locked = info.locked == true and info.owned ~= true
	entry.button:SetAttribute("Locked", locked)
	if locked then
		entry.sub.Text = ("REBIRTH %d"):format(info.unlockRebirths or 0)
		entry.sub.BackgroundColor3 = ShopStyle.LOCKED
		entry.sub.TextColor3 = Theme.INK
	end
	return locked
end

-- A COAT REACHES A PLAYER THREE WAYS NOW, AND THE PILL IS WHERE THE CARD
-- SAYS WHICH (designer, 2026-09-23).
--
--   FREE       Scrappy. Owned by everybody from their first second, so the
--              card has no price and no lock -- ever, on any save.
--   PRICED     Shadow and the Mastiff, behind their rebirth. The pill is
--              the coin price, or the rebirth that opens the sale.
--   FROM CRATE everything else. There is no coin price at all, so the pill
--              names the ROUTE and the rarity border does the selling --
--              the same call the drop-pool skins made when their price row
--              became "REBIRTH DROP" rather than a gold `0`.
--
-- A `0` IS THE FAILURE THIS BRANCH EXISTS TO PREVENT, and it is on record:
-- ten drop-pool skins rendered "0" in gold on the you-can-afford-this
-- green, and tapping them did nothing because the server correctly refused.
-- ClientMain's loop writes `format(info.cost)` before this runs, so the
-- overwrite HERE is what keeps that out of the shop -- one call site rather
-- than a branch in the render loop.
function Cards.paint(entry: any, info: any, coins: number)
	local fromCrate = info.fromCrate == true
	-- `forSale` FALSE FOR ANYTHING WITHOUT A COIN PRICE, which is what stops
	-- the too-dear muting landing on a card that has no price to be short of:
	-- `ShopImageCards.paint` mutes when `coins < (cost or huge)`, and both a
	-- crate coat and a free one push a cost of 0.
	Presentation.paint(entry, {
		rarity = info.rarity, current = info.equipped, owned = info.owned,
		forSale = not fromCrate and info.free ~= true, cost = info.cost,
	}, coins)
	-- THE GATE FIRST, THE ROUTE SECOND, and that order is what keeps a stale
	-- push honest: a crate coat carries no gate, so `info.locked` is false and
	-- the wash never appears -- but if one ever arrives locked, the wash is
	-- drawn and the pill still names the crate rather than a price the card
	-- does not have.
	applyGate(entry, info)
	if fromCrate and info.owned ~= true then
		entry.sub.Text = "FROM CRATE"
	end
end

return Cards
