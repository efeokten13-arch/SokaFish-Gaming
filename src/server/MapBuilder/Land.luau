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

function Land.path(p0, p1, radius, mat, from)
	local len = (p1 - p0).Magnitude
	local steps = math.ceil(len / 5)
	for i = 0, steps do
		local p = p0:Lerp(p1, i / steps)
		Land.paintDisc(p.X, p.Z, radius, mat, from)
	end
end

function Land.rocks(cfg)
	local rng = Random.new(cfg.Seed + 1)
	local main = Layout.mainDiscs(cfg)
	-- ana ada kıyısında kayalar
	for k = 2, #main do
		if rng:NextNumber() < 0.7 then
			local d = main[k]
			local len = math.sqrt(d[1] ^ 2 + d[2] ^ 2)
			local dir = Vector3.new(d[1], 0, d[2]) / len
			local p = Vector3.new(d[1], 0, d[2]) + dir * (d[3] * 0.85)
			Terrain:FillBall(Vector3.new(p.X, 3, p.Z), rng:NextNumber(6, 12), ROCK)
		end
	end
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
