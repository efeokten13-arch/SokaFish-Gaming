--!strict
-- Tüm balıklar burada. Yeni balık = yeni satır. Sayılar taslak (Ege: "kafandan yaz, değiştiririz").
-- island: koleksiyon kitabında hangi ada sekmesinde görünür (1 = başlangıç denizi, 2 = Mermaid Island)
-- order: o adanın sayfasındaki sırası
-- sell: Fish Market satış fiyatı ($) · perMinute: havuzda tutulunca dakikalık gelir ($/dk)
-- ocean: hangi okyanusta çıkar · spots: "Near" | "Mid" | "Far" (açık denizde merkeze uzaklık)
-- retired = true: artık tutulamaz ve kitapta görünmez (eski kayıtlarda kalan balıklar için duruyor)
-- look: 3D model (shared/FishModelBuilder.luau). Alanlar:
--   kind: "fish" (varsayılan) | "puffer" | "lionfish" | "seahorse" | "ray" | "jelly" | "eel" | "octopus" | "squid" | "angler" | "billfish" | "shark"
--   length: boy (stud) · body / belly / fin: renkler · accent: desen / ikinci renk · eye: göz bebeği rengi
--   shape (kind "fish"): "Slim" | "Normal" | "Deep" | "Round" | "Torpedo"
--   tail: "fork" | "fan" | "lunate" · dorsal: "soft" | "spiny" | "sail" | "fancy"
--   pattern: "spots" | "speckle" | "bars" | "lines" | "bands" | "patches" | nil
--   extras: { "Beak", "Whiskers", "Finlets", "Hammer", "Pearl", "Teeth", "FinTips" } · bandsAt / bandEdge: bant yerleri ve kenar rengi
--   reflect: 0-1 parlaklık · metal: true = metal malzeme (altın balıklar) · glow: true = parlar (ışık + neon detaylar)

export type FishLook = {
	kind: string?,
	shape: string?,
	length: number,
	body: Color3,
	belly: Color3,
	fin: Color3,
	accent: Color3?,
	eye: Color3?,
	tail: string?,
	dorsal: string?,
	pattern: string?,
	extras: { string }?,
	reflect: number?,
	glow: boolean?,
	metal: boolean?,
	bandsAt: { number }?,
	bandEdge: Color3?,
}

export type FishDef = {
	displayName: string,
	rarity: string,
	sell: number,
	perMinute: number,
	ocean: string,
	island: number,
	order: number,
	spots: { string },
	retired: boolean?,
	look: FishLook,
}

local ALL = { "Near", "Mid", "Far" }
local MIDFAR = { "Mid", "Far" }
local FAR = { "Far" }
local C = Color3.fromRGB

local Fish: { [string]: FishDef } = {
	------------------------------------------------------------------------------------------
	-- 1. ada: başlangıç denizi (ocean "Warm")
	------------------------------------------------------------------------------------------
	Sardine = {
		displayName = "Sardine", rarity = "Common", sell = 4, perMinute = 1,
		ocean = "Warm", island = 1, order = 1, spots = ALL,
		look = { kind = "fish", shape = "Slim", length = 1.7, body = C(70, 120, 160), belly = C(230, 238, 245), fin = C(150, 175, 195),
			accent = C(40, 60, 90), tail = "fork", dorsal = "soft", pattern = "spots", reflect = 0.3 },
	},
	Cod = {
		displayName = "Cod", rarity = "Common", sell = 5, perMinute = 1,
		ocean = "Warm", island = 1, order = 2, spots = ALL,
		look = { kind = "fish", shape = "Normal", length = 2.3, body = C(128, 130, 82), belly = C(228, 226, 196), fin = C(105, 108, 66),
			accent = C(80, 82, 48), tail = "fan", dorsal = "soft", pattern = "speckle", extras = { "Whiskers" } },
	},
	Mackerel = {
		displayName = "Mackerel", rarity = "Common", sell = 8, perMinute = 2,
		ocean = "Warm", island = 1, order = 3, spots = ALL,
		look = { kind = "fish", shape = "Slim", length = 2.1, body = C(40, 128, 135), belly = C(222, 232, 236), fin = C(40, 95, 105),
			accent = C(20, 45, 60), tail = "fork", dorsal = "soft", pattern = "bars", reflect = 0.2 },
	},
	Clownfish = {
		displayName = "Clownfish", rarity = "Uncommon", sell = 18, perMinute = 4,
		ocean = "Warm", island = 1, order = 4, spots = ALL,
		look = { kind = "fish", shape = "Round", length = 1.7, body = C(255, 120, 20), belly = C(255, 150, 60), fin = C(255, 130, 30),
			accent = C(255, 255, 255), tail = "fan", dorsal = "soft", pattern = "bands", bandsAt = { -0.5, 0.0, 0.55 }, bandEdge = C(25, 25, 30) },
	},
	SeaBass = {
		displayName = "Sea Bass", rarity = "Uncommon", sell = 25, perMinute = 6,
		ocean = "Warm", island = 1, order = 5, spots = ALL,
		look = { kind = "fish", shape = "Normal", length = 2.8, body = C(96, 112, 92), belly = C(230, 232, 222), fin = C(70, 84, 70),
			accent = C(50, 62, 52), tail = "fork", dorsal = "spiny", pattern = "lines", reflect = 0.15 },
	},
	RedSnapper = {
		displayName = "Red Snapper", rarity = "Rare", sell = 60, perMinute = 14,
		ocean = "Warm", island = 1, order = 6, spots = MIDFAR,
		look = { kind = "fish", shape = "Deep", length = 2.6, body = C(232, 80, 80), belly = C(255, 196, 180), fin = C(215, 60, 70),
			accent = C(255, 150, 140), tail = "fork", dorsal = "spiny", eye = C(200, 30, 30), reflect = 0.1 },
	},
	Pufferfish = {
		displayName = "Pufferfish", rarity = "Rare", sell = 90, perMinute = 25,
		ocean = "Warm", island = 1, order = 7, spots = MIDFAR,
		look = { kind = "puffer", length = 1.9, body = C(214, 196, 110), belly = C(250, 242, 212), fin = C(190, 160, 70),
			accent = C(110, 90, 45) },
	},
	Jellyfish = {
		displayName = "Jellyfish", rarity = "Epic", sell = 350, perMinute = 100,
		ocean = "Warm", island = 1, order = 8, spots = FAR,
		look = { kind = "jelly", length = 2.3, body = C(225, 140, 255), belly = C(255, 170, 235), fin = C(200, 120, 255),
			accent = C(255, 210, 250), glow = true },
	},
	Squid = {
		displayName = "Squid", rarity = "Epic", sell = 500, perMinute = 140,
		ocean = "Warm", island = 1, order = 9, spots = FAR,
		look = { kind = "squid", length = 3.2, body = C(200, 70, 50), belly = C(240, 140, 110), fin = C(170, 50, 45),
			accent = C(120, 30, 40), glow = true },
	},
	ReefShark = {
		displayName = "Reef Shark", rarity = "Legendary", sell = 2500, perMinute = 800,
		ocean = "Warm", island = 1, order = 10, spots = FAR,
		look = { kind = "shark", length = 5.0, body = C(95, 120, 150), belly = C(238, 240, 244), fin = C(80, 105, 135),
			extras = { "Teeth", "FinTips" }, glow = true },
	},

	------------------------------------------------------------------------------------------
	-- 2. ada: Mermaid Island (ocean "Coral") — Ege'nin şablonu (23 Kasım)
	------------------------------------------------------------------------------------------
	Parrotfish = {
		displayName = "Parrotfish", rarity = "Common", sell = 14, perMinute = 3,
		ocean = "Coral", island = 2, order = 1, spots = ALL,
		look = { kind = "fish", shape = "Deep", length = 2.6, body = C(50, 200, 175), belly = C(120, 220, 230), fin = C(70, 110, 230),
			accent = C(240, 120, 200), tail = "fan", dorsal = "soft", pattern = "patches", extras = { "Beak" }, reflect = 0.1 },
	},
	Lionfish = {
		displayName = "Lionfish", rarity = "Common", sell = 20, perMinute = 4,
		ocean = "Coral", island = 2, order = 2, spots = ALL,
		look = { kind = "lionfish", length = 2.3, body = C(205, 90, 50), belly = C(252, 236, 220), fin = C(220, 110, 70),
			accent = C(250, 240, 225) },
	},
	CoralSeahorse = {
		displayName = "Coral Seahorse", rarity = "Uncommon", sell = 45, perMinute = 10,
		ocean = "Coral", island = 2, order = 3, spots = ALL,
		look = { kind = "seahorse", length = 3.0, body = C(245, 120, 70), belly = C(255, 190, 120), fin = C(255, 150, 190),
			accent = C(255, 215, 90) },
	},
	StarfishRay = {
		displayName = "Starfish Ray", rarity = "Uncommon", sell = 60, perMinute = 13,
		ocean = "Coral", island = 2, order = 4, spots = ALL,
		look = { kind = "ray", length = 3.2, body = C(225, 110, 60), belly = C(250, 225, 200), fin = C(200, 85, 50),
			accent = C(255, 200, 80) },
	},
	CrystalJelly = {
		displayName = "Crystal Jelly", rarity = "Rare", sell = 160, perMinute = 40,
		ocean = "Coral", island = 2, order = 5, spots = MIDFAR,
		look = { kind = "jelly", length = 2.4, body = C(170, 150, 255), belly = C(120, 230, 255), fin = C(220, 170, 255),
			accent = C(255, 160, 230), glow = true },
	},
	RibbonEel = {
		displayName = "Ribbon Eel", rarity = "Rare", sell = 200, perMinute = 48,
		ocean = "Coral", island = 2, order = 6, spots = MIDFAR,
		look = { kind = "eel", length = 4.2, body = C(40, 90, 210), belly = C(250, 220, 60), fin = C(255, 225, 60),
			accent = C(30, 30, 40) },
	},
	PearlOctopus = {
		displayName = "Pearl Octopus", rarity = "Epic", sell = 700, perMinute = 180,
		ocean = "Coral", island = 2, order = 7, spots = FAR,
		look = { kind = "octopus", length = 2.8, body = C(240, 140, 160), belly = C(255, 210, 200), fin = C(200, 100, 170),
			accent = C(255, 190, 120), extras = { "Pearl" }, glow = true },
	},
	SirenAngler = {
		displayName = "Siren Angler", rarity = "Epic", sell = 850, perMinute = 220,
		ocean = "Coral", island = 2, order = 8, spots = FAR,
		look = { kind = "angler", length = 2.6, body = C(30, 40, 80), belly = C(50, 60, 110), fin = C(70, 50, 140),
			accent = C(80, 240, 255), eye = C(120, 255, 255), glow = true },
	},
	CoralSwordfish = {
		displayName = "Coral Swordfish", rarity = "Epic", sell = 1000, perMinute = 260,
		ocean = "Coral", island = 2, order = 9, spots = FAR,
		look = { kind = "billfish", length = 4.8, body = C(70, 150, 220), belly = C(225, 240, 250), fin = C(240, 110, 170),
			accent = C(255, 140, 190), reflect = 0.15, glow = true },
	},
	GoldenFish = {
		displayName = "Golden Fish", rarity = "Legendary", sell = 4000, perMinute = 1000,
		ocean = "Coral", island = 2, order = 10, spots = FAR,
		look = { kind = "fish", shape = "Deep", length = 2.8, body = C(255, 188, 20), belly = C(255, 222, 90), fin = C(255, 200, 50),
			accent = C(255, 240, 160), tail = "fan", dorsal = "fancy", pattern = "patches", reflect = 0.2, metal = true, glow = true },
	},

	------------------------------------------------------------------------------------------
	-- Emekli balıklar (eski kayıtlarda havuzda / teknede kalmış olabilir; artık çıkmaz, kitapta yok)
	------------------------------------------------------------------------------------------
	-- 23 Kasım'da Ada 1 listesinden çıkanlar
	Tuna = {
		displayName = "Bluefin Tuna", rarity = "Rare", sell = 130, perMinute = 35,
		ocean = "Warm", island = 1, order = 99, spots = MIDFAR, retired = true,
		look = { kind = "fish", shape = "Torpedo", length = 3.4, body = C(30, 52, 100), belly = C(215, 222, 232), fin = C(40, 60, 100),
			accent = C(250, 210, 50), tail = "lunate", dorsal = "soft", extras = { "Finlets" }, reflect = 0.25 },
	},
	Swordfish = {
		displayName = "Swordfish", rarity = "Epic", sell = 400, perMinute = 120,
		ocean = "Warm", island = 1, order = 99, spots = FAR, retired = true,
		look = { kind = "billfish", length = 4.6, body = C(55, 62, 120), belly = C(200, 208, 225), fin = C(40, 45, 90),
			accent = C(120, 110, 200), reflect = 0.2, glow = true },
	},
	Hammerhead = {
		displayName = "Hammerhead Shark", rarity = "Epic", sell = 600, perMinute = 170,
		ocean = "Warm", island = 1, order = 99, spots = FAR, retired = true,
		look = { kind = "shark", length = 5.0, body = C(120, 130, 140), belly = C(232, 234, 236), fin = C(100, 110, 120),
			extras = { "Hammer" }, glow = true },
	},
	GoldenMarlin = {
		displayName = "Golden Marlin", rarity = "Legendary", sell = 2500, perMinute = 800,
		ocean = "Warm", island = 1, order = 99, spots = FAR, retired = true,
		look = { kind = "billfish", dorsal = "sail", length = 5.2, body = C(250, 180, 20), belly = C(255, 225, 110), fin = C(230, 140, 10),
			accent = C(255, 240, 170), reflect = 0.2, metal = true, glow = true },
	},
	CoralGrouper = {
		displayName = "Coral Grouper", rarity = "Epic", sell = 300, perMinute = 50,
		ocean = "Coral", island = 2, order = 99, spots = MIDFAR, retired = true,
		look = { kind = "fish", shape = "Deep", length = 3.6, body = C(220, 60, 90), belly = C(250, 190, 170), fin = C(150, 30, 70),
			accent = C(255, 220, 230), tail = "fan", pattern = "spots" },
	},
	GoldenMoray = {
		displayName = "Golden Moray", rarity = "Legendary", sell = 3000, perMinute = 900,
		ocean = "Coral", island = 2, order = 99, spots = FAR, retired = true,
		look = { kind = "eel", length = 5.5, body = C(230, 190, 50), belly = C(255, 235, 150), fin = C(150, 110, 20),
			accent = C(120, 90, 20), glow = true },
	},
}

return Fish
