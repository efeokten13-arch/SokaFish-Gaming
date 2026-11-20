--!strict
-- 2. ada: Ancient Coral Atoll. Ana denizden uzakta, ayrı ve ilk harita kadar büyük bir deniz.
-- Kişisel ada yok: herkesin balık tuttuğu ve hazine aradığı ortak bölge. Balıklar ocean = "Coral".
-- Koordinatlar atol merkezine göre (X doğu, Z güney). MapBuilder.Atoll() kurar.
return {
	Origin = Vector3.new(6000, 0, 0),
	SeaSize = 3600, -- ilk harita ile aynı
	SeabedY = -40,
	-- Ana atol halkası: kalp şekli, ortada lagün, güneyde giriş
	Ring = { radius = 520, lobe = 70, gaps = { { 62, 118 }, { 148, 168 } } },
	-- Tepeler (halka üzerindeki açı, yükseklik)
	Hills = { { -90, 34 }, { -135, 24 }, { -40, 28 }, { 15, 18 }, { 45, 22 }, { 200, 26 }, { 240, 20 }, { 130, 14 } },
	Dock = { x = 0, z = 860 }, -- varış iskelesi (güney açıklığın önünde)
	Islets = {
		{ name = "Sunken Temple", x = -980, z = -760, r = 95, kind = "temple" },
		{ name = "Giant's Reef", x = 1000, z = -820, r = 90, kind = "tower" },
		{ name = "Siren's Cove", x = 1040, z = 600, r = 100, kind = "cove" },
	},
	-- 4 köşe adası (hazine sandıkları)
	Corners = {
		{ name = "Skull Key", x = -1330, z = -1330 },
		{ name = "Gull Rock", x = 1330, z = -1330 },
		{ name = "Pearl Isle", x = 1330, z = 1330 },
		{ name = "Smuggler's Den", x = -1330, z = 1330 },
	},
	Labyrinth = { x0 = -1420, x1 = -860, z0 = -420, z1 = 820 },
	Wall = 1560, -- görünmez sınır (dağların önünde)
	Spots = {
		{ "Near", -120, -40 }, { "Near", 140, 60 }, { "Near", 0, -200 }, { "Near", -60, 220 },
		{ "Mid", -1060, 100 }, { "Mid", -960, 600 }, { "Mid", 720, -380 }, { "Mid", 560, 1000 }, { "Mid", -620, -1000 },
		{ "Far", -1150, -1150 }, { "Far", 1180, -1150 }, { "Far", 1200, 1000 }, { "Far", -1150, 1150 },
	},
	-- Atoldeki su rengi (sadece oyuncu atoldeyken; ana adanın suyu değişmez)
	Water = {
		color = Color3.fromRGB(30, 158, 170),
		transparency = 0.7,
		reflectance = 0.3,
		waveSize = 0.15,
		waveSpeed = 8,
	},
	RegionMinX = 4000, -- bu X'in ötesi atol sayılır
}
