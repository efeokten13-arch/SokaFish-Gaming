--!strict
-- Nadirlik seviyeleri.
-- weight: çıkma ağırlığı (yüksek = daha sık)
-- barSpeed: reeling bar'ın hızı (yüksek = daha zor)
-- targetSize: bar'daki hedef alanın genişliği, 0-1 arası (küçük = daha zor)

local Rarities = {
	Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary" },

	Common = { weight = 60, barSpeed = 1.0, targetSize = 0.30, color = Color3.fromRGB(200, 200, 200) },
	Uncommon = { weight = 25, barSpeed = 1.3, targetSize = 0.25, color = Color3.fromRGB(90, 200, 90) },
	Rare = { weight = 10, barSpeed = 1.7, targetSize = 0.20, color = Color3.fromRGB(70, 140, 255) },
	Epic = { weight = 4, barSpeed = 2.2, targetSize = 0.15, color = Color3.fromRGB(170, 80, 255) },
	Legendary = { weight = 1, barSpeed = 3.0, targetSize = 0.10, color = Color3.fromRGB(255, 190, 40) },
}

return Rarities
