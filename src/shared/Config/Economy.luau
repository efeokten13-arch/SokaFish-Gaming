--!strict
-- Genel ekonomi ayarları. Game pass / boost'lar ileride buraya bağlanır.

local Economy = {
	StartingMoney = 0,

	-- Havuz
	PoolCapacity = 6, -- ada başına havuzdaki maksimum balık
	OfflineEarningsCapHours = 8, -- offline gelir en fazla kaç saatlik birikir

	-- Olta / yem şans çarpanları (Common dışındaki nadirliklerin ağırlığını büyütür)
	Rods = {
		BasicRod = { displayName = "Basic Rod", price = 0, luck = 1.0 },
		CarbonRod = { displayName = "Carbon Rod", price = 300, luck = 1.3 },
		MasterRod = { displayName = "Master Rod", price = 3000, luck = 1.8 },
	},
	Baits = {
		BasicBait = { displayName = "Basic Bait", price = 0, luck = 1.0 },
		ShrimpBait = { displayName = "Shrimp Bait", price = 150, luck = 1.2 },
		GlowBait = { displayName = "Glow Bait", price = 1500, luck = 1.6 },
	},

	-- Spot'ların şans çarpanı (uzak = daha iyi balık)
	SpotLuck = { Near = 1.0, Mid = 1.2, Far = 1.5 },

	-- Kayıt
	AutosaveSeconds = 60,
}

return Economy
