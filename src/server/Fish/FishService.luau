--!strict
-- Balık seçimi (sunucuda). Hangi balığın çıkacağına sadece burası karar verir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")

local Fish = require(Config:WaitForChild("Fish"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Economy = require(Config:WaitForChild("Economy"))

local FishService = {}

local rng = Random.new()

-- Bu okyanus + spot'ta çıkabilecek balıkları nadirliğe göre grupla
local function fishPool(ocean: string, spot: string): { [string]: { string } }
	local byRarity: { [string]: { string } } = {}
	for id, def in Fish do
		if def.ocean == ocean and table.find(def.spots, spot) then
			byRarity[def.rarity] = byRarity[def.rarity] or {}
			table.insert(byRarity[def.rarity], id)
		end
	end
	return byRarity
end

-- Önce nadirlik seç (luck Common dışındakileri büyütür), sonra o nadirlikten rastgele balık
function FishService.Roll(ocean: string, spot: string, luck: number): string?
	local byRarity = fishPool(ocean, spot)

	local total = 0
	local weights: { { rarity: string, w: number } } = {}
	for _, rarity in Rarities.Order do
		if byRarity[rarity] then
			local base = (Rarities :: any)[rarity].weight :: number
			local w = if rarity == "Common" then base else base * luck
			table.insert(weights, { rarity = rarity, w = w })
			total += w
		end
	end
	if total == 0 then
		return nil
	end

	local pick = rng:NextNumber(0, total)
	for _, entry in weights do
		pick -= entry.w
		if pick <= 0 then
			local list = byRarity[entry.rarity]
			return list[rng:NextInteger(1, #list)]
		end
	end
	return nil
end

-- Oyuncunun toplam şansı = olta * yem * spot
function FishService.GetLuck(rodId: string, baitId: string, spot: string): number
	local rod = Economy.Rods[rodId]
	local bait = Economy.Baits[baitId]
	local spotLuck = (Economy.SpotLuck :: any)[spot] or 1
	return (rod and rod.luck or 1) * (bait and bait.luck or 1) * spotLuck
end

return FishService
