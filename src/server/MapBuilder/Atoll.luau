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

-- Ada parçası: daireler {x, z, r}. Kıyıdan deniz dibine YUMUŞAK yamaç (basamak / plaka yok).
-- o.height: üst yüzey yüksekliği (varsayılan 4; negatifse su altı tepesi)
-- o.slope: yamacın yatay yayılımı / dikey düşüş (küçük = dik kıyı, büyük = yayvan sığlık)
-- o.mid: su üstü yamaç malzemesi; o.wobble: her dairenin yamaç düzensizliği
local LR = Random.new(77)
local function land(discs, topMat, o)
	o = o or {}
	local H = o.height or 4
	local slope = o.slope or 1.6
	local wob = o.wobble or 0.12
	local mid = o.mid or topMat or GRASS
	local f = {}
	for i = 1, #discs do
		f[i] = 1 + LR:NextNumber(-wob, wob)
	end
	local n = 0
	local y = -40
	while y < H - 0.5 do
		local mat = y < 2 and SAND or mid
		for i, d in discs do
			column(d[1], d[2], d[3] + (H - y) * slope * f[i], y, mat)
			n += 1
			if n % 100 == 0 then
				task.wait()
			end
		end
		y += 2.5
	end
	for _, d in discs do
		column(d[1], d[2], d[3], H, topMat or GRASS)
	end
end

-- Yüzeye serpiştirilmiş farklı zemin lekeleri (toprak, çamur, kaya...) -> adalar tek renk durmaz
local function patches(discs, mats, count, H, rng, rmin, rmax)
	for _ = 1, count do
		local d = discs[rng:NextInteger(1, #discs)]
		local a = rng:NextNumber(0, math.pi * 2)
		local dist = math.sqrt(rng:NextNumber()) * d[3] * 0.8
		Terrain:FillCylinder(CFrame.new(O.X + d[1] + math.cos(a) * dist, H - 1.5, O.Z + d[2] + math.sin(a) * dist), 3, rng:NextNumber(rmin or 5, rmax or 14), mats[rng:NextInteger(1, #mats)])
	end
end

-- Yumuşak tümsek (küresel kalıp): h yükseklik, R taban yarıçapı, base zemin yüksekliği
local function mound(x, z, h, R, mat, base)
	local rho = (R * R + h * h) / (2 * h)
	ball(x, (base or 4) + h - rho, z, rho, mat)
end

-- Kayalık tepe: üst üste küçülen 3 kalıp (alt: çim, üst: kaya)
local function peak(x, z, h, R, rng, lowMat, rockMat, base)
	mound(x, z, h * 0.55, R, lowMat, base)
	mound(x + rng:NextNumber(-R, R) * 0.12, z + rng:NextNumber(-R, R) * 0.12, h * 0.85, R * 0.68, rockMat, base)
	mound(x + rng:NextNumber(-R, R) * 0.18, z + rng:NextNumber(-R, R) * 0.18, h, R * 0.4, rockMat, base)
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

local function tower(parent, x, z, h, broken, dia, baseY)
	local m = Instance.new("Model")
	m.Name = "RuinTower"
	local k = (dia or 11) / 11
	local g = baseY or ((ground(x, z) or 6) - 1)
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

-- Deniz kızının kayası: iskelenin yanında, suyun içinde; üstü düz oturma yeri, yosunlu, kabuk / mercan / deniz yıldızlı.
-- NPC ("Mermaid Marina") Studio'da elle konur; oturma noktası "SeatMarker" parçasında (görünmez).
local function mermaid(parent, x, z)
	local m = Instance.new("Model")
	m.Name = "MermaidRock"
	local base = Vector3.new(O.X + x, 0, O.Z + z)
	local SLATE = Enum.Material.Slate
	local function blob(name, dx, dy, dz, sx, sy, sz, col, mat, yaw)
		return Util.ball(m, name, Vector3.new(sx, sy, sz), CFrame.new(base + Vector3.new(dx, dy, dz)) * CFrame.Angles(0, yaw or 0, 0), col, mat or SLATE)
	end
	local g1, g2, g3 = Color3.fromRGB(116, 111, 106), Color3.fromRGB(100, 97, 95), Color3.fromRGB(132, 126, 118)
	blob("RockRoot", 0, -6, 0, 22, 26, 20, g2)
	blob("RockMain", 0, 0.5, 0, 22, 16, 19, g1)
	blob("RockLeft", -8, -1, 3, 14, 12, 12, g2, nil, 0.5)
	blob("RockRight", 8, -1, -2, 13, 11, 12, g3, nil, 1.1)
	blob("RockBack", 0, 0, -7, 16, 13, 11, g3, nil, 0.3)
	blob("RockBackrest", -3, 3, -6.5, 8, 15, 6.5, g1, nil, 0.4)
	-- düz oturma yeri
	Util.cyl(m, "Seat", 1.2, 9.5, CFrame.new(base + Vector3.new(0.5, 7.9, 1.2)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(150, 146, 138), SLATE)
	-- yosun
	for _, mp in { { -4.5, 8.9, -3.5, 8, 2.4, 6 }, { 6, 7.2, 3, 5, 1.8, 4 }, { -8, 6.5, 6, 4.6, 1.6, 3.6 }, { 5.5, 7.8, -4.5, 5, 1.8, 4 } } do
		blob("Moss", mp[1], mp[2], mp[3], mp[4], mp[5], mp[6], MOSS, Enum.Material.Grass)
	end
	-- etrafta daha küçük kayalar
	for k = 1, 7 do
		local a = k * 0.9 + 0.4
		local d = 12 + (k % 3) * 2.2
		local sz = 3 + (k % 4) * 1.2
		blob("Pebble", math.cos(a) * d, 0.6 - sz / 3, math.sin(a) * d, sz * 1.5, sz, sz * 1.3, (k % 2 == 0) and g1 or g3, nil, a)
	end
	-- mercan tomurcukları (kayanın dibinde)
	for k = 1, 6 do
		local a = k * 1.1
		local col = CORALS[(k % #CORALS) + 1]
		local cx, cz = math.cos(a) * 10.5, math.sin(a) * 10
		for j = 1, 3 do
			local h = 2 + j * 0.9
			blob("Coral", cx + (j - 2) * 0.9, 1.6 + h / 2 - 3, cz + (j % 2) * 0.8, 1, h, 1, col, Enum.Material.SmoothPlastic)
		end
	end
	-- kabuklar + deniz yıldızları
	for _, sp in { { 6.5, 6.4, 7.5, 0.4 }, { -9.5, 4.6, 5.5, 2.3 } } do
		local cf = CFrame.new(base + Vector3.new(sp[1], sp[2], sp[3])) * CFrame.Angles(0, sp[4], 0)
		Util.ball(m, "ClamBottom", Vector3.new(2.4, 0.9, 2), cf, Color3.fromRGB(255, 214, 224), Enum.Material.Slate)
		Util.ball(m, "ClamTop", Vector3.new(2.4, 0.8, 2), cf * CFrame.new(-0.2, 0.7, 0) * CFrame.Angles(0, 0, math.rad(35)), Color3.fromRGB(255, 200, 215), Enum.Material.Slate)
	end
	for _, sp in { { -2.5, 8.55, 7.2 }, { 7.8, 6.2, 4.2 }, { -10.5, 3.5, 2 } } do
		local star = Util.ball(m, "Starfish", Vector3.new(1.8, 0.35, 1.8), CFrame.new(base + Vector3.new(sp[1], sp[2], sp[3])), Color3.fromRGB(255, 140, 70), Enum.Material.SmoothPlastic)
		star.CanCollide = false
	end
	local pearl = Util.ball(m, "Pearl", Vector3.new(1.1, 1.1, 1.1), CFrame.new(base + Vector3.new(3.8, 9.1, 3.8)), Color3.fromRGB(255, 250, 240), Enum.Material.Neon)
	pearl.CanCollide = false
	Util.light(pearl, 0.8, 14, Color3.fromRGB(190, 230, 255))
	-- oturma noktası (NPC'nin ayağı buraya gelir); iskeleye (kuzeyden güneye) bakar
	local seat = Util.zone(m, "SeatMarker", Vector3.new(1, 1, 1), CFrame.lookAt(base + Vector3.new(0.5, 8.5, 1.2), base + Vector3.new(0.5, 8.5, 40)))
	seat.Name = "SeatMarker"
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
	local b = Util.billboard(p, text, 0, 150)
	b.Size = UDim2.fromOffset(150, 22) -- küçük yazı
	b.MaxDistance = (h or 30) + 60 -- sadece yaklaşınca görünür
	return p
end

-- ağaç / kaya konmayacak alanlar (tapınakların içi)
local EXCL = {}
local function exclude(x, z, hx, hz)
	table.insert(EXCL, { x, z, hx, hz })
end
local function blocked(x, z)
	for _, e in EXCL do
		if math.abs(x - e[1]) < e[3] and math.abs(z - e[2]) < e[4] then
			return true
		end
	end
	return false
end

local function plant(parent, x, z, rng, kind)
	if blocked(x, z) then
		return false
	end
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

-- Dağ: çeşitli türler. rock = çıplak kaya, green = yeşil yamaç + kaya tepe, mixed = alt yeşil / üst kaya
local function mountain(rng, x, z, h, kind)
	kind = kind or "mixed"
	local base = h * 0.75
	local y = -30
	while y < h do
		local t = math.max(y, 0) / h
		local r = base * (1 - t) ^ 1.2 + 6
		local mat
		if y < 1 then
			mat = kind == "rock" and ROCK or SAND -- su hattında kumsal / kaya eteği
		elseif kind == "rock" then
			local q = rng:NextNumber()
			mat = q < 0.6 and ROCK or (q < 0.85 and Enum.Material.Slate or Enum.Material.Basalt)
		elseif kind == "green" then
			mat = t > 0.62 and ROCK or (rng:NextNumber() < 0.3 and GRASS or LEAFY)
		else
			mat = t > 0.4 and (rng:NextNumber() < 0.75 and ROCK or Enum.Material.Slate) or (rng:NextNumber() < 0.5 and LEAFY or GRASS)
		end
		ball(x + rng:NextNumber(-4, 4), y, z + rng:NextNumber(-4, 4), r, mat)
		y += math.max(r * 0.33, 8)
	end
end

-- Tüm dağların listesi (deterministik; Border terrain'i kurar, Structures yeşil yamaçlara ağaç dikmek için okur).
-- Kale/kapı tarafı (batı, kuzey, kanal) ESKİ deniz ölçüsüyle ve eski rng sırasıyla üretilir, böylece deniz doğu/güneye
-- büyüse de o taraf aynı kalır. Eski doğu/güney dağları atılır, yeni sınıra yenileri konur.
local CORNER_R = 560 -- harita köşelerinin yuvarlaklık yarıçapı (stud)
local function mountainSpecs(c)
	local x0, z0, x1, z1 = seaRect()
	local B = bandInfo()
	local ox1 = (C.SeaOld.x1 - C.Center[1]) * C.Scale
	local oz1 = (C.SeaOld.y1 - C.Center[2]) * C.Scale
	local specs = {}
	local function add(rng, x, z, h, drop)
		local q = rng:NextNumber()
		table.insert(specs, { x = x, z = z, h = h, drop = drop, kind = q < 0.38 and "rock" or (q < 0.72 and "green" or "mixed"), seed = rng:NextInteger(1, 1000000) })
	end
	local function edge(rng, cx1, cz1, px, pz, nx_, nz_, drop)
		if (px - x0) ^ 2 + (pz - z0) ^ 2 < 300 ^ 2 then
			return -- kanalın ağzı
		end
		local nearSE = (px - cx1) ^ 2 + (pz - cz1) ^ 2 < 800 ^ 2
		local h = nearSE and rng:NextNumber(250, 340) or rng:NextNumber(170, 290)
		local off = h * 0.75 + 6 + 30
		add(rng, px + nx_ * off + rng:NextNumber(-25, 25), pz + nz_ * off + rng:NextNumber(-25, 25), h, drop)
	end
	local step = 150
	-- 1) eski düzen (eski dikdörtgen, eski rng sırası)
	local rng = Random.new(500)
	for x = x0, ox1, step do
		edge(rng, ox1, oz1, x, z0, 0, -1, false)
		edge(rng, ox1, oz1, x, oz1, 0, 1, true)
	end
	for z = z0, oz1, step do
		edge(rng, ox1, oz1, x0, z, -1, 0, false)
		edge(rng, ox1, oz1, ox1, z, 1, 0, true)
	end
	edge(rng, ox1, oz1, ox1, oz1, 0.707, 0.707, true)
	edge(rng, ox1, oz1, x0, oz1, -0.707, 0.707, true)
	edge(rng, ox1, oz1, ox1, z0, 0.707, -0.707, true)
	-- kanalın iki yanı ve ucu
	local ox, oz = -B.nx, -B.nz
	local L = c.Channel.length
	local side = c.Channel.width / 2 + 130
	for s = 0, L, 110 do
		for _, sg in { -1, 1 } do
			add(rng, x0 + ox * s + B.dx * side * sg, z0 + oz * s + B.dz * side * sg, rng:NextNumber(130, 200))
		end
	end
	local ex, ez = x0 + ox * (L + 60), z0 + oz * (L + 60)
	for _, off in { -300, -150, 0, 150, 300 } do
		add(rng, ex + B.dx * off, ez + B.dz * off, rng:NextNumber(170, 240))
	end
	-- surun arka (kuzeybatı) tarafı
	for t = 270, B.len / 2 + 120, 110 do
		for _, sg in { -1, 1 } do
			add(rng, B.gx + B.dx * t * sg - B.nx * B.half * 0.8, B.gz + B.dz * t * sg - B.nz * B.half * 0.8, rng:NextNumber(110, 190))
		end
	end
	local out = {}
	for _, sp in specs do
		if not sp.drop then
			table.insert(out, sp)
		end
	end
	-- 2) yeni doğu ve güney sınırı + uzayan kuzey/batı kenarları (ayrı rng)
	specs = out
	local r2 = Random.new(900)
	local xn = x0 + math.floor((ox1 - x0) / step + 1e-6) * step + step
	for x = xn, x1, step do
		edge(r2, x1, z1, x, z0, 0, -1, false)
	end
	for x = x0, x1, step do
		edge(r2, x1, z1, x, z1, 0, 1, false)
	end
	local zn = z0 + math.floor((oz1 - z0) / step + 1e-6) * step + step
	for z = zn, z1, step do
		edge(r2, x1, z1, x0, z, -1, 0, false)
	end
	for z = z0, z1, step do
		edge(r2, x1, z1, x1, z, 1, 0, false)
	end
	edge(r2, x1, z1, x1, z1, 0.707, 0.707, false)
	edge(r2, x1, z1, x0, z1, -0.707, 0.707, false)
	edge(r2, x1, z1, x1, z0, 0.707, -0.707, false)
	-- yuvarlak köşelerin yayı boyunca dağlar
	for _, cn in { { x1, z0, -1, 1 }, { x1, z1, -1, -1 }, { x0, z1, 1, -1 } } do
		local ix, iz = cn[1] + cn[3] * CORNER_R, cn[2] + cn[4] * CORNER_R
		for t = 0.08, 1.5, 0.19 do
			local h = r2:NextNumber(190, 300)
			local d = CORNER_R + h * 0.75 + 70
			add(r2, ix - cn[3] * math.cos(t) * d, iz - cn[4] * math.sin(t) * d, h)
		end
	end
	return specs
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
	local GROUND, MUD, SLATE, SANDSTONE, LIME, BASALT, PAVE =
		Enum.Material.Ground, Enum.Material.Mud, Enum.Material.Slate, Enum.Material.Sandstone, Enum.Material.Limestone, Enum.Material.Basalt, Enum.Material.Pavement

	-- Karşılama adası: küçük, geniş kumsallı, hafif kumullu
	do
		local discs, x, z, r = blobAt(rng, c.Welcome.x, c.Welcome.y, c.Welcome.r, 4)
		land(discs, LEAFY, { slope = 2.2, height = 4 })
		patches(discs, { SAND, GROUND, SAND }, 6, 4, rng, 5, 10)
		mound(x - r * 0.3, z + r * 0.1, 7, r * 0.55, LEAFY)
		mound(x + r * 0.15, z - r * 0.4, 4, r * 0.35, SAND)
		mound(x - r * 0.05, z + r * 0.55, 3, r * 0.3, SAND)
	end
	-- Random Treasure Island: sık orman, ortasında kayalık tepe (sandık tepede)
	do
		local discs, x, z, r = blobAt(rng, c.TreasureIsland.x, c.TreasureIsland.y, c.TreasureIsland.r, 6)
		land(discs, GRASS, { slope = 1.3, height = 5, mid = LEAFY })
		patches(discs, { MUD, GROUND, LEAFY }, 9, 5, rng, 6, 13)
		peak(x, z, 16, r * 0.7, rng, LEAFY, ROCK, 5)
	end
	task.wait()
	-- Star Island: 5 kollu yıldız; kıyılar dik kaya, ortada düz kaya platformu, kol uçlarında sivri kayalar
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
		land(discs, GRASS, { slope = 0.9, height = 5, mid = ROCK })
		patches(discs, { ROCK, SLATE, GRASS, BASALT }, 12, 5, rng, 5, 12)
		land({ { x, z, 28 } }, SLATE, { slope = 0.6, height = 9, mid = ROCK })
		for k = 0, 4 do
			local a = math.rad(-90 + k * 72)
			peak(x + math.cos(a) * R * 0.78, z + math.sin(a) * R * 0.78, 14 + rng:NextNumber(0, 8), R * 0.2, rng, GRASS, ROCK, 5)
		end
	end
	task.wait()
	-- Ana tapınak adası: taş platformlu, güneyinde ormanlık tepeler
	do
		local discs = chainDiscs(c.MainTemple.points, 10, rng, 60)
		for _ = 1, 5 do
			local d = discs[rng:NextInteger(1, #discs)]
			local a = rng:NextNumber(0, math.pi * 2)
			table.insert(discs, { d[1] + math.cos(a) * d[3] * 0.6, d[2] + math.sin(a) * d[3] * 0.6, d[3] * rng:NextNumber(0.4, 0.6) })
		end
		land(discs, LEAFY, { slope = 1.5, height = 4 })
		patches(discs, { GROUND, SANDSTONE, GRASS, ROCK, MUD }, 22, 4, rng, 8, 20)
		local tx, tz = P(c.MainTemple.temple[1], c.MainTemple.temple[2])
		-- tapınak platformu (dikdörtgene yakın, köşeleri yuvarlak)
		local plat = { { tx, tz, 109 } }
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(plat, { tx + sx * 71, tz + sz * 61, 85 })
			end
		end
		land(plat, PAVE, { slope = 1.1, height = 7, mid = ROCK })
		local sx_, sz_ = P(c.MainTemple.points[3][1], c.MainTemple.points[3][2])
		peak(sx_ + 6, sz_ - 4, 20, 44, rng, LEAFY, ROCK, 4)
		mound(sx_ - 40, sz_ + 30, 9, 26, GRASS, 4)
		-- plazanın çevresindeki halkada tepecikler (kuzey ve güney geniş, doğu dar)
		mound(tx - 60, tz - 195, 14, 30, GRASS, 4)
		mound(tx + 95, tz - 185, 11, 26, LEAFY, 4)
		mound(tx - 150, tz - 170, 9, 22, ROCK, 4)
		mound(tx - 90, tz + 205, 10, 26, GRASS, 4)
		mound(tx + 70, tz + 235, 15, 32, LEAFY, 4)
		mound(tx + 175, tz + 110, 8, 20, ROCK, 4)
		mound(tx + 180, tz - 80, 8, 18, GRASS, 4)
	end
	task.wait()
	-- 4 hilal ada: her biri başka karakterde (kumsal / kayalık / orman / kumtaşı)
	local styles = {
		{ top = SAND, mid = SAND, mats = { GRASS, SANDSTONE, GROUND }, h = 3, mound = SAND },
		{ top = GRASS, mid = ROCK, mats = { ROCK, SLATE, GROUND }, h = 5, mound = ROCK },
		{ top = LEAFY, mid = LEAFY, mats = { MUD, GRASS, GROUND }, h = 4, mound = LEAFY },
		{ top = GRASS, mid = SANDSTONE, mats = { SANDSTONE, SAND, LIME }, h = 4, mound = SANDSTONE },
	}
	for i, arc in c.Crescents do
		local st = styles[i]
		local discs = chainDiscs(arc, 8, rng, c.CrescentR)
		land(discs, st.top, { slope = 1.3 + i * 0.15, height = st.h, mid = st.mid })
		patches(discs, st.mats, 8, st.h, rng, 5, 11)
		for k = 1, #discs, 3 do
			local d = discs[k]
			mound(d[1], d[2], rng:NextNumber(4, 10), d[3] * 0.7, st.mound, st.h)
		end
		task.wait()
	end
	-- minik adalar
	for k, isl in c.Islets do
		local discs, x, z, r = blobAt(rng, isl[1], isl[2], isl[3], 3)
		local sty = ({ SAND, LEAFY, GRASS, SAND, LEAFY, Enum.Material.Ground })[(k - 1) % 6 + 1]
		land(discs, sty, { slope = 1.4 + (k % 3) * 0.3, height = 3 + (k % 3), mid = (k % 2 == 0) and ROCK or nil })
		if k == 2 or k == 5 or k == 7 then
			mound(x, z, 8, r * 0.5, ROCK, 3)
		end
	end
	-- Small Ancient Temple: kayalık, yüksek adalar
	do
		local discs = chainDiscs(c.SmallTemple.points, 12, rng, 60)
		land(discs, GRASS, { slope = 1.1, height = 5, mid = ROCK })
		patches(discs, { ROCK, SLATE, GROUND, LIME }, 14, 5, rng, 6, 14)
		local tx, tz = P(c.SmallTemple.temple[1], c.SmallTemple.temple[2])
		land({ { tx, tz, 46 }, { tx + 34, tz + 8, 34 } }, SLATE, { slope = 0.7, height = 9, mid = ROCK })
		peak(tx - 150, tz + 10, 22, 44, rng, GRASS, ROCK, 5)
	end
	task.wait()
	-- Büyük batığın su altı tepesi (kumsal DEĞİL: dipte yatar, yüzeye çıkmaz)
	do
		local bx, bz = P(c.BigShip.x, c.BigShip.y)
		land({ { bx, bz, 78 }, { bx + 34, bz - 22, 56 }, { bx - 30, bz + 24, 50 } }, SAND, { slope = 2.6, height = c.BigShip.floorY, wobble = 0.2 })
	end
	-- üstteki batık gemilerin oturduğu su altı sığlıkları
	for _, sh in c.SunkenShips do
		local sx, sz = P(sh[1], sh[2])
		land({ { sx, sz, 34 } }, SAND, { slope = 2.4, height = -4, wobble = 0.15 })
	end
	task.wait()

	-- Kale şeridi: kapının iki yanında kara, kapı aralığı su kalır
	local B = bandInfo()
	local center = { B.gx, B.gz }
	local k = 0
	local bandDiscs = {}
	while true do
		local off = B.gap + k * 40
		if off > B.len / 2 + 60 then
			break
		end
		for _, sg in { -1, 1 } do
			local x, z = center[1] + B.dx * off * sg, center[2] + B.dz * off * sg
			table.insert(bandDiscs, { x, z, B.half })
			land({ { x, z, B.half } }, k % 3 == 0 and LEAFY or GRASS, { slope = 1.2, height = 5, mid = GRASS })
		end
		k += 1
		if k % 4 == 0 then
			task.wait()
		end
	end
	patches(bandDiscs, { GROUND, PAVE, GROUND, SANDSTONE }, 22, 5, rng, 6, 14)
end

-- Dairesel labirent (yukarıdan yuvarlak): ortada sandık adası, etrafında halkalar, TEK giriş (dış duvarda).
-- Deterministik: terrain ve props aşamaları aynı düzeni üretir.
local function mazeData(c)
	local L = c.Labyrinth
	local cx, cz = P(L.x, L.y)
	local rings = L.rings
	local N = {}
	for r = 1, rings do
		N[r] = 4 * 2 ^ (r - 1) -- halka başına dilim sayısı: 4, 8, 16, 32
	end
	local function radius(b)
		return L.centerR + b * L.pitch
	end
	-- arcOpen[b][j]: b. çemberin j. yayında geçit var mı. Yay sayısı: b=0 -> N[1]; b<rings -> N[b+1]; b=rings -> N[rings]
	local function arcCount(b)
		if b == 0 then
			return N[1]
		elseif b >= rings then
			return N[rings]
		end
		return N[b + 1]
	end
	local arcOpen, radialOpen = {}, {}
	for b = 0, rings do
		arcOpen[b] = {}
		for j = 0, arcCount(b) - 1 do
			arcOpen[b][j] = false
		end
	end
	for r = 1, rings do
		radialOpen[r] = {}
		for i = 0, N[r] - 1 do
			radialOpen[r][i] = false
		end
	end
	local rng = Random.new(402)
	local seen = {}
	local function key(r, i)
		return r * 1000 + i
	end
	-- komşular: {r, i, açıcı fonksiyon}
	local function neighbors(r, i)
		local out = {}
		if r == 0 then
			for j = 0, N[1] - 1 do
				table.insert(out, { 1, j, function() arcOpen[0][j] = true end })
			end
			return out
		end
		local n = N[r]
		local prev, nxt = (i - 1) % n, (i + 1) % n
		table.insert(out, { r, prev, function() radialOpen[r][prev] = true end })
		table.insert(out, { r, nxt, function() radialOpen[r][i] = true end })
		if r == 1 then
			table.insert(out, { 0, 0, function() arcOpen[0][i] = true end })
		else
			table.insert(out, { r - 1, i // 2, function() arcOpen[r - 1][i] = true end })
		end
		if r < rings then
			table.insert(out, { r + 1, 2 * i, function() arcOpen[r][2 * i] = true end })
			table.insert(out, { r + 1, 2 * i + 1, function() arcOpen[r][2 * i + 1] = true end })
		end
		return out
	end
	-- giriş: dış halkada, batı-güneybatı yönünde (merkez adasına giden en uzun yol için DFS girişten başlar)
	local entry = math.floor(L.entryDeg / 360 * N[rings]) % N[rings]
	arcOpen[rings][entry] = true
	local stack = { { rings, entry } }
	seen[key(rings, entry)] = true
	while #stack > 0 do
		local cur = stack[#stack]
		local opts = {}
		for _, nb in neighbors(cur[1], cur[2]) do
			if not seen[key(nb[1], nb[2])] then
				table.insert(opts, nb)
			end
		end
		if #opts == 0 then
			table.remove(stack)
		else
			local o = opts[rng:NextInteger(1, #opts)]
			o[3]()
			seen[key(o[1], o[2])] = true
			table.insert(stack, { o[1], o[2] })
		end
	end
	return { cx = cx, cz = cz, rings = rings, N = N, radius = radius, arcCount = arcCount, arcOpen = arcOpen, radialOpen = radialOpen }
end

-- Tüm duvarların örnek noktaları {x, z} (step ≈ nokta aralığı, stud)
local function mazeWalls(M, step)
	local pts = {}
	local function arc(R, a0, a1)
		local len = R * (a1 - a0)
		local n = math.max(1, math.floor(len / step))
		for s = 0, n do
			local a = a0 + (a1 - a0) * s / n
			table.insert(pts, { M.cx + math.cos(a) * R, M.cz + math.sin(a) * R })
		end
	end
	for b = 0, M.rings do
		local cnt = M.arcCount(b)
		for j = 0, cnt - 1 do
			if not M.arcOpen[b][j] then
				arc(M.radius(b), j / cnt * math.pi * 2, (j + 1) / cnt * math.pi * 2)
			end
		end
	end
	for r = 1, M.rings do
		for i = 0, M.N[r] - 1 do
			if not M.radialOpen[r][i] then
				local a = (i + 1) / M.N[r] * math.pi * 2
				local R0, R1 = M.radius(r - 1), M.radius(r)
				local n = math.max(1, math.floor((R1 - R0) / step))
				for s = 0, n do
					local R = R0 + (R1 - R0) * s / n
					table.insert(pts, { M.cx + math.cos(a) * R, M.cz + math.sin(a) * R })
				end
			end
		end
	end
	return pts
end

-- 3) Labirent: yuvarlak, alçak, dalgalı taş duvarlar ------------------------------------------------
function Atoll.Maze(c)
	local rng = Random.new(403)
	local M = mazeData(c)
	local n = 0
	for _, p in mazeWalls(M, 6) do
		-- duvarlar suyun biraz üstüne çıkar (alçak), yuvarlak ve üst üste binen toplar
		local hgt = -4 + 1.6 * math.sin(p[1] * 0.045 + p[2] * 0.03) + rng:NextNumber(-0.6, 0.6)
		ball(p[1] + rng:NextNumber(-1.2, 1.2), hgt, p[2] + rng:NextNumber(-1.2, 1.2), rng:NextNumber(9, 10.5), ROCK)
		n += 1
		if n % 150 == 0 then
			task.wait()
		end
	end
	-- ortadaki kum adası (sandık burada)
	land({ { M.cx, M.cz, 26 } }, SAND, { slope = 2.2, height = 3, wobble = 0.05 })
	Terrain:FillCylinder(CFrame.new(O.X + M.cx + 8, 1.5, O.Z + M.cz - 6), 3, 9, Enum.Material.Sandstone)
	mound(M.cx - 12, M.cz + 9, 6, 10, ROCK, 3)
end

-- 4) Kıyı şeridi (kumsal) + dağ sınırı ---------------------------------------------------------
function Atoll.Border(c)
	local x0, z0, x1, z1 = seaRect()
	local skirt, gap = 120, 300
	-- deniz kenarı boyunca: kıyıdan dışa doğru düz kumsal, denizin altında yumuşak eğimle iner
	local function block(xa, za, xb, zb, yTop)
		local w, d = math.abs(xb - xa), math.abs(zb - za)
		local tile = 220
		local nx_, nz_ = math.max(1, math.ceil(w / tile)), math.max(1, math.ceil(d / tile))
		for i = 0, nx_ - 1 do
			for j = 0, nz_ - 1 do
				local cw, cd = w / nx_, d / nz_
				Terrain:FillBlock(CFrame.new(O.X + math.min(xa, xb) + cw * (i + 0.5), (BOTTOM + yTop) / 2, O.Z + math.min(za, zb) + cd * (j + 0.5)), Vector3.new(cw, yTop - BOTTOM, cd), SAND)
			end
		end
	end
	local levels = {}
	for y = -40, 1, 3 do
		table.insert(levels, y)
	end
	table.insert(levels, 4)
	for _, y in levels do
		local e = math.max(-y, 0) * 1.5
		block(x0 - skirt, z0 + gap, x0 + e, z1 + skirt, y) -- batı
		block(x0 + gap, z0 - skirt, x1 + skirt, z0 + e, y) -- kuzey
		block(x1 - e, z0 - skirt, x1 + skirt, z1 + skirt, y) -- doğu
		block(x0 - skirt, z1 - e, x1 + skirt, z1 + skirt, y) -- güney
		task.wait()
	end
	-- yuvarlatılmış köşeler (kale köşesi hariç): çeyrek dairenin dışında kalan köşe alanı kumsal + kara olur
	local CR = CORNER_R
	for _, cn in { { x1, z0, -1, 1 }, { x1, z1, -1, -1 }, { x0, z1, 1, -1 } } do
		local kx, kz, sx, sz = cn[1], cn[2], cn[3], cn[4]
		local ix, iz = kx + sx * CR, kz + sz * CR
		local cell, n = 8, 0
		for a = 0, CR - cell, cell do
			for b = 0, CR - cell, cell do
				local px, pz = kx + sx * (a + cell / 2), kz + sz * (b + cell / 2)
				local d = math.sqrt((px - ix) ^ 2 + (pz - iz) ^ 2) - CR
				if d > -62 then
					local top = d < 0 and d * 0.66 or math.min(2 + d * 0.09, 10)
					local mat = top < 3.5 and SAND or (math.noise(px / 40, pz / 40, 2.2) > 0 and LEAFY or GRASS)
					Terrain:FillBlock(CFrame.new(O.X + px, (BOTTOM + top) / 2, O.Z + pz), Vector3.new(cell, top - BOTTOM, cell), mat)
				end
				n += 1
				if n % 400 == 0 then
					task.wait()
				end
			end
		end
	end
	-- dağlar
	for i, sp in mountainSpecs(c) do
		mountain(Random.new(sp.seed), sp.x, sp.z, sp.h, sp.kind)
		if i % 3 == 0 then
			task.wait()
		end
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

-- Mercanlar: arazinin gerçek yüksekliğine (yamaç / deniz tabanı) oturur, havada asılı kalmaz
local function scatterCorals(folder, cx, cz, rmin, rmax, n, rng)
	for _ = 1, n do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(rmin, rmax)
		local px, pz = cx + math.cos(a) * d, cz + math.sin(a) * d
		local gy = ground(px, pz)
		if gy and gy < -0.5 then
			coral(folder, W(px, pz, gy), rng)
		end
	end
end

-- Zemin üstü yerel nokta
local function gp(x, z, dy)
	return Vector3.new(O.X + x, (ground(x, z) or 4) + (dy or 0), O.Z + z)
end

-- Meşale (ahşap direk, metal kase, ateş + ışık). Adadaki tüm lambaların yerine.
local function torch(parent, pos)
	local m = Instance.new("Model")
	m.Name = "Torch"
	Util.pole(m, "Pole", pos.X, pos.Z, pos.Y, pos.Y + 8, 0.7, DARK, Enum.Material.Wood)
	Util.cyl(m, "Cup", 1.6, 2.6, CFrame.new(pos.X, pos.Y + 8.4, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(60, 54, 48), Enum.Material.Metal)
	local flame = Util.ball(m, "Flame", Vector3.new(1.9, 2.8, 1.9), CFrame.new(pos.X, pos.Y + 9.9, pos.Z), Color3.fromRGB(255, 160, 60), Enum.Material.Neon)
	flame.CanCollide = false
	Util.light(flame, 1.5, 32, Color3.fromRGB(255, 170, 80))
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 0
	fire.Parent = flame
	m.Parent = parent
	return m
end

-- Küçük süs yapıları ------------------------------------------------------------------------
local function logProp(parent, x, z, yaw, len)
	local p = gp(x, z, 1.1)
	return Util.cyl(parent, "Log", len, 2.2, CFrame.new(p) * CFrame.Angles(0, yaw, 0), Color3.fromRGB(110, 84, 58), Enum.Material.Wood)
end

local function shellProp(parent, x, z, rng)
	local p = gp(x, z, 0)
	local col = CORALS[rng:NextInteger(1, #CORALS)]:Lerp(Color3.new(1, 1, 1), 0.55)
	local yaw = rng:NextNumber(0, 6.28)
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	Util.ball(parent, "ClamBottom", Vector3.new(7, 2.6, 6), cf * CFrame.new(0, 1, 0), col, Enum.Material.Slate)
	Util.ball(parent, "ClamTop", Vector3.new(7, 2.2, 6), cf * CFrame.new(-0.6, 3.1, 0) * CFrame.Angles(0, 0, math.rad(38)), col, Enum.Material.Slate)
	local pearl = Util.ball(parent, "Pearl", Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(0, 2, 0), Color3.fromRGB(255, 250, 240), Enum.Material.Neon)
	pearl.CanCollide = false
end

local function standingStone(parent, x, z, h, rng, glowColor)
	local p = gp(x, z, h / 2 - 1)
	local cf = CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), rng:NextNumber(0, 6.28), rng:NextNumber(-0.06, 0.06))
	stone(parent, "StandingStone", Vector3.new(3.6, h, 2.6), cf, true)
	if glowColor then
		local r = Util.part(parent, "StoneRune", Vector3.new(0.5, h * 0.5, 0.3), cf * CFrame.new(0, 0, -1.4), glowColor, Enum.Material.Neon)
		r.CanCollide = false
	end
end

local function campfire(parent, x, z, rng)
	local p = gp(x, z, 0)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		Util.part(parent, "FireStone", Vector3.new(2, 1.2, 1.6), CFrame.new(p + Vector3.new(math.cos(a) * 2.6, 0.5, math.sin(a) * 2.6)) * CFrame.Angles(0, -a, 0), Color3.fromRGB(120, 116, 110), Enum.Material.Rock)
	end
	for k = 0, 2 do
		Util.cyl(parent, "FireLog", 4, 0.9, CFrame.new(p + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, k * 1.05, 0.5), DARK, Enum.Material.Wood)
	end
	local flame = Util.ball(parent, "FireGlow", Vector3.new(2, 2.6, 2), CFrame.new(p + Vector3.new(0, 2.2, 0)), Color3.fromRGB(255, 150, 50), Enum.Material.Neon)
	flame.CanCollide = false
	Util.light(flame, 1.6, 36, Color3.fromRGB(255, 160, 70))
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 0
	fire.Parent = flame
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2 + rng:NextNumber(0, 1)
		logProp(parent, x + math.cos(a) * 7, z + math.sin(a) * 7, a + math.pi / 2, 5)
	end
end

local function fallenColumn(parent, x, z, rng)
	local p = gp(x, z, 1.6)
	return Util.cyl(parent, "FallenColumn", rng:NextNumber(10, 17), 3.4, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.12, 0.12)), STONE:Lerp(MOSS, 0.3), Enum.Material.Marble)
end

local function rocksAround(parent, cx, cz, r, n, rng)
	for _ = 1, n do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = math.sqrt(rng:NextNumber()) * r
		local gy = ground(cx + math.cos(a) * d, cz + math.sin(a) * d)
		if gy and gy > 1 and not blocked(cx + math.cos(a) * d, cz + math.sin(a) * d) then
			Decor.rock(parent, Vector3.new(O.X + cx + math.cos(a) * d, gy, O.Z + cz + math.sin(a) * d), rng)
		end
	end
end

local function pirateFlag(parent, x, z)
	local p = gp(x, z, 0)
	Util.pole(parent, "FlagPole", p.X, p.Z, p.Y - 1, p.Y + 22, 0.9, DARK, Enum.Material.Wood)
	Util.part(parent, "Flag", Vector3.new(0.3, 6, 9), CFrame.new(p + Vector3.new(0, 19, 4.8)), Color3.fromRGB(24, 24, 28), Enum.Material.Fabric)
	Util.ball(parent, "Skull", Vector3.new(0.6, 3, 3), CFrame.new(p + Vector3.new(0.3, 19.6, 4.8)), Color3.fromRGB(240, 235, 220), Enum.Material.SmoothPlastic)
end

-- düz ahşap iskele (pilingli). Kök kısmı taş rıhtımla araziye BAĞLANIR (havada kalmaz).
local function pier(parent, x0, z0, x1, z1, width, name)
	local y = 6.5
	local p0, p1 = W(x0, z0, y - 0.5), W(x1, z1, y - 0.5)
	Util.beam(parent, name or "Pier", p0, p1, width, 1, WOOD, Enum.Material.WoodPlanks)
	local dir = p1 - p0
	local len = dir.Magnitude
	dir = dir.Unit
	local quay = Util.part(parent, (name or "Pier") .. "Quay", Vector3.new(width + 4, 11.6, 14), CFrame.lookAt(Vector3.new(p0.X, -0.2, p0.Z), Vector3.new(p0.X, -0.2, p0.Z) + dir), STONE:Lerp(MOSS, 0.3), Enum.Material.Cobblestone)
	quay.Name = (name or "Pier") .. "Quay"
	local side = Vector3.new(-dir.Z, 0, dir.X) * (width / 2 - 0.8)
	for s = 6, len, 10 do
		local p = p0 + dir * s
		for _, sg in { -1, 1 } do
			Util.pole(parent, "Piling", p.X + side.X * sg, p.Z + side.Z * sg, -10, y + 1.4, 0.9, DARK, Enum.Material.Wood)
		end
	end
end

-- Ana tapınak (büyük): sütunlu çevre revağı, ön merdiven, yuvarlak açık tavan, zemin mozaiği, kurban sunağı
local TEMPLE_SCALE = 1.7 -- tapınak bu çarpanla büyütülür (model orijinal ölçüde kurulur, sonra ScaleTo)
local function brazier(parent, cf)
	Util.cyl(parent, "BrazierStem", 4, 2, cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Cobblestone)
	Util.cyl(parent, "BrazierBowl", 1.4, 5, cf * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(60, 54, 48), Enum.Material.Metal)
	local flame = Util.ball(parent, "BrazierFlame", Vector3.new(3, 3.6, 3), cf * CFrame.new(0, 6.4, 0), Color3.fromRGB(255, 160, 60), Enum.Material.Neon)
	flame.CanCollide = false
	Util.light(flame, 1.6, 34, Color3.fromRGB(255, 170, 80))
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 0
	fire.Parent = flame
end

local function mainTemple(parent, x, z)
	local m = Instance.new("Model")
	m.Name = "MainTemple"
	local g = (ground(x, z) or 7) - 1
	local cf = CFrame.new(O.X + x, g, O.Z + z)
	local hw, hd = 52, 44 -- iç alan yarı ölçüleri (x: batı->doğu, z: kuzey->güney). Ön yüz BATI (iskele tarafı)
	local top = 6.6
	local colH = 26
	local GOLD2 = Color3.fromRGB(226, 180, 70)
	local TEAL = Color3.fromRGB(40, 150, 160)
	local rng = Random.new(31)
	-- 3 kat kaide
	for k = 0, 2 do
		stone(m, "Step", Vector3.new(hw * 2 + 16 - k * 4, 2.2, hd * 2 + 16 - k * 4), cf * CFrame.new(0, 1.1 + k * 2.2, 0), k == 0)
	end
	-- ön (batı) geniş merdiven: 8 basamak
	for i = 0, 7 do
		local h = (i + 1) * 0.825
		stone(m, "Stair", Vector3.new(3, h, 28), cf * CFrame.new(-(hw + 24) + i * 3 + 1.5, h / 2, 0), i == 0)
	end
	-- zemin: mermer döşeme, mozaik daire ve altın halka, parlayan rün çizgileri
	Util.part(m, "Floor", Vector3.new(hw * 2, 0.4, hd * 2), cf * CFrame.new(0, top + 0.2, 0), Color3.fromRGB(214, 208, 196), Enum.Material.Marble)
	Util.cyl(m, "MosaicRing", 0.3, 60, cf * CFrame.new(0, top + 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), GOLD2, Enum.Material.Metal)
	Util.cyl(m, "Mosaic", 0.3, 54, cf * CFrame.new(0, top + 0.65, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(28, 66, 108), Enum.Material.Marble)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local rune = Util.part(m, "Rune", Vector3.new(1.2, 0.15, 7), cf * CFrame.new(math.cos(a) * 21, top + 0.85, math.sin(a) * 21) * CFrame.Angles(0, -a, 0), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
		rune.CanCollide = false
	end
	-- sütun: kaide + gövde + başlık
	local function pillar(lx, lz, h)
		h = h or colH
		stone(m, "ColumnBase", Vector3.new(7, 1.6, 7), cf * CFrame.new(lx, top + 0.8, lz))
		Util.cyl(m, "Column", h, 4.6, cf * CFrame.new(lx, top + 1.6 + h / 2, lz) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Marble)
		stone(m, "ColumnCap", Vector3.new(7.6, 2, 7.6), cf * CFrame.new(lx, top + 1.6 + h + 1, lz), true)
	end
	for _, lx in { -48, -36, -24, -12, 0, 12, 24, 36, 48 } do
		pillar(lx, -41)
		pillar(lx, 41)
	end
	for _, lz in { -40, -28, -16, 16, 28, 40 } do
		pillar(-48, lz)
	end
	-- arka (doğu) sütun sırası: duvarın dışında, ön sıra gibi
	for _, lz in { -40, -28, -16, 16, 28, 40 } do
		pillar(48, lz)
	end
	-- arka (doğu) duvar + kabartma süsleri
	-- arka (doğu) duvar: ortası içeriden dışarı doğru YIKILMIŞ (|z| < 12 açık geçit), kenarlara doğru yükselen kırık profil
	local wr = Random.new(91)
	for _, sg in { -1, 1 } do
		for zz = 12, 42, 3 do
			local h = math.clamp(6 + (zz - 12) * 1.7 + wr:NextNumber(-3, 3), 4, colH + 2)
			local lean = zz < 22 and -(22 - zz) * 0.018 or 0
			local shift = zz < 22 and (22 - zz) * 0.12 or 0
			stone(m, "BackWall", Vector3.new(3, h, 3.05), cf * CFrame.new(hw - 10 + shift, top + h / 2 + 0.4, sg * (zz + 1.5)) * CFrame.Angles(0, 0, lean), true)
			if h < colH and wr:NextNumber() < 0.5 then
				local s2 = wr:NextNumber(1.4, 2.4)
				stone(m, "WallChip", Vector3.new(3, s2, 2.4), cf * CFrame.new(hw - 10 + shift, top + h + s2 / 2, sg * (zz + 1.5)) * CFrame.Angles(wr:NextNumber(-0.4, 0.4), 0, wr:NextNumber(-0.5, 0.5)))
			end
		end
	end
	for _, lz in { -30, 30 } do
		Util.part(m, "Relief", Vector3.new(0.5, 11, 5), cf * CFrame.new(hw - 11.6, top + 13, lz), TEAL, Enum.Material.Slate)
		Util.part(m, "ReliefTrim", Vector3.new(0.6, 1, 6), cf * CFrame.new(hw - 11.6, top + 19.4, lz), GOLD2, Enum.Material.Metal)
	end
	-- iç sütun halkası (sunağı çevreler)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + math.pi / 8
		pillar(math.cos(a) * 28, math.sin(a) * 28, 14)
	end
	-- arşitrav: sütunların üstünde sürekli taş kuşak + altın friz
	local colTop = top + 1.6 + colH + 2
	stone(m, "ArchitraveN", Vector3.new(hw * 2 + 10, 3.2, 6), cf * CFrame.new(0, colTop + 1.6, -41), true)
	stone(m, "ArchitraveS", Vector3.new(hw * 2 + 10, 3.2, 6), cf * CFrame.new(0, colTop + 1.6, 41), true)
	stone(m, "ArchitraveW", Vector3.new(6, 3.2, hd * 2 + 6), cf * CFrame.new(-48, colTop + 1.6, 0), true)
	for _, sg in { -1, 1 } do -- doğu kuşağı ortadan kırık
		stone(m, "ArchitraveE", Vector3.new(6, 3.2, 33), cf * CFrame.new(48, colTop + 1.6, sg * 30.5), true)
		Util.part(m, "Frieze", Vector3.new(6.4, 0.8, 33), cf * CFrame.new(48, colTop + 3.4, sg * 30.5), GOLD2, Enum.Material.Metal)
	end
	for _, lz in { -41, 41 } do
		Util.part(m, "Frieze", Vector3.new(hw * 2 + 10, 0.8, 6.4), cf * CFrame.new(0, colTop + 3.4, lz), GOLD2, Enum.Material.Metal)
	end
	Util.part(m, "Frieze", Vector3.new(6.4, 0.8, hd * 2 + 6), cf * CFrame.new(-48, colTop + 3.4, 0), GOLD2, Enum.Material.Metal)
	-- tavan: ortada yuvarlak (açık) gökyüzü deliği
	local roofY = colTop + 4.9
	local hole = 14
	local function slab(sx, sz, lx, lz)
		stone(m, "Roof", Vector3.new(sx, 3, sz), cf * CFrame.new(lx, roofY, lz))
	end
	local rl = hd + 4 - hole
	slab(hw * 2 + 8, rl, 0, -(hole + rl / 2))
	slab(hw * 2 + 8, rl, 0, hole + rl / 2)
	local rw = hw + 4 - hole
	slab(rw, hole * 2, -(hole + rw / 2), 0)
	slab(18, hole * 2, hole + 9, 0) -- doğu tarafı çökmüş
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			stone(m, "RoofCorner", Vector3.new(8.4, 3, 8.4), cf * CFrame.new(sx * 11.2, roofY, sz * 11.2) * CFrame.Angles(0, math.rad(45), 0))
		end
	end
	for k = 0, 19 do
		local a = k / 20 * math.pi * 2
		stone(m, "Rim", Vector3.new(4.4, 3.4, 3), cf * CFrame.new(math.cos(a) * 15.6, roofY + 3, math.sin(a) * 15.6) * CFrame.Angles(0, -a + math.pi / 2, 0), true)
	end
	-- ön alınlık: basamaklı üçgen + parlayan deniz güneşi arması
	for k = 0, 4 do
		stone(m, "Pediment", Vector3.new(5, 3, (hd * 2 + 8) * (1 - k * 0.19)), cf * CFrame.new(-hw - 1, roofY + 3 + k * 3, 0), k % 2 == 0)
	end
	Util.cyl(m, "EmblemRing", 0.8, 11, cf * CFrame.new(-hw - 3.8, roofY + 8, 0), GOLD2, Enum.Material.Metal)
	local emb = Util.cyl(m, "Emblem", 0.8, 8, cf * CFrame.new(-hw - 4.4, roofY + 8, 0), Color3.fromRGB(110, 220, 255), Enum.Material.Neon)
	emb.CanCollide = false
	-- öndeki sütunlara asılı bayraklar
	for _, lz in { -34, -22, 22, 34 } do
		Util.part(m, "Banner", Vector3.new(0.4, 16, 6), cf * CFrame.new(-52.4, top + 18, lz), TEAL, Enum.Material.Fabric)
		Util.part(m, "BannerTrim", Vector3.new(0.5, 1.4, 6.4), cf * CFrame.new(-52.4, top + 26.4, lz), GOLD2, Enum.Material.Metal)
	end
	-- sarmaşık ve yosun
	for k = 1, 16 do
		local lx = -48 + (k - 1) * 6.4
		local lz = (k % 2 == 0) and -44.2 or 44.2
		local len = rng:NextNumber(4, 11)
		Util.noCollide(Util.part(m, "Vine", Vector3.new(0.4, len, 0.4), cf * CFrame.new(lx, colTop - len / 2, lz), Color3.fromRGB(70, 120, 55), Enum.Material.Grass))
	end
	-- kurban sunağı (sunak mantığı: Role = SacrificeAltar)
	Util.cyl(m, "AltarBase", 2.4, 10, cf * CFrame.new(0, top + 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Marble)
	Util.cyl(m, "AltarPedestal", 4, 4, cf * CFrame.new(0, top + 4.4, 0) * CFrame.Angles(0, 0, math.pi / 2), STONE, Enum.Material.Marble)
	local bowl = Util.cyl(m, "AltarBowl", 1.2, 6.4, cf * CFrame.new(0, top + 7, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 150, 230), Enum.Material.Neon)
	bowl:SetAttribute("Role", "SacrificeAltar")
	Util.light(bowl, 2, 40, Color3.fromRGB(120, 190, 255))
	local flame = Util.ball(m, "AltarFlame", Vector3.new(2.4, 3.4, 2.4), cf * CFrame.new(0, top + 9.2, 0), Color3.fromRGB(150, 220, 255), Enum.Material.Neon)
	flame.CanCollide = false
	-- merdivenin iki yanı: ateş kaseleri, balık muhafızları, dikilitaşlar
	for _, sz in { -1, 1 } do
		brazier(m, cf * CFrame.new(-(hw + 10), 0, sz * 20))
		brazier(m, cf * CFrame.new(hw + 8, 0, sz * (hd + 8)))
		brazier(m, cf * CFrame.new(-(hw + 8), 0, sz * (hd + 8)))
		local ob = stone(m, "Obelisk", Vector3.new(4, 26, 4), cf * CFrame.new(-(hw + 34), 13, sz * 26), true)
		local cap = Util.part(m, "ObeliskCap", Vector3.new(2.4, 3, 2.4), cf * CFrame.new(-(hw + 34), 27.5, sz * 26), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
		cap.CanCollide = false
		Util.light(cap, 1.4, 30, Color3.fromRGB(120, 220, 255))
		Decor.fishStatue(m, (cf * CFrame.new(-(hw + 20), 0, sz * 34)).Position, sz == 1 and math.rad(-90) or math.rad(90))
	end
	-- yıkıntı: duvardan dışarı savrulmuş taşlar, devrilmiş sütun, kırık sütun kütükleri, çökmüş çatı parçası
	local function surf(lx)
		if lx <= hw + 4 then
			return top
		elseif lx <= hw + 6 then
			return 4.4
		elseif lx <= hw + 8 then
			return 2.2
		end
		return 1
	end
	for _ = 1, 38 do
		local sz_ = wr:NextNumber(1.4, 5.5)
		local lx = hw - 16 + wr:NextNumber() ^ 0.75 * 62
		local lz = wr:NextNumber(-1, 1) * (11 + math.max(lx - hw, 0) * 0.5)
		local b = stone(m, "Rubble", Vector3.new(sz_, sz_ * wr:NextNumber(0.5, 0.9), sz_ * wr:NextNumber(0.7, 1.3)), cf * CFrame.new(lx, surf(lx) + sz_ * 0.3, lz) * CFrame.Angles(wr:NextNumber(-0.5, 0.5), wr:NextNumber(0, 6.28), wr:NextNumber(-0.5, 0.5)), wr:NextNumber() < 0.4)
		b.CanCollide = sz_ > 3.6
	end
	for _, st in { { -4, 7 }, { 4, 3.5 } } do
		stone(m, "ColumnBase", Vector3.new(7, 1.6, 7), cf * CFrame.new(48, top + 0.8, st[1]))
		Util.cyl(m, "BrokenColumn", st[2], 4.6, cf * CFrame.new(48, top + 1.6 + st[2] / 2, st[1]) * CFrame.Angles(0.06, 0, math.pi / 2), STONE, Enum.Material.Marble)
	end
	Util.cyl(m, "FallenColumn", 22, 4.6, cf * CFrame.new(hw + 26, 1 + 2.3, 7) * CFrame.Angles(0, 0.35, 0), STONE, Enum.Material.Marble)
	stone(m, "ColumnCap", Vector3.new(7.6, 2, 7.6), cf * CFrame.new(hw + 40, 2, 13) * CFrame.Angles(0.3, 0.6, 0.2), true)
	stone(m, "RoofChunk", Vector3.new(12, 3, 18), cf * CFrame.new(hw + 13, 4.2, -5) * CFrame.Angles(0.15, 0.25, -0.38), true)
	stone(m, "PedimentChunk", Vector3.new(5, 3, 16), cf * CFrame.new(hw + 20, 2.2, -16) * CFrame.Angles(0.2, -0.5, 0.15), false)
	m.Parent = parent
	local pivot = Util.zone(m, "Pivot", Vector3.new(1, 1, 1), cf)
	m.PrimaryPart = pivot
	m:ScaleTo(TEMPLE_SCALE)
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

-- Dev ölü deniz canavarı iskeleti: okyanus TABANINDA yatar (ls = uzunluk çarpanı, ts = kalınlık çarpanı)
local function skeleton(parent, x, z, yaw, ls, ts, floorY)
	local m = Instance.new("Model")
	m.Name = "SeaMonsterSkeleton"
	local bone = Color3.fromRGB(232, 224, 200)
	local base = CFrame.new(O.X + x, floorY + 3 * ts, O.Z + z) * CFrame.Angles(0, yaw, 0)
	local function pt(lx, ly, lz)
		return (base * CFrame.new(lx, ly, lz)).Position
	end
	for k = 0, 23 do
		local lx = k * 5.5 * ls
		local ly = math.sin(k * 0.5) * 2.4 * ts
		local lz = math.sin(k * 0.28) * 3.5 * ts
		local s = math.max(2.2, 6.2 - k * 0.15) * ts
		Util.ball(m, "Vertebra", Vector3.new(s, s * 0.9, s), base * CFrame.new(lx, ly, lz), bone, Enum.Material.Slate)
		if k >= 2 and k <= 13 then
			local rh = (12 - math.abs(k - 7) * 0.9) * ts
			for _, sg in { -1, 1 } do
				local a = pt(lx, ly, lz + sg * 1.5 * ts)
				local b = pt(lx, ly + rh * 0.5, lz + sg * rh * 0.75)
				local c2 = pt(lx, ly + rh, lz + sg * rh * 0.55)
				local d = pt(lx, ly + rh * 1.15, lz + sg * rh * 0.1)
				Util.rod(m, "Rib", a, b, 0.9 * ts, bone, Enum.Material.Slate)
				Util.rod(m, "Rib", b, c2, 0.8 * ts, bone, Enum.Material.Slate)
				Util.rod(m, "Rib", c2, d, 0.6 * ts, bone, Enum.Material.Slate)
			end
		end
	end
	-- kuyruk ucu: gittikçe incelen kemikler
	for k = 24, 33 do
		local lx = k * 5.5 * ls
		local s = math.max(1.2, 3.4 - (k - 24) * 0.22) * ts
		Util.ball(m, "TailBone", Vector3.new(s, s * 0.8, s), base * CFrame.new(lx, math.sin(k * 0.5) * 1.6 * ts, math.sin(k * 0.28) * 5 * ts), bone, Enum.Material.Slate)
	end
	local head = base * CFrame.new(-14 * ls, 4 * ts, 0)
	Util.ball(m, "Skull", Vector3.new(20, 9, 11) * ts, head, bone, Enum.Material.Slate)
	Util.part(m, "Jaw", Vector3.new(14, 2, 8) * ts, head * CFrame.new(-6 * ts, -4.5 * ts, 0) * CFrame.Angles(0, 0, math.rad(8)), bone, Enum.Material.Slate)
	for k = 0, 6 do
		for _, sg in { -1, 1 } do
			Util.part(m, "Tooth", Vector3.new(0.8, 2.4, 0.8) * ts, head * CFrame.new((-4 - k * 1.7) * ts, -4.2 * ts, sg * 3.4 * ts), Color3.fromRGB(245, 240, 225), Enum.Material.Slate)
		end
	end
	for _, sg in { -1, 1 } do
		Util.ball(m, "EyeSocket", Vector3.new(2.6, 2.6, 2.6) * ts, head * CFrame.new(-3 * ts, 1.8 * ts, sg * 4.2 * ts), Color3.fromRGB(30, 28, 26), Enum.Material.Slate)
		-- boynuz / diken (iki yan)
		Util.part(m, "Horn", Vector3.new(1.2, 8, 1.2) * ts, head * CFrame.new(2 * ts, 6 * ts, sg * 3 * ts) * CFrame.Angles(0, 0, math.rad(-20)), bone, Enum.Material.Slate)
	end
	m.Parent = parent
	return m
end

-- Büyük batık: deniz tabanında yatan, içi girilebilir kırık gemi. floorY = zemin yüksekliği.
-- Sandık geminin ortasında, güvertedeki açıklıktan veya yırtık yan taraftan dalıp ulaşılır.
local function bigWreck(parent, x, z, yaw, floorY)
	local m = Instance.new("Model")
	m.Name = "BigShipwreck"
	local rng = Random.new(88)
	local L, Wd = 130, 36
	local N = 16
	local base = CFrame.new(O.X + x, floorY, O.Z + z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(7))
	local plank = Color3.fromRGB(86, 58, 38)
	local plank2 = Color3.fromRGB(104, 72, 46)
	local seg = L / N
	local function halfW(t)
		return Wd / 2 * math.sin(math.pi * (0.06 + 0.88 * t)) ^ 0.55
	end
	Util.part(m, "Keel", Vector3.new(2.4, 2.4, L + 4), base * CFrame.new(0, 0.6, 0), DARK, Enum.Material.Wood)
	for i = 0, N do
		local t = i / N
		local zl = -L / 2 + t * L
		local w = halfW(t)
		-- zemin tahtaları
		Util.part(m, "HullFloor", Vector3.new(w * 1.5, 0.8, seg + 0.4), base * CFrame.new(0, 1.2, zl), plank2, Enum.Material.WoodPlanks)
		-- yan kaplama: 4 şerit (alttan üste, dışa doğru açılır)
		for _, sg in { -1, 1 } do
			for j = 0, 3 do
				local gash = sg == 1 and i >= 6 and i <= 10 and j >= 1 -- sancak tarafında geniş yırtık (giriş)
				local missing = j >= 2 and rng:NextNumber() < 0.22
				if not gash and not missing then
					local lean = math.rad(62 - j * 16)
					Util.part(m, "Hull", Vector3.new(1.2, 5.6, seg + 0.5), base * CFrame.new(sg * w * (0.5 + 0.16 * j), 3 + j * 4.6, zl) * CFrame.Angles(0, 0, -sg * lean), (j + i) % 2 == 0 and plank or plank2, Enum.Material.WoodPlanks)
				end
			end
		end
		-- iç dikmeler
		if i % 3 == 0 and rng:NextNumber() < 0.8 then
			for _, sg in { -1, 1 } do
				Util.part(m, "Rib", Vector3.new(0.9, 14, 0.9), base * CFrame.new(sg * w * 0.86, 9, zl), DARK, Enum.Material.Wood)
			end
		end
		-- güverte: sadece baş ve kıç taraf (ortası açık)
		if i <= 4 or i >= 12 then
			Util.part(m, "Deck", Vector3.new(w * 1.7, 0.7, seg + 0.3), base * CFrame.new(0, 14.4, zl), plank2, Enum.Material.WoodPlanks)
		end
	end
	-- kıç kasarası: arka duvar, iki yan duvar, kısmi çatı
	local sternZ = L / 2 - 6
	Util.part(m, "CabinBack", Vector3.new(24, 10, 1.2), base * CFrame.new(0, 17, sternZ + 4), plank, Enum.Material.WoodPlanks)
	for _, sg in { -1, 1 } do
		Util.part(m, "CabinSide", Vector3.new(1.2, 10, 18), base * CFrame.new(sg * 12, 17, sternZ - 5), plank, Enum.Material.WoodPlanks)
	end
	for k = 0, 2 do
		if k ~= 1 then
			Util.part(m, "CabinRoof", Vector3.new(26, 0.8, 5.4), base * CFrame.new(0, 22.4, sternZ - 11 + k * 7), plank2, Enum.Material.WoodPlanks)
		end
	end
	-- devrik direk, yelken, halat
	Util.cyl(m, "Mast", 64, 2.6, base * CFrame.new(6, 13, -12) * CFrame.Angles(math.rad(8), math.rad(24), math.rad(14)), DARK, Enum.Material.Wood)
	local sail = Util.part(m, "Sail", Vector3.new(0.3, 14, 18), base * CFrame.new(-12, 12, -22) * CFrame.Angles(0, math.rad(30), math.rad(40)), Color3.fromRGB(205, 195, 175), Enum.Material.Fabric)
	sail.Transparency = 0.2
	sail.CanCollide = false
	-- toplar (sancak tarafı güvertesinin kenarı), fıçılar, sandıklar
	for k = 0, 3 do
		local cz = -L / 2 + 14 + k * 8
		local w = halfW((cz + L / 2) / L)
		Util.cyl(m, "Cannon", 6.5, 2, base * CFrame.new(-w * 0.85, 16, cz) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(50, 50, 56), Enum.Material.Metal)
	end
	for k = 1, 5 do
		local bp = (base * CFrame.new(rng:NextNumber(-8, 8), 1.6, rng:NextNumber(-L / 2 + 12, L / 2 - 14))).Position
		if k % 2 == 0 then
			Decor.barrel(m, bp - Vector3.new(0, 1.7, 0))
		else
			Decor.crate(m, bp - Vector3.new(0, 1.5, 0), rng:NextNumber(0, 6))
		end
	end
	-- çapa
	Util.rod(m, "AnchorShaft", (base * CFrame.new(-12, 2, -L / 2 - 6)).Position, (base * CFrame.new(-12, 9, -L / 2 - 6)).Position, 1.2, Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
	Util.part(m, "AnchorArm", Vector3.new(9, 1.2, 1.2), base * CFrame.new(-12, 3, -L / 2 - 6), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
	-- gemiye tutunmuş deniz otları
	for k = 1, 14 do
		local kz = rng:NextNumber(-L / 2, L / 2)
		local kw = halfW((kz + L / 2) / L)
		local h = rng:NextNumber(6, 14)
		local kp = (base * CFrame.new((rng:NextNumber() < 0.5 and -1 or 1) * kw * 0.9, 8 + h / 2, kz)).Position
		Util.noCollide(Util.part(m, "Kelp", Vector3.new(0.6, h, 0.25), CFrame.new(kp) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), 0), Color3.fromRGB(50, 140, 70):Lerp(Color3.fromRGB(110, 170, 60), rng:NextNumber()), Enum.Material.Grass))
	end
	m.Parent = parent
	-- sandık: geminin tam ortasında zeminde
	local cp = (base * CFrame.new(0, 1.6, 0)).Position
	return m, cp
end

-- Kale: şerit boyunca DAĞDAN DAĞA kesintisiz sur, ortada dev kapı (anahtarla açılacak), nöbet kuleleri, meşaleler
local WALL_TOP = 58
-- Kapı kanatları: her kanat ayrı Model (DoorL / DoorR), PrimaryPart = menteşe ("Hinge", görünmez).
-- Sürgü + kilit ayrı Model (Bar). Client anahtarı olan oyuncu için kanatları yerelde açar (GateCinematics).
local function gateDoors(parent, basis)
	local doors = Instance.new("Model")
	doors.Name = "GateDoors"
	local wood = Color3.fromRGB(120, 78, 44)
	local function door(sx)
		local d = Instance.new("Model")
		d.Name = sx < 0 and "DoorL" or "DoorR"
		local hinge = Util.zone(d, "Hinge", Vector3.new(1, 1, 1), basis * CFrame.new(sx * 64.5, 22, 0))
		d.PrimaryPart = hinge
		d:SetAttribute("Side", sx)
		d.Parent = doors
		return d
	end
	local L, R = door(-1), door(1)
	local bar = Instance.new("Model")
	bar.Name = "Bar"
	bar.Parent = doors
	for _, sx in { -1, 1 } do
		local px = sx * 32.5
		local m = sx < 0 and L or R
		local panel = Util.part(m, "GatePanel", Vector3.new(64, 66, 5), basis * CFrame.new(px, 22, 0), wood, Enum.Material.WoodPlanks)
		panel:SetAttribute("Locked", true)
		CollectionService:AddTag(panel, "PassSeal")
		local iron = Color3.fromRGB(38, 36, 40)
		-- ayrı ayrı tahtalar (farklı tonlarda, ön yüzde hafif çıkıntılı)
		for k = 0, 7 do
			local shade = wood:Lerp(Color3.fromRGB(66, 40, 22), (k % 3) * 0.16)
			Util.part(m, "Plank", Vector3.new(7.5, 64, 0.8), basis * CFrame.new(px - 28 + k * 8, 22, -2.8), shade, Enum.Material.WoodPlanks)
		end
		for _, by in { 4, 22, 40 } do
			-- demir kuşak, perçinler ve kapı menteşesi
			Util.part(m, "GateBand", Vector3.new(64, 3.2, 1.2), basis * CFrame.new(px, by, -3.5), iron, Enum.Material.Metal)
			for k = -3, 3 do
				Util.ball(m, "Rivet", Vector3.new(1.5, 1.5, 1.5), basis * CFrame.new(px + k * 8.6, by, -4.2), Color3.fromRGB(70, 66, 70), Enum.Material.Metal)
			end
			Util.part(m, "HingeStrap", Vector3.new(20, 2.8, 1.4), basis * CFrame.new(sx * 54.5, by + 5, -4), iron, Enum.Material.Metal)
			Util.cyl(m, "HingePin", 5.6, 3.4, basis * CFrame.new(sx * 64, by + 5, -4) * CFrame.Angles(0, 0, math.pi / 2), iron, Enum.Material.Metal)
		end
		-- sivri demir uçlar (kapının üst kenarı)
		for k = 0, 7 do
			Util.part(m, "Spike", Vector3.new(1.4, 5, 1.4), basis * CFrame.new(px - 28 + k * 8, 57, -2.6), iron, Enum.Material.Metal)
		end
		-- ortada altın göbek ve halka tokmak
		local boss = Util.cyl(m, "Boss", 1, 8, basis * CFrame.new(sx * 9, 22, -4.4) * CFrame.Angles(0, math.pi / 2, 0), GOLD, Enum.Material.Metal)
		boss.CanCollide = false
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			local ringBead = Util.ball(m, "Ring", Vector3.new(1.3, 1.3, 1.3), basis * CFrame.new(sx * 9 + math.cos(a) * 4.6, 22 + math.sin(a) * 4.6 - 8, -5.2), Color3.fromRGB(60, 56, 60), Enum.Material.Metal)
			ringBead.CanCollide = false
		end
	end
	-- iki kanadı birbirine bağlayan ağır demir sürgü ve braketler
	Util.part(bar, "GateBar", Vector3.new(104, 3.4, 3), basis * CFrame.new(0, 31, -6), Color3.fromRGB(44, 42, 46), Enum.Material.Metal)
	for _, bx in { -44, 44 } do
		Util.part(bar, "BarBracket", Vector3.new(5, 9, 3), basis * CFrame.new(bx, 31, -5), Color3.fromRGB(60, 56, 60), Enum.Material.Metal)
	end
	local lock = Util.part(bar, "GateLock", Vector3.new(7, 8, 3), basis * CFrame.new(0, 24, -6.4), GOLD, Enum.Material.Metal)
	lock.CanCollide = false
	doors.Parent = parent
	return doors
end

local function castleGate(parent, B)
	local m = Instance.new("Model")
	m.Name = "CastleGate"
	local basis = CFrame.lookAt(Vector3.new(O.X + B.gx, 0, O.Z + B.gz), Vector3.new(O.X + B.gx + B.nx, 0, O.Z + B.gz + B.nz))
	local wood = Color3.fromRGB(120, 78, 44)
	local wallStone = STONE:Lerp(MOSS, 0.2)
	local gateHalf = 65
	gateDoors(m, basis)
	-- taş kapı pervazları (kanatların iki yanı)
	for _, sx in { -1, 1 } do
		stone(m, "GateJamb", Vector3.new(10, 72, 14), basis * CFrame.new(sx * 69.5, 27, 0), true)
	end
	stone(m, "GateLintel", Vector3.new(180, 12, 14), basis * CFrame.new(0, 62, 0), true)
	for k = -8, 8 do
		stone(m, "GateMerlon", Vector3.new(6.6, 6, 6), basis * CFrame.new(k * 10.4, 71, 0))
	end
	local sign = Util.part(m, "GateSign", Vector3.new(80, 10, 1), basis * CFrame.new(0, 80, -1), Color3.fromRGB(40, 90, 120), Enum.Material.WoodPlanks)
	Util.sign(sign, Enum.NormalId.Front, "SEALED GATE - the Mermaid has the key", CREAM)
	-- sur: iki yana, deniz kenarındaki dağlara kadar (sur uçları dağın içine gömülür)
	local reach = B.len / 2 + 80
	for _, sg in { -1, 1 } do
		local a, b = gateHalf, reach
		local len = b - a
		local cx = sg * (a + b) / 2
		Util.part(m, "Wall", Vector3.new(len, 100, 12), basis * CFrame.new(cx, 8, 0), wallStone, Enum.Material.Cobblestone)
		-- siperlikler (iki yüz)
		for s = a + 5, b - 5, 10 do
			for _, face in { -1, 1 } do
				stone(m, "Merlon", Vector3.new(5.4, 5, 3.4), basis * CFrame.new(sg * s, WALL_TOP + 2.5, face * 4.3))
			end
		end
		-- payandalar ve meşaleler (deniz / pratik üssü tarafında)
		for s = a + 22, b - 20, 30 do
			stone(m, "Pilaster", Vector3.new(4.4, WALL_TOP + 8, 3), basis * CFrame.new(sg * s, (WALL_TOP - 8) / 2 + 0.5, -7), true)
			local torch = Util.ball(m, "Torch", Vector3.new(2, 2.6, 2), basis * CFrame.new(sg * (s + 15), 36, -7.5), Color3.fromRGB(255, 160, 60), Enum.Material.Neon)
			torch.CanCollide = false
			Util.light(torch, 1.4, 34, Color3.fromRGB(255, 170, 80))
		end
	end
	m.Parent = parent
	-- nöbet kuleleri (suyun üstündekiler dibe kadar uzanır). Tepe yüksekliği hepsinde aynı.
	local TOWER_TOP = 84
	for _, t in { -95, 95, -250, 250, -405, 405 } do
		local tx, tz = B.gx + B.dx * t, B.gz + B.dz * t
		local gy = ground(tx, tz)
		local baseY = gy and (gy - 1) or -42
		tower(parent, tx, tz, TOWER_TOP - baseY, false, 20, baseY)
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
	local corals = Instance.new("Folder")
	corals.Name = "Corals"
	corals.Parent = f

	-- Karşılama adası: iskele DOĞUYA (ana tapınak adasına doğru) uzanır; mermaid kayası kıyıda ----------------
	local wx, wz = P(c.Welcome.x, c.Welcome.y)
	local wr = c.Welcome.r * S
	scatterPlants(f, wx, wz, wr, 26, rng, 0.5)
	label(f, wx, wz, "Welcome Island", 46)
	pier(f, wx + wr - 14, wz, wx + wr + 40, wz, 10, "StartDock")
	for _, dx in { 12, 32 } do
		torch(f, Vector3.new(O.X + wx + wr + dx, deckY, O.Z + wz + 6))
		torch(f, Vector3.new(O.X + wx + wr + dx, deckY, O.Z + wz - 6))
	end
	-- kaya iskelenin hemen kuzeyinde, suyun içinde; deniz kızı üstünde oturur
	local rkx, rkz = wx + wr + 30, wz - 22
	local rock = mermaid(f, rkx, rkz)
	-- kumsal süsleri: kamp ateşi, sürüklenmiş kütükler, sandık/fıçı, kabuklar, kayalar
	campfire(f, wx - wr * 0.25, wz + wr * 0.3, rng)
	for k = 1, 3 do
		logProp(f, wx + rng:NextNumber(-wr, wr) * 0.5, wz + rng:NextNumber(-wr, wr) * 0.6, rng:NextNumber(0, 3), rng:NextNumber(7, 12))
	end
	Decor.crate(f, gp(wx + wr - 18, wz + 14, 0), 0.3)
	Decor.crate(f, gp(wx + wr - 14, wz + 18, 0), 0.9)
	Decor.barrel(f, gp(wx + wr - 22, wz + 10, 0))
	Decor.barrel(f, gp(wx + wr - 20, wz - 14, 0))
	for k = 1, 3 do
		shellProp(f, wx + rng:NextNumber(-wr, wr) * 0.7, wz + rng:NextNumber(-wr, wr) * 0.7, rng)
	end
	rocksAround(f, wx, wz, wr * 0.9, 8, rng)
	local dest = Workspace:FindFirstChild("SeaMapDestinations") or Instance.new("Folder")
	dest.Name = "SeaMapDestinations"
	dest.Parent = Workspace
	for _, n in { "Coral", "Coral_Boat" } do
		local old = dest:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	-- oyuncu iskelede, deniz kızının kayasının yanında doğar ve ona bakar
	local sp = Vector3.new(O.X + wx + wr + 22, deckY + 0.5, O.Z + wz - 2)
	Util.zone(dest, "Coral", Vector3.new(6, 1, 6), CFrame.lookAt(sp, Vector3.new(O.X + rkx, deckY + 0.5, O.Z + rkz)))
	local bp = Vector3.new(O.X + wx + wr + 52, 1, O.Z + wz + 26)
	Util.zone(dest, "Coral_Boat", Vector3.new(6, 1, 6), CFrame.lookAt(bp, bp + Vector3.new(60, 0, 0)))
	task.wait()

	-- Random Treasure Island: sık orman, kayalık tepede sandık, korsan bayrağı ----------------------------------
	local tx, tz = P(c.TreasureIsland.x, c.TreasureIsland.y)
	local tr = c.TreasureIsland.r * S
	scatterPlants(f, tx, tz, tr, 40, rng, 0.55)
	for k = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = math.sqrt(rng:NextNumber()) * tr * 0.85
		plant(f, tx + math.cos(a) * d, tz + math.sin(a) * d, rng, 3)
	end
	rocksAround(f, tx, tz, tr * 0.9, 8, rng)
	for k = 1, 2 do
		logProp(f, tx + rng:NextNumber(-tr, tr) * 0.5, tz + rng:NextNumber(-tr, tr) * 0.5, rng:NextNumber(0, 3), 11)
	end
	Decor.barrel(f, gp(tx - tr * 0.55, tz + tr * 0.35, 0))
	Decor.barrel(f, gp(tx - tr * 0.5, tz + tr * 0.42, 0))
	Decor.crate(f, gp(tx - tr * 0.6, tz + tr * 0.4, 0), 0.5)
	pirateFlag(f, tx + 12, tz - 10)
	redX(f, tx, tz)
	chest(f, tx, tz, rng:NextNumber(0, 6), "Large")
	label(f, tx, tz, "Random Treasure Island", 56)
	pier(f, tx + tr - 6, tz + 10, tx + tr + 50, tz + 10, 7, "TreasureDock")

	-- Star Island: kayalık yıldız; ortada taş platform, çevresinde dikili taşlar --------------------------------
	local sx, sz = P(c.Star.x, c.Star.y)
	local sR = c.Star.r * S
	scatterPlants(f, sx, sz, sR, 14, rng, 0.2)
	rocksAround(f, sx, sz, sR, 18, rng)
	for k = 0, 4 do
		local a = math.rad(-90 + k * 72 + 36)
		standingStone(f, sx + math.cos(a) * 22, sz + math.sin(a) * 22, rng:NextNumber(9, 14), rng, Color3.fromRGB(255, 220, 110))
	end
	redX(f, sx, sz)
	chest(f, sx, sz, rng:NextNumber(0, 6), "Large")
	label(f, sx, sz, "Star Island", 60)
	pier(f, sx - sR * 0.5, sz + sR * 0.55, sx - sR * 0.5 - 20, sz + sR * 0.55 + 55, 7, "StarDock")
	task.wait()

	-- Ana tapınak adası: büyük tapınak, sunak, iskele merdivene bağlı --------------------------------------------
	local mx, mz = P(c.MainTemple.temple[1], c.MainTemple.temple[2])
	exclude(mx + 20, mz, 195, 155) -- plazanın üstüne ağaç ve kaya konmaz (çevresindeki yeşil halka serbest)
	mainTemple(f, mx, mz)
	local d0x, d0z = P(c.MainTemple.dock.from[1], c.MainTemple.dock.from[2])
	local d1x, d1z = P(c.MainTemple.dock.to[1], c.MainTemple.dock.to[2])
	pier(f, d0x, d0z, d1x, d1z, 12, "TempleDock")
	for _, t in { 0.25, 0.6, 0.95 } do
		local lx = d0x + (d1x - d0x) * t
		local lz = d0z + (d1z - d0z) * t
		torch(f, Vector3.new(O.X + lx, deckY, O.Z + lz + 7))
		torch(f, Vector3.new(O.X + lx, deckY, O.Z + lz - 7))
	end
	label(f, mx, mz, "Main Temple (Sacrifice Altar)", 190)
	for _, p in c.MainTemple.points do
		local px_, pz_ = P(p[1], p[2])
		scatterPlants(f, px_, pz_, p[3] * S, 45, rng, 0.45)
	end
	rocksAround(f, mx, mz + 200, 120, 10, rng)
	do
		local ax, az = P(1240, 775)
		arch(f, ax, az, math.rad(90))
		local wx2, wz2 = P(1320, 790)
		ruinWall(f, wx2, wz2, 0.4, 24)
		fallenColumn(f, mx + 10, mz + 172, rng)
		fallenColumn(f, mx + 90, mz + 178, rng)
	end

	-- Hilal adalar (her biri farklı karakter) + minik adalar ------------------------------------------------------
	local perDisc = { 3, 1, 6, 2 }
	for i, arc in c.Crescents do
		local discs = chainDiscs(arc, 0, Random.new(700 + i), c.CrescentR)
		for k, d in discs do
			scatterPlants(f, d[1], d[2], d[3], perDisc[i], rng, 0.4)
			scatterCorals(corals, d[1], d[2], d[3] + 10, d[3] + 95, 5, rng)
			if i == 1 and k % 2 == 0 then
				shellProp(f, d[1] + rng:NextNumber(-8, 8), d[2] + rng:NextNumber(-8, 8), rng)
				logProp(f, d[1] + rng:NextNumber(-10, 10), d[2] + rng:NextNumber(-10, 10), rng:NextNumber(0, 3), 9)
			elseif i == 2 then
				rocksAround(f, d[1], d[2], d[3] * 0.8, 4, rng)
			elseif i == 4 and k % 3 == 1 then
				standingStone(f, d[1] + rng:NextNumber(-8, 8), d[2] + rng:NextNumber(-8, 8), rng:NextNumber(8, 13), rng, Color3.fromRGB(120, 220, 255))
				fallenColumn(f, d[1] + rng:NextNumber(-12, 12), d[2] + rng:NextNumber(-12, 12), rng)
			end
		end
		task.wait()
	end
	for _, isl in c.Islets do
		local x, z = P(isl[1], isl[2])
		scatterPlants(f, x, z, isl[3] * S, 5, rng, 0.6)
		scatterCorals(corals, x, z, isl[3] * S + 10, isl[3] * S + 80, 4, rng)
	end

	-- Small Ancient Temple: kayalık adada kalıntılar ------------------------------------------------------------------
	local sx2, sz2 = P(c.SmallTemple.temple[1], c.SmallTemple.temple[2])
	exclude(sx2, sz2, 80, 80) -- küçük tapınağın içine ağaç konmaz
	temple(f, sx2, sz2, 0.8)
	tower(f, sx2 + 70, sz2 + 22, 24, true)
	ruinWall(f, sx2 - 60, sz2 + 18, 0.3, 26)
	ruinWall(f, sx2 + 30, sz2 - 50, 1.4, 22)
	arch(f, sx2 + 110, sz2 + 70, 0.6)
	fallenColumn(f, sx2 - 30, sz2 - 40, rng)
	fallenColumn(f, sx2 + 50, sz2 + 50, rng)
	campfire(f, sx2 - 100, sz2 + 50, rng)
	local cx2, cz2 = sx2 + 150, sz2 + 60
	redX(f, cx2, cz2)
	chest(f, cx2, cz2, rng:NextNumber(0, 6), "Large")
	for _, p in c.SmallTemple.points do
		local px_, pz_ = P(p[1], p[2])
		scatterPlants(f, px_, pz_, p[3] * S, 8, rng, 0.4)
		rocksAround(f, px_, pz_, p[3] * S * 0.8, 5, rng)
		scatterCorals(corals, px_, pz_, p[3] * S + 20, p[3] * S + 100, 4, rng)
	end
	label(f, sx2, sz2, "Small Ancient Temple", 64)
	task.wait()

	-- Labirent: ortada sandık; duvarlara renkli mercan taşları ve mercanlar ---------------------------------------------
	local L = c.Labyrinth
	local lcx, lcz = P(L.x, L.y)
	redX(f, lcx, lcz)
	chest(f, lcx, lcz, rng:NextNumber(0, 6), "Large")
	label(f, lcx, lcz, "Labyrinth", 50)
	do
		local stones = Instance.new("Folder")
		stones.Name = "MazeStones"
		stones.Parent = f
		local n = 0
		for _, p in mazeWalls(mazeData(c), 13) do
			local px_, pz_ = p[1] + rng:NextNumber(-2.5, 2.5), p[2] + rng:NextNumber(-2.5, 2.5)
			local gy = ground(px_, pz_)
			if gy then
				local sz_ = rng:NextNumber(4, 8)
				local col = CORALS[rng:NextInteger(1, #CORALS)]:Lerp(Color3.fromRGB(150, 145, 135), 0.2)
				local b = Util.ball(stones, "CoralStone", Vector3.new(sz_, sz_ * 0.8, sz_), CFrame.new(O.X + px_, gy + sz_ * 0.1, O.Z + pz_) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), col, Enum.Material.Rock)
				b.CanCollide = false
				if rng:NextNumber() < 0.12 then
					coral(stones, Vector3.new(O.X + px_, gy + 1.5, O.Z + pz_), rng)
				end
			end
			n += 1
			if n % 60 == 0 then
				task.wait()
			end
		end
	end
	scatterCorals(corals, lcx, lcz, 40, 380, 28, rng)
	task.wait()

	-- Büyük batık gemi: deniz DİBİNDE, içi girilebilir; sandık içinde (dalıp alınır) --------------------------------------
	local bx, bz = P(c.BigShip.x, c.BigShip.y)
	-- gemi, dipteki tepenin GERÇEK yüksekliğine oturur (zemin tahtası arazi yüzeyiyle aynı seviyede)
	local shipFloor = (ground(bx, bz) or c.BigShip.floorY) - 1.4
	local _, cp = bigWreck(f, bx, bz, math.rad(35), shipFloor)
	chest(f, cp.X - O.X, cp.Z - O.Z, math.rad(35), "Large", cp.Y)
	label(f, bx, bz, "Big Flooded Ship (dive in!)", 40)
	scatterCorals(corals, bx, bz, 70, 170, 24, rng)

	-- Üstteki batık gemiler (ahşap ve metal toplanır) -----------------------------------------------------------------------
	for i, s in c.SunkenShips do
		local x, z = P(s[1], s[2])
		wreck(f, x, z, math.rad(rng:NextNumber(0, 360)), 1.3 + (i % 2) * 0.4)
		for _ = 1, 8 do
			local d = Util.part(f, "Debris", Vector3.new(rng:NextNumber(3, 6), 0.5, 1.2), CFrame.new(O.X + x + rng:NextNumber(-45, 45), 0.2, O.Z + z + rng:NextNumber(-45, 45)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), WOOD, Enum.Material.WoodPlanks)
			d.CanCollide = false
			d:SetAttribute("Loot", i % 2 == 0 and "Metal" or "Wood")
		end
		scatterCorals(corals, x, z, 40, 130, 8, rng)
	end
	local ssx, ssz = P(c.SunkenShips[2][1], c.SunkenShips[2][2])
	label(f, ssx, ssz, "Sunken Ships", 50)
	task.wait()

	-- Dev ölü deniz canavarı: okyanus tabanında, dağlardan uzakta ---------------------------------------------------------
	local kx, kz = P(c.Monster.skeleton[1], c.Monster.skeleton[2])
	local ms = c.Monster.scale
	skeleton(f, kx, kz, 0, ms * 0.8, ms * 0.7, c.SeabedY)
	label(f, kx + 190, kz, "Dead Sea Monster", 40)
	scatterCorals(corals, kx + 190, kz, 120, 260, 14, rng)

	-- Kale: dağdan dağa sur, dev kapı, kuleler, çadırlar, iskeleler, hedef gemisi, işaret noktaları ----------------------------
	castleGate(f, B)
	label(f, B.gx - B.nx * 20, B.gz - B.nz * 20, "Castle Gate", 100)
	Atoll.Training(c)
	task.wait()

	-- Dağların yeşil yamaçlarına ağaç ve çalı (sadece denize bakan taraf)
	do
		local tr = Random.new(950)
		local ax0, az0, ax1, az1 = seaRect()
		local mcx, mcz = (ax0 + ax1) / 2, (az0 + az1) / 2
		local n = 0
		for _, sp in mountainSpecs(c) do
			if sp.kind ~= "rock" then
				local toSea = math.atan2(mcz - sp.z, mcx - sp.x)
				for _ = 1, 4 do
					local a = toSea + tr:NextNumber(-1.1, 1.1)
					local d = tr:NextNumber(0.35, 0.8) * sp.h * 0.75
					local px_, pz_ = sp.x + math.cos(a) * d, sp.z + math.sin(a) * d
					local gy = ground(px_, pz_)
					if gy and gy > 6 and gy < sp.h * 0.5 then
						plant(f, px_, pz_, tr, tr:NextNumber() < 0.35 and 1 or 2)
					end
				end
			end
			n += 1
			if n % 20 == 0 then
				task.wait()
			end
		end
	end

	-- Görünmez sınır duvarları (dağların önünde). Kuzeybatı köşesinde kanalın ağzı açık bırakılır -------------------------------
	local x0, z0, x1, z1 = seaRect()
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


-- 5) Doku geçişi: adaların yüzeyini yükseklik + eğime göre yeniden boyar (su kenarında kumsal, dik yamaçta kaya,
-- çim alanlarda toprak / yaprak / çamur lekeleri, deniz dibinde kumtaşı ve koyu lekeler). Kale tarafına dokunmaz.
local AIR = Enum.Material.Air
local MUD, GROUND = Enum.Material.Mud, Enum.Material.Ground
local SLATE_, BASALT_, SANDST, LIME_ = Enum.Material.Slate, Enum.Material.Basalt, Enum.Material.Sandstone, Enum.Material.Limestone
local KEEP = { [Enum.Material.Pavement] = true, [Enum.Material.Cobblestone] = true, [Enum.Material.Brick] = true, [AIR] = true, [WATER] = true }
local GREENS = { [GRASS] = true, [LEAFY] = true, [GROUND] = true, [MUD] = true }
local ROCKS = { [ROCK] = true, [SLATE_] = true, [BASALT_] = true }
function Atoll.Paint(c, part, parts)
	local x0, z0, x1, z1 = seaRect()
	local B = bandInfo()
	local CH = 192
	local wd = (x1 - x0) / parts
	local xa, xb = x0 + wd * (part - 1), x0 + wd * part
	local channels = { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }
	for cx = xa, xb - 1, CH do
		local cw = math.min(CH, xb - cx)
		for cz = z0, z1 - 1, CH do
			local reg = Region3.new(Vector3.new(O.X + cx - 4, -48, O.Z + cz - 4), Vector3.new(O.X + cx + cw + 4, 64, O.Z + cz + CH + 4)):ExpandToGrid(4)
			local ch = Terrain:ReadVoxelChannels(reg, 4, channels)
			local mats, occ = ch.SolidMaterial, ch.SolidOccupancy
			local sz = Vector3.new(#mats, #mats[1], #mats[1][1])
			local lo = reg.CFrame.Position - reg.Size / 2
			local H, J = {}, {}
			for i = 1, sz.X do
				H[i], J[i] = {}, {}
				for k = 1, sz.Z do
					local h, jj = -999, 0
					for j = sz.Y, 1, -1 do
						local m = mats[i][j][k]
						if m ~= AIR and m ~= WATER and occ[i][j][k] > 0.05 then
							h, jj = lo.Y + (j - 1) * 4 + occ[i][j][k] * 4, j
							break
						end
					end
					H[i][k], J[i][k] = h, jj
				end
			end
			local changed = false
			for i = 2, sz.X - 1 do
				for k = 2, sz.Z - 1 do
					local j = J[i][k]
					local h = H[i][k]
					local wx, wz = lo.X + (i - 0.5) * 4 - O.X, lo.Z + (k - 0.5) * 4 - O.Z
					local band = (wx - B.gx) * B.nx + (wz - B.gz) * B.nz
					if j > 0 and h < 60 and wx > x0 and wx < x1 and wz > z0 and wz < z1 and band > B.half + 140 then
						local m = mats[i][j][k]
						if not KEEP[m] then
							local slope = math.max(math.abs(H[i + 1][k] - h), math.abs(H[i - 1][k] - h), math.abs(H[i][k + 1] - h), math.abs(H[i][k - 1] - h))
							local n = math.noise(wx / 46, wz / 46, 1.3) + 0.5 * math.noise(wx / 15, wz / 15, 7.1)
							local nm
							if h < -3 then
								if m == SAND then
									if n > 0.55 then
										nm = SANDST
									elseif n < -0.62 then
										nm = GROUND
									end
								end
							elseif ROCKS[m] then
								if slope < 2.5 and n > 0.55 then
									nm = SLATE_
								elseif n < -0.65 then
									nm = BASALT_
								end
							elseif h < 2.4 then
								if m ~= SANDST and m ~= LIME_ then
									nm = SAND
								end
							elseif slope > 3 then
								nm = (m == SAND or m == SANDST or m == LIME_) and SANDST or (n > 0.2 and SLATE_ or ROCK)
							elseif GREENS[m] then
								if h < 3.8 then
									nm = n > 0 and SAND or GROUND
								elseif slope > 1.9 then
									nm = GROUND
								elseif n > 0.55 then
									nm = m == LEAFY and GRASS or LEAFY
								elseif n < -0.62 then
									nm = MUD
								elseif n < -0.42 then
									nm = GROUND
								end
							elseif m == SAND and n < -0.6 then
								nm = SANDST
							end
							if nm and nm ~= m then
								mats[i][j][k] = nm
								if j > 1 and mats[i][j - 1][k] ~= AIR and mats[i][j - 1][k] ~= WATER then
									mats[i][j - 1][k] = nm
								end
								changed = true
							end
						end
					end
				end
			end
			if changed then
				Terrain:WriteVoxelChannels(reg, 4, { SolidMaterial = mats, SolidOccupancy = occ, LiquidOccupancy = ch.LiquidOccupancy })
			end
			task.wait()
		end
	end
end

-- 6) Atış eğitimi körfezi "Gunnery Range": kale kapısının ARKASINDA, körfezin en geniş yerinde.
-- Konum ölçüsü: kapıdan körfezin içine doğru s stud, kapıya bakınca sağa doğru u stud. "TrainFrame" parçası bu çerçevenin kökü.
-- Sol kıyıda (u<0) korsanın komuta güvertesi, sağ kıyıda (u>0) hedef geminin bağlı durduğu iskele, ortada iki yüzer sal.
-- Hedef gemiyi, oturumu ve vuruşları server/Combat/PracticeService yönetir (Config/Practice.luau).
function Atoll.Training(c)
	C = C or cfg()
	O = O or C.Origin
	local B = bandInfo()
	local atoll = Workspace:FindFirstChild("Atoll")
	if not atoll then
		return
	end
	-- eski (kapı önündeki) eğitim nesnelerini kaldır
	for _, d in atoll:GetChildren() do
		if d.Name:match("^Practice") or d.Name == "PirateSpot" or d.Name:match("^Target") then
			d:Destroy()
		end
	end
	local f = Util.fresh("Folder", "Training", atoll)
	local fx, fz = -B.nx, -B.nz
	local origin = Vector3.new(O.X + B.gx, 0, O.Z + B.gz)
	local frame = CFrame.lookAt(origin, origin + Vector3.new(fx, 0, fz))
	local function F(s, u, y)
		return frame * CFrame.new(u, y or 0, -s)
	end
	local function T(s, u, y)
		return F(s, u, y).Position
	end
	local function L(s, u) -- label() için atoll-yerel x, z
		local p = T(s, u)
		return p.X - O.X, p.Z - O.Z
	end
	local PS = require(ReplicatedStorage.Shared.Config.Practice:Clone())
	local DECK = 6.5
	local METAL = Color3.fromRGB(48, 48, 54)
	local ROPE = Color3.fromRGB(176, 150, 104)
	local TCOLORS = { Color3.fromRGB(205, 40, 40), Color3.fromRGB(245, 245, 245) }

	Util.zone(f, "TrainFrame", Vector3.new(2, 2, 2), frame)

	-- Ahşap platform: tahta zemin, kalas çizgileri, kıyıdaki taş dayanak, kazıklar, su kenarında korkuluk
	local function deck(name, s0, s1, u0, u1, waterEdgeU)
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = f
		local sc, uc = (s0 + s1) / 2, (u0 + u1) / 2
		local ss, su = s1 - s0, u1 - u0
		Util.part(m, "Deck", Vector3.new(su, 1, ss), F(sc, uc, DECK - 0.5), WOOD, Enum.Material.WoodPlanks)
		for k = 0, math.floor(su / 6) do
			local u = u0 + 3 + k * 6
			if u < u1 - 1 then
				Util.noCollide(Util.part(m, "Seam", Vector3.new(0.25, 0.05, ss), F(sc, u, DECK + 0.02), DARK, Enum.Material.Wood))
			end
		end
		-- kıyıya dayanak: platformun kara ucunda taş blok (kayaya gömülür)
		local landU = waterEdgeU > uc and u0 or u1
		Util.part(m, "Quay", Vector3.new(34, 18, ss + 2), F(sc, landU + (landU == u0 and 15 or -15), DECK - 9.5), STONE:Lerp(MOSS, 0.3), Enum.Material.Cobblestone)
		for s = s0 + 4, s1 - 3, 10 do
			for u = u0 + 6, u1 - 3, 14 do
				local p = T(s, u)
				Util.pole(m, "Piling", p.X, p.Z, -14, DECK + 1.4, 1.3, DARK, Enum.Material.Wood)
			end
		end
		-- su kenarı kirişi + korkuluk direkleri
		Util.part(m, "Rim", Vector3.new(1.2, 1.2, ss + 1), F(sc, waterEdgeU, DECK + 0.3), DARK, Enum.Material.Wood)
		for s = s0 + 3, s1 - 2, 10 do
			local p = T(s, waterEdgeU)
			Util.pole(m, "Post", p.X, p.Z, DECK, DECK + 3.4, 0.9, DARK, Enum.Material.Wood)
		end
		Util.part(m, "Rail", Vector3.new(0.5, 0.5, ss), F(sc, waterEdgeU, DECK + 3.2), DARK, Enum.Material.Wood)
		return m
	end

	local function crate(m, s, u, yaw, sz)
		local cf = F(s, u, DECK + sz / 2) * CFrame.Angles(0, yaw, 0)
		Util.part(m, "Crate", Vector3.new(sz, sz, sz), cf, Color3.fromRGB(150, 108, 66), Enum.Material.WoodPlanks)
		Util.noCollide(Util.part(m, "Strap", Vector3.new(sz + 0.1, 0.4, sz + 0.1), cf, DARK, Enum.Material.Wood))
	end
	local function barrel(m, s, u, h)
		h = h or 4
		Util.cyl(m, "Barrel", h, 3, F(s, u, DECK + h / 2) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(122, 84, 52), Enum.Material.Wood)
		for _, k in { -0.3, 0.3 } do
			Util.noCollide(Util.cyl(m, "Hoop", 0.35, 3.15, F(s, u, DECK + h / 2 + k * h) * CFrame.Angles(0, 0, math.pi / 2), METAL, Enum.Material.Metal))
		end
	end
	local function ballPile(m, s, u)
		local n = 0
		for row = 1, 3 do
			for i = 1, 4 - row do
				for j = 1, 4 - row do
					n += 1
					Util.ball(m, "Cannonball", Vector3.new(1.7, 1.7, 1.7), F(s + (i - 2 + row * 0.5) * 1.8, u + (j - 2 + row * 0.5) * 1.8, DECK + 0.85 + (row - 1) * 1.4), Color3.fromRGB(34, 34, 38), Enum.Material.Metal)
				end
			end
		end
	end
	local function cannonDeco(m, s, u, yaw)
		local cf = F(s, u, DECK) * CFrame.Angles(0, yaw, 0)
		Util.cyl(m, "Barrel", 8, 2.2, cf * CFrame.new(0, 3.4, 0), METAL, Enum.Material.Metal)
		Util.cyl(m, "Muzzle", 0.8, 2.9, cf * CFrame.new(3.8, 3.4, 0), METAL, Enum.Material.Metal)
		Util.part(m, "Carriage", Vector3.new(6, 1.2, 3.4), cf * CFrame.new(-0.5, 2.2, 0), WOOD, Enum.Material.WoodPlanks)
		for _, z in { -1.9, 1.9 } do
			Util.cyl(m, "Wheel", 0.8, 3.6, cf * CFrame.new(-0.5, 1.8, z) * CFrame.Angles(0, math.pi / 2, 0), DARK, Enum.Material.Wood)
		end
	end
	local function bollard(m, s, u)
		Util.cyl(m, "Bollard", 2.4, 1.5, F(s, u, DECK + 1.2) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Wood)
		Util.cyl(m, "BollardTop", 0.5, 2.2, F(s, u, DECK + 2.5) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Wood)
	end
	local function lampPost(m, s, u)
		torch(m, T(s, u, DECK))
	end
	local function flag(m, s, u, color, yaw, high)
		local p = T(s, u)
		Util.pole(m, "FlagPole", p.X, p.Z, DECK, DECK + (high or 24), 0.8, DARK, Enum.Material.Wood)
		Util.noCollide(Util.part(m, "Flag", Vector3.new(0.2, 4, 7), F(s, u, DECK + (high or 24) - 2.5) * CFrame.Angles(0, yaw or 0, 0) * CFrame.new(0, 0, 3.6), color, Enum.Material.Fabric))
	end
	local function targetBoard(m, s, u, faceX)
		-- tahta ayak + halka halka hedef tahtası (faceX = +1 sağa (+u), -1 sola bakar)
		local yaw = faceX > 0 and 0 or math.pi
		local cf = F(s, u, DECK) * CFrame.Angles(0, yaw, 0)
		for _, z in { -2.4, 2.4 } do
			Util.part(m, "StandLeg", Vector3.new(0.9, 7, 0.9), cf * CFrame.new(0, 3.5, z), DARK, Enum.Material.Wood)
		end
		Util.part(m, "Back", Vector3.new(0.8, 1, 6.4), cf * CFrame.new(0, 7.5, 0), DARK, Enum.Material.Wood)
		local rings = { { 7.6, 1 }, { 5.8, 2 }, { 4, 1 }, { 2.2, 2 } }
		for k, r in rings do
			Util.noCollide(Util.cyl(m, "Ring", 0.3, r[1], cf * CFrame.new(0.55 + k * 0.06, 8.3, 0), TCOLORS[r[2]], Enum.Material.SmoothPlastic))
		end
	end
	local function rope(m, p0, p1)
		local r = Util.rod(m, "MoorRope", p0, p1, 0.45, ROPE, Enum.Material.Fabric)
		r.CanCollide = false
		return r
	end

	-- ---- Platform A: korsanın komuta güvertesi (sol kıyı) ----------------------------------------------------------------
	do
		local m = deck("CommandDeck", 175, 235, -250, -120, -120)
		-- gölgelik: dört direk, tahta çatı
		for _, s in { 181, 229 } do
			for _, u in { -240, -214 } do
				local p = T(s, u)
				Util.pole(m, "RoofPost", p.X, p.Z, DECK, DECK + 13, 1.2, DARK, Enum.Material.Wood)
			end
		end
		Util.part(m, "Roof", Vector3.new(34, 1, 56), F(205, -227, DECK + 13.5), Color3.fromRGB(120, 82, 52), Enum.Material.WoodPlanks)
		Util.part(m, "RoofTrim", Vector3.new(35, 0.6, 57), F(205, -227, DECK + 14.2), DARK, Enum.Material.Wood)
		-- gölgelik altı: masa, sandık, harita
		Util.part(m, "Table", Vector3.new(8, 0.8, 5), F(205, -228, DECK + 3.4), WOOD, Enum.Material.WoodPlanks)
		for _, d in { { -3.2, -2 }, { 3.2, -2 }, { -3.2, 2 }, { 3.2, 2 } } do
			Util.part(m, "TableLeg", Vector3.new(0.7, 3, 0.7), F(205 + d[2], -228 + d[1], DECK + 1.5), DARK, Enum.Material.Wood)
		end
		Util.noCollide(Util.part(m, "Map", Vector3.new(5, 0.1, 3.2), F(205, -228, DECK + 3.85) * CFrame.Angles(0, 0.2, 0), Color3.fromRGB(232, 214, 168), Enum.Material.Fabric))
		Util.part(m, "Chest", Vector3.new(4.5, 2.6, 3), F(190, -236, DECK + 1.3), Color3.fromRGB(110, 72, 44), Enum.Material.WoodPlanks)
		Util.noCollide(Util.part(m, "ChestBand", Vector3.new(4.6, 0.5, 3.1), F(190, -236, DECK + 2.4), GOLD, Enum.Material.Metal))
		for _, s in { 186, 224 } do
			lampPost(m, s, -135)
		end
		lampPost(m, 205, -246)
		cannonDeco(m, 188, -132, 0)
		cannonDeco(m, 222, -132, 0)
		ballPile(m, 232, -160)
		ballPile(m, 178, -160)
		crate(m, 233, -196, 0.3, 4)
		crate(m, 233, -190, 0.9, 3)
		crate(m, 178, -196, -0.2, 4)
		barrel(m, 177, -182)
		barrel(m, 177, -188)
		barrel(m, 232, -176)
		for _, s in { 186, 205, 224 } do
			bollard(m, s, -123)
		end
		flag(m, 231, -126, Color3.fromRGB(26, 26, 30), 0, 28)
		-- büyük tabela: koyu levha + yazı (koya bakar)
		local sign = Util.part(m, "Sign", Vector3.new(22, 3.4, 0.8), F(205, -126, DECK + 9.5) * CFrame.Angles(0, -math.pi / 2, 0), Color3.fromRGB(58, 40, 28), Enum.Material.WoodPlanks)
		Util.sign(sign, Enum.NormalId.Front, "GUNNERY RANGE", Color3.fromRGB(255, 226, 150))
		for _, s in { 195, 215 } do
			local p = T(s, -126)
			Util.pole(m, "SignPost", p.X, p.Z, DECK, DECK + 11.5, 0.9, DARK, Enum.Material.Wood)
		end
		Util.zone(f, "PirateTalkPoint", Vector3.new(3, 3, 3), F(205, -146, DECK + 3))
		Util.zone(f, "TrainStart", Vector3.new(6, 1, 6), F(PS.PlayerStart.s, PS.PlayerStart.u, 1))
	end

	-- ---- Platform B: hedef geminin bağlı durduğu iskele (sağ kıyı) -------------------------------------------------------
	do
		local m = deck("TargetDock", 175, 235, 120, 250, 120)
		for k, s in { 185, 205, 225 } do
			targetBoard(m, s, 134, -1)
		end
		for _, s in { 192, 218 } do
			bollard(m, s, 123)
		end
		for _, s in { 182, 228 } do
			lampPost(m, s, 124)
		end
		lampPost(m, 205, 244)
		crate(m, 232, 236, 0.4, 4)
		crate(m, 178, 238, -0.3, 3.4)
		barrel(m, 176, 224)
		barrel(m, 176, 230)
		ballPile(m, 232, 214)
		cannonDeco(m, 205, 215, math.pi)
		flag(m, 178, 126, Color3.fromRGB(190, 30, 30), 0, 26)
		local sign = Util.part(m, "Sign", Vector3.new(20, 3.2, 0.8), F(205, 245, DECK + 9.5) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(58, 40, 28), Enum.Material.WoodPlanks)
		Util.sign(sign, Enum.NormalId.Front, "TARGET DOCK", Color3.fromRGB(255, 190, 150))
		for _, s in { 195, 215 } do
			local p = T(s, 245)
			Util.pole(m, "SignPost", p.X, p.Z, DECK, DECK + 11.5, 0.9, DARK, Enum.Material.Wood)
		end
		-- halatlar: hedef gemi (u = berth.u, cıvata ±8) iskeleye bağlı. Gemi çözülünce service bunları gizler.
		for _, d in { { 197, 192 }, { 213, 218 } } do
			rope(m, T(d[1], 100.5, 5.2), T(d[2], 122.5, DECK + 2.6))
		end
	end

	-- ---- Gözetleme kulesi (eski START salının yerinde): korsan tepede durur, kapı açılınca düşman gemisini gösterir -----
	local TOWER = { s = 140, u = -86, top = 30 }
	do
		local m = Instance.new("Model")
		m.Name = "LookoutTower"
		m.Parent = f
		local s0, u0, H = TOWER.s, TOWER.u, TOWER.top
		-- dört kalın ayak (deniz dibinden), çapraz kuşaklar
		local legs = {}
		for _, d in { { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } } do
			local p = T(s0 + d[1], u0 + d[2])
			Util.pole(m, "Leg", p.X, p.Z, -30, H, 1.8, DARK, Enum.Material.Wood)
			table.insert(legs, d)
		end
		for _, y in { 4, 14, 24 } do
			for i = 1, 4 do
				local a, b = legs[i], legs[i % 4 + 1]
				Util.noCollide(Util.rod(m, "Brace", T(s0 + a[1], u0 + a[2], y), T(s0 + b[1], u0 + b[2], y + 8), 0.8, WOOD, Enum.Material.Wood))
			end
		end
		-- su seviyesinde iskele basamağı + merdiven
		Util.part(m, "Landing", Vector3.new(14, 1, 6), F(s0, u0 + 10, 2), WOOD, Enum.Material.WoodPlanks)
		for _, side in { -1.6, 1.6 } do
			Util.noCollide(Util.rod(m, "LadderRail", T(s0 + side, u0 + 8.8, 2), T(s0 + side, u0 + 8.4, H + 3), 0.4, DARK, Enum.Material.Wood))
		end
		for y = 4, H, 2.4 do
			Util.noCollide(Util.cyl(m, "Rung", 3.2, 0.3, F(s0, u0 + 8.8 - (y / H) * 0.4, y) * CFrame.Angles(0, math.pi / 2, 0), DARK, Enum.Material.Wood))
		end
		-- gözetleme platformu, korkuluk, çatı
		Util.part(m, "Platform", Vector3.new(16, 1, 16), F(s0, u0, H + 0.5), WOOD, Enum.Material.WoodPlanks)
		for _, d in { { -7.5, -7.5 }, { 7.5, -7.5 }, { -7.5, 7.5 }, { 7.5, 7.5 } } do
			local p = T(s0 + d[1], u0 + d[2])
			Util.pole(m, "RoofPost", p.X, p.Z, H + 1, H + 11, 0.8, DARK, Enum.Material.Wood)
		end
		for _, e in { { 0, -7.5, 16, 0.4 }, { 0, 7.5, 16, 0.4 }, { -7.5, 0, 0.4, 16 }, { 7.5, 0, 0.4, 16 } } do
			Util.part(m, "Railing", Vector3.new(e[4] < 1 and e[4] or 16, 0.4, e[3] < 1 and e[3] or 16), F(s0 + e[1], u0 + e[2], H + 4), DARK, Enum.Material.Wood)
		end
		Util.part(m, "Roof", Vector3.new(19, 1, 19), F(s0, u0, H + 11.5), Color3.fromRGB(120, 82, 52), Enum.Material.WoodPlanks)
		Util.part(m, "RoofTier", Vector3.new(14, 1, 14), F(s0, u0, H + 12.5), Color3.fromRGB(110, 74, 46), Enum.Material.WoodPlanks)
		Util.part(m, "RoofTier", Vector3.new(8, 1, 8), F(s0, u0, H + 13.5), Color3.fromRGB(100, 66, 42), Enum.Material.WoodPlanks)
		-- tepede korsan bayrağı, fener, fıçı, dürbün sehpası
		local fp = T(s0 - 7, u0 - 7)
		Util.pole(m, "FlagPole", fp.X, fp.Z, H + 1, H + 26, 0.7, DARK, Enum.Material.Wood)
		local flagP = Util.part(m, "Flag", Vector3.new(0.2, 5, 8), F(s0 - 7, u0 - 7, H + 23.5) * CFrame.new(0, 0, -4.2), Color3.fromRGB(22, 22, 26), Enum.Material.Fabric)
		flagP.CanCollide = false
		Util.sign(flagP, Enum.NormalId.Right, "☠", Color3.fromRGB(236, 230, 214))
		Util.sign(flagP, Enum.NormalId.Left, "☠", Color3.fromRGB(236, 230, 214))
		torch(m, T(s0 + 6.5, u0 - 6.5, H + 1))
		torch(m, T(s0 - 6.5, u0 + 6.5, H + 1))
		Util.cyl(m, "Barrel", 3.6, 2.8, F(s0 + 5.5, u0 + 5.5, H + 2.8) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(122, 84, 52), Enum.Material.Wood)
		Util.cyl(m, "Spyglass", 3.4, 0.6, F(s0 - 5, u0 + 4, H + 5) * CFrame.Angles(0, 0.6, 0.25), GOLD, Enum.Material.Metal).CanCollide = false
		Util.part(m, "SpyglassStand", Vector3.new(0.5, 4, 0.5), F(s0 - 5, u0 + 4, H + 3), DARK, Enum.Material.Wood)
	end
	Util.zone(f, "PirateTowerSpot", Vector3.new(2, 2, 2), F(TOWER.s, TOWER.u, TOWER.top + 1))

	local lx, lz = L(205, 0)
	label(f, lx, lz, "Gunnery Range", 38)

	-- Atmosfer: arka kayalık + kafatası mağarası + şelale, halatlar/bayraklar, sarmaşık, sis, fenerler (TrainingDecor.luau)
	require(script.Parent.TrainingDecor).Build(f, frame, { torch = torch })

	-- ---- Kapı vinci: korsan burada durur, anahtarı olan gelince çarkı çevirip kapıyı açar -----------------------------
	local GY = 10 -- buradaki çimen zeminin yüksekliği
	do
		local m = Instance.new("Model")
		m.Name = "GateWinch"
		m.Parent = f
		Util.part(m, "WinchDeck", Vector3.new(26, 1, 20), F(36, -104, GY + 0.5), WOOD, Enum.Material.WoodPlanks)
		for _, d in { { 27, -116 }, { 27, -92 }, { 45, -116 }, { 45, -92 } } do
			local p = T(d[1], d[2])
			Util.pole(m, "DeckPost", p.X, p.Z, GY - 2, GY + 1, 1.2, DARK, Enum.Material.Wood)
		end
		-- çark (capstan): gövde, üst kapak, kollar
		local c = F(33, -108, GY + 1)
		Util.cyl(m, "CapstanBody", 5, 4.6, c * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Wood)
		Util.cyl(m, "CapstanTop", 1, 6, c * CFrame.new(0, 5.4, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(120, 82, 52), Enum.Material.WoodPlanks)
		for k = 0, 3 do
			Util.cyl(m, "CapstanBar", 11, 0.8, c * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, k * math.pi / 4, 0), Color3.fromRGB(140, 98, 60), Enum.Material.Wood)
		end
		for _, y in { 1.5, 3.4 } do
			Util.cyl(m, "CapstanHoop", 0.5, 4.9, c * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), METAL, Enum.Material.Metal)
		end
		-- zincir: çarktan surun üstündeki makaraya, oradan sol kanadın üst köşesine
		local pulley = T(2, -70, 60)
		Util.cyl(m, "Pulley", 2, 4, CFrame.new(pulley) * CFrame.Angles(0, 0, 0), METAL, Enum.Material.Metal)
		local chainA = Util.rod(m, "Chain", T(33, -105.6, GY + 3), pulley, 0.7, METAL, Enum.Material.DiamondPlate)
		chainA.CanCollide = false
		-- kol (manivela) + işaret tabelası
		Util.part(m, "LeverBase", Vector3.new(3, 1.6, 3), F(40, -96, GY + 1.8), METAL, Enum.Material.Metal)
		Util.part(m, "Lever", Vector3.new(0.7, 6, 0.7), F(40, -96, GY + 5) * CFrame.Angles(0, 0, math.rad(-20)), DARK, Enum.Material.Wood)
		Util.ball(m, "LeverKnob", Vector3.new(1.4, 1.4, 1.4), F(40, -96, GY + 5) * CFrame.Angles(0, 0, math.rad(-20)) * CFrame.new(0, 3, 0), Color3.fromRGB(170, 30, 30), Enum.Material.SmoothPlastic)
		torch(m, T(27, -96, GY + 1))
		local tp = T(45, -114, GY + 1)
		torch(m, tp)
		barrel(m, 44, -98, 4)
		-- deck yüksekliği fonksiyonları DECK'e göre çalışıyor: fıçıyı vinç zeminine indir
		for _, d in m:GetChildren() do
			if d.Name == "Barrel" or d.Name == "Hoop" then
				d.CFrame = d.CFrame - Vector3.new(0, DECK - GY - 1, 0)
			end
		end
	end
	-- oyuncunun gemiyi getirip ateş edeceği nokta (Config/Practice.FireSpot) — client burada parlayan halka çizer
	Util.zone(f, "FireSpot", Vector3.new(4, 4, 4), F(PS.FireSpot.s, PS.FireSpot.u, 1))

	-- Korsan öğretmeni gözetleme kulesinin tepesine taşı (kıyıdaki asıl NPC Studio'da duruyor). Düşman gemisine bakar.
	local npcs = Workspace:FindFirstChild("NPCs")
	local pirate = npcs and npcs:FindFirstChild("Pirate Tutor")
	if pirate then
		local top = TOWER.top + 1
		local spot = T(TOWER.s + 2, TOWER.u + 2, top)
		local face = T(PS.Berth.s, PS.Berth.u, top)
		pirate:PivotTo(CFrame.lookAt(spot + Vector3.new(0, 3, 0), Vector3.new(face.X, spot.Y + 3, face.Z)))
		local bb, sz = pirate:GetBoundingBox()
		pirate:PivotTo(pirate:GetPivot() + Vector3.new(0, top - (bb.Position.Y - sz.Y / 2), 0))
	end
end

-- Aşama aşama çalıştırılabilir (Studio Edit modunda command bar / execute_luau):
--   B.Atoll("sea") ; B.Atoll("land") ; B.Atoll("maze") ; B.Atoll("border") ; B.Atoll("props")
--   B.Atoll("terrain") = sea + land + maze + border ; B.Atoll() = hepsi
-- Sadece kapı kanatlarını yeniden kurar (B.Atoll("gate")). Sur, kuleler, tabela yerinde kalır.
function Atoll.Gate(c)
	C = C or c or cfg()
	O = O or C.Origin
	local B = bandInfo()
	local atoll = Workspace:FindFirstChild("Atoll")
	local gate = atoll and atoll:FindFirstChild("CastleGate", true)
	if not gate then
		warn("[Atoll] CastleGate yok")
		return
	end
	local old = gate:FindFirstChild("GateDoors")
	if old then
		old:Destroy()
	end
	-- eski (tek parça kurulmuş) kanat parçalarını temizle
	for _, d in gate:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "GatePanel" or d.Name == "Plank" or d.Name == "GateBand" or d.Name == "Rivet" or d.Name == "HingeStrap"
			or d.Name == "HingePin" or d.Name == "Spike" or d.Name == "Boss" or d.Name == "Ring" or d.Name == "GateBar" or d.Name == "BarBracket" or d.Name == "GateLock") then
			d:Destroy()
		end
	end
	local basis = CFrame.lookAt(Vector3.new(O.X + B.gx, 0, O.Z + B.gz), Vector3.new(O.X + B.gx + B.nx, 0, O.Z + B.gz + B.nz))
	gateDoors(gate, basis)
end

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
	if all or stage == "terrain" or stage == "paint" then
		for k = 1, 4 do
			Atoll.Paint(C, k, 4)
		end
	elseif stage and stage:match("^paint%d$") then
		Atoll.Paint(C, tonumber(stage:sub(6)), 4)
	end
	if all or stage == "props" then
		Atoll.Structures(C)
	elseif stage == "training" then
		Atoll.Training(C)
	elseif stage == "gate" then
		Atoll.Gate(C)
	end
end

return Atoll
