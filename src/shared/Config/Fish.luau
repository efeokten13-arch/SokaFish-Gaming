--!strict
-- Tüm balıklar burada. Yeni balık = yeni satır.
-- sell: Main Hall'da satış fiyatı
-- perHour: havuzda tutulunca saatlik gelir
-- ocean: hangi okyanusta çıkar
-- spots: hangi fishing spot türlerinde çıkar ("Near", "Mid", "Far")
-- Sayılar taslak, playtest'ten sonra ayarlanacak.

export type FishDef = {
	displayName: string,
	rarity: string,
	sell: number,
	perHour: number,
	ocean: string,
	spots: { string },
}

local Fish: { [string]: FishDef } = {
	Cod = {
		displayName = "Cod",
		rarity = "Common",
		sell = 5,
		perHour = 1,
		ocean = "Warm",
		spots = { "Near", "Mid", "Far" },
	},
	Mackerel = {
		displayName = "Mackerel",
		rarity = "Common",
		sell = 8,
		perHour = 2,
		ocean = "Warm",
		spots = { "Near", "Mid" },
	},
	SeaBass = {
		displayName = "Sea Bass",
		rarity = "Uncommon",
		sell = 25,
		perHour = 6,
		ocean = "Warm",
		spots = { "Mid", "Far" },
	},
	Pufferfish = {
		displayName = "Pufferfish",
		rarity = "Rare",
		sell = 90,
		perHour = 25,
		ocean = "Warm",
		spots = { "Mid", "Far" },
	},
	Swordfish = {
		displayName = "Swordfish",
		rarity = "Epic",
		sell = 400,
		perHour = 120,
		ocean = "Warm",
		spots = { "Far" },
	},
	GoldenMarlin = {
		displayName = "Golden Marlin",
		rarity = "Legendary",
		sell = 2500,
		perHour = 800,
		ocean = "Warm",
		spots = { "Far" },
	},
}

return Fish
