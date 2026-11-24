--!strict
-- Eşyalar, inci (2. para birimi) ve ganimet tabloları.
-- Sayıları buradan değiştir; kod dokunmadan çalışır.
--
-- Nadirlik renkleri (sandık ışığı ve ödül kartları en nadir ödülün rengini alır):
--   Green  = altın / tahta      Blue = metal
--   Purple = inci               Yellow = büyük inci (BigPearlAt ve üstü) veya özel eşya

local Items = {}

Items.TierOrder = { "Green", "Blue", "Purple", "Yellow" }
Items.TierColors = {
	Green = Color3.fromRGB(80, 215, 100),
	Blue = Color3.fromRGB(70, 150, 255),
	Purple = Color3.fromRGB(175, 85, 255),
	Yellow = Color3.fromRGB(255, 200, 45),
}
Items.TierNames = { Green = "Common", Blue = "Rare", Purple = "Epic", Yellow = "Legendary" }

-- icon: Roblox yeni emojileri (🪵 🪙) göstermiyor, eskileri kullan
-- field = oyuncu verisindeki alan adı (data.money, data.pearls, data.wood, data.metal)
Items.Defs = {
	Gold = { name = "Gold", icon = "💰", field = "money", tier = "Green" },
	Wood = { name = "Wood", icon = "🌲", field = "wood", tier = "Green" },
	Metal = { name = "Metal", icon = "🔩", field = "metal", tier = "Blue" },
	Pearl = { name = "Pearls", icon = "🦪", field = "pearls", tier = "Purple" },
	-- görev eşyası (sayı değil): Marina'nın kayıp kolyesi. Sadece deniz kızı görevi sürerken sandıktan çıkar
	Necklace = { name = "Diamond Necklace", icon = "💎", flag = "hasNecklace", tier = "Yellow", quest = true },
}

Items.BigPearlAt = 7 -- bu kadar ve üstü inci = sarı (Legendary)

-- Sandık: her açılışta Rewards kadar ödül; her ödül ağırlığa göre seçilir.
-- Miktarlar: Gold sandığın Tier'ına göre (Config/Treasure.Tiers min/max), diğerleri min..max.
-- İnci her zaman 1..10 (küçük sayılar daha sık; 7+ nadir).
Items.Chest = {
	Rewards = 3,
	Weights = {
		Small = { Gold = 45, Wood = 30, Metal = 17, Pearl = 8 },
		Medium = { Gold = 35, Wood = 28, Metal = 24, Pearl = 13 },
		Large = { Gold = 25, Wood = 25, Metal = 28, Pearl = 22 },
	},
	Wood = { min = 3, max = 8 },
	Metal = { min = 1, max = 4 },
	Pearl = { min = 1, max = 10 },
}

-- Batık gemi enkazı (gemilerin yanında yüzen sandık + tahtalar): tahta ve metal, bazen inci
Items.Wreck = {
	Rewards = 2,
	CooldownMinutes = 10, -- her oyuncu her enkazı bu kadar dakikada bir toplayabilir
	Weights = { Wood = 50, Metal = 38, Pearl = 12 },
	Wood = { min = 4, max = 10 },
	Metal = { min = 2, max = 5 },
	Pearl = { min = 1, max = 3 },
}

-- Nadir balık tutunca düşük ihtimalle inci
Items.FishPearls = {
	Rare = { chance = 0.03, min = 1, max = 1 },
	Epic = { chance = 0.08, min = 1, max = 2 },
	Legendary = { chance = 0.25, min = 1, max = 3 },
}

-- Balık fedası (2. ada, Temple Keeper): Epic balık ver -> sonraki tuttuğun balık Golden Fish
Items.Altar = {
	Rarity = "Epic", -- feda edilebilen nadirlik (çantadaki en ucuzu alınır)
	RewardFish = "GoldenFish", -- kutsamanın garanti ettiği balık (Config/Fish)
	BlessAt = 6.2, -- sahnede altın ışığın oyuncuya indiği an (sn) -> parıltı başlar
	Duration = 8.5, -- sahnenin toplam süresi (sn) -> veri gönderilir
}

-- Deniz kızı Marina'nın görevi (2. ada): 3 eşyayı istediğin sırada, tek tek ya da hepsini birden götür -> kale kapısı anahtarı
Items.Mermaid = {
	NecklaceChance = 0.5, -- görev sürerken her sandık açılışında kolye ihtimali
	NecklaceGuaranteeAt = 3, -- en geç bu kadarıncı sandıkta kesin çıkar
	QuestFish = "GoldenFish", -- istenen balık (çantada olmalı; havuzdaki sayılmaz)
}

function Items.TierRank(tier: string): number
	return table.find(Items.TierOrder, tier) or 1
end

return Items
