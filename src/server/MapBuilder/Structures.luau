--!nonstrict
-- Ana ada: plaza, Fish Market, tekne dükkanı, doğu iskelesi, kulübeler, süsler.
local Workspace = game:GetService("Workspace")
local Util = require(script.Parent.Util)
local Land = require(script.Parent.Land)
local Decor = require(script.Parent.Decor)
local BoatModels = require(script.Parent.Parent.Boat.BoatModels)
local BoatsCfg = require(game:GetService("ReplicatedStorage").Shared.Config.Boats)

local Structures = {}

local WOOD = Color3.fromRGB(139, 94, 60)
local DARK = Color3.fromRGB(92, 62, 40)
local WALL = Color3.fromRGB(182, 132, 86) -- ahşap duvar
local WALLMAT = Enum.Material.WoodPlanks
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
	Land.paintDisc(P.x, P.z, P.radius * 0.62, Enum.Material.Slate, Enum.Material.Cobblestone)
	-- yollar: plazadan iskeleye, hole, kulübelere, balıkçıya, sahillere
	local SAND = Enum.Material.Sandstone
	Land.path(Vector3.new(P.x + P.radius - 4, 0, P.z), Vector3.new(cfg.Pier.startX + 2, 0, cfg.Pier.walkZ), 6, SAND)
	-- dalgalı patikalar (doğal görünüm)
	Land.wavyPath(Vector3.new(P.x, 0, P.z - P.radius + 4), Vector3.new(cfg.Hall.x, 0, cfg.Hall.z + cfg.Hall.depth / 2 + 4), 6, SAND, 11, 4, 1)
	for i, h in { { -135, 70 }, { -150, -60 } } do
		local a = Vector3.new(P.x, 0, P.z)
		local b = Vector3.new(h[1], 0, h[2] + 10)
		Land.wavyPath(a + (b - a).Unit * (P.radius - 4), b, 4.5, SAND, 20 + i, 6, 1.5)
	end
	Land.wavyPath(Vector3.new(P.x, 0, P.z + P.radius - 4), Vector3.new(P.x, 0, 200), 5, SAND, 31, 6, 1.5)
	Land.wavyPath(Vector3.new(P.x - P.radius + 4, 0, P.z), Vector3.new(-200, 0, P.z), 5, SAND, 41, 6, 1.5)

	local f = Util.fresh("Model", "Plaza")
	local g = cfg.GrassY
	local STONE2 = Color3.fromRGB(196, 190, 178)
	-- pusula işlemesi (parlamayan taş)
	for k = 0, 3 do
		local a = math.rad(k * 90)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p0 = Vector3.new(P.x, g + 0.08, P.z) + dir * 11
		local p1 = Vector3.new(P.x, g + 0.08, P.z) + dir * 26
		Util.noCollide(Util.beam(f, "Inlay", p0, p1, 1.4, 0.15, STONE2, Enum.Material.Marble))
	end
	-- çeşme
	local fc = CFrame.new(P.x, g, P.z)
	local up = CFrame.Angles(0, 0, math.pi / 2)
	Util.cyl(f, "Basin", 2.2, 20, fc * CFrame.new(0, 1.1, 0) * up, Color3.fromRGB(150, 146, 140), Enum.Material.Cobblestone)
	Util.cyl(f, "BasinRim", 0.5, 20.6, fc * CFrame.new(0, 2.3, 0) * up, STONE2, Enum.Material.Marble)
	local water = Util.cyl(f, "Water", 0.4, 17.4, fc * CFrame.new(0, 2.15, 0) * up, Color3.fromRGB(60, 150, 200), Enum.Material.Glass)
	water.Transparency = 0.25
	water.CanCollide = false
	Util.cyl(f, "Column", 5, 2.4, fc * CFrame.new(0, 4.6, 0) * up, STONE2, Enum.Material.Marble)
	Util.cyl(f, "Bowl", 0.8, 7, fc * CFrame.new(0, 7.3, 0) * up, Color3.fromRGB(150, 146, 140), Enum.Material.Cobblestone)
	local top = Util.cyl(f, "BowlWater", 0.3, 6, fc * CFrame.new(0, 7.75, 0) * up, Color3.fromRGB(60, 150, 200), Enum.Material.Glass)
	top.Transparency = 0.25
	Util.ball(f, "Finial", Vector3.new(1.4, 2, 1.4), fc * CFrame.new(0, 8.8, 0), Color3.fromRGB(205, 175, 100), Enum.Material.Metal)
	Util.light(top, 0.5, 18, Color3.fromRGB(200, 230, 255))
	-- heykeller
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local pos = Vector3.new(P.x + math.cos(a) * 35, g, P.z + math.sin(a) * 35)
		Decor.fishStatue(f, pos, -a + math.pi / 2)
	end
	-- fenerler
	for k = 0, 7 do
		local a = math.rad(k * 45 + 22.5)
		Decor.lamp(f, Vector3.new(P.x + math.cos(a) * 39, g, P.z + math.sin(a) * 39))
	end
	-- heykellerin arasında tropikal saksılar (yolları kapatmasın diye çaprazlarda değil, yolların yanında)
	local rng = Random.new(cfg.Seed + 33)
	for k = 0, 3 do
		for _, side in { -1, 1 } do
			local a = math.rad(k * 90 + side * 17)
			local pos = Vector3.new(P.x + math.cos(a) * 31, g, P.z + math.sin(a) * 31)
			Util.cyl(f, "Planter", 2, 6, CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(150, 146, 140), Enum.Material.Cobblestone)
			Util.cyl(f, "Soil", 0.3, 5.4, CFrame.new(pos + Vector3.new(0, 2.05, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(90, 64, 42), Enum.Material.Ground)
			if k % 2 == 0 then
				Decor.fern(f, pos + Vector3.new(0, 2, 0), rng)
			else
				Decor.bush(f, pos + Vector3.new(0, 1.6, 0), rng)
			end
			Decor.flowers(f, pos + Vector3.new(0, 2.1, 0), rng)
		end
	end
	-- Spawn: çeşmenin önünde
	local sp = Workspace:FindFirstChildOfClass("SpawnLocation")
	if sp then
		sp.Anchored = true
		sp.Size = Vector3.new(10, 1, 10)
		sp.CFrame = CFrame.new(P.x, g + 0.5, P.z + 20)
		sp.Transparency = 1
		sp.CanCollide = false
		local dec = sp:FindFirstChildOfClass("Decal")
		if dec then
			dec.Transparency = 1
		end
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
	Land.paintRect(cx, cz, w + 34, d + 30, Enum.Material.Ground)

	Util.part(m, "Foundation", Vector3.new(w + 6, 1.2, d + 6), CFrame.new(cx, g + 0.4, cz), STONE, Enum.Material.Cobblestone)
	local fy = g + 1 -- zemin üstü
	-- arka ve yan duvarlar
	Util.part(m, "WallBack", Vector3.new(w, wallH, 1.5), CFrame.new(cx, fy + wallH / 2, cz - d / 2), WALL, WALLMAT)
	Util.part(m, "WallWest", Vector3.new(1.5, wallH, d), CFrame.new(cx - w / 2, fy + wallH / 2, cz), WALL, WALLMAT)
	Util.part(m, "WallEast", Vector3.new(1.5, wallH, d), CFrame.new(cx + w / 2, fy + wallH / 2, cz), WALL, WALLMAT)
	-- ön cephe: ortada 16 stud'luk geniş kapı
	local gate = 18
	local sideW = (w - gate) / 2
	Util.part(m, "WallFrontL", Vector3.new(sideW, wallH, 1.5), CFrame.new(cx - gate / 2 - sideW / 2, fy + wallH / 2, cz + d / 2), WALL, WALLMAT)
	Util.part(m, "WallFrontR", Vector3.new(sideW, wallH, 1.5), CFrame.new(cx + gate / 2 + sideW / 2, fy + wallH / 2, cz + d / 2), WALL, WALLMAT)
	Util.part(m, "Lintel", Vector3.new(gate, 4, 1.5), CFrame.new(cx, fy + wallH - 2, cz + d / 2), WALL, WALLMAT)
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
			Util.part(m, "Gable", Vector3.new(1.5, sh + 0.05, sw), CFrame.new(cx + sx, topY + sh * (k + 0.5), cz), WALL, WALLMAT)
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
	-- detaylar: yatay kalaslar, çatı mahyası ve kenar kirişleri, pencereler, tente, fenerler
	local frontZ = cz + d / 2 + 0.8
	for _, hy in { 3.2, 7.2, 11.2 } do
		Util.part(m, "Trim", Vector3.new(w + 0.4, 0.5, 0.3), CFrame.new(cx, fy + hy, frontZ - 0.05), DARK, Enum.Material.Wood)
	end
	Util.part(m, "Ridge", Vector3.new(w + 7, 1, 1.4), CFrame.new(cx, topY + rise + 0.9, cz), DARK, Enum.Material.Wood)
	for _, s in { -1, 1 } do
		Util.part(m, "Eave", Vector3.new(w + 7, 0.6, 0.6), CFrame.new(cx, topY + 0.3, cz + s * (half + 1.3)), DARK, Enum.Material.Wood)
	end
	for _, sx in { -1, 1 } do
		local wx = cx + sx * (gate / 2 + sideW / 2)
		Util.part(m, "WindowFrame", Vector3.new(7, 5, 0.4), CFrame.new(wx, fy + 6.5, frontZ + 0.1), DARK, Enum.Material.Wood)
		Util.part(m, "Window", Vector3.new(6, 4, 0.3), CFrame.new(wx, fy + 6.5, frontZ + 0.25), Color3.fromRGB(150, 205, 230), Enum.Material.Glass).Transparency = 0.3
		Util.part(m, "Sill", Vector3.new(7.6, 0.4, 1.2), CFrame.new(wx, fy + 3.9, frontZ + 0.6), DARK, Enum.Material.Wood)
		-- pencere altı çiçek kutusu
		Util.part(m, "FlowerBox", Vector3.new(6.4, 1, 1), CFrame.new(wx, fy + 3.3, frontZ + 0.7), Color3.fromRGB(120, 80, 48), Enum.Material.WoodPlanks)
		for k = -2, 2 do
			Util.noCollide(Util.ball(m, "Blossom", Vector3.new(1, 0.8, 1), CFrame.new(wx + k * 1.2, fy + 4, frontZ + 0.7), k % 2 == 0 and Color3.fromRGB(235, 70, 90) or Color3.fromRGB(250, 200, 60), Enum.Material.Fabric))
		end
		-- kapı yanı fener
		local lx = cx + sx * (gate / 2 + 1.6)
		Util.part(m, "LanternArm", Vector3.new(0.3, 0.3, 1.6), CFrame.new(lx, fy + 9.5, frontZ + 0.8), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
		local lan = Util.part(m, "Lantern", Vector3.new(1, 1.4, 1), CFrame.new(lx, fy + 8.7, frontZ + 1.5), Color3.fromRGB(255, 210, 130), Enum.Material.Glass)
		lan.Transparency = 0.2
		Util.light(lan, 0.9, 16)
	end
	-- çizgili tente
	for k = 0, 5 do
		local col = k % 2 == 0 and Color3.fromRGB(196, 60, 50) or Color3.fromRGB(245, 240, 228)
		Util.part(m, "Awning", Vector3.new(gate / 6, 0.25, 4), CFrame.new(cx - gate / 2 + gate / 12 + k * gate / 6, fy + 10.2, frontZ + 2) * CFrame.Angles(math.rad(18), 0, 0), col, Enum.Material.Fabric)
	end
	-- girişte balık sandıkları
	for k, sx in { -12, -9, 9, 12 } do
		local c = Util.part(m, "FishCrate", Vector3.new(2.6, 1.4, 2.2), CFrame.new(cx + sx, g + 1.9, frontZ + 4) * CFrame.Angles(0, math.rad(k * 7), 0), Color3.fromRGB(150, 104, 62), Enum.Material.WoodPlanks)
		Util.part(m, "Ice", Vector3.new(2.3, 0.3, 1.9), c.CFrame * CFrame.new(0, 0.7, 0), Color3.fromRGB(215, 240, 250), Enum.Material.Ice)
	end

	m.PrimaryPart = counter
	return m
end

-- Old Fisherman: plazanın yanında duran NPC. Ona konuşan oyuncu ada alır (FishermanService).
function Structures.Fisherman(cfg)
	local m = Util.fresh("Model", "OldFisherman")
	local g = cfg.GrassY
	local base = Vector3.new(cfg.Plaza.x + 16, g, cfg.Plaza.z + 28)
	local face = Vector3.new(cfg.Plaza.x, g, cfg.Plaza.z + 12) -- spawn'a bakar
	local cf = CFrame.lookAt(base, Vector3.new(face.X, base.Y, face.Z))
	local SKIN = Color3.fromRGB(226, 178, 140)
	local function box(name, size, off, color, mat)
		return Util.part(m, name, size, cf * CFrame.new(off), color, mat or Enum.Material.SmoothPlastic)
	end
	local function ball(name, size, off, color, mat)
		return Util.ball(m, name, size, cf * CFrame.new(off), color, mat or Enum.Material.SmoothPlastic)
	end
	box("LeftLeg", Vector3.new(0.9, 2, 1), Vector3.new(-0.5, 1, 0), Color3.fromRGB(60, 70, 90))
	box("RightLeg", Vector3.new(0.9, 2, 1), Vector3.new(0.5, 1, 0), Color3.fromRGB(60, 70, 90))
	local torso = box("Torso", Vector3.new(2.2, 2.2, 1.2), Vector3.new(0, 3.1, 0), Color3.fromRGB(40, 90, 140), Enum.Material.Fabric)
	box("LeftArm", Vector3.new(0.8, 2, 0.9), Vector3.new(-1.5, 3.1, 0), Color3.fromRGB(40, 90, 140), Enum.Material.Fabric)
	box("RightArm", Vector3.new(0.8, 2, 0.9), Vector3.new(1.5, 3.2, -0.6) , Color3.fromRGB(40, 90, 140), Enum.Material.Fabric)
	local head = ball("Head", Vector3.new(1.6, 1.7, 1.6), Vector3.new(0, 5.0, 0), SKIN)
	ball("Beard", Vector3.new(1.5, 1.4, 0.9), Vector3.new(0, 4.4, -0.55), Color3.fromRGB(235, 235, 240))
	ball("Mustache", Vector3.new(1.2, 0.35, 0.3), Vector3.new(0, 4.95, -0.85), Color3.fromRGB(235, 235, 240))
	ball("EyeL", Vector3.new(0.22, 0.22, 0.2), Vector3.new(-0.32, 5.2, -0.78), Color3.fromRGB(30, 30, 30))
	ball("EyeR", Vector3.new(0.22, 0.22, 0.2), Vector3.new(0.32, 5.2, -0.78), Color3.fromRGB(30, 30, 30))
	-- sarı yağmur şapkası
	Util.cyl(m, "HatBrim", 0.2, 3.2, cf * CFrame.new(0, 5.65, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(240, 190, 40), Enum.Material.Fabric)
	Util.cyl(m, "HatTop", 0.9, 1.7, cf * CFrame.new(0, 6.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(240, 190, 40), Enum.Material.Fabric)
	-- olta
	Util.rod(m, "Rod", (cf * CFrame.new(1.5, 2.8, -1.4)).Position, (cf * CFrame.new(3.2, 8.5, -3.6)).Position, 0.18, Color3.fromRGB(110, 76, 44), Enum.Material.Wood)
	Util.rod(m, "Line", (cf * CFrame.new(3.2, 8.5, -3.6)).Position, (cf * CFrame.new(3.2, 4.6, -3.6)).Position, 0.05, Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			p.CanCollide = (p.Name == "Torso" or p.Name == "LeftLeg" or p.Name == "RightLeg")
		end
	end
	-- isim levhası ve konuşma balonu
	local tag = Util.billboard(head, "Old Fisherman", 3.2, 170)
	tag.Name = "NameTag"
	local speech = Instance.new("BillboardGui")
	speech.Name = "Speech"
	speech.Size = UDim2.fromOffset(300, 70)
	speech.StudsOffset = Vector3.new(0, 6.4, 0)
	speech.MaxDistance = 90
	speech.Enabled = false
	speech.Parent = head
	local bg = Instance.new("TextLabel")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(255, 252, 240)
	bg.TextColor3 = Color3.fromRGB(40, 40, 40)
	bg.Font = Enum.Font.GothamMedium
	bg.TextScaled = true
	bg.Text = ""
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = bg
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = bg
	bg.Parent = speech
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Old Fisherman"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso
	m.PrimaryPart = torso
	return m
end

-- İskele: kıyıya paralel omurga + ortadan adaya yürüme yolu + adaya doğru parmaklar (tekne yuvaları)
function Structures.Pier(cfg)
	local P = cfg.Pier
	local m = Util.fresh("Model", "Pier")
	local y = cfg.DeckY
	local W2 = P.width / 2
	local function deckX(name, x0, x1, z, width)
		return Util.part(m, name, Vector3.new(math.abs(x1 - x0), 1, width), CFrame.new((x0 + x1) / 2, y - 0.5, z), WOOD, Enum.Material.WoodPlanks)
	end
	local function deckZ(name, z0, z1, x, width)
		return Util.part(m, name, Vector3.new(width, 1, math.abs(z1 - z0)), CFrame.new(x, y - 0.5, (z0 + z1) / 2), WOOD, Enum.Material.WoodPlanks)
	end
	local function pilings(x0, z0, x1, z1, step, offX, offZ)
		local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
		local n = math.max(1, math.floor(len / step))
		for i = 0, n do
			local t = i / n
			local x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
			for _, sgn in { -1, 1 } do
				local px, pz = x + offX * sgn, z + offZ * sgn
				local gy = Util.groundY(px, pz)
				if not gy or gy < 1 then -- karada kazık olmasın
					Util.pole(m, "Piling", px, pz, -10, y + 1.8, 1.1, DARK, Enum.Material.Wood)
				end
			end
		end
	end
	-- omurga (güney ucu karadaki çıkıntıya girer)
	deckZ("Spine", P.zTop, P.zBottom, P.x, P.width)
	pilings(P.x, P.zTop, P.x, P.zBottom, 12, W2 - 0.6, 0)
	-- ortadan adaya yürüme yolu
	deckX("Walkway", P.startX, P.x - W2, P.walkZ, 8)
	pilings(P.startX + 6, P.walkZ, P.x - W2, P.walkZ, 12, 0, 3.4)
	-- parmaklar: omurgadan adaya doğru (-X)
	local xIn = P.x - W2
	for _, z in P.fingers do
		Util.part(m, "Finger", Vector3.new(P.fingerLen, 1, 3), CFrame.new(xIn - P.fingerLen / 2, y - 0.5, z), WOOD, Enum.Material.WoodPlanks)
		Util.pole(m, "Piling", xIn - P.fingerLen + 2, z, -10, y + 1.5, 0.9, DARK, Enum.Material.Wood)
		Util.pole(m, "Piling", xIn - P.fingerLen / 2, z, -10, y + 1.5, 0.9, DARK, Enum.Material.Wood)
	end
	-- Vitrin: satılık tekneler (BoatService bunlara "Buy" düğmesi ekler); suya indirme iskelenin deniz tarafında
	local showroom = Instance.new("Folder")
	showroom.Name = "Showroom"
	showroom.Parent = m
	local spawn
	for i, z in P.slipZ do
		local id = BoatsCfg.ShopOrder[i]
		local info = id and BoatsCfg[id]
		Util.pole(m, "SlotPost", xIn - 1.5, z, y, y + 5, 0.6, DARK, Enum.Material.Wood)
		local sb = Util.part(m, "SlotSign", Vector3.new(0.4, 3.4, 6.5), CFrame.new(xIn - 1.5, y + 6.6, z), Color3.fromRGB(40, 90, 120), Enum.Material.WoodPlanks)
		local text = info and (string.upper(info.displayName) .. "  $" .. info.price .. "\nSpeed " .. info.speed .. "  ·  Slots " .. info.slots) or "COMING SOON"
		Util.sign(sb, Enum.NormalId.Right, text, CREAM)
		Util.sign(sb, Enum.NormalId.Left, text, CREAM)
		if id then
			local cx = xIn - P.fingerLen / 2 - 1
			-- burnu iskeleye (denize) bakar
			local cf = CFrame.lookAt(Vector3.new(cx, 0.65, z), Vector3.new(cx + 1, 0.65, z))
			local boat = BoatModels.Build(id, cf, true)
			if boat then
				local lx = P.x + W2 + 30
				boat:SetAttribute("Launch", CFrame.lookAt(Vector3.new(lx, 0.65, z), Vector3.new(lx + 1, 0.65, z)))
				boat.Parent = showroom
				if i == 1 then
					spawn = Util.zone(m, "BoatSpawn", Vector3.new(10, 1, 10), CFrame.new(lx, 1, z))
				end
			end
		end
	end
	-- yürüme yolunun karadaki ucunda tekne dükkanı tabelası ve fiyat listesi
	local sx, sz = P.startX + 2, P.walkZ
	for _, dz in { -4.6, 4.6 } do
		Util.pole(m, "ArchPost", sx, sz + dz, y, y + 11, 0.9, DARK, Enum.Material.Wood)
	end
	local arch = Util.part(m, "BoatShop", Vector3.new(1, 3, 11), CFrame.new(sx, y + 10, sz), Color3.fromRGB(40, 90, 120), Enum.Material.WoodPlanks)
	Util.sign(arch, Enum.NormalId.Left, "BOAT SHOP", CREAM)
	Util.sign(arch, Enum.NormalId.Right, "BOAT SHOP", CREAM)
	local lines = {}
	for _, id in BoatsCfg.ShopOrder do
		table.insert(lines, BoatsCfg[id].displayName .. " - $" .. BoatsCfg[id].price)
	end
	local menu = Util.part(m, "Menu", Vector3.new(0.3, 4.6, 6), CFrame.new(sx - 6, y + 3.2, sz - 7.5), Color3.fromRGB(240, 230, 205), Enum.Material.WoodPlanks)
	Util.sign(menu, Enum.NormalId.Left, table.concat(lines, "\n"), Color3.fromRGB(60, 40, 25))
	Util.pole(m, "MenuPost", sx - 6, sz - 7.5, cfg.GrassY - 2, y + 0.9, 0.5, DARK, Enum.Material.Wood)
	-- fenerler
	for z = P.zTop + 14, P.zBottom, 30 do
		Decor.lamp(m, Vector3.new(P.x + W2 - 0.8, y, z))
	end
	Decor.lamp(m, Vector3.new((P.startX + P.x) / 2, y, P.walkZ + 3.4))
	m.PrimaryPart = spawn
	return m
end

-- Ana adada küçük kulübeler, ağ askıları, sandıklar, palmiyeler
function Structures.Props(cfg)
	local f = Util.fresh("Model", "MainIslandProps")
	local g = cfg.GrassY
	local rng = Random.new(cfg.Seed + 5)
	-- kulübeler
	for _, h in { { -150, -60 } } do -- (-135, 70) artık Rod Shop (MapBuilder/RodShop)
		local x, z = h[1], h[2]
		Land.paintDisc(x, z, 11, Enum.Material.Ground)
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
		if z > 8 and z < 28 and x > 0 then okFar = false end -- iskele yolu
		local gy = Util.groundY(x, z)
		if okFar and gy and gy > 4 and gy < 8 then
			Decor.palm(f, Vector3.new(x, g, z), rng)
			placed += 1
		end
	end
	return f
end

return Structures
