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
local C
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

local function tower(parent, x, z, h, broken, dia)
	local m = Instance.new("Model")
	m.Name = "RuinTower"
	local k = (dia or 11) / 11
	local g = (ground(x, z) or 6) - 1
	local cf = CFrame.new(O.X + x, g, O.Z + z)
	Util.cyl(m, "Tower", h, 11 * k, cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), STONE:Lerp(MOSS, 0.25), Enum.Material.Cobblestone)
	Util.cyl(m, "Band", 1.4, 12 * k, cf * CFrame.new(0, h * 0.35, 0) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Slate)
	for n = 0, 9 do
		if not broken or n % 3 ~= 0 then
			local a = n / 10 * math.pi * 2
			stone(m, "Merlon", Vector3.new(2.4 * k, 2.8, 2.4 * k), cf * CFrame.new(math.cos(a) * 5 * k, h + 1.4, math.sin(a) * 5 * k))
		end
	end
	for _, a in { 0, math.pi } do
		Util.part(m, "Window", Vector3.new(0.4, 3.4, 1.8), cf * CFrame.new(math.cos(a) * 5.6 * k, h * 0.65, math.sin(a) * 5.6 * k) * CFrame.Angles(0, -a, 0), Color3.fromRGB(28, 24, 20), Enum.Material.Slate)
	end
	m.Parent = parent
	return m
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
local function chest(parent, x, z, yaw, tier, atY)
	local m = Instance.new("Model")
	m.Name = "TreasureChest"
	local g = atY or (ground(x, z) or 6)
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

local function wreck(parent, x, z, yaw, scale)
	local s = scale or 1
	local m = Instance.new("Model")
	m.Name = "Shipwreck"
	local cf = CFrame.new(O.X + x, -2, O.Z + z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(8), 0, math.rad(20))
	Util.ball(m, "Hull", Vector3.new(11, 7, 36) * s, cf, Color3.fromRGB(86, 58, 38), Enum.Material.WoodPlanks)
	Util.part(m, "Deck", Vector3.new(8, 0.6, 26) * s, cf * CFrame.new(0, 2.6 * s, 0), Color3.fromRGB(110, 76, 48), Enum.Material.WoodPlanks)
	Util.cyl(m, "Mast", 22 * s, 1.2 * s, cf * CFrame.new(0, 10 * s, -3 * s) * CFrame.Angles(0, 0, math.rad(72)), DARK, Enum.Material.Wood)
	local sail = Util.part(m, "Sail", Vector3.new(0.2, 8 * s, 7 * s), cf * CFrame.new(-5 * s, 13 * s, -3 * s) * CFrame.Angles(0, 0, math.rad(-22)), Color3.fromRGB(210, 200, 180), Enum.Material.Fabric)
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
	return m
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


-- =====================================================================================
-- Mermaid Island yerleşimi (eskizden). Koordinatlar config'te piksel; P() stud'a çevirir.
-- =====================================================================================

-- eskiz pikseli -> stud (atol merkezine göre)
local function P(a, b)
	return (a - C.Center[1]) * C.Scale, (b - C.Center[2]) * C.Scale
end

-- deniz dikdörtgeni (stud)
local function seaRect()
	local x0, z0 = P(C.Sea.x0, C.Sea.y0)
	local x1, z1 = P(C.Sea.x1, C.Sea.y1)
	return x0, z0, x1, z1
end

-- kale şeridi: yön d (a->b), deniz tarafı normali n (güneydoğu), kapının yeri g
local function bandInfo()
	local ax, az = P(C.Band.a[1], C.Band.a[2])
	local bx, bz = P(C.Band.b[1], C.Band.b[2])
	local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	local dx, dz = (bx - ax) / len, (bz - az) / len
	local nx, nz = -dz, dx
	if nx < 0 then
		nx, nz = -nx, -nz
	end
	return {
		ax = ax, az = az, bx = bx, bz = bz, len = len, dx = dx, dz = dz, nx = nx, nz = nz,
		gx = (ax + bx) / 2, gz = (az + bz) / 2, half = C.Band.halfWidth * C.Scale, gap = C.Band.gateGap,
	}
end

local function mountain(rng, x, z, h)
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

-- noktalar {px, py, rpx} -> çizgi boyunca daireler (stud)
local function chainDiscs(points, jitter, rng, defaultR)
	local discs = {}
	for i = 1, #points do
		local x, z = P(points[i][1], points[i][2])
		local r = (points[i][3] or defaultR) * C.Scale
		table.insert(discs, { x, z, r })
		local nxt = points[i + 1]
		if nxt then
			local x2, z2 = P(nxt[1], nxt[2])
			local r2 = (nxt[3] or defaultR) * C.Scale
			local dist = math.sqrt((x2 - x) ^ 2 + (z2 - z) ^ 2)
			local steps = math.max(1, math.floor(dist / (math.min(r, r2) * 0.7)))
			for s = 1, steps - 1 do
				local t = s / steps
				table.insert(discs, {
					x + (x2 - x) * t + rng:NextNumber(-jitter, jitter),
					z + (z2 - z) * t + rng:NextNumber(-jitter, jitter),
					(r + (r2 - r) * t) * rng:NextNumber(0.85, 1.1),
				})
			end
		end
	end
	return discs
end

local function blobAt(rng, a, b, rpx, extra)
	local x, z = P(a, b)
	local r = rpx * C.Scale
	local discs = { { x, z, r } }
	for _ = 1, extra do
		local ang = rng:NextNumber(0, math.pi * 2)
		table.insert(discs, { x + math.cos(ang) * r * 0.6, z + math.sin(ang) * r * 0.6, r * rng:NextNumber(0.4, 0.65) })
	end
	return discs, x, z, r
end

-- sığ resif rafı (açık renkli su)
local function shelf(x, z, r)
	Terrain:FillCylinder(CFrame.new(O.X + x, -16, O.Z + z), 4, r, SAND)
end

-- 1) Deniz dikdörtgeni + kuzeybatı kanalı ----------------------------------------------
function Atoll.Sea(c)
	local R = c.Clear
	local tile = 200
	for x = R.x0, R.x1 - 1, tile do
		for z = R.z0, R.z1 - 1, tile do
			Terrain:FillBlock(CFrame.new(O.X + x + tile / 2, 160, O.Z + z + tile / 2), Vector3.new(tile, 440, tile), Enum.Material.Air)
		end
		task.wait()
	end
	local function water(xa, za, xb, zb)
		local cx, cz = O.X + (xa + xb) / 2, O.Z + (za + zb) / 2
		local w, d = xb - xa, zb - za
		Terrain:FillBlock(CFrame.new(cx, c.SeabedY - 4, cz), Vector3.new(w, 8, d), SAND)
		Terrain:FillBlock(CFrame.new(cx, c.SeabedY / 2, cz), Vector3.new(w, -c.SeabedY, d), WATER)
	end
	local x0, z0, x1, z1 = seaRect()
	local x = x0
	while x < x1 do
		local w = math.min(tile, x1 - x)
		local z = z0
		while z < z1 do
			local d = math.min(tile, z1 - z)
			water(x, z, x + w, z + d)
			z += d
		end
		x += w
		task.wait()
	end
	-- kale kapısının ardındaki kanal: köşeden dışarı, çapraz
	local B = bandInfo()
	local half = c.Channel.width / 2 + 40
	for s = -100, c.Channel.length + 100, 100 do
		local cx, cz = x0 - B.nx * s, z0 - B.nz * s
		water(cx - half, cz - half, cx + half, cz + half)
	end
end

-- 2) Adalar ----------------------------------------------------------------------------
function Atoll.Land(c)
	local rng = Random.new(201)
	local S = c.Scale

	-- Karşılama adası
	do
		local discs, x, z, r = blobAt(rng, c.Welcome.x, c.Welcome.y, c.Welcome.r, 6)
		land(discs, LEAFY)
		hill(x + r * 0.2, z - r * 0.25, 14, rng)
		shelf(x, z, r + 170)
	end
	-- Random Treasure Island
	do
		local discs, x, z, r = blobAt(rng, c.TreasureIsland.x, c.TreasureIsland.y, c.TreasureIsland.r, 5)
		land(discs, GRASS)
		shelf(x, z, r + 150)
	end
	task.wait()
	-- Star Island: 5 kollu yıldız
	do
		local x, z = P(c.Star.x, c.Star.y)
		local R = c.Star.r * S
		local discs = { { x, z, R * 0.42 } }
		for k = 0, 4 do
			local a = math.rad(-90 + k * 72)
			for _, f in { 0.55, 0.8, 1.0 } do
				table.insert(discs, { x + math.cos(a) * R * f, z + math.sin(a) * R * f, R * (0.3 - 0.15 * f) })
			end
		end
		land(discs, GRASS)
		shelf(x, z, R + 160)
	end
	task.wait()
	-- Ana tapınak adası
	do
		local discs = chainDiscs(c.MainTemple.points, 10, rng, 60)
		for _ = 1, 5 do
			local d = discs[rng:NextInteger(1, #discs)]
			local a = rng:NextNumber(0, math.pi * 2)
			table.insert(discs, { d[1] + math.cos(a) * d[3] * 0.6, d[2] + math.sin(a) * d[3] * 0.6, d[3] * rng:NextNumber(0.4, 0.6) })
		end
		land(discs, LEAFY)
		local tx, tz = P(c.MainTemple.points[2][1], c.MainTemple.points[2][2])
		shelf(tx, tz, 330)
	end
	task.wait()
	-- 4 hilal ada
	for _, arc in c.Crescents do
		local discs = chainDiscs(arc, 8, rng, c.CrescentR)
		land(discs, LEAFY)
		for _, d in discs do
			shelf(d[1], d[2], d[3] + 110)
		end
		task.wait()
	end
	-- minik adalar
	for _, isl in c.Islets do
		local discs, x, z, r = blobAt(rng, isl[1], isl[2], isl[3], 3)
		land(discs, LEAFY)
		shelf(x, z, r + 110)
	end
	-- Small Ancient Temple
	do
		local discs = chainDiscs(c.SmallTemple.points, 12, rng, 60)
		land(discs, GRASS)
		local tx, tz = P(c.SmallTemple.temple[1], c.SmallTemple.temple[2])
		hill(tx + 150, tz + 20, 14, rng)
		for _, d in discs do
			shelf(d[1], d[2], d[3] + 100)
		end
	end
	task.wait()
	-- Büyük batığın yattığı kumsal ve ölü canavarın kum şeridi
	do
		local bx, bz = P(c.BigShip.x, c.BigShip.y)
		land(chainDiscs({ { c.BigShip.x - 25, c.BigShip.y - 40, c.BigShip.r }, { c.BigShip.x + 5, c.BigShip.y + 35, c.BigShip.r } }, 4, rng, 30), SAND)
		shelf(bx, bz, 190)
		land(chainDiscs(c.Monster.points, 8, rng, 28), SAND)
		local mx, mz = P(c.Monster.skeleton[1], c.Monster.skeleton[2])
		shelf(mx, mz, 250)
	end
	task.wait()

	-- Kale şeridi: kapının iki yanında kara, kapı aralığı su kalır
	local B = bandInfo()
	local center = { B.gx, B.gz }
	local k = 0
	while true do
		local off = B.gap + k * 40
		if off > B.len / 2 + 60 then
			break
		end
		for _, sg in { -1, 1 } do
			local x, z = center[1] + B.dx * off * sg, center[2] + B.dz * off * sg
			land({ { x, z, B.half } }, k % 3 == 0 and LEAFY or GRASS)
			-- deniz kenarında kum plaj
			column(x + B.nx * (B.half - 8), z + B.nz * (B.half - 8), 28, 3, SAND)
		end
		k += 1
		if k % 4 == 0 then
			task.wait()
		end
	end
	-- şeridin arka (kuzeybatı) tarafında kale dağları (kapı çevresi boş kalır)
	local mrng = Random.new(540)
	for t = 270, B.len / 2 + 120, 110 do
		for _, sg in { -1, 1 } do
			local x = center[1] + B.dx * t * sg - B.nx * B.half * 0.8
			local z = center[2] + B.dz * t * sg - B.nz * B.half * 0.8
			mountain(mrng, x, z, mrng:NextNumber(110, 190))
		end
		task.wait()
	end
end

-- 3) Labirent (5x5 kaya + mercan duvarı) ------------------------------------------------
function Atoll.Maze(c)
	local rng = Random.new(402)
	local L = c.Labyrinth
	local x0, z0 = P(L.x0, L.y0)
	local x1, z1 = P(L.x1, L.y1)
	local n = L.cells
	local cw, ch = (x1 - x0) / n, (z1 - z0) / n
	-- vw[i][j]: j. satırdaki i. çizgide dikey duvar; hw[i][j]: i. sütunda j. çizgide yatay duvar
	local vw, hw = {}, {}
	for i = 0, n do
		vw[i] = {}
		for j = 0, n - 1 do
			vw[i][j] = true
		end
	end
	for i = 0, n - 1 do
		hw[i] = {}
		for j = 0, n do
			hw[i][j] = true
		end
	end
	local seen = {}
	local function key(i, j)
		return i * 100 + j
	end
	local stack = { { 0, 0 } }
	seen[key(0, 0)] = true
	while #stack > 0 do
		local cur = stack[#stack]
		local i, j = cur[1], cur[2]
		local opts = {}
		if i > 0 and not seen[key(i - 1, j)] then
			table.insert(opts, { i - 1, j, "W" })
		end
		if i < n - 1 and not seen[key(i + 1, j)] then
			table.insert(opts, { i + 1, j, "E" })
		end
		if j > 0 and not seen[key(i, j - 1)] then
			table.insert(opts, { i, j - 1, "N" })
		end
		if j < n - 1 and not seen[key(i, j + 1)] then
			table.insert(opts, { i, j + 1, "S" })
		end
		if #opts == 0 then
			table.remove(stack)
		else
			local o = opts[rng:NextInteger(1, #opts)]
			if o[3] == "W" then
				vw[i][j] = false
			elseif o[3] == "E" then
				vw[i + 1][j] = false
			elseif o[3] == "N" then
				hw[i][j] = false
			else
				hw[i][j + 1] = false
			end
			seen[key(o[1], o[2])] = true
			table.insert(stack, { o[1], o[2] })
		end
	end
	-- girişler: batıdan (orta satır) ve güneyden (3. sütun)
	vw[0][math.floor(n / 2)] = false
	hw[math.min(3, n - 1)][n] = false

	local function wallLine(xa, za, xb, zb)
		local len = math.sqrt((xb - xa) ^ 2 + (zb - za) ^ 2)
		local steps = math.max(1, math.floor(len / 8))
		for s = 0, steps do
			local t = s / steps
			ball(xa + (xb - xa) * t + rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1, 2), za + (zb - za) * t + rng:NextNumber(-1.5, 1.5), rng:NextNumber(6, 8), ROCK)
		end
	end
	for i = 0, n do
		for j = 0, n - 1 do
			if vw[i][j] then
				wallLine(x0 + i * cw, z0 + j * ch, x0 + i * cw, z0 + (j + 1) * ch)
			end
		end
		task.wait()
	end
	for i = 0, n - 1 do
		for j = 0, n do
			if hw[i][j] then
				wallLine(x0 + i * cw, z0 + j * ch, x0 + (i + 1) * cw, z0 + j * ch)
			end
		end
		task.wait()
	end
	for i = 0, n do
		for j = 0, n do
			ball(x0 + i * cw, 4, z0 + j * ch, 10, ROCK)
		end
	end
	-- ortadaki kumsal (sandık burada)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	land({ { cx, cz, 26 } }, SAND)
	shelf(cx, cz, 360)
end

-- 4) Dağ sınırı + kuzeybatı kanalı ---------------------------------------------------------
function Atoll.Border(c)
	local rng = Random.new(500)
	local x0, z0, x1, z1 = seaRect()
	local out = 60
	local function place(x, z)
		if (x - x0) ^ 2 + (z - z0) ^ 2 < 300 ^ 2 then
			return -- kanalın ağzı
		end
		local nearSE = (x - x1) ^ 2 + (z - z1) ^ 2 < 800 ^ 2
		local h = nearSE and rng:NextNumber(250, 340) or rng:NextNumber(170, 290)
		mountain(rng, x + rng:NextNumber(-25, 25), z + rng:NextNumber(-25, 25), h)
	end
	local step = 150
	for x = x0, x1, step do
		place(x, z0 - out)
		place(x, z1 + out)
		task.wait()
	end
	for z = z0, z1, step do
		place(x0 - out, z)
		place(x1 + out, z)
		task.wait()
	end
	place(x1 + out, z1 + out)
	place(x0 - out, z1 + out)
	place(x1 + out, z0 - out)

	-- kanalın iki yanı ve ucu
	local B = bandInfo()
	local ox, oz = -B.nx, -B.nz
	local L = c.Channel.length
	local side = c.Channel.width / 2 + 130
	for s = 0, L, 110 do
		for _, sg in { -1, 1 } do
			mountain(rng, x0 + ox * s + B.dx * side * sg, z0 + oz * s + B.dz * side * sg, rng:NextNumber(130, 200))
		end
		task.wait()
	end
	local ex, ez = x0 + ox * (L + 60), z0 + oz * (L + 60)
	for _, off in { -300, -150, 0, 150, 300 } do
		mountain(rng, ex + B.dx * off, ez + B.dz * off, rng:NextNumber(170, 240))
	end
end

-- =====================================================================================
-- Yapılar
-- =====================================================================================

local function scatterPlants(parent, cx, cz, r, n, rng, palmP)
	for _ = 1, n do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = math.sqrt(rng:NextNumber()) * r * 0.9
		plant(parent, cx + math.cos(a) * d, cz + math.sin(a) * d, rng, rng:NextNumber() < palmP and 1 or nil)
	end
end

local function scatterCorals(folder, cx, cz, rmin, rmax, n, rng, y)
	for _ = 1, n do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(rmin, rmax)
		coral(folder, W(cx + math.cos(a) * d, cz + math.sin(a) * d, y or -12), rng)
	end
end

-- düz ahşap iskele (pilingli)
local function pier(parent, x0, z0, x1, z1, width, name)
	local y = 6.5
	local p0, p1 = W(x0, z0, y - 0.5), W(x1, z1, y - 0.5)
	Util.beam(parent, name or "Pier", p0, p1, width, 1, WOOD, Enum.Material.WoodPlanks)
	local dir = p1 - p0
	local len = dir.Magnitude
	dir = dir.Unit
	local side = Vector3.new(-dir.Z, 0, dir.X) * (width / 2 - 0.8)
	for s = 6, len, 10 do
		local p = p0 + dir * s
		for _, sg in { -1, 1 } do
			Util.pole(parent, "Piling", p.X + side.X * sg, p.Z + side.Z * sg, -10, y + 1.4, 0.9, DARK, Enum.Material.Wood)
		end
	end
end

-- Ana tapınak: sütunlu, yuvarlak açık tavanlı, ortasında kurban sunağı
local function mainTemple(parent, x, z)
	local m = Instance.new("Model")
	m.Name = "MainTemple"
	local g = (ground(x, z) or 4) - 1
	local cf = CFrame.new(O.X + x, g, O.Z + z)
	local hw, hd = 36, 32
	for k = 0, 2 do
		stone(m, "Step", Vector3.new(hw * 2 + 12 - k * 4, 2.2, hd * 2 + 12 - k * 4), cf * CFrame.new(0, 1.1 + k * 2.2, 0), k == 0)
	end
	local top = 6.6
	local colH = 24
	local function pillar(lx, lz)
		Util.cyl(m, "Column", colH, 4.6, cf * CFrame.new(lx, top + colH / 2, lz) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Marble)
	end
	for _, lx in { -30, -18, -6, 6, 18, 30 } do
		pillar(lx, -26)
		pillar(lx, 26)
	end
	for _, lz in { -13, 0, 13 } do
		pillar(-30, lz)
		pillar(30, lz)
	end
	-- arka (doğu) duvar
	stone(m, "BackWall", Vector3.new(3, colH, hd * 2 - 4), cf * CFrame.new(hw - 2, top + colH / 2, 0), true)
	-- tavan: ortada yuvarlak (açık) gökyüzü deliği
	local roofY = top + colH + 1.5
	local hole = 12
	local function slab(sx, sz, lx, lz)
		stone(m, "Roof", Vector3.new(sx, 3, sz), cf * CFrame.new(lx, roofY, lz))
	end
	local rl = hd + 4 - hole
	slab(hw * 2 + 8, rl, 0, -(hole + rl / 2))
	slab(hw * 2 + 8, rl, 0, hole + rl / 2)
	local rw = hw + 4 - hole
	slab(rw, hole * 2, -(hole + rw / 2), 0)
	slab(rw, hole * 2, hole + rw / 2, 0)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			stone(m, "RoofCorner", Vector3.new(7, 3, 7), cf * CFrame.new(sx * 9.6, roofY, sz * 9.6) * CFrame.Angles(0, math.rad(45), 0))
		end
	end
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		stone(m, "Rim", Vector3.new(4.2, 3, 3), cf * CFrame.new(math.cos(a) * 13.6, roofY + 3, math.sin(a) * 13.6) * CFrame.Angles(0, -a + math.pi / 2, 0), true)
	end
	-- kurban sunağı
	Util.cyl(m, "AltarBase", 2.4, 9, cf * CFrame.new(0, top + 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Marble)
	Util.cyl(m, "AltarPedestal", 4, 4, cf * CFrame.new(0, top + 4.4, 0) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Marble)
	local bowl = Util.cyl(m, "AltarBowl", 1.2, 6.4, cf * CFrame.new(0, top + 7, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 150, 230), Enum.Material.Neon)
	bowl:SetAttribute("Role", "SacrificeAltar")
	Util.light(bowl, 2, 40, Color3.fromRGB(120, 190, 255))
	local flame = Util.ball(m, "AltarFlame", Vector3.new(2.4, 3.4, 2.4), cf * CFrame.new(0, top + 9.2, 0), Color3.fromRGB(150, 220, 255), Enum.Material.Neon)
	flame.CanCollide = false
	local shaft = Util.cyl(m, "LightShaft", 70, 20, cf * CFrame.new(0, top + 30, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(190, 225, 255), Enum.Material.Neon)
	shaft.Transparency = 0.9
	shaft.CanCollide = false
	shaft.CanQuery = false
	shaft.CastShadow = false
	m.Parent = parent
	return m
end

-- Çadır (A çatılı)
local function tent(parent, x, z, yaw, color)
	local m = Instance.new("Model")
	m.Name = "Tent"
	local g = ground(x, z) or 4
	local cf = CFrame.new(O.X + x, g, O.Z + z) * CFrame.Angles(0, yaw, 0)
	for _, s in { -1, 1 } do
		Util.part(m, "Side", Vector3.new(9, 0.5, 11), cf * CFrame.new(s * 2.9, 3.2, 0) * CFrame.Angles(0, 0, -s * math.rad(50)), color, Enum.Material.Fabric)
	end
	Util.part(m, "Floor", Vector3.new(6, 0.3, 10.5), cf * CFrame.new(0, 0.2, 0), DARK, Enum.Material.WoodPlanks)
	m.Parent = parent
end

-- Antrenman hedef gemisi (yüzer, hedef tahtalı)
local function practiceBoat(parent, x, z, yaw)
	local m = Instance.new("Model")
	m.Name = "PracticeBoat"
	local cf = CFrame.new(O.X + x, 0.6, O.Z + z) * CFrame.Angles(0, yaw, 0)
	Util.ball(m, "Hull", Vector3.new(12, 6, 30), cf * CFrame.new(0, 1.5, 0), Color3.fromRGB(110, 76, 48), Enum.Material.WoodPlanks)
	Util.part(m, "Deck", Vector3.new(9, 0.6, 22), cf * CFrame.new(0, 3.8, 0), Color3.fromRGB(130, 90, 56), Enum.Material.WoodPlanks)
	Util.cyl(m, "Mast", 14, 0.9, cf * CFrame.new(0, 11, -2) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Wood)
	for k, spec in { { 9, Color3.fromRGB(210, 40, 40) }, { 6.2, Color3.fromRGB(245, 245, 245) }, { 3.2, Color3.fromRGB(210, 40, 40) } } do
		local t = Util.cyl(m, "Target", 0.5 + k * 0.1, spec[1], cf * CFrame.new(0, 9, -2.6 - k * 0.1) * CFrame.Angles(0, math.pi / 2, 0), spec[2], Enum.Material.SmoothPlastic)
		t.CanCollide = false
	end
	m:SetAttribute("PracticeTarget", true)
	m.Parent = parent
	return m
end

-- Ölü deniz canavarı iskeleti (süs)
local function skeleton(parent, x, z, yaw)
	local m = Instance.new("Model")
	m.Name = "SeaMonsterSkeleton"
	local bone = Color3.fromRGB(232, 224, 200)
	local base = CFrame.new(O.X + x, 2, O.Z + z) * CFrame.Angles(0, yaw, 0)
	local function pt(lx, ly, lz)
		return (base * CFrame.new(lx, ly, lz)).Position
	end
	for k = 0, 23 do
		local lx = k * 5.5
		local ly = math.sin(k * 0.5) * 2.4
		local lz = math.sin(k * 0.28) * 3.5
		local s = math.max(2.2, 6.2 - k * 0.15)
		Util.ball(m, "Vertebra", Vector3.new(s, s * 0.9, s), base * CFrame.new(lx, ly, lz), bone, Enum.Material.Slate)
		if k >= 2 and k <= 13 then
			local rh = 12 - math.abs(k - 7) * 0.9
			for _, sg in { -1, 1 } do
				local a = pt(lx, ly, lz + sg * 1.5)
				local b = pt(lx, ly + rh * 0.5, lz + sg * rh * 0.75)
				local c2 = pt(lx, ly + rh, lz + sg * rh * 0.55)
				local d = pt(lx, ly + rh * 1.15, lz + sg * rh * 0.1)
				Util.rod(m, "Rib", a, b, 0.9, bone, Enum.Material.Slate)
				Util.rod(m, "Rib", b, c2, 0.8, bone, Enum.Material.Slate)
				Util.rod(m, "Rib", c2, d, 0.6, bone, Enum.Material.Slate)
			end
		end
	end
	local head = base * CFrame.new(-14, 4, 0)
	Util.ball(m, "Skull", Vector3.new(20, 9, 11), head, bone, Enum.Material.Slate)
	Util.part(m, "Jaw", Vector3.new(14, 2, 8), head * CFrame.new(-6, -4.5, 0) * CFrame.Angles(0, 0, math.rad(8)), bone, Enum.Material.Slate)
	for k = 0, 6 do
		for _, sg in { -1, 1 } do
			Util.part(m, "Tooth", Vector3.new(0.8, 2.4, 0.8), head * CFrame.new(-4 - k * 1.7, -4.2, sg * 3.4), Color3.fromRGB(245, 240, 225), Enum.Material.Slate)
		end
	end
	for _, sg in { -1, 1 } do
		Util.ball(m, "EyeSocket", Vector3.new(2.6, 2.6, 2.6), head * CFrame.new(-3, 1.8, sg * 4.2), Color3.fromRGB(30, 28, 26), Enum.Material.Slate)
	end
	m.Parent = parent
	return m
end

-- Dev kale kapısı: kapının iki yanında nöbet kuleleri, kapalı ahşap kanatlar (anahtarla açılacak)
local function castleGate(parent, B)
	local m = Instance.new("Model")
	m.Name = "CastleGate"
	local basis = CFrame.lookAt(Vector3.new(O.X + B.gx, 0, O.Z + B.gz), Vector3.new(O.X + B.gx + B.nx, 0, O.Z + B.gz + B.nz))
	local wood = Color3.fromRGB(120, 78, 44)
	for _, sx in { -1, 1 } do
		local panel = Util.part(m, "GatePanel", Vector3.new(64, 48, 5), basis * CFrame.new(sx * 32.5, 16, 0), wood, Enum.Material.WoodPlanks)
		panel:SetAttribute("Locked", true)
		CollectionService:AddTag(panel, "PassSeal")
		for _, by in { 4, 16, 28 } do
			Util.part(m, "GateBand", Vector3.new(64, 2.4, 5.8), basis * CFrame.new(sx * 32.5, by, 0), DARK, Enum.Material.Metal)
		end
	end
	stone(m, "GateLintel", Vector3.new(210, 10, 14), basis * CFrame.new(0, 46, 0), true)
	local sign = Util.part(m, "GateSign", Vector3.new(70, 9, 1), basis * CFrame.new(0, 58, 0), Color3.fromRGB(40, 90, 120), Enum.Material.WoodPlanks)
	Util.sign(sign, Enum.NormalId.Front, "SEALED GATE - the Mermaid has the key", CREAM)
	m.Parent = parent
	for _, sg in { -1, 1 } do
		tower(parent, B.gx + B.dx * 95 * sg, B.gz + B.dz * 95 * sg, 54, false, 20)
	end
	return m
end

function Atoll.Structures(c)
	local f = Util.fresh("Model", "Atoll")
	local stale = Workspace:FindFirstChild("AtollMermaid")
	if stale then
		stale:Destroy()
	end
	local rng = Random.new(600)
	local S = c.Scale
	local B = bandInfo()
	local deckY = 6.5

	-- Karşılama adası: mermaid kayası, başlangıç iskelesi, gemi iskelesi ---------------------
	local wx, wz = P(c.Welcome.x, c.Welcome.y)
	local wr = c.Welcome.r * S
	scatterPlants(f, wx, wz, wr, 45, rng, 0.5)
	label(f, wx, wz, "Welcome Island", 50)
	pier(f, wx - wr + 8, wz, wx - wr - 95, wz, 10, "StartDock")
	Decor.lamp(f, Vector3.new(O.X + wx - wr - 90, deckY, O.Z + wz + 6))
	Decor.lamp(f, Vector3.new(O.X + wx - wr - 30, deckY, O.Z + wz + 6))
	local rkx, rkz = wx - wr - 12, wz + 30
	ball(rkx + 9, 0, rkz - 5, 7, ROCK)
	ball(rkx - 9, -1, rkz + 6, 6, ROCK)
	local npc = mermaid(f, rkx, rkz)
	npc:SetAttribute("Role", "Mermaid")
	local dest = Workspace:FindFirstChild("SeaMapDestinations") or Instance.new("Folder")
	dest.Name = "SeaMapDestinations"
	dest.Parent = Workspace
	for _, n in { "Coral", "Coral_Boat" } do
		local old = dest:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local sp = Vector3.new(O.X + wx - wr - 72, deckY + 0.5, O.Z + wz)
	Util.zone(dest, "Coral", Vector3.new(6, 1, 6), CFrame.lookAt(sp, Vector3.new(O.X + rkx, deckY + 0.5, O.Z + rkz)))
	local bp = Vector3.new(O.X + wx - wr - 58, 1, O.Z + wz - 22)
	Util.zone(dest, "Coral_Boat", Vector3.new(6, 1, 6), CFrame.lookAt(bp, bp + Vector3.new(-60, 0, 0)))
	task.wait()

	-- Random Treasure Island ------------------------------------------------------------------
	local tx, tz = P(c.TreasureIsland.x, c.TreasureIsland.y)
	local tr = c.TreasureIsland.r * S
	scatterPlants(f, tx, tz, tr, 22, rng, 0.6)
	redX(f, tx, tz)
	chest(f, tx, tz, rng:NextNumber(0, 6), "Large")
	label(f, tx, tz, "Random Treasure Island", 40)
	pier(f, tx + tr - 6, tz + 10, tx + tr + 50, tz + 10, 7, "TreasureDock")

	-- Star Island -----------------------------------------------------------------------------
	local sx, sz = P(c.Star.x, c.Star.y)
	local sR = c.Star.r * S
	scatterPlants(f, sx, sz, sR, 30, rng, 0.55)
	redX(f, sx, sz)
	chest(f, sx, sz, rng:NextNumber(0, 6), "Large")
	label(f, sx, sz, "Star Island", 46)
	pier(f, sx - sR * 0.5, sz + sR * 0.55, sx - sR * 0.5 - 20, sz + sR * 0.55 + 55, 7, "StarDock")
	task.wait()

	-- Ana tapınak adası: tapınak, sunak, iskele --------------------------------------------------
	local mx, mz = P(c.MainTemple.temple[1], c.MainTemple.temple[2])
	mainTemple(f, mx, mz)
	local d0x, d0z = P(c.MainTemple.dock.from[1], c.MainTemple.dock.from[2])
	local d1x, d1z = P(c.MainTemple.dock.to[1], c.MainTemple.dock.to[2])
	pier(f, d0x, d0z, d1x, d1z, 10, "TempleDock")
	Decor.lamp(f, Vector3.new(O.X + d1x + 4, deckY, O.Z + d1z + 6))
	label(f, mx, mz, "Main Temple (Sacrifice Altar)", 80)
	for _, p in c.MainTemple.points do
		local px_, pz_ = P(p[1], p[2])
		scatterPlants(f, px_, pz_, p[3] * S, 14, rng, 0.45)
	end
	-- tapınağın önüne kalıntılar
	do
		local ax, az = P(1240, 760)
		arch(f, ax, az, math.rad(90))
		local wx2, wz2 = P(1300, 770)
		ruinWall(f, wx2, wz2, 0.4, 22)
	end

	-- Hilal adalar + minik adalar -------------------------------------------------------------
	local corals = Instance.new("Folder")
	corals.Name = "Corals"
	corals.Parent = f
	for i, arc in c.Crescents do
		local discs = chainDiscs(arc, 0, Random.new(700 + i), c.CrescentR)
		for _, d in discs do
			scatterPlants(f, d[1], d[2], d[3], 3, rng, 0.4)
			scatterCorals(corals, d[1], d[2], d[3] + 25, d[3] + 120, 4, rng, -12)
		end
		task.wait()
	end
	for _, isl in c.Islets do
		local x, z = P(isl[1], isl[2])
		scatterPlants(f, x, z, isl[3] * S, 6, rng, 0.6)
	end

	-- Small Ancient Temple ------------------------------------------------------------------------
	local sx2, sz2 = P(c.SmallTemple.temple[1], c.SmallTemple.temple[2])
	temple(f, sx2, sz2, 0.8)
	tower(f, sx2 + 70, sz2 + 22, 24, true)
	ruinWall(f, sx2 - 60, sz2 + 18, 0.3, 26)
	ruinWall(f, sx2 + 30, sz2 - 50, 1.4, 22)
	arch(f, sx2 + 110, sz2 + 70, 0.6)
	local cx2, cz2 = sx2 + 150, sz2 + 60
	redX(f, cx2, cz2)
	chest(f, cx2, cz2, rng:NextNumber(0, 6), "Large")
	for _, p in c.SmallTemple.points do
		local px_, pz_ = P(p[1], p[2])
		scatterPlants(f, px_, pz_, p[3] * S, 10, rng, 0.4)
	end
	label(f, sx2, sz2, "Small Ancient Temple", 52)
	task.wait()

	-- Labirent: ortada sandık ---------------------------------------------------------------------
	local L = c.Labyrinth
	local lx0, lz0 = P(L.x0, L.y0)
	local lx1, lz1 = P(L.x1, L.y1)
	local lcx, lcz = (lx0 + lx1) / 2, (lz0 + lz1) / 2
	redX(f, lcx, lcz)
	chest(f, lcx, lcz, rng:NextNumber(0, 6), "Large")
	label(f, lcx, lcz, "Labyrinth", 40)
	for _ = 1, 90 do
		coral(corals, W(rng:NextNumber(lx0, lx1), rng:NextNumber(lz0, lz1), -9), rng)
	end
	task.wait()

	-- Büyük batık gemi (sandık yanında) --------------------------------------------------------------
	local bx, bz = P(c.BigShip.x, c.BigShip.y)
	wreck(f, bx, bz, math.rad(35), 2.2)
	local chx, chz = bx + 22, bz - 6
	redX(f, chx, chz)
	chest(f, chx, chz, rng:NextNumber(0, 6), "Large")
	label(f, bx, bz, "Big Flooded Ship", 60)
	scatterCorals(corals, bx, bz, 60, 160, 25, rng, -9)

	-- Üstteki batık gemiler (ahşap ve metal toplanır) ---------------------------------------------------
	for i, s in c.SunkenShips do
		local x, z = P(s[1], s[2])
		wreck(f, x, z, math.rad(rng:NextNumber(0, 360)), 1.3 + (i % 2) * 0.4)
		for _ = 1, 8 do
			local d = Util.part(f, "Debris", Vector3.new(rng:NextNumber(3, 6), 0.5, 1.2), CFrame.new(O.X + x + rng:NextNumber(-45, 45), 0.2, O.Z + z + rng:NextNumber(-45, 45)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), WOOD, Enum.Material.WoodPlanks)
			d.CanCollide = false
			d:SetAttribute("Loot", i % 2 == 0 and "Metal" or "Wood")
		end
		scatterCorals(corals, x, z, 40, 130, 8, rng, -10)
	end
	local ssx, ssz = P(c.SunkenShips[2][1], c.SunkenShips[2][2])
	label(f, ssx, ssz, "Sunken Ships", 50)
	task.wait()

	-- Ölü deniz canavarı ----------------------------------------------------------------------------
	local kx, kz = P(c.Monster.skeleton[1], c.Monster.skeleton[2])
	skeleton(f, kx - 70, kz, math.rad(-25))
	label(f, kx, kz, "Dead Sea Monster", 40)

	-- Kale şeridi: kapı, çadırlar, iskeleler, hedef gemisi, işaret noktaları ---------------------------------
	castleGate(f, B)
	label(f, B.gx - B.nx * 20, B.gz - B.nz * 20, "Castle Gate", 80)
	local tentColors = { Color3.fromRGB(190, 60, 50), Color3.fromRGB(200, 170, 90), Color3.fromRGB(70, 110, 160), Color3.fromRGB(160, 90, 50) }
	local ti = 0
	for _, off in { -330, -270, -210, 210, 270, 330 } do
		ti += 1
		tent(f, B.gx + B.dx * off + B.nx * 40, B.gz + B.dz * off + B.nz * 40, math.atan2(-B.dx, -B.dz), tentColors[(ti - 1) % #tentColors + 1])
	end
	label(f, B.gx + B.dx * 270 + B.nx * 40, B.gz + B.dz * 270 + B.nz * 40, "Practice Base", 36)
	-- iki iskele (başlangıç iskelesi sağda)
	for _, off in { -230, 240 } do
		local sx_, sz_ = B.gx + B.dx * off + B.nx * (B.half + 10), B.gz + B.dz * off + B.nz * (B.half + 10)
		pier(f, sx_ - B.nx * 20, sz_ - B.nz * 20, sx_ + B.nx * 60, sz_ + B.nz * 60, 8, "PracticeDock")
	end
	-- hedef gemisi ve işaret noktaları (ileride antrenman mantığı bunlara bağlanır)
	local tbx, tbz = B.gx + B.nx * 330 + B.dx * -160, B.gz + B.nz * 330 + B.dz * -160
	practiceBoat(f, tbx, tbz, math.atan2(-B.dx, -B.dz))
	Util.zone(f, "PracticeStart", Vector3.new(6, 1, 6), CFrame.new(O.X + B.gx + B.dx * 240 + B.nx * (B.half + 50), 7, O.Z + B.gz + B.dz * 240 + B.nz * (B.half + 50)))
	Util.zone(f, "PirateSpot", Vector3.new(6, 1, 6), CFrame.new(O.X + B.gx + B.dx * -120 + B.nx * 45, 7, O.Z + B.gz + B.dz * -120 + B.nz * 45))
	Util.zone(f, "TargetStill", Vector3.new(6, 1, 6), CFrame.new(O.X + tbx, 1, O.Z + tbz))
	Util.zone(f, "TargetPathA", Vector3.new(6, 1, 6), CFrame.new(O.X + tbx + B.dx * 320, 1, O.Z + tbz + B.dz * 320))
	Util.zone(f, "TargetPathB", Vector3.new(6, 1, 6), CFrame.new(O.X + tbx + B.dx * -320, 1, O.Z + tbz + B.dz * -320))
	task.wait()

	-- Mercanlar (açık sularda, tekneyi engellemez) ---------------------------------------------------------------
	local x0, z0, x1, z1 = seaRect()
	for k = 1, 160 do
		local x, z = rng:NextNumber(x0 + 100, x1 - 100), rng:NextNumber(z0 + 100, z1 - 100)
		-- kale şeridine ve labirente yaklaşma
		local inBand = (x - B.gx) * B.nx + (z - B.gz) * B.nz < B.half + 80 and math.abs((x - B.gx) * B.dx + (z - B.gz) * B.dz) < B.len / 2 + 80
		if not inBand then
			coral(corals, W(x, z, -14), rng)
		end
		if k % 40 == 0 then
			task.wait()
		end
	end

	-- Görünmez sınır duvarları (dağların önünde). Kuzeybatı köşesinde kanalın ağzı açık bırakılır -----------------
	local function wall(cx_, cz_, sx_, sz_)
		local p = Util.part(f, "Boundary", Vector3.new(sx_, 800, sz_), CFrame.new(O.X + cx_, 300, O.Z + cz_))
		p.Transparency = 1
		p.CanQuery = false
	end
	local gap = 300
	wall(x0, (z0 + gap + z1) / 2, 6, z1 - (z0 + gap))
	wall((x0 + gap + x1) / 2, z0, x1 - (x0 + gap), 6)
	wall(x1, (z0 + z1) / 2, 6, z1 - z0)
	wall((x0 + x1) / 2, z1, x1 - x0, 6)
	local ox, oz = -B.nx, -B.nz
	local ex, ez = x0 + ox * (c.Channel.length + 60), z0 + oz * (c.Channel.length + 60)
	local endWall = Util.part(f, "Boundary", Vector3.new(760, 800, 6), CFrame.lookAt(Vector3.new(O.X + ex, 300, O.Z + ez), Vector3.new(O.X + ex + ox, 300, O.Z + ez + oz)))
	endWall.Transparency = 1
	endWall.CanQuery = false
	label(f, ex - ox * 120, ez - oz * 120, "Beyond the gate: Island 3 (coming soon)", 60)
	return f
end

-- Aşama aşama çalıştırılabilir (Studio Edit modunda command bar / execute_luau):
--   B.Atoll("sea") ; B.Atoll("land") ; B.Atoll("maze") ; B.Atoll("border") ; B.Atoll("props")
--   B.Atoll("terrain") = sea + land + maze + border ; B.Atoll() = hepsi
function Atoll.Build(stage)
	C = cfg()
	O = C.Origin
	local all = stage == nil
	if all or stage == "terrain" or stage == "sea" then
		Atoll.Sea(C)
	end
	if all or stage == "terrain" or stage == "land" then
		Atoll.Land(C)
	end
	if all or stage == "terrain" or stage == "maze" then
		Atoll.Maze(C)
	end
	if all or stage == "terrain" or stage == "border" then
		Atoll.Border(C)
	end
	if all or stage == "props" then
		Atoll.Structures(C)
	end
end

return Atoll
