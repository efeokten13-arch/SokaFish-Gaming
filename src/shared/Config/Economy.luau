--!strict
-- Genel ekonomi ayarları. Game pass / boost'lar ileride buraya bağlanır.

local Economy = {
	StartingMoney = 10, -- ilk kayığı ($1) hemen alabilsin

	-- Havuz
	PoolCapacity = 5, -- ada başına havuzdaki maksimum balık
	OfflineEarningsCapHours = 8, -- offline gelir en fazla kaç saatlik birikir

	-- Oltalar (ana adadaki Rod Shop'ta satılır)
	-- luck = şans çarpanı, length = elde görünen boy (stud), order = dükkân sırası
	-- 3D model: ReplicatedStorage.Assets.Rods.<id> (place dosyasında). Yoksa look renkleriyle basit olta çizilir.
	StarterRod = "BranchRod",
	RodOrder = { "BranchRod", "BambooRod", "ApprenticeRod", "IronRod", "CoralRod", "WreckRod", "SharkRod" },
	RarityColors = {
		Common = Color3.fromRGB(200, 200, 200),
		Uncommon = Color3.fromRGB(110, 220, 120),
		Rare = Color3.fromRGB(80, 160, 255),
		Epic = Color3.fromRGB(190, 110, 255),
		Legendary = Color3.fromRGB(255, 190, 50),
		Mythic = Color3.fromRGB(255, 80, 90),
	},
	Rods = {
		BranchRod = {
			displayName = "Branch Rod", rarity = "Common", price = 0, luck = 1.0, length = 5, order = 1,
			look = { shaft = Color3.fromRGB(120, 84, 50), handle = Color3.fromRGB(190, 160, 110), reel = Color3.fromRGB(120, 84, 50) },
		},
		BambooRod = {
			displayName = "Old Bamboo Rod", rarity = "Common", price = 150, luck = 1.15, length = 5.3, order = 2,
			look = { shaft = Color3.fromRGB(205, 180, 110), handle = Color3.fromRGB(150, 120, 90), reel = Color3.fromRGB(140, 100, 60) },
		},
		ApprenticeRod = {
			displayName = "Pirate Apprentice Rod", rarity = "Uncommon", price = 600, luck = 1.3, length = 5.6, order = 3,
			look = { shaft = Color3.fromRGB(90, 55, 35), handle = Color3.fromRGB(170, 140, 90), reel = Color3.fromRGB(200, 160, 70) },
		},
		IronRod = {
			displayName = "Iron-Riveted Rod", rarity = "Rare", price = 2000, luck = 1.5, length = 5.9, order = 4,
			look = { shaft = Color3.fromRGB(140, 100, 60), handle = Color3.fromRGB(70, 70, 75), reel = Color3.fromRGB(60, 60, 65) },
		},
		CoralRod = {
			displayName = "Coral Grip Rod", rarity = "Epic", price = 6000, luck = 1.75, length = 6.2, order = 5,
			look = { shaft = Color3.fromRGB(245, 240, 235), handle = Color3.fromRGB(255, 130, 170), reel = Color3.fromRGB(80, 220, 210) },
		},
		WreckRod = {
			displayName = "Shipwreck Rod", rarity = "Legendary", price = 15000, luck = 2.0, length = 6.5, order = 6,
			look = { shaft = Color3.fromRGB(90, 110, 70), handle = Color3.fromRGB(110, 70, 45), reel = Color3.fromRGB(150, 90, 50) },
		},
		SharkRod = {
			displayName = "Shark Tooth Rod", rarity = "Mythic", price = 40000, luck = 2.5, length = 7, order = 7,
			look = { shaft = Color3.fromRGB(240, 235, 220), handle = Color3.fromRGB(220, 210, 190), reel = Color3.fromRGB(200, 195, 180) },
		},
	},
	Baits = {
		BasicBait = { displayName = "Basic Bait", price = 0, luck = 1.0 },
		ShrimpBait = { displayName = "Shrimp Bait", price = 150, luck = 1.2 },
		GlowBait = { displayName = "Glow Bait", price = 1500, luck = 1.6 },
	},

	-- Spot'ların şans çarpanı (uzak = daha iyi balık)
	SpotLuck = { Near = 1.0, Mid = 1.2, Far = 1.5 },

	PoolTickSeconds = 10, -- havuz geliri bu aralıkla eklenir (saniye)

	-- Kayıt
	AutosaveSeconds = 60,
}

return Economy
