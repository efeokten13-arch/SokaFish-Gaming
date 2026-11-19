--!strict
-- Genel ekonomi ayarları. Game pass / boost'lar ileride buraya bağlanır.

local Economy = {
	StartingMoney = 0,

	-- Havuz
	PoolCapacity = 6, -- ada başına havuzdaki maksimum balık
	OfflineEarningsCapHours = 8, -- offline gelir en fazla kaç saatlik birikir

	-- Oltalar: luck = şans çarpanı, look = 3D model renkleri (RodModelBuilder kullanır)
	Rods = {
		BasicRod = {
			displayName = "Basic Rod",
			price = 0,
			luck = 1.0,
			look = {
				shaft = Color3.fromRGB(160, 115, 70),
				handle = Color3.fromRGB(85, 58, 35),
				reel = Color3.fromRGB(130, 130, 130),
			},
		},
		CarbonRod = {
			displayName = "Carbon Rod",
			price = 300,
			luck = 1.3,
			look = {
				shaft = Color3.fromRGB(40, 40, 46),
				handle = Color3.fromRGB(200, 60, 50),
				reel = Color3.fromRGB(185, 185, 195),
				reflect = 0.15,
			},
		},
		MasterRod = {
			displayName = "Master Rod",
			price = 3000,
			luck = 1.8,
			look = {
				shaft = Color3.fromRGB(232, 180, 40),
				handle = Color3.fromRGB(45, 32, 65),
				reel = Color3.fromRGB(245, 225, 150),
				reflect = 0.3,
			},
		},
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
