--!strict
-- Tüm balıklar burada. Yeni balık = yeni satır.
-- sell: Main Hall'da satış fiyatı
-- perMinute: havuzda tutulunca dakikalık gelir
-- ocean: hangi okyanusta çıkar
-- spots: hangi fishing spot türlerinde çıkar ("Near", "Mid", "Far")
-- look: 3D model görünümü (FishModelBuilder kullanır)
--   shape: "Slim" | "Normal" | "Round" | "Long"
--   length: stud cinsinden boy
--   body / belly / fin: renkler
--   extras: { "Bill" (kılıç burun), "Sail" (yelken sırt yüzgeci), "Spikes" (diken) }
--   reflect: 0-1 parlaklık (opsiyonel)
-- Sayılar taslak, playtest'ten sonra ayarlanacak.

export type FishLook = {
	shape: string,
	length: number,
	body: Color3,
	belly: Color3,
	fin: Color3,
	extras: { string }?,
	reflect: number?,
}

export type FishDef = {
	displayName: string,
	rarity: string,
	sell: number,
	perMinute: number,
	ocean: string,
	spots: { string },
	look: FishLook,
}

local Fish: { [string]: FishDef } = {
	Cod = {
		displayName = "Cod",
		rarity = "Common",
		sell = 5,
		perMinute = 1,
		ocean = "Warm",
		spots = { "Near", "Mid", "Far" },
		look = {
			shape = "Normal",
			length = 2.2,
			body = Color3.fromRGB(125, 112, 80),
			belly = Color3.fromRGB(225, 218, 195),
			fin = Color3.fromRGB(100, 88, 62),
		},
	},
	Mackerel = {
		displayName = "Mackerel",
		rarity = "Common",
		sell = 8,
		perMinute = 2,
		ocean = "Warm",
		spots = { "Near", "Mid" },
		look = {
			shape = "Slim",
			length = 2.0,
			body = Color3.fromRGB(40, 112, 122),
			belly = Color3.fromRGB(215, 225, 230),
			fin = Color3.fromRGB(30, 80, 90),
			reflect = 0.15,
		},
	},
	SeaBass = {
		displayName = "Sea Bass",
		rarity = "Uncommon",
		sell = 25,
		perMinute = 6,
		ocean = "Warm",
		spots = { "Mid", "Far" },
		look = {
			shape = "Normal",
			length = 2.7,
			body = Color3.fromRGB(110, 122, 128),
			belly = Color3.fromRGB(232, 232, 232),
			fin = Color3.fromRGB(78, 88, 95),
			reflect = 0.1,
		},
	},
	Pufferfish = {
		displayName = "Pufferfish",
		rarity = "Rare",
		sell = 90,
		perMinute = 25,
		ocean = "Warm",
		spots = { "Mid", "Far" },
		look = {
			shape = "Round",
			length = 1.7,
			body = Color3.fromRGB(222, 190, 90),
			belly = Color3.fromRGB(248, 238, 205),
			fin = Color3.fromRGB(200, 155, 55),
			extras = { "Spikes" },
		},
	},
	Swordfish = {
		displayName = "Swordfish",
		rarity = "Epic",
		sell = 400,
		perMinute = 120,
		ocean = "Warm",
		spots = { "Far" },
		look = {
			shape = "Long",
			length = 4.5,
			body = Color3.fromRGB(40, 60, 105),
			belly = Color3.fromRGB(195, 205, 220),
			fin = Color3.fromRGB(30, 45, 80),
			extras = { "Bill" },
			reflect = 0.15,
		},
	},
	GoldenMarlin = {
		displayName = "Golden Marlin",
		rarity = "Legendary",
		sell = 2500,
		perMinute = 800,
		ocean = "Warm",
		spots = { "Far" },
		look = {
			shape = "Long",
			length = 5.0,
			body = Color3.fromRGB(232, 180, 40),
			belly = Color3.fromRGB(255, 232, 145),
			fin = Color3.fromRGB(205, 140, 20),
			extras = { "Bill", "Sail" },
			reflect = 0.35,
		},
	},
}

return Fish
