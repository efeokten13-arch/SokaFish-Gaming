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
	DeckY = 3.5, -- iskele ve dock üst yüzü

	Main = { radius = 235 },
	Ring = { count = 12, radius = 700, startAngle = 15 },
	Island = { bayRadius = 64, bayShift = 28, backRadius = 30, tipRadius = 15, arc = 120, dockLength = 26, netPost = 8 },

	Pier = { x = 330, zTop = -90, zBottom = 150, startX = 195, width = 10, slots = 5, firstSlotZ = -45, slotSpacing = 38 },
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
