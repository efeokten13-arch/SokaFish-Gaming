--!nonstrict
-- Ana ada: plaza, Fish Market, tekne dükkanı, doğu iskelesi, kulübeler, süsler.
local Workspace = game:GetService("Workspace")
local Util = require(script.Parent.Util)
local Land = require(script.Parent.Land)
local Decor = require(script.Parent.Decor)

local Structures = {}

local WOOD = Color3.fromRGB(139, 94, 60)
local DARK = Color3.fromRGB(92, 62, 40)
local WALL = Color3.fromRGB(226, 208, 170)
local ROOF = Color3.fromRGB(176, 84, 60)
local STONE = Color3.fromRGB(150, 150, 156)
local CREAM = Color3.fromRGB(255, 244, 214)

local function ring(parent, cx, y, cz, radius, segs, width, color)
	for i = 0, segs - 1 do
		local a0, a1 = i / segs * math.pi * 2, (i + 1) / segs * math.pi * 2
		local p0 = Vector3.new(cx + math.cos(a0) * radius, y, cz + math.sin(a0) * radius)
		local p1 = Vector3.new(cx + math.cos(a1) * radius, y, cz + math.sin(a1) * radius)
		local b = Util.beam(parent, "RingSeg", p0, p1, width, 0.3, color, Enum.Material.Neon)
		b.CanCollide = false
	end
end

function Structures.Plaza(cfg)
	local P = cfg.Plaza
	Land.paintDisc(P.x, P.z, P.radius, Enum.Material.Cobblestone)
	Land.paintDisc(P.x, P.z, P.radius * 0.62, Enum.Material.Slate)
	-- yol: plazadan iskeleye
	Land.path(Vector3.new(P.x + P.radius - 4, 0, P.z), Vector3.new(cfg.Pier.startX, 0, 0), 6, Enum.Material.Sandstone)
	-- hole giden yol
	Land.path(Vector3.new(P.x, 0, P.z - P.radius + 4), Vector3.new(cfg.Hall.x, 0, cfg.Hall.z + cfg.Hall.depth / 2 + 4), 6, Enum.Material.Sandstone)

	local f = Util.fresh("Model", "Plaza")
	local y = cfg.GrassY + 0.15
	ring(f, P.x, y, P.z, 29, 48, 1.1, Color3.fromRGB(120, 230, 255))
	ring(f, P.x, y, P.z, 24, 40, 0.5, Color3.fromRGB(255, 226, 150))
	-- yıldız (pentagram)
	local pts = {}
	for k = 0, 4 do
		local a = math.rad(-90 + k * 72)
		pts[k] = Vector3.new(P.x + math.cos(a) * 24, y, P.z + math.sin(a) * 24)
	end
	for k = 0, 4 do
		local b = Util.beam(f, "StarLine", pts[k], pts[(k + 2) % 5], 0.8, 0.3, Color3.fromRGB(255, 226, 150), Enum.Material.Neon)
		b.CanCollide = false
	end
	local core = Util.cyl(f, "StarCore", 0.4, 5, CFrame.new(P.x, y, P.z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(120, 230, 255), Enum.Material.Neon)
	core.CanCollide = false
	Util.light(core, 1.5, 50, Color3.fromRGB(150, 235, 255))
	-- heykeller
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local pos = Vector3.new(P.x + math.cos(a) * 35, cfg.GrassY, P.z + math.sin(a) * 35)
		Decor.fishStatue(f, pos, -a + math.pi / 2)
	end
	-- fenerler
	for k = 0, 7 do
		local a = math.rad(k * 45 + 22.5)
		Decor.lamp(f, Vector3.new(P.x + math.cos(a) * 39, cfg.GrassY, P.z + math.sin(a) * 39))
	end
	-- Spawn plazanın ortasında
	local sp = Workspace:FindFirstChildOfClass("SpawnLocation")
	if sp then
		sp.Anchored = true
		sp.Size = Vector3.new(10, 1, 10)
		sp.CFrame = CFrame.new(P.x, cfg.GrassY + 0.5, P.z + 12)
		sp.Transparency = 1
		sp.CanCollide = false
		local dec = sp:FindFirstChildOfClass("Decal")
		if dec then dec.Transparency = 1 end
	end
	return f
end

-- Fish Market binası + SellCounter + BoatShop
function Structures.Hall(cfg)
	local H = cfg.Hall
	local m = Util.fresh("Model", "MainHall")
	local g = cfg.GrassY
	local wallH = 13
	local cx, cz = H.x, H.z
	local w, d = H.width, H.depth

	Util.part(m, "Foundation", Vector3.new(w + 6, 1.2, d + 6), CFrame.new(cx, g + 0.4, cz), STONE, Enum.Material.Cobblestone)
	local fy = g + 1 -- zemin üstü
	-- arka ve yan duvarlar
	Util.part(m, "WallBack", Vector3.new(w, wallH, 1.5), CFrame.new(cx, fy + wallH / 2, cz - d / 2), WALL, Enum.Material.Brick)
	Util.part(m, "WallWest", Vector3.new(1.5, wallH, d), CFrame.new(cx - w / 2, fy + wallH / 2, cz), WALL, Enum.Material.Brick)
	Util.part(m, "WallEast", Vector3.new(1.5, wallH, d), CFrame.new(cx + w / 2, fy + wallH / 2, cz), WALL, Enum.Material.Brick)
	-- ön cephe: ortada 16 stud'luk geniş kapı
	local gate = 18
	local sideW = (w - gate) / 2
	Util.part(m, "WallFrontL", Vector3.new(sideW, wallH, 1.5), CFrame.new(cx - gate / 2 - sideW / 2, fy + wallH / 2, cz + d / 2), WALL, Enum.Material.Brick)
	Util.part(m, "WallFrontR", Vector3.new(sideW, wallH, 1.5), CFrame.new(cx + gate / 2 + sideW / 2, fy + wallH / 2, cz + d / 2), WALL, Enum.Material.Brick)
	Util.part(m, "Lintel", Vector3.new(gate, 4, 1.5), CFrame.new(cx, fy + wallH - 2, cz + d / 2), WALL, Enum.Material.Brick)
	-- ahşap kirişler
	for _, x in { -w / 2, -gate / 2, gate / 2, w / 2 } do
		Util.part(m, "Post", Vector3.new(1.6, wallH, 1.8), CFrame.new(cx + x, fy + wallH / 2, cz + d / 2 + 0.4), DARK, Enum.Material.Wood)
	end
	-- çatı: iki eğik tahta + alınlık basamakları
	local rise = 10
	local half = d / 2
	local ang = math.atan2(rise, half)
	local len = math.sqrt(half * half + rise * rise) + 3
	local topY = fy + wallH
	for _, s in { -1, 1 } do
		local board = Util.part(m, "Roof", Vector3.new(w + 6, 1.2, len),
			CFrame.new(cx, topY + rise / 2 + 0.6, cz + s * (half / 2 - 0.5)) * CFrame.Angles(s * ang, 0, 0), ROOF, Enum.Material.Slate)
		board.Name = "Roof"
	end
	local steps = 6
	for k = 0, steps - 1 do
		local sw = d * (1 - (k + 0.5) / steps)
		local sh = rise / steps
		for _, sx in { -w / 2, w / 2 } do
			Util.part(m, "Gable", Vector3.new(1.5, sh + 0.05, sw), CFrame.new(cx + sx, topY + sh * (k + 0.5), cz), WALL, Enum.Material.Brick)
		end
	end
	-- Fish Market tabelası
	local board = Util.part(m, "SignBoard", Vector3.new(30, 6, 1), CFrame.new(cx, topY + 2.5, cz + d / 2 + 2.2), Color3.fromRGB(40, 90, 120), Enum.Material.WoodPlanks)
	Util.sign(board, Enum.NormalId.Back, "FISH MARKET", CREAM)
	Util.light(board, 0.6, 24)
	-- İç zemin
	Util.part(m, "Floor", Vector3.new(w - 2, 0.4, d - 2), CFrame.new(cx, fy + 0.2, cz), Color3.fromRGB(158, 120, 84), Enum.Material.WoodPlanks)
	-- SellCounter: girişin içinde tezgah
	local counter = Util.part(m, "SellCounter", Vector3.new(26, 4, 4), CFrame.new(cx, fy + 2.4, cz - d / 2 + 9), WOOD, Enum.Material.WoodPlanks)
	Util.part(m, "CounterTop", Vector3.new(27, 0.6, 5), CFrame.new(cx, fy + 4.7, cz - d / 2 + 9), DARK, Enum.Material.Wood)
	local cs = Util.part(m, "CounterSign", Vector3.new(10, 3, 0.4), CFrame.new(cx, fy + 8.4, cz - d / 2 + 2), Color3.fromRGB(40, 90, 120), Enum.Material.WoodPlanks)
	Util.sign(cs, Enum.NormalId.Back, "SELL FISH", CREAM)
	-- balık tezgahları (süs)
	for _, sx in { -22, 22 } do
		Util.part(m, "Stall", Vector3.new(10, 3, 5), CFrame.new(cx + sx, fy + 1.7, cz + 2), WOOD, Enum.Material.WoodPlanks)
		Util.part(m, "StallIce", Vector3.new(9, 0.4, 4), CFrame.new(cx + sx, fy + 3.4, cz + 2), Color3.fromRGB(210, 238, 250), Enum.Material.Ice)
	end
	Util.light(Util.zone(m, "Lamp1", Vector3.new(1, 1, 1), CFrame.new(cx, topY - 2, cz)), 1.4, 60)

	-- BoatShop: salonun doğusunda küçük bir dükkan
	local bx, bz = cx + w / 2 + 26, cz + 4
	local shop = Instance.new("Model")
	shop.Name = "BoatShopBuilding"
	Util.part(shop, "Base", Vector3.new(18, 1, 14), CFrame.new(bx, g + 0.5, bz), STONE, Enum.Material.Cobblestone)
	Util.part(shop, "Back", Vector3.new(16, 9, 1), CFrame.new(bx, g + 5.5, bz - 6), WALL, Enum.Material.Brick)
	Util.part(shop, "Left", Vector3.new(1, 9, 12), CFrame.new(bx - 8, g + 5.5, bz), WALL, Enum.Material.Brick)
	Util.part(shop, "Right", Vector3.new(1, 9, 12), CFrame.new(bx + 8, g + 5.5, bz), WALL, Enum.Material.Brick)
	Util.part(shop, "Roof", Vector3.new(20, 1, 16), CFrame.new(bx, g + 10.5, bz), ROOF, Enum.Material.Slate)
	local bs = Util.part(m, "BoatShop", Vector3.new(14, 4, 3), CFrame.new(bx, g + 2.5, bz + 3), WOOD, Enum.Material.WoodPlanks)
	local sb = Util.part(shop, "ShopSign", Vector3.new(12, 3, 0.5), CFrame.new(bx, g + 12.5, bz + 6.5), Color3.fromRGB(40, 90, 120), Enum.Material.WoodPlanks)
	Util.sign(sb, Enum.NormalId.Back, "BOAT SHOP", CREAM)
	shop.Parent = m
	Land.path(Vector3.new(bx, 0, bz + 10), Vector3.new(cfg.Plaza.x + cfg.Plaza.radius - 4, 0, cfg.Plaza.z), 5, Enum.Material.Sandstone)

	m.PrimaryPart = counter
	return m
end

-- Doğu iskelesi (L şeklinde) + 5 tekne yuvası
function Structures.Pier(cfg)
	local P = cfg.Pier
	local m = Util.fresh("Model", "Pier")
	local y = cfg.DeckY
	local function deck(name, x0, z0, x1, z1)
		local len = math.max(math.abs(x1 - x0), math.abs(z1 - z0))
		local alongX = math.abs(x1 - x0) > math.abs(z1 - z0)
		local size = alongX and Vector3.new(len, 1, P.width) or Vector3.new(P.width, 1, len)
		return Util.part(m, name, size, CFrame.new((x0 + x1) / 2, y - 0.5, (z0 + z1) / 2), WOOD, Enum.Material.WoodPlanks)
	end
	local function posts(x0, z0, x1, z1, step, sideX, sideZ)
		local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
		local n = math.max(1, math.floor(len / step))
		for i = 0, n do
			local t = i / n
			local x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
			for _, s in { -1, 1 } do
				Util.pole(m, "Piling", x + sideX * s * (P.width / 2 - 0.6), z + sideZ * s * (P.width / 2 - 0.6), -10, y + 1.8, 1.1, DARK, Enum.Material.Wood)
			end
		end
	end
	-- bağlantı yolu (karadan ana iskeleye)
	deck("Connector", P.startX, 0, P.x + P.width / 2, 0)
	posts(P.startX + 30, 0, P.x, 0, 12, 0, 1)
	-- ana iskele (kuzey-güney)
	deck("MainPier", P.x, P.zTop, P.x, P.zBottom)
	posts(P.x, P.zTop, P.x, P.zBottom, 12, 1, 0)
	-- parmak iskeleler: slot i, parmak i ile i+1 arasında
	local slotNames = { "KAYAK", "ROWBOAT", "SLOOP", "WARSHIP", "SHIP 5" }
	local spawn
	local fingerLen = 34
	local x0 = P.x + P.width / 2
	for k = 0, P.slots do
		local z = P.firstSlotZ - P.slotSpacing / 2 + k * P.slotSpacing
		local f = Util.part(m, "Finger", Vector3.new(fingerLen, 1, 3), CFrame.new(x0 + fingerLen / 2, y - 0.5, z), WOOD, Enum.Material.WoodPlanks)
		for _, px in { x0 + 3, x0 + fingerLen - 2 } do
			Util.pole(m, "Piling", px, z, -10, y + 1.5, 0.9, DARK, Enum.Material.Wood)
		end
	end
	for i = 0, P.slots - 1 do
		local z = P.firstSlotZ + i * P.slotSpacing
		local post = Util.pole(m, "SlotPost", x0 + 1.5, z, y, y + 8, 0.6, DARK, Enum.Material.Wood)
		local sb = Util.part(m, "SlotSign", Vector3.new(0.5, 3, 9), CFrame.new(x0 + 1.5, y + 7.6, z), Color3.fromRGB(40, 90, 120), Enum.Material.WoodPlanks)
		Util.sign(sb, Enum.NormalId.Right, i == 0 and "SLIP 1\nKAYAK" or ("SLIP " .. (i + 1) .. "\nEMPTY"), CREAM)
		if i == 0 then
			spawn = Util.zone(m, "BoatSpawn", Vector3.new(10, 1, 10), CFrame.new(x0 + 17, 1, z))
		end
	end
	-- iskele başında büyük tabela + fenerler
	local arch = Util.part(m, "PierSign", Vector3.new(1, 4, 16), CFrame.new(P.x - P.width / 2 - 0.5, y + 10, P.zTop + 6), Color3.fromRGB(40, 90, 120), Enum.Material.WoodPlanks)
	Util.sign(arch, Enum.NormalId.Left, "HARBOR", CREAM)
	Util.pole(m, "SignPost", P.x - P.width / 2 - 0.5, P.zTop + 1, y, y + 8, 0.8, DARK, Enum.Material.Wood)
	Util.pole(m, "SignPost2", P.x - P.width / 2 - 0.5, P.zTop + 11, y, y + 8, 0.8, DARK, Enum.Material.Wood)
	for z = P.zTop + 10, P.zBottom, 30 do
		Decor.lamp(m, Vector3.new(P.x - P.width / 2 + 0.8, y, z))
	end
	m.PrimaryPart = spawn
	return m
end

-- Ana adada küçük kulübeler, ağ askıları, sandıklar, palmiyeler
function Structures.Props(cfg)
	local f = Util.fresh("Model", "MainIslandProps")
	local g = cfg.GrassY
	local rng = Random.new(cfg.Seed + 5)
	-- kulübeler
	for _, h in { { 120, 85 }, { -135, 70 }, { -150, -60 } } do
		local x, z = h[1], h[2]
		Util.part(f, "HutBase", Vector3.new(16, 1, 14), CFrame.new(x, g + 0.5, z), STONE, Enum.Material.Cobblestone)
		Util.part(f, "HutWalls", Vector3.new(14, 8, 12), CFrame.new(x, g + 5, z), Color3.fromRGB(190, 150, 104), Enum.Material.WoodPlanks)
		Util.part(f, "HutRoof", Vector3.new(17, 1, 15), CFrame.new(x, g + 9.5, z), Color3.fromRGB(176, 84, 60), Enum.Material.Slate)
		local door = Util.part(f, "HutDoor", Vector3.new(3, 5, 0.4), CFrame.new(x, g + 3.5, z + 6.1), DARK, Enum.Material.Wood)
		Util.part(f, "HutWindow", Vector3.new(3, 3, 0.4), CFrame.new(x + 4.5, g + 6, z + 6.1), Color3.fromRGB(150, 210, 235), Enum.Material.Glass)
		Decor.crate(f, Vector3.new(x - 8, g, z + 8), rng:NextNumber(0, 3))
		Decor.barrel(f, Vector3.new(x + 8, g, z + 8))
	end
	-- ağ askıları
	Decor.netRack(f, Vector3.new(-120, g, 120), Vector3.new(-96, g, 120), 9)
	Decor.netRack(f, Vector3.new(60, g, 100), Vector3.new(84, g, 100), 9)
	Decor.netRack(f, Vector3.new(160, g, -40), Vector3.new(160, g, -16), 9)
	-- salon çevresi
	for k = 0, 5 do
		Decor.crate(f, Vector3.new(cfg.Hall.x - 36 - (k % 2) * 3.4, g, cfg.Hall.z + 26 + math.floor(k / 2) * 3.4), rng:NextNumber(0, 3))
	end
	Decor.barrel(f, Vector3.new(cfg.Hall.x + 36, g, cfg.Hall.z + 24))
	Decor.barrel(f, Vector3.new(cfg.Hall.x + 39, g, cfg.Hall.z + 24))
	-- palmiyeler (plaza, salon ve iskele yolundan uzak)
	local placed, tries = 0, 0
	while placed < 26 and tries < 400 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(70, 200)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local okFar = true
		if (Vector2.new(x, z) - Vector2.new(cfg.Plaza.x, cfg.Plaza.z)).Magnitude < cfg.Plaza.radius + 8 then okFar = false end
		if math.abs(x - cfg.Hall.x) < cfg.Hall.width / 2 + 30 and math.abs(z - cfg.Hall.z) < cfg.Hall.depth / 2 + 30 then okFar = false end
		if z > -14 and z < 14 and x > 0 then okFar = false end
		if x > 40 and z > -20 and z < 30 then okFar = false end
		local gy = Util.groundY(x, z)
		if okFar and gy and gy > 4 and gy < 8 then
			Decor.palm(f, Vector3.new(x, g, z), rng)
			placed += 1
		end
	end
	return f
end

return Structures
