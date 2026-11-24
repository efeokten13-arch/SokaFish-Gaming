--!strict
-- Ganimet zarları: sandık ve enkaz ödüllerini seçer, oyuncuya verir.
-- Ödül formatı: { id = "Pearl", amount = 4, tier = "Purple" }  (Config/Items)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Treasure = require(Config:WaitForChild("Treasure"))
local DataService = require(script.Parent.Parent.Data.DataService)

export type Reward = { id: string, amount: number, tier: string }

local Loot = {}
local rng = Random.new()

local function pick(weights: { [string]: number }): string
	local total = 0
	for _, w in weights do
		total += w
	end
	local r = rng:NextNumber() * total
	for id, w in weights do
		r -= w
		if r <= 0 then
			return id
		end
	end
	return next(weights) :: string
end

-- İnci: küçük sayılar sık, büyükler nadir (r^2 dağılımı)
local function pearlAmount(min: number, max: number): number
	return min + math.floor((max - min + 1) * rng:NextNumber() ^ 2)
end

local function amountFor(id: string, cfg: any, chestTier: string?): number
	if id == "Gold" then
		local t = (Treasure.Tiers :: any)[chestTier or "Small"] or Treasure.Tiers.Small
		return rng:NextInteger(t.min, t.max)
	elseif id == "Pearl" then
		return math.min(pearlAmount(cfg.Pearl.min, cfg.Pearl.max), cfg.Pearl.max)
	end
	local r = cfg[id]
	return rng:NextInteger(r.min, r.max)
end

local function tierFor(id: string, amount: number): string
	if id == "Pearl" and amount >= Items.BigPearlAt then
		return "Yellow"
	end
	return (Items.Defs :: any)[id].tier
end

-- kind: "chest" | "wreck"; chestTier: sandığın Tier attribute'u (Small/Medium/Large)
function Loot.Roll(kind: string, chestTier: string?): ({ Reward }, string)
	local cfg: any = if kind == "wreck" then Items.Wreck else Items.Chest
	local weights = if kind == "wreck" then cfg.Weights else (cfg.Weights[chestTier or "Small"] or cfg.Weights.Small)
	local out: { Reward } = {}
	local top = "Green"
	for _ = 1, cfg.Rewards do
		local id = pick(weights)
		local amount = amountFor(id, cfg, chestTier)
		local tier = tierFor(id, amount)
		table.insert(out, { id = id, amount = amount, tier = tier })
		if Items.TierRank(tier) > Items.TierRank(top) then
			top = tier
		end
	end
	-- en nadir ödül en sona: animasyonda en son o açılır
	table.sort(out, function(a, b)
		return Items.TierRank(a.tier) < Items.TierRank(b.tier)
	end)
	return out, top
end

function Loot.Grant(player: Player, rewards: { Reward })
	for _, r in rewards do
		local def = (Items.Defs :: any)[r.id]
		if def and def.field then
			DataService.Give(player, def.field, r.amount)
		elseif def and def.flag then
			local data = DataService.Get(player) :: any
			if data then
				data[def.flag] = true
			end
		end
	end
end

-- Deniz kızı görevi sürerken sandıkta kolye: her açılışta %50, en geç 3. sandıkta kesin.
-- Çıkarsa en sıradan ödülün yerine geçer (sarı = en nadir, en sona). Yeni "top" tier'ı döndürür.
function Loot.QuestNecklace(player: Player, rewards: { Reward }, top: string): string
	local data = DataService.Get(player) :: any
	if not data or data.mermaidQuest ~= 1 or data.hasNecklace or table.find(data.mqGiven or {}, "necklace") then
		return top
	end
	local cfg = Items.Mermaid
	data.necklaceTries = (data.necklaceTries or 0) + 1
	if data.necklaceTries < cfg.NecklaceGuaranteeAt and rng:NextNumber() > cfg.NecklaceChance then
		return top
	end
	table.remove(rewards, 1)
	table.insert(rewards, { id = "Necklace", amount = 1, tier = "Yellow" })
	return "Yellow"
end

-- Nadir balık tutunca inci şansı. Verilen miktarı döndürür (0 = yok). Push çağıran yapar.
function Loot.FishPearls(player: Player, rarity: string): number
	local c = (Items.FishPearls :: any)[rarity]
	if not c or rng:NextNumber() > c.chance then
		return 0
	end
	local n = rng:NextInteger(c.min, c.max)
	DataService.Give(player, "pearls", n)
	return n
end

return Loot
