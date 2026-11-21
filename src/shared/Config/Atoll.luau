--!strict
-- 2. ada: Mermaid Island (eski adı Ancient Coral Atoll; id hâlâ "Coral"). Ana denizden uzakta, ayrı ve ilk harita kadar büyük bir deniz.
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
	-- Mermaid Island: kuzeydeki iki büyük dağ ve aralarındaki kilitli geçit (anahtarla açılır, 3. adaya gider).
	-- Dağ sırası z = z hattında, x = ±peakX'ten ±endX'e (duvara kadar) uzanır; ortada geçit kalır.
	Pass = { z = -1470, peakX = 380, peakH = 330, endX = 1560, endH = 100, step = 130, gate = 118 },
	-- Varış: oyuncu mermaid taşının karşısında doğar (taşa bakar); gemisi sol iskeleye bağlıdır.
	-- spawn/boat/rock/jetty koordinatları atol merkezine göre (varış iskelesi Dock ile aynı bölgede).
	Arrival = {
		rock = { x = 30, z = 822 },
		spawn = { x = 14, z = 866 },
		boat = { x = -44, z = 841 },
		jetty = { x0 = -22, x1 = -72, z = 851 },
	},
	Labyrinth = { x0 = -1420, x1 = -860, z0 = -420, z1 = 820 },
	Wall = 1560, -- görünmez sınır (dağların önünde)
	Spots = {}, -- işaretli nokta yok: açık denizin her yerinde balık tutulur
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
