--!strict
-- Nadirlik seviyeleri.
-- weight: çıkma ağırlığı (yüksek = daha sık)
-- barSpeed: reeling bar'ın hızı (yüksek = daha zor)
-- targetSize: bar'daki hedef alanın genişliği, 0-1 arası (küçük = daha zor)
-- luckPow: şans bu nadirliği ne kadar büyütür (ağırlık × şans^luckPow). Nadir olan daha çok büyür,
--   böylece iyi olta / bulut altı gerçekten Legendary şansını yükseltir.
--   Yaklaşık Legendary şansı: şans 1 → %1.5 · şans 2.5 (en iyi olta) → %3 · şans 10 (olta + bulut) → %8 · şans 24 (her şey) → %14

local Rarities = {
	Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary" },

	Common = { weight = 60, luckPow = 0, barSpeed = 1.0, targetSize = 0.30, color = Color3.fromRGB(200, 200, 200) },
	Uncommon = { weight = 25, luckPow = 0.25, barSpeed = 1.3, targetSize = 0.25, color = Color3.fromRGB(90, 200, 90) },
	Rare = { weight = 10, luckPow = 0.5, barSpeed = 1.7, targetSize = 0.20, color = Color3.fromRGB(70, 140, 255) },
	Epic = { weight = 5, luckPow = 0.75, barSpeed = 2.2, targetSize = 0.15, color = Color3.fromRGB(170, 80, 255) },
	Legendary = { weight = 1.5, luckPow = 1.0, barSpeed = 3.0, targetSize = 0.10, color = Color3.fromRGB(255, 190, 40) },
}

return Rarities
