--!strict
-- 2. ada: Mermaid Island (eski adı Ancient Coral Atoll; id hâlâ "Coral"). Ana denizden uzakta, ayrı bir deniz.
-- Kişisel ada yok: herkesin balık tuttuğu ve hazine aradığı ortak bölge. Balıklar ocean = "Coral".
-- Yerleşim Ege'nin eskizinden alındı (2272x1524 piksellik harita). Bu dosyadaki tüm {x, y} değerleri ESKİZİN PİKSELİDİR;
-- builder bunları stud'a çevirir: x = (px - Center[1]) * Scale, z = (py - Center[2]) * Scale (X doğu, Z güney).
-- Bir adayı kaydırmak için sadece pikselini değiştir, sonra MapBuilder.Atoll("props") / ("terrain") çalıştır.
return {
	Origin = Vector3.new(6000, 0, 0),
	Scale = 1.585, -- 1 piksel = 1.585 stud (deniz yaklaşık 3415 x 2211 stud)
	Center = { 1136, 762 },
	SeabedY = -40,
	-- Eski araziyi silinecek alan (stud, atol merkezine göre)
	Clear = { x0 = -2500, x1 = 2100, z0 = -1900, z1 = 1500 },
	-- Deniz dikdörtgeni (piksel). Dışı dağ/kara.
	Sea = { x0 = 50, y0 = 35, x1 = 2205, y1 = 1430 },

	-- Sol üstteki kale şeridi (eskizdeki çapraz kara): a -> b doğrusu boyunca uzanır, ortasında dev kale kapısı var.
	-- halfWidth: şeridin yarı genişliği (piksel). gateGap: kapının iki yanında kara başlamadan önceki boşluk (stud).
	-- Kapının arkasındaki (kuzeybatı) deniz kanalla haritanın dışına devam eder (ileride 3. ada).
	Band = { a = { 50, 395 }, b = { 425, 35 }, halfWidth = 55, gateGap = 150 },
	Channel = { length = 520, width = 260 },

	-- Karşılama adası: mermaid kayası ve başlangıç iskelesi burada
	Welcome = { x = 375, y = 730, r = 58 },
	-- Random Treasure Island (sandık)
	TreasureIsland = { x = 395, y = 1190, r = 48 },
	-- Star Island (sandık)
	Star = { x = 1765, y = 255, r = 75 },
	-- Ana tapınak adası: noktalar {x, y, yarıçap(px)}; tapınak ve iskele konumları
	MainTemple = {
		points = { { 1280, 620, 62 }, { 1285, 700, 70 }, { 1268, 785, 52 } },
		temple = { 1288, 650 },
		dock = { from = { 1198, 765 }, to = { 1108, 765 } },
	},
	-- Tapınağın çevresindeki 4 hilal ada (her biri bir çizgi) ve ortadaki minik ada
	CrescentR = 34,
	Crescents = {
		{ { 715, 575 }, { 760, 500 }, { 830, 445 }, { 900, 418 }, { 950, 410 } },
		{ { 1105, 415 }, { 1170, 405 }, { 1250, 430 }, { 1320, 480 } },
		{ { 725, 775 }, { 745, 860 }, { 800, 935 }, { 880, 985 }, { 945, 985 } },
		{ { 1080, 1000 }, { 1150, 1005 }, { 1230, 970 }, { 1285, 900 } },
	},
	Islets = { { 945, 760, 34 }, { 1510, 1000, 24 } },
	-- Small Ancient Temple (sağ alt): ada zinciri
	SmallTemple = {
		points = { { 1700, 1150, 58 }, { 1790, 1130, 62 }, { 1890, 1125, 64 }, { 1985, 1135, 56 }, { 2030, 1180, 50 } },
		temple = { 1800, 1120 },
	},
	-- Labirent (sağ orta): kaya + mercan duvarlı 5x5 hücre, ortasında sandık
	Labyrinth = { x0 = 1690, y0 = 480, x1 = 1990, y1 = 800, cells = 5 },
	-- Büyük batık gemi (sığlıkta yatar, sandık içinde)
	BigShip = { x = 655, y = 1095, r = 30 },
	-- Yarı batık ölü deniz canavarı (süs): kum şeridi ve iskeletin yeri
	Monster = {
		points = { { 1075, 1215, 28 }, { 1040, 1285, 28 }, { 990, 1345, 28 }, { 935, 1400, 28 } },
		skeleton = { 1035, 1290 },
	},
	-- Üstteki batık gemiler (ahşap + metal toplanır)
	SunkenShips = { { 880, 140 }, { 1050, 100 }, { 1190, 130 } },

	-- Atoldeki su rengi (sadece oyuncu atoldeyken; ana adanın suyu değişmez)
	Water = {
		color = Color3.fromRGB(30, 158, 170),
		transparency = 0.7,
		reflectance = 0.3,
		waveSize = 0.15,
		waveSpeed = 8,
	},
	RegionMinX = 3000, -- bu X'in ötesi atol sayılır (kanal da dahil)
}
