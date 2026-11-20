--!nonstrict
-- 2. ada: Ancient Coral Atoll (ortak balık + hazine bölgesi). Ayarlar: Config/Atoll.luau
-- Kurulanlar: Workspace.Atoll (yapılar, süsler, mercanlar, sandıklar), Workspace.FishingSpots.Atoll,
-- Workspace.SeaMapDestinations.Coral / Coral_Boat. Arazi tek seferde kurulur (Atoll.Build).
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Terrain = Workspace.Terrain
local Util = require(script.Parent.Util)
local Decor = require(script.Parent.Decor)

local Atoll = {}

local SAND, GRASS, LEAFY, ROCK = Enum.Material.Sand, Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Rock
local WATER = Enum.Material.Water
local BOTTOM = -44
local LAYERS = { { -36, 60 }, { -29, 50 }, { -22, 40 }, { -15, 31 }, { -9, 23 }, { -4, 16 }, { -1, 9 } }
local STONE = Color3.fromRGB(158, 152, 136)
local MOSS = Color3.fromRGB(104, 130, 84)
local DARK = Color3.fromRGB(92, 62, 40)
local WOOD = Color3.fromRGB(139, 94, 60)
local GOLD = Color3.fromRGB(230, 185, 60)
local CREAM = Color3.fromRGB(255, 244, 214)
local CORALS = {
	Color3.fromRGB(245, 90, 130), -- pembe
	Color3.fromRGB(175, 90, 230), -- mor
	Color3.fromRGB(255, 150, 60), -- turuncu
	Color3.fromRGB(70, 160, 245), -- mavi
	Color3.fromRGB(235, 55, 60), -- kırmızı
	Color3.fromRGB(255, 210, 70), -- sarı
	Color3.fromRGB(80, 220, 180), -- turkuaz
	Color3.fromRGB(255, 120, 200), -- açık pembe
}

local O
local function cfg()
	return require(ReplicatedStorage.Shared.Config.Atoll:Clone())
end
local function W(x, z, y)
	return Vector3.new(O.X + x, y or 0, O.Z + z)
end
local function ground(x, z)
	return Util.groundY(O.X + x, O.Z + z)
end
local function column(x, z, radius, top, mat)
	Terrain:FillCylinder(CFrame.new(O.X + x, (top + BOTTOM) / 2, O.Z + z), top - BOTTOM, radius, mat)
end
local function ball(x, y, z, r, mat)
	Terrain:FillBall(Vector3.new(O.X + x, y, O.Z + z), r, mat)
end

-- Ada parçası: daireler {x, z, r} -> kum yamaçlar + üstte yeşil
local function land(discs, topMat)
	local n = 0
	for _, l in LAYERS do
		for _, d in discs do
			column(d[1], d[2], d[3] + l[2], l[1], SAND)
			n += 1
			if n % 100 == 0 then
				task.wait()
			end
		end
	end
	for _, d in discs do
		column(d[1], d[2], d[3], 4, topMat or GRASS)
	end
end

local function ringPoint(c, deg, extra)
	local a = math.rad(deg)
	local rr = c.Ring.radius + c.Ring.lobe * math.cos(2 * a) + (extra or 0)
	return math.cos(a) * rr, math.sin(a) * rr
end

local function inGap(deg, gaps)
	deg = deg % 360
	for _, g in gaps do
		if deg > g[1] and deg < g[2] then
			return true
		end
	end
	return false
end

-- Tepe: üst üste küçülen toplar, eteği yapraklı çim, sırtında kaya
local function hill(x, z, h, rng)
	local y = 2
	local r = h * 1.6
	while r > 6 do
		ball(x + rng:NextNumber(-3, 3), y, z + rng:NextNumber(-3, 3), r, LEAFY)
		y += h * 0.22
		r *= 0.78
	end
	ball(x, y - 2, z, math.max(r, 8), GRASS)
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		ball(x + math.cos(a) * h * 0.9, h * 0.4, z + math.sin(a) * h * 0.9, h * 0.35, ROCK)
	end
end

-- 1) Deniz + sığlıklar ----------------------------------------------------------
function Atoll.Sea(c)
	local half = c.SeaSize // 8 * 4
	local tile = 200
	-- önce bölgeyi parça parça tamamen temizle (eski kurulum kalmasın)
	for x = -half, half - 1, tile do
		for z = -half, half - 1, tile do
			Terrain:FillBlock(CFrame.new(O.X + x + tile / 2, 160, O.Z + z + tile / 2), Vector3.new(tile, 440, tile), Enum.Material.Air)
		end
		task.wait()
	end
	local x0 = -half
	while x0 < half do
		local w = math.min(tile, half - x0)
		local z0 = -half
		while z0 < half do
			local d = math.min(tile, half - z0)
			local cx, cz = O.X + x0 + w / 2, O.Z + z0 + d / 2
			Terrain:FillBlock(CFrame.new(cx, c.SeabedY - 4, cz), Vector3.new(w, 8, d), SAND)
			Terrain:FillBlock(CFrame.new(cx, c.SeabedY / 2, cz), Vector3.new(w, -c.SeabedY, d), WATER)
			z0 += d
		end
		x0 += w
		task.wait()
	end
	-- sığ resif rafı: atolün çevresinde açık renkli, mercanlı su (taban -14)
	Terrain:FillCylinder(CFrame.new(O.X, -16, O.Z), 4, c.Ring.radius + 300, SAND)
	for _, isl in c.Islets do
		Terrain:FillCylinder(CFrame.new(O.X + isl.x, -14, O.Z + isl.z), 4, isl.r + 160, SAND)
	end
	for _, cn in c.Corners do
		Terrain:FillCylinder(CFrame.new(O.X + cn.x, -14, O.Z + cn.z), 4, 170, SAND)
	end
	-- labirent: çok sığ (taban -8)
	local L = c.Labyrinth
	for x = L.x0, L.x1, 40 do
		for z = L.z0, L.z1, 40 do
			Terrain:FillBlock(CFrame.new(O.X + x + 20, -10, O.Z + z + 20), Vector3.new(40, 4, 40), SAND)
		end
		task.wait()
	end
end

-- 2) Ana halka + tepeler + lagün -----------------------------------------------
function Atoll.Ring(c)
	local R = c.Ring
	local rng = Random.new(201)
	local discs = {}
	for deg = 0, 359, 3 do
		if not inGap(deg, R.gaps) then
			local a = math.rad(deg)
			local x, z = ringPoint(c, deg, rng:NextNumber(-14, 14))
			local width = 80 + 28 * math.sin(a * 3 + 1) + rng:NextNumber(-8, 8)
			table.insert(discs, { x, z, width })
		end
	end
	land(discs, LEAFY)
	-- güney giriş kanalının iki ucuna küçük adacıklar (resimdeki gibi)
	local sx, sz = ringPoint(c, 128)
	land({ { sx, sz, 70 }, { sx + 40, sz + 20, 50 } }, GRASS)
	-- lagün: kenarı sığ (açık turkuaz), ortası derin (koyu mavi)
	Terrain:FillCylinder(CFrame.new(O.X, -14, O.Z), 4, R.radius - 110, SAND)
	Terrain:FillCylinder(CFrame.new(O.X, -24, O.Z), 28, R.radius - 260, WATER)
	task.wait()
	for i, hdef in c.Hills do
		local x, z = ringPoint(c, hdef[1])
		hill(x, z, hdef[2], Random.new(700 + i))
		task.wait()
	end
	-- dümdüz olmasın: halka boyunca alçak, yumuşak tümsekler
	local mrng = Random.new(777)
	for deg = 0, 359, 7 do
		if not inGap(deg, R.gaps) then
			local x, z = ringPoint(c, deg, mrng:NextNumber(-40, 40))
			ball(x, mrng:NextNumber(-2, 2), z, mrng:NextNumber(14, 26), LEAFY)
		end
	end
end

-- 3) Uydu adalar, köşe adaları, labirent kayaları --------------------------------
function Atoll.Islets(c)
	for i, isl in c.Islets do
		local rng = Random.new(300 + i)
		local discs = { { isl.x, isl.z, isl.r } }
		for _ = 1, 7 do
			local a = rng:NextNumber(0, math.pi * 2)
			table.insert(discs, { isl.x + math.cos(a) * isl.r * 0.65, isl.z + math.sin(a) * isl.r * 0.65, isl.r * rng:NextNumber(0.4, 0.65) })
		end
		land(discs, GRASS)
		hill(isl.x + rng:NextNumber(-20, 20), isl.z + rng:NextNumber(-20, 20), 16, rng)
		task.wait()
	end
	for i, cn in c.Corners do
		local rng = Random.new(350 + i)
		local discs = { { cn.x, cn.z, 52 } }
		for _ = 1, 4 do
			local a = rng:NextNumber(0, math.pi * 2)
			table.insert(discs, { cn.x + math.cos(a) * 30, cn.z + math.sin(a) * 30, rng:NextNumber(22, 34) })
		end
		land(discs, GRASS)
		ball(cn.x + 18, 6, cn.z - 14, 14, ROCK)
		task.wait()
	end
	-- Coral Labyrinth: suyun yüzeyine çıkan dar kaya sırtları, aralarında tekne kanalları
	local L = c.Labyrinth
	local rng = Random.new(400)
	local row = 0
	for z = L.z0 + 50, L.z1 - 30, 95 do
		row += 1
		local x = L.x0 + (row % 2) * 40
		while x < L.x1 - 30 do
			local len = rng:NextNumber(50, 120)
			local steps = math.floor(len / 6)
			for k = 0, steps do
				ball(x + k * 6, rng:NextNumber(-3, 0), z + math.sin(k * 0.6) * 7, rng:NextNumber(3.5, 6), ROCK)
			end
			x += len + rng:NextNumber(45, 70)
		end
		task.wait()
	end
end

-- 4) Kare dağ sınırı (oyuncular tırmanamaz: önünde görünmez duvar var) -----------
function Atoll.Border(c)
	local rng = Random.new(500)
	local E = c.SeaSize / 2 - 90
	local function mountain(x, z, h)
		local base = h * 0.75
		local y = -30
		while y < h do
			local t = math.max(y, 0) / h
			local r = base * (1 - t) ^ 1.2 + 6
			local mat = t > 0.72 and ROCK or (rng:NextNumber() < 0.25 and GRASS or LEAFY)
			ball(x + rng:NextNumber(-4, 4), y, z + rng:NextNumber(-4, 4), r, mat)
			y += math.max(r * 0.33, 8)
		end
	end
	local step = 170
	for s = -E, E, step do
		for _, p in { { s, -E }, { s, E }, { -E, s }, { E, s } } do
			mountain(p[1] + rng:NextNumber(-25, 25), p[2] + rng:NextNumber(-25, 25), rng:NextNumber(170, 300))
		end
		task.wait()
	end
end

-- Yapılar ve süsler --------------------------------------------------------------

local function stone(parent, name, size, cf, mossy)
	return Util.part(parent, name, size, cf, mossy and STONE:Lerp(MOSS, 0.4) or STONE, Enum.Material.Cobblestone)
end

local function temple(parent, x, z, s)
	local m = Instance.new("Model")
	m.Name = "Temple"
	local g = (ground(x, z) or 6) - 1
	local cf = CFrame.new(O.X + x, g, O.Z + z)
	for k = 0, 3 do
		stone(m, "Step", Vector3.new((40 - k * 5) * s, 2.4 * s, (34 - k * 5) * s), cf * CFrame.new(0, (1.2 + k * 2.4) * s, 0), k == 0)
	end
	local top = 9.6 * s
	for _, cx in { -12, -4, 4, 12 } do
		for _, cz in { -8, 8 } do
			Util.cyl(m, "Column", 14 * s, 2.6 * s, cf * CFrame.new(cx * s, top + 7 * s, cz * s) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Marble)
		end
	end
	stone(m, "Lintel", Vector3.new(30 * s, 2.4 * s, 20 * s), cf * CFrame.new(0, top + 15 * s, 0))
	for _, side in { 1, -1 } do
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = Vector3.new(30 * s, 6 * s, 10 * s)
		w.CFrame = cf * CFrame.new(0, top + 19 * s, side * 5 * s) * CFrame.Angles(0, side == 1 and 0 or math.pi, 0)
		w.Color = STONE:Lerp(MOSS, 0.35)
		w.Material = Enum.Material.Cobblestone
		w.Parent = m
	end
	Util.part(m, "Door", Vector3.new(6 * s, 10 * s, 0.5), cf * CFrame.new(0, top + 5 * s, 8.6 * s), Color3.fromRGB(28, 24, 20), Enum.Material.Slate)
	-- sarmaşıklar
	for k = 1, 6 do
		Util.noCollide(Util.part(m, "Vine", Vector3.new(0.4, 6 * s, 0.4), cf * CFrame.new(-14 * s + k * 4 * s, top + 10 * s, 9 * s), Color3.fromRGB(70, 120, 55), Enum.Material.Grass))
	end
	m.Parent = parent
	return m, cf
end

local function tower(parent, x, z, h, broken)
	local m = Instance.new("Model")
	m.Name = "RuinTower"
	local g = (ground(x, z) or 6) - 1
	local cf = CFrame.new(O.X + x, g, O.Z + z)
	Util.cyl(m, "Tower", h, 11, cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), STONE:Lerp(MOSS, 0.25), Enum.Material.Cobblestone)
	Util.cyl(m, "Band", 1.4, 12, cf * CFrame.new(0, h * 0.35, 0) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Slate)
	for k = 0, 9 do
		if not broken or k % 3 ~= 0 then
			local a = k / 10 * math.pi * 2
			stone(m, "Merlon", Vector3.new(2.4, 2.8, 2.4), cf * CFrame.new(math.cos(a) * 5, h + 1.4, math.sin(a) * 5))
		end
	end
	for _, a in { 0, math.pi } do
		Util.part(m, "Window", Vector3.new(0.4, 3.4, 1.8), cf * CFrame.new(math.cos(a) * 5.6, h * 0.65, math.sin(a) * 5.6) * CFrame.Angles(0, -a, 0), Color3.fromRGB(28, 24, 20), Enum.Material.Slate)
	end
	m.Parent = parent
end

local function arch(parent, x, z, yaw)
	local m = Instance.new("Model")
	m.Name = "Arch"
	local g = (ground(x, z) or 6) - 1
	local cf = CFrame.new(O.X + x, g, O.Z + z) * CFrame.Angles(0, yaw or 0, 0)
	stone(m, "PillarL", Vector3.new(3.6, 15, 3.6), cf * CFrame.new(-7, 7.5, 0), true)
	stone(m, "PillarR", Vector3.new(3.6, 12, 3.6), cf * CFrame.new(7, 6, 0), true)
	stone(m, "Top", Vector3.new(19, 3, 4), cf * CFrame.new(-0.5, 15.5, 0) * CFrame.Angles(0, 0, math.rad(-5)))
	stone(m, "Rubble", Vector3.new(4, 2, 3), cf * CFrame.new(10, 1, 3) * CFrame.Angles(0.3, 0.6, 0.2), true)
	m.Parent = parent
end

local function ruinWall(parent, x, z, yaw, len)
	local m = Instance.new("Model")
	m.Name = "RuinWall"
	local g = (ground(x, z) or 6) - 1
	local cf = CFrame.new(O.X + x, g, O.Z + z) * CFrame.Angles(0, yaw, 0)
	local n = math.floor(len / 4)
	for k = 0, n do
		local h = 3 + math.abs(math.sin(k * 1.7)) * 6
		stone(m, "Block", Vector3.new(4, h, 3), cf * CFrame.new(-len / 2 + k * 4, h / 2, 0), k % 2 == 0)
	end
	m.Parent = parent
end

-- Batık sütunlar (sudan çıkan harabe)
local function sunkenPillars(parent, x, z, rng)
	for k = 1, 5 do
		local h = rng:NextNumber(6, 18)
		local p = Util.cyl(parent, "SunkenPillar", h + 14, 3, CFrame.new(O.X + x + rng:NextNumber(-25, 25), h / 2 - 7, O.Z + z + rng:NextNumber(-25, 25)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, math.pi / 2 + rng:NextNumber(-0.15, 0.15)), STONE:Lerp(MOSS, 0.45), Enum.Material.Marble)
		p.CanCollide = true
	end
end

local function redX(parent, x, z)
	local g = (ground(x, z) or 6) + 0.1
	for _, a in { 45, -45 } do
		Util.noCollide(Util.part(parent, "X", Vector3.new(10, 0.3, 1.8), CFrame.new(O.X + x, g, O.Z + z) * CFrame.Angles(0, math.rad(a), 0), Color3.fromRGB(200, 30, 30), Enum.Material.SmoothPlastic))
	end
end

-- Hazine sandığı (TreasureService "Open" düğmesi ekler, ödülü verir)
local function chest(parent, x, z, yaw, tier)
	local m = Instance.new("Model")
	m.Name = "TreasureChest"
	local g = (ground(x, z) or 6)
	local cf = CFrame.new(O.X + x, g, O.Z + z) * CFrame.Angles(0, yaw or 0, 0)
	local base = Util.part(m, "Base", Vector3.new(4.4, 2.4, 3), cf * CFrame.new(0, 1.2, 0), Color3.fromRGB(120, 72, 38), Enum.Material.WoodPlanks)
	local lid = Util.part(m, "Lid", Vector3.new(4.5, 1.1, 3.1), cf * CFrame.new(0, 2.95, 0), Color3.fromRGB(130, 80, 42), Enum.Material.WoodPlanks)
	for _, dx in { -1.6, 1.6 } do
		Util.part(m, "Band", Vector3.new(0.35, 3.6, 3.2), cf * CFrame.new(dx, 1.85, 0), GOLD, Enum.Material.Metal)
	end
	Util.part(m, "Lock", Vector3.new(0.8, 0.9, 0.3), cf * CFrame.new(0, 2.4, -1.65), GOLD, Enum.Material.Metal)
	local glow = Util.part(m, "Glow", Vector3.new(3.6, 0.2, 2.2), cf * CFrame.new(0, 2.45, 0), Color3.fromRGB(255, 220, 90), Enum.Material.Neon)
	glow.Transparency = 1
	Util.light(base, 0.8, 14, Color3.fromRGB(255, 210, 110))
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			p.CanCollide = p == base
		end
	end
	m.PrimaryPart = base
	m:SetAttribute("Tier", tier or "Small")
	m:SetAttribute("LidClosed", lid.CFrame)
	CollectionService:AddTag(m, "TreasureChest")
	m.Parent = parent
	return m
end

-- Mercan çeşitleri: dallı, beyin, yelpaze, tüp, deniz otu
local function coral(parent, pos, rng)
	local m = Instance.new("Model")
	m.Name = "Coral"
	local col = CORALS[rng:NextInteger(1, #CORALS)]
	local kind = rng:NextInteger(1, 5)
	local function nc(p)
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		return p
	end
	local s = rng:NextNumber(0.8, 1.6)
	if kind == 1 then -- dallı
		for _ = 1, rng:NextInteger(4, 7) do
			local h = rng:NextNumber(2, 6) * s
			local off = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)) * s
			nc(Util.cyl(m, "Branch", h, rng:NextNumber(0.6, 1.1) * s, CFrame.new(pos + off + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, math.pi / 2 + rng:NextNumber(-0.5, 0.5)), col, Enum.Material.SmoothPlastic))
			nc(Util.ball(m, "Tip", Vector3.new(1.5, 1.5, 1.5) * s, CFrame.new(pos + off + Vector3.new(0, h, 0)), col:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.SmoothPlastic))
		end
	elseif kind == 2 then -- beyin mercanı
		nc(Util.ball(m, "Brain", Vector3.new(6, 3.6, 6) * s, CFrame.new(pos + Vector3.new(0, 1.2 * s, 0)), col, Enum.Material.Pebble))
	elseif kind == 3 then -- yelpaze
		for k = 1, 3 do
			nc(Util.ball(m, "Fan", Vector3.new(0.3, 6, 5) * s, CFrame.new(pos + Vector3.new(k - 2, 3 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), col, Enum.Material.Fabric))
		end
	elseif kind == 4 then -- tüp mercan
		for _ = 1, rng:NextInteger(4, 8) do
			local h = rng:NextNumber(2, 5) * s
			local off = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)) * s
			nc(Util.cyl(m, "Tube", h, 1.3 * s, CFrame.new(pos + off + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), col, Enum.Material.SmoothPlastic))
			nc(Util.cyl(m, "TubeTop", 0.3, 0.8 * s, CFrame.new(pos + off + Vector3.new(0, h + 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), col:Lerp(Color3.new(0, 0, 0), 0.4), Enum.Material.SmoothPlastic))
		end
	else -- deniz otu
		for _ = 1, rng:NextInteger(5, 9) do
			local h = rng:NextNumber(4, 10)
			local off = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			nc(Util.part(m, "Kelp", Vector3.new(0.5, h, 0.2), CFrame.new(pos + off + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), 0), Color3.fromRGB(50, 140, 70):Lerp(Color3.fromRGB(110, 170, 60), rng:NextNumber()), Enum.Material.Grass))
		end
	end
	m.Parent = parent
end

local function wreck(parent, x, z, yaw)
	local m = Instance.new("Model")
	m.Name = "Shipwreck"
	local cf = CFrame.new(O.X + x, -2, O.Z + z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(8), 0, math.rad(20))
	Util.ball(m, "Hull", Vector3.new(11, 7, 36), cf, Color3.fromRGB(86, 58, 38), Enum.Material.WoodPlanks)
	Util.part(m, "Deck", Vector3.new(8, 0.6, 26), cf * CFrame.new(0, 2.6, 0), Color3.fromRGB(110, 76, 48), Enum.Material.WoodPlanks)
	Util.cyl(m, "Mast", 22, 1.2, cf * CFrame.new(0, 10, -3) * CFrame.Angles(0, 0, math.rad(72)), DARK, Enum.Material.Wood)
	local sail = Util.part(m, "Sail", Vector3.new(0.2, 8, 7), cf * CFrame.new(-5, 13, -3) * CFrame.Angles(0, 0, math.rad(-22)), Color3.fromRGB(210, 200, 180), Enum.Material.Fabric)
	sail.Transparency = 0.15
	m.Parent = parent
end

local function serpent(parent, x, z, yaw)
	local m = Instance.new("Model")
	m.Name = "SeaSerpent"
	local green = Color3.fromRGB(56, 130, 96)
	local cf = CFrame.new(O.X + x, 0, O.Z + z) * CFrame.Angles(0, yaw, 0)
	for k = 0, 4 do
		Util.ball(m, "Hump", Vector3.new(5, 9 - k, 11), cf * CFrame.new(0, 0.5, k * 11), green, Enum.Material.SmoothPlastic)
		Util.ball(m, "Fin", Vector3.new(0.6, 3, 4), cf * CFrame.new(0, 5 - k * 0.7, k * 11), Color3.fromRGB(210, 70, 60), Enum.Material.SmoothPlastic)
	end
	Util.cyl(m, "Neck", 13, 4.4, cf * CFrame.new(0, 6.5, -7) * CFrame.Angles(math.rad(-20), 0, math.pi / 2), green, Enum.Material.SmoothPlastic)
	Util.ball(m, "Head", Vector3.new(5.4, 4.4, 7.5), cf * CFrame.new(0, 13, -11), green, Enum.Material.SmoothPlastic)
	for _, ex in { -2, 2 } do
		Util.ball(m, "Eye", Vector3.new(1, 1, 1), cf * CFrame.new(ex, 14, -13.5), Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
	end
	m.Parent = parent
end

local function mermaid(parent, x, z)
	local m = Instance.new("Model")
	m.Name = "MermaidStatue"
	local st = Color3.fromRGB(150, 180, 175)
	ball(x, -2, z, 10, ROCK)
	local cf = CFrame.new(O.X + x, 4, O.Z + z)
	Util.ball(m, "Tail", Vector3.new(4, 11, 4), cf * CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(15)), st, Enum.Material.Marble)
	Util.ball(m, "Fluke", Vector3.new(7, 1.6, 2.6), cf * CFrame.new(2.2, 1.6, 0), st, Enum.Material.Marble)
	Util.ball(m, "Torso", Vector3.new(3.6, 5.4, 2.6), cf * CFrame.new(-0.8, 13, 0), st, Enum.Material.Marble)
	Util.ball(m, "Head", Vector3.new(2.4, 2.7, 2.4), cf * CFrame.new(-1, 17.4, 0), st, Enum.Material.Marble)
	Util.ball(m, "Hair", Vector3.new(3, 5.4, 2.2), cf * CFrame.new(-0.4, 16, 0.8), st:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Marble)
	m.Parent = parent
end

local function smallDock(parent, x, z, dirX, dirZ)
	-- kıyıdan denize uzanan küçük iskele (tekneyle yanaşıp adaya çıkmak için)
	local dir = Vector3.new(dirX, 0, dirZ).Unit
	local start = Vector3.new(x, 0, z)
	local stop = start + dir * 34
	local y = 6.5
	local d = Util.beam(parent, "Dock", W(start.X, start.Z, y - 0.5), W(stop.X, stop.Z, y - 0.5), 7, 1, WOOD, Enum.Material.WoodPlanks)
	local side = Vector3.new(-dir.Z, 0, dir.X) * 3
	for k = 1, 4 do
		local p = start + dir * (k * 8.5)
		for _, sgn in { -1, 1 } do
			Util.pole(parent, "Piling", O.X + p.X + side.X * sgn, O.Z + p.Z + side.Z * sgn, -10, y + 1.4, 0.9, DARK, Enum.Material.Wood)
		end
	end
	return d
end

local function label(parent, x, z, text, h)
	local p = Util.zone(parent, "Label", Vector3.new(1, 1, 1), CFrame.new(O.X + x, h or 30, O.Z + z))
	local b = Util.billboard(p, text, 0, 280)
	b.MaxDistance = 900
	return p
end

local function plant(parent, x, z, rng, kind)
	local gy = ground(x, z)
	if not gy or gy < 3 then
		return false
	end
	local pos = W(x, z, gy - 0.3)
	kind = kind or rng:NextInteger(1, 4)
	if kind == 1 then
		Decor.palm(parent, pos, rng)
	elseif kind == 2 then
		Decor.bush(parent, pos, rng)
	elseif kind == 3 then
		Decor.fern(parent, pos, rng)
	else
		Decor.flowers(parent, pos, rng)
	end
	return true
end

function Atoll.Structures(c)
	local f = Util.fresh("Model", "Atoll")
	local rng = Random.new(600)
	local function rp(deg, extra)
		return ringPoint(c, deg, extra)
	end
	-- Ana atol: tapınak en yüksek tepede, kuleler, kemerler, duvarlar
	local tx, tz = rp(-90)
	temple(f, tx, tz, 1.2)
	for _, t in { { -135, 22, true }, { -40, 26, false }, { 45, 20, true }, { 200, 18, true }, { 15, 16, false } } do
		local x, z = rp(t[1], 6)
		tower(f, x, z, t[2], t[3])
	end
	for _, a in { { -112, 20 }, { 170, 80 }, { 65, -30 }, { 235, 110 } } do
		local x, z = rp(a[1], -10)
		arch(f, x, z, math.rad(a[2]))
	end
	for _, w in { { -70, 0.3 }, { -20, 1.2 }, { 220, 2.2 }, { 120, 0.8 } } do
		local x, z = rp(w[1], 18)
		ruinWall(f, x, z, w[2], 26)
	end
	task.wait()
	-- Ağaçlar ve bitkiler: halkada bol
	for _ = 1, 420 do
		local deg = rng:NextNumber(0, 360)
		if not inGap(deg, c.Ring.gaps) then
			local x, z = rp(deg, rng:NextNumber(-70, 70))
			plant(f, x, z, rng, rng:NextNumber() < 0.38 and 1 or nil)
		end
	end
	task.wait()
	-- Uydu adalar
	for _, isl in c.Islets do
		if isl.kind == "temple" then
			temple(f, isl.x + 10, isl.z - 8, 0.7)
		elseif isl.kind == "tower" then
			tower(f, isl.x + 14, isl.z - 10, 22, true)
			arch(f, isl.x - 22, isl.z + 18, 0.5)
		else
			ruinWall(f, isl.x - 20, isl.z, 1.1, 22)
		end
		redX(f, isl.x - 18, isl.z + 22)
		chest(f, isl.x - 18, isl.z + 22, rng:NextNumber(0, 6), "Medium")
		label(f, isl.x, isl.z, isl.name, 46)
		local dx, dz = -isl.x, -isl.z
		local len = math.sqrt(dx * dx + dz * dz)
		smallDock(f, isl.x + dx / len * (isl.r + 30), isl.z + dz / len * (isl.r + 30), dx, dz)
		for _ = 1, 45 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = math.sqrt(rng:NextNumber()) * isl.r * 1.05
			plant(f, isl.x + math.cos(a) * d, isl.z + math.sin(a) * d, rng, rng:NextNumber() < 0.35 and 1 or nil)
		end
		task.wait()
	end
	-- Köşe adaları: sandık, palmiye, küçük iskele
	for _, cn in c.Corners do
		chest(f, cn.x, cn.z, rng:NextNumber(0, 6), "Large")
		redX(f, cn.x, cn.z + 6)
		label(f, cn.x, cn.z, cn.name, 34)
		smallDock(f, cn.x - math.sign(cn.x) * 70, cn.z - math.sign(cn.z) * 40, -math.sign(cn.x), -math.sign(cn.z) * 0.6)
		for _ = 1, 16 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(12, 55)
			plant(f, cn.x + math.cos(a) * d, cn.z + math.sin(a) * d, rng, rng:NextNumber() < 0.5 and 1 or nil)
		end
		task.wait()
	end
	-- Ana atoldeki gizli sandıklar (X işaretleri)
	for _, deg in { -150, -60, 30, 190, 128 } do
		local x, z = rp(deg, rng:NextNumber(-25, 25))
		if deg == 128 then
			x, z = rp(128)
		end
		redX(f, x, z)
		chest(f, x, z, rng:NextNumber(0, 6), "Small")
	end
	label(f, -1140, 200, "Coral Labyrinth", 30)
	label(f, 700, -600, "Whispering Shallows", 28)
	label(f, 0, 0, "Ancient Coral Atoll", 90)
	task.wait()

	-- Mercanlar ve deniz otları (su altında, tekneyi engellemez)
	local corals = Instance.new("Folder")
	corals.Name = "Corals"
	corals.Parent = f
	local L = c.Labyrinth
	for k = 1, 320 do
		coral(corals, W(rng:NextNumber(L.x0, L.x1), rng:NextNumber(L.z0, L.z1), -8), rng)
		if k % 60 == 0 then
			task.wait()
		end
	end
	-- atol çevresindeki resif rafı ve lagün kenarı
	for k = 1, 420 do
		local deg = rng:NextNumber(0, 360)
		local extra = rng:NextNumber() < 0.5 and rng:NextNumber(110, 280) or -rng:NextNumber(120, 240)
		local x, z = rp(deg, extra)
		coral(corals, W(x, z, -14), rng)
		if k % 60 == 0 then
			task.wait()
		end
	end
	for _, isl in c.Islets do
		for _ = 1, 45 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = isl.r + rng:NextNumber(40, 150)
			coral(corals, W(isl.x + math.cos(a) * d, isl.z + math.sin(a) * d, -12), rng)
		end
		task.wait()
	end
	for _, cn in c.Corners do
		for _ = 1, 30 do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(85, 160)
			coral(corals, W(cn.x + math.cos(a) * d, cn.z + math.sin(a) * d, -12), rng)
		end
		task.wait()
	end
	-- batıklar, deniz yılanı, deniz kızı, batık sütunlar
	wreck(f, -760, -480, math.rad(30))
	wreck(f, 420, 1150, math.rad(-60))
	wreck(f, -560, 1250, math.rad(100))
	wreck(f, 1300, -200, math.rad(10))
	serpent(f, 880, -420, math.rad(40))
	serpent(f, -300, -1200, math.rad(-70))
	mermaid(f, 800, 960)
	sunkenPillars(f, -680, 120, rng)
	sunkenPillars(f, 540, -700, rng)
	task.wait()

	-- Varış iskelesi
	local D = c.Dock
	local deckY = 6.5
	local dock = Instance.new("Model")
	dock.Name = "ArrivalDock"
	Util.part(dock, "Deck", Vector3.new(44, 1, 26), CFrame.new(O.X + D.x, deckY - 0.5, O.Z + D.z), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -20, 0, 20 } do
		for _, z in { -11, 11 } do
			Util.pole(dock, "Piling", O.X + D.x + x, O.Z + D.z + z, -10, deckY + 1.5, 1.1, DARK, Enum.Material.Wood)
		end
	end
	local sign = Util.part(dock, "Sign", Vector3.new(18, 4.4, 0.5), CFrame.new(O.X + D.x, deckY + 7, O.Z + D.z - 12.5), Color3.fromRGB(40, 90, 120), Enum.Material.WoodPlanks)
	Util.sign(sign, Enum.NormalId.Back, "ANCIENT CORAL ATOLL", CREAM)
	Util.sign(sign, Enum.NormalId.Front, "Find the treasure! Open the Map to sail home", CREAM)
	for _, x in { -8, 8 } do
		Util.pole(dock, "SignPost", O.X + D.x + x, O.Z + D.z - 12.5, deckY, deckY + 6, 0.6, DARK, Enum.Material.Wood)
	end
	Decor.lamp(dock, Vector3.new(O.X + D.x - 20, deckY, O.Z + D.z + 11))
	Decor.lamp(dock, Vector3.new(O.X + D.x + 20, deckY, O.Z + D.z + 11))
	dock.Parent = f
	local dest = Workspace:FindFirstChild("SeaMapDestinations") or Instance.new("Folder")
	dest.Name = "SeaMapDestinations"
	dest.Parent = Workspace
	for _, n in { "Coral", "Coral_Boat" } do
		local old = dest:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	Util.zone(dest, "Coral", Vector3.new(6, 1, 6), CFrame.new(O.X + D.x, deckY + 0.5, O.Z + D.z + 3))
	Util.zone(dest, "Coral_Boat", Vector3.new(6, 1, 6), CFrame.lookAt(Vector3.new(O.X + D.x, 1, O.Z + D.z + 34), Vector3.new(O.X + D.x, 1, O.Z + D.z - 10)))

	-- Görünmez sınır duvarları (dağların önünde; tırmanılamaz)
	local Wd = c.Wall
	for _, w in { { Wd, 0, 6, Wd * 2 }, { -Wd, 0, 6, Wd * 2 }, { 0, Wd, Wd * 2, 6 }, { 0, -Wd, Wd * 2, 6 } } do
		local p = Util.part(f, "Boundary", Vector3.new(w[3], 800, w[4]), CFrame.new(O.X + w[1], 300, O.Z + w[2]))
		p.Transparency = 1
		p.CanQuery = false
	end
	return f
end

function Atoll.Spots(c)
	local root = Workspace:FindFirstChild("FishingSpots") or Instance.new("Folder")
	root.Name = "FishingSpots"
	root.Parent = Workspace
	local old = root:FindFirstChild("Atoll")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Atoll"
	local colors = { Near = Color3.fromRGB(120, 235, 160), Mid = Color3.fromRGB(255, 214, 120), Far = Color3.fromRGB(255, 130, 130) }
	for i, s in c.Spots do
		local kind = s[1]
		local p = Util.cyl(folder, "Coral" .. kind .. i, 0.4, 24, CFrame.new(O.X + s[2], 0.3, O.Z + s[3]) * CFrame.Angles(0, 0, math.pi / 2), colors[kind], Enum.Material.Neon)
		p.Transparency = 0.7
		p.CanCollide = false
		p.CanQuery = false
		p:SetAttribute("SpotType", kind)
		p:SetAttribute("Ocean", "Coral")
		Util.billboard(p, kind, 6, 70)
	end
	folder.Parent = root
end

-- Aşama aşama çalıştırılabilir: Atoll.Build("terrain") / Atoll.Build("props") / Atoll.Build()
function Atoll.Build(stage)
	local c = cfg()
	O = c.Origin
	if stage == nil or stage == "terrain" then
		Atoll.Sea(c)
		Atoll.Ring(c)
		Atoll.Islets(c)
		Atoll.Border(c)
	end
	if stage == nil or stage == "props" then
		Atoll.Structures(c)
		Atoll.Spots(c)
	end
end

return Atoll
