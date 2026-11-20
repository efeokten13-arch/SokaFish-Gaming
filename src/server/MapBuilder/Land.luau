--!nonstrict
-- Deniz tabanı, su, ana ada ve hilal adaların arazisi.
local Terrain = workspace.Terrain
local Layout = require(script.Parent.Layout)

local Land = {}

local BOTTOM = -44
local SAND, GRASS, ROCK = Enum.Material.Sand, Enum.Material.Grass, Enum.Material.Rock
-- {üst yükseklik, taşma}: aşağıdan yukarı daralan basamaklar = yumuşak sığlık
local LAYERS = { { -36, 60 }, { -29, 50 }, { -22, 40 }, { -15, 31 }, { -9, 23 }, { -4, 16 }, { -1, 9 } }

local function column(x, z, radius, top, mat)
	Terrain:FillCylinder(CFrame.new(x, (top + BOTTOM) / 2, z), top - BOTTOM, radius, mat)
end

function Land.sea(cfg)
	Terrain:Clear()
	-- Tüm kenarlar 4 stud'luk ızgaraya oturmalı, yoksa su yüzeyi dama gibi delik deşik görünür
	local half = cfg.SeaSize // 8 * 4
	local tile = 448
	local bed = cfg.SeabedY
	local x0 = -half
	while x0 < half do
		local w = math.min(tile, half - x0)
		local z0 = -half
		while z0 < half do
			local d = math.min(tile, half - z0)
			local cx, cz = x0 + w / 2, z0 + d / 2
			Terrain:FillBlock(CFrame.new(cx, bed - 4, cz), Vector3.new(w, 8, d), SAND)
			Terrain:FillBlock(CFrame.new(cx, bed / 2, cz), Vector3.new(w, -bed, d), Enum.Material.Water)
			z0 += d
		end
		x0 += w
		task.wait()
	end
end

function Land.allDiscs(cfg)
	local discs = Layout.mainDiscs(cfg)
	for i = 1, cfg.Ring.count do
		for _, d in Layout.discs(cfg, Layout.frame(cfg, i)) do
			table.insert(discs, d)
		end
	end
	return discs
end

-- Önce tüm kum katmanları, sonra tüm çim tepeler (komşu daireler birbirini bozmasın)
function Land.islands(cfg)
	local discs = Land.allDiscs(cfg)
	local n = 0
	for _, l in LAYERS do
		for _, d in discs do
			column(d[1], d[2], d[3] + l[2], l[1], SAND)
			n += 1
			if n % 80 == 0 then
				task.wait()
			end
		end
	end
	for _, d in discs do
		column(d[1], d[2], d[3], 4, GRASS)
		n += 1
		if n % 80 == 0 then
			task.wait()
		end
	end
end

-- Zemin boyaması: yüksekliği değiştirmez, sadece malzemeyi değiştirir (from varsayılan: çim)
function Land.paintDisc(x, z, radius, mat, from)
	from = from or GRASS
	local dz = -radius
	while dz < radius do
		local zc = dz + 2
		local half = math.sqrt(math.max(radius * radius - zc * zc, 0))
		if half > 1 then
			local region = Region3.new(Vector3.new(x - half, 0, z + dz), Vector3.new(x + half, 12, z + dz + 4)):ExpandToGrid(4)
			Terrain:ReplaceMaterial(region, 4, from, mat)
		end
		dz += 4
	end
end

-- Dikdörtgen boyama (binaların altı: çim yaprakları zeminden çıkmasın)
function Land.paintRect(cx, cz, w, d, mat, from)
	local region = Region3.new(Vector3.new(cx - w / 2, 0, cz - d / 2), Vector3.new(cx + w / 2, 12, cz + d / 2)):ExpandToGrid(4)
	Terrain:ReplaceMaterial(region, 4, from or GRASS, mat)
end

-- Dalgalı patika: uçlar sabit, ortası yana kıvrılır; genişlik de hafif değişir (doğal görünüm)
function Land.wavyPath(p0, p1, radius, mat, seed, amp, waves)
	local rng = Random.new(seed or 1)
	amp = amp or 5
	waves = waves or 1.5
	local phase = rng:NextNumber(0, math.pi * 2)
	local dir = p1 - p0
	local len = dir.Magnitude
	local side = Vector3.new(-dir.Z, 0, dir.X).Unit
	local steps = math.ceil(len / 3)
	for i = 0, steps do
		local t = i / steps
		local off = math.sin(t * math.pi * 2 * waves + phase) * amp * math.sin(t * math.pi)
		local p = p0:Lerp(p1, t) + side * off
		local r = radius * (0.85 + 0.25 * math.sin(t * 9 + phase))
		Land.paintDisc(p.X, p.Z, r, mat)
	end
end

function Land.path(p0, p1, radius, mat, from)
	local len = (p1 - p0).Magnitude
	local steps = math.ceil(len / 5)
	for i = 0, steps do
		local p = p0:Lerp(p1, i / steps)
		Land.paintDisc(p.X, p.Z, radius, mat, from)
	end
end

-- Ana adanın kıyı kayaları: çizgi boyunca, iskele bölgesi hariç
function Land.mainRocks(cfg)
	local rng = Random.new(cfg.Seed + 1)
	local poly = cfg.Main.outline
	if not poly then
		return
	end
	local P = cfg.Pier
	for i = 1, #poly do
		local a, b = poly[i], poly[i % #poly + 1]
		if rng:NextNumber() < 0.6 then
			local t = rng:NextNumber(0.2, 0.8)
			local x, z = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
			-- iskele koyunda kaya olmasın
			local nearPier = x > P.startX - 10 and z > P.zTop - 15 and z < P.zBottom + 10
			if not nearPier then
				Terrain:FillBall(Vector3.new(x, 2, z), rng:NextNumber(5, 10), ROCK)
			end
		end
	end
end

-- Ana adayı sil ve yeni kıyı çizgisine göre yeniden kur (12 ada etkilenmez)
function Land.rebuildMain(cfg)
	local R = 360
	-- eski adayı kaldır: önce hava, sonra suyu geri doldur (deniz tabanı -40'ın altında kalır)
	Terrain:FillCylinder(CFrame.new(0, 32, 0), 136, R, Enum.Material.Air)
	Terrain:FillCylinder(CFrame.new(0, -18, 0), 36, R, Enum.Material.Water)
	task.wait()
	local discs = Layout.mainDiscs(cfg)
	local n = 0
	for _, l in LAYERS do
		for _, d in discs do
			column(d[1], d[2], d[3] + l[2], l[1], SAND)
			n += 1
			if n % 80 == 0 then
				task.wait()
			end
		end
	end
	for _, d in discs do
		column(d[1], d[2], d[3], 4, GRASS)
		n += 1
		if n % 80 == 0 then
			task.wait()
		end
	end
	Land.mainRocks(cfg)
	return #discs
end

function Land.rocks(cfg)
	local rng = Random.new(cfg.Seed + 1)
	Land.mainRocks(cfg)
	-- adalarda sırtın dışında bir iki kaya
	for i = 1, cfg.Ring.count do
		local f = Layout.frame(cfg, i)
		for _, t in { -0.35, 0.4 } do
			local p = Layout.arcPoint(cfg, f, t)
			local r = Layout.radiusAt(cfg, t)
			local q = p + (p - f.bay).Unit * (r * 0.9)
			Terrain:FillBall(Vector3.new(q.X, 2, q.Z), rng:NextNumber(4, 8), ROCK)
		end
	end
end

return Land
