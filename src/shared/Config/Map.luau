--!strict
-- Harita ölçüleri ve yerleşim. MapBuilder haritayı bu dosyadan üretir.
-- Bir sayıyı değiştirip MapBuilder'ı yeniden çalıştırmak haritayı günceller.
-- Birim: stud. X = doğu, Z = güney. Harita merkezi (0, 0). Su yüzeyi y = 0.

local Map = {
	Seed = 12,
	WaterY = 0,
	SeabedY = -40,
	SeaSize = 3600,

	-- Terrain 4 stud'luk adımlara yuvarlandığı için ölçülmüş yükseklikler
	BeachY = 2,
	GrassY = 6,
	DeckY = 6.5, -- iskele ve dock üst yüzü (ada zemini ile aynı seviye)

	Main = {
		radius = 235, -- eski yuvarlak ada (outline yoksa kullanılır)
		-- Ana adanın kıyı çizgisi (Ege'nin çizimi, Kasım 2026). {x, z} noktaları, saat yönünde.
		-- Ada bu çizginin içinde, kenarları yumuşak ve doğal olacak şekilde kurulur.
		outline = {
			{ 98, 170 }, { 58, 188 }, { 8, 196 }, { -43, 198 }, { -94, 190 }, { -137, 172 }, { -165, 143 },
			{ -181, 99 }, { -191, 48 }, { -194, -2 }, { -190, -53 }, { -177, -93 }, { -153, -129 },
			{ -119, -158 }, { -79, -176 }, { -29, -185 }, { 22, -191 }, { 58, -200 }, { 98, -189 },
			{ 132, -169 }, { 161, -141 }, { 183, -111 }, { 187, -86 }, { 167, -75 }, { 123, -77 },
			{ 87, -78 }, { 71, -62 }, { 67, -20 }, { 67, 23 }, { 65, 40 }, { 68, 64 }, { 76, 88 },
			{ 84, 112 }, { 92, 138 },
		},
	},
	Ring = { count = 12, radius = 700, startAngle = 15 },
	Island = { bayRadius = 64, bayShift = 28, backRadius = 30, tipRadius = 15, arc = 120, dockLength = 26, netPost = 8 },

	-- İskele: kıyıya paralel omurga (güney ucu adanın sol alt çıkıntısına bağlı),
	-- ortadan adaya ahşap yürüme yolu, parmaklar omurgadan adaya doğru.
	Pier = {
		x = 161, -- omurganın merkezi
		zTop = -84, -- güney ucu (karaya girer)
		zBottom = 96, -- kuzey ucu
		width = 10,
		walkZ = 18, -- yürüme yolu
		startX = 64, -- yürüme yolunun karadaki başlangıcı
		fingerLen = 34,
		fingers = { -71, -33, 5, 56, 94 },
		slipZ = { -52, -14, 37, 75 }, -- tekne yuvaları (ShopOrder sırasıyla)
	},
	Hall = { x = -20, z = -118, width = 64, depth = 38 },
	Plaza = { x = -20, z = 18, radius = 40 },

	Spots = {
		Near = { count = 6, radius = 450, offset = 0 },
		Mid = { count = 6, radius = 980, offset = 30 },
		Far = { count = 4, radius = 1450, offset = 45 },
	},

	Water = {
		color = Color3.fromRGB(30, 158, 198),
		transparency = 0.45,
		reflectance = 0.3,
		waveSize = 0.25,
		waveSpeed = 12,
	},
}

return Map
