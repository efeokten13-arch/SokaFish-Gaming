--!nonstrict
-- 12 özel ada: balık ağı, havuz bölgesi, iskele, kulübe, palmiyeler. Hepsi Workspace.PrivateIslands içinde.
local Workspace = game:GetService("Workspace")
local Util = require(script.Parent.Util)
local Layout = require(script.Parent.Layout)
local Decor = require(script.Parent.Decor)
local Land = require(script.Parent.Land)

local Islands = {}

local WOOD = Color3.fromRGB(139, 94, 60)
local DARK = Color3.fromRGB(92, 62, 40)
local ROPE = Color3.fromRGB(205, 190, 150)
local CREAM = Color3.fromRGB(255, 244, 214)
local STONE = Color3.fromRGB(150, 150, 156)

local function v3(p, y)
	return Vector3.new(p.X, y, p.Z)
end

-- Boynuzlar arasında direkler, halat, şamandıra ve ip ağ
local function net(model, cfg, f)
	local a = Layout.arcPoint(cfg, f, -1)
	local b = Layout.arcPoint(cfg, f, 1)
	local g = cfg.GrassY
	local dir = (b - a)
	local len = dir.Magnitude
	local n = math.floor(len / 8)
	local folder = Instance.new("Folder")
	folder.Name = "FishNet"
	-- direkler (ağ hattı, boynuz uçlarından biraz içeride değil tam suda)
	local posts = {}
	for i = 0, n do
		local p = a + dir * (i / n)
		posts[i] = p
		Util.pole(folder, "NetPost", p.X, p.Z, -8, 5, 0.9, DARK, Enum.Material.Wood)
		local float = Util.ball(folder, "Buoy", Vector3.new(1.6, 1.6, 1.6), CFrame.new(p.X, 0.3, p.Z), Color3.fromRGB(235, 90, 60), Enum.Material.SmoothPlastic)
		float.CanCollide = false
	end
	-- üst halat ve su altı ipleri
	Util.rod(folder, "NetRopeTop", v3(a, 4.2), v3(b, 4.2), 0.35, ROPE, Enum.Material.Fabric).CanCollide = false
	Util.rod(folder, "NetRopeMid", v3(a, -2), v3(b, -2), 0.25, ROPE, Enum.Material.Fabric).CanCollide = false
	Util.rod(folder, "NetRopeLow", v3(a, -7), v3(b, -7), 0.25, ROPE, Enum.Material.Fabric).CanCollide = false
	local strands = math.floor(len / 3)
	for i = 0, strands do
		local p = a + dir * (i / strands)
		local s = Util.part(folder, "Strand", Vector3.new(0.18, 11.4, 0.18), CFrame.new(p.X, -1.5, p.Z), ROPE, Enum.Material.Fabric)
		s.CanCollide = false
	end
	folder.Parent = model
	return a, b
end

local function dock(model, cfg, f)
	local tipPos = Layout.arcPoint(cfg, f, 1)
	local y = cfg.DeckY
	-- boynuzun ucundan merkeze doğru uzanan küçük iskele
	local start = tipPos + f.u * 6
	local stop = tipPos + f.u * (18 + cfg.Island.dockLength)
	local deckFolder = Instance.new("Folder")
	deckFolder.Name = "DockDeck"
	Util.beam(deckFolder, "Deck", v3(start, y - 0.5), v3(stop, y - 0.5), 6, 1, WOOD, Enum.Material.WoodPlanks)
	local len = (stop - start).Magnitude
	for i = 0, math.floor(len / 8) do
		local p = start:Lerp(stop, i / math.max(1, math.floor(len / 8)))
		local side = Vector3.new(-f.u.Z, 0, f.u.X) * 2.4
		for _, s in { -1, 1 } do
			Util.pole(deckFolder, "Piling", p.X + side.X * s, p.Z + side.Z * s, -9, y + 1.4, 0.9, DARK, Enum.Material.Wood)
		end
	end
	-- "Dock" parçası: iskelenin ucundaki bağlama platformu (kayık buraya yanaşır)
	local endPos = stop + f.u * 3
	local d = Util.part(model, "Dock", Vector3.new(8, 1, 8), CFrame.lookAt(v3(endPos, y - 0.5), v3(endPos + f.u, y - 0.5)), WOOD, Enum.Material.WoodPlanks)
	local sidev = Vector3.new(-f.u.Z, 0, f.u.X)
	for _, s in { -1, 1 } do
		local bp = endPos + sidev * s * 3.2
		Util.pole(deckFolder, "Piling", bp.X, bp.Z, -9, y + 1.4, 1, DARK, Enum.Material.Wood)
		Util.cyl(deckFolder, "Bollard", 1.4, 1, CFrame.new(bp.X, y + 0.7, bp.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
	end
	Decor.lamp(deckFolder, Vector3.new(endPos.X + sidev.X * 3, y, endPos.Z + sidev.Z * 3))
	deckFolder.Parent = model
	return d, endPos
end

local function hut(model, cfg, f, i)
	local g = cfg.GrassY
	local p = Layout.arcPoint(cfg, f, 0) + f.back * 6
	local yaw = math.atan2(-f.u.X, -f.u.Z) -- ön yüz (+Z) merkeze (u) baksın... 
	local cf = CFrame.lookAt(v3(p, g), v3(p, g) + f.u * 10)
	local h = Instance.new("Model")
	h.Name = "Hut"
	local function box(name, size, off, color, mat)
		return Util.part(h, name, size, cf * CFrame.new(off), color, mat)
	end
	box("Base", Vector3.new(15, 1, 13), Vector3.new(0, 0.5, 0), STONE, Enum.Material.Cobblestone)
	box("Walls", Vector3.new(13, 7, 11), Vector3.new(0, 4.5, 0), Color3.fromRGB(190, 150, 104), Enum.Material.WoodPlanks)
	box("Roof", Vector3.new(16, 1, 14), Vector3.new(0, 8.5, 0), Color3.fromRGB(176, 84, 60), Enum.Material.Slate)
	-- ön yüz: lookAt ile -Z ileri; ön = -Z
	box("Door", Vector3.new(3, 5, 0.4), Vector3.new(0, 3.5, -5.6), DARK, Enum.Material.Wood)
	box("Window", Vector3.new(3, 3, 0.4), Vector3.new(4, 5.5, -5.6), Color3.fromRGB(150, 210, 235), Enum.Material.Glass)
	local sg = box("Sign", Vector3.new(7, 2.2, 0.3), Vector3.new(-3.6, 5.8, -5.75), Color3.fromRGB(40, 90, 120), Enum.Material.WoodPlanks)
	Util.sign(sg, Enum.NormalId.Front, "ISLAND " .. i, CREAM)
	Decor.crate(h, v3(p, g) + (cf.RightVector * -7 + cf.LookVector * 7), i)
	Decor.barrel(h, v3(p, g) + (cf.RightVector * 7 + cf.LookVector * 7))
	h.Parent = model
	return h
end

-- Oyuncunun ışınlanacağı yer ve adanın üstündeki sahip yazısı
local function spawnPoint(model, cfg, f)
	local old = model:FindFirstChild("Spawn")
	if old then
		old:Destroy()
	end
	local p = Layout.arcPoint(cfg, f, 0.35)
	local part = Util.zone(model, "Spawn", Vector3.new(6, 1, 6), CFrame.new(p.X, cfg.GrassY + 0.5, p.Z))
	local gui = Util.billboard(part, "FREE ISLAND", 9, 220)
	gui.Name = "OwnerLabel"
	gui.MaxDistance = 220
	return part
end

-- Toprak patikalar: iskeleden hilal boyunca kulübeye, kulübenin önü ve öteki boynuza
local function paths(cfg, f)
	local DIRT = Enum.Material.Ground
	local hutP = Layout.arcPoint(cfg, f, 0) + f.back * 6
	Land.paintDisc(hutP.X, hutP.Z, 10, DIRT)
	local t = 1.0
	while t >= -0.85 do
		local p = Layout.arcPoint(cfg, f, t)
		Land.paintDisc(p.X, p.Z, 3, DIRT)
		t -= 0.05
	end
	-- kulübeden havuz kıyısına kısa yol
	local shore = Layout.arcPoint(cfg, f, 0) + f.u * 10
	Land.path(hutP, shore, 2.5, DIRT)
end

function Islands.AddPaths(cfg)
	for i = 1, cfg.Ring.count do
		paths(cfg, Layout.frame(cfg, i))
		task.wait()
	end
end

-- Kulübenin önünde koleksiyon kitabı kürsüsü (BookService "Open" düğmesi ekler)
local function book(model, cfg, f)
	local old = model:FindFirstChild("Lectern")
	if old then
		old:Destroy()
	end
	local g = cfg.GrassY
	local hutP = Layout.arcPoint(cfg, f, 0) + f.back * 6
	local pos = hutP + f.u * 10 + Vector3.new(-f.u.Z, 0, f.u.X) * 3.5
	local cf = CFrame.lookAt(v3(pos, g), v3(pos, g) - f.u)
	local m = Instance.new("Model")
	m.Name = "Lectern"
	Util.part(m, "Stand", Vector3.new(1, 3.4, 1), cf * CFrame.new(0, 1.7, 0), DARK, Enum.Material.Wood)
	Util.part(m, "Foot", Vector3.new(2.4, 0.4, 2), cf * CFrame.new(0, 0.2, 0), DARK, Enum.Material.Wood)
	Util.part(m, "Top", Vector3.new(2.8, 0.3, 2.2), cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(math.rad(-25), 0, 0), WOOD, Enum.Material.WoodPlanks)
	local bk = Util.part(m, "Book", Vector3.new(2.2, 0.35, 1.6), cf * CFrame.new(0, 3.75, 0) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(150, 45, 40), Enum.Material.Fabric)
	Util.part(m, "Pages", Vector3.new(2, 0.1, 1.4), cf * CFrame.new(0, 3.95, -0.05) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(245, 238, 215), Enum.Material.Plastic)
	local tag = Util.billboard(bk, "COLLECTION BOOK", 2.5, 170)
	tag.MaxDistance = 60
	m.PrimaryPart = bk
	m.Parent = model
	return m
end

function Islands.AddBooks(cfg)
	local folder = Workspace:FindFirstChild("PrivateIslands")
	for i = 1, cfg.Ring.count do
		local model = folder and folder:FindFirstChild("Island" .. i)
		if model then
			book(model, cfg, Layout.frame(cfg, i))
		end
	end
end

-- Var olan adalara Spawn ekler (adaları yeniden kurmadan)
function Islands.AddSpawns(cfg)
	local folder = Workspace:FindFirstChild("PrivateIslands")
	for i = 1, cfg.Ring.count do
		local model = folder and folder:FindFirstChild("Island" .. i)
		if model then
			spawnPoint(model, cfg, Layout.frame(cfg, i))
		end
	end
end

-- Havuz TV'si: siyah, kocaman ekran (≈2 karakter boyu, 3 karakter genişliği), havuza bakar.
-- Ekran içeriği (balıklar, butonlar) client'ta: client/UI/PoolScreen (sadece ada sahibi görür/kullanır).
Islands.TV = { t = 0.17, back = 3, width = 16, height = 11, lift = 2.4 }
local function tv(model, cfg, f)
	local old = model:FindFirstChild("PoolTV")
	if old then
		old:Destroy()
	end
	local T = Islands.TV
	local g = cfg.GrassY
	local p = Layout.arcPoint(cfg, f, T.t) + f.back * T.back
	local gy = Util.groundY(p.X, p.Z) or g
	local face = (f.bay - p) * Vector3.new(1, 0, 1)
	local base = CFrame.lookAt(Vector3.new(p.X, gy, p.Z), Vector3.new(p.X, gy, p.Z) + face.Unit)
	-- yerdeki süsleri temizle
	local natural = { Palm = true, Bush = true, Fern = true, Flowers = true, Rock = true }
	for _, root in { model, Workspace:FindFirstChild("Nature") } do
		for _, d in root and root:GetDescendants() or {} do
			if d.Parent and natural[d.Name] and (d:IsA("Model") or d:IsA("BasePart")) then
				local q = if d:IsA("Model") then d:GetPivot().Position else d.Position
				if (Vector2.new(q.X, q.Z) - Vector2.new(p.X, p.Z)).Magnitude < 10 then
					d:Destroy()
				end
			end
		end
	end
	local m = Instance.new("Model")
	m.Name = "PoolTV"
	local W, H, L = T.width, T.height, T.lift
	local cy = L + H / 2
	local BLACK = Color3.fromRGB(18, 18, 22)
	-- ayaklar ve taban
	for _, sx in { -1, 1 } do
		Util.part(m, "Leg", Vector3.new(1, L + 1, 1), base * CFrame.new(sx * W * 0.32, (L + 1) / 2, 0.6), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
		Util.part(m, "Foot", Vector3.new(2.6, 0.4, 3.4), base * CFrame.new(sx * W * 0.32, 0.2, 0.6), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	end
	-- kasa (çerçeve) + arka kutu
	Util.part(m, "Bezel", Vector3.new(W + 1.2, H + 1.2, 1), base * CFrame.new(0, cy, 0.3), BLACK, Enum.Material.SmoothPlastic)
	Util.part(m, "Back", Vector3.new(W - 2, H - 2, 1.4), base * CFrame.new(0, cy, 1.3), BLACK, Enum.Material.SmoothPlastic)
	-- ekran camı (ön yüz = -Z, havuza bakar)
	local screen = Util.part(m, "Screen", Vector3.new(W, H, 0.2), base * CFrame.new(0, cy, -0.25), Color3.fromRGB(8, 10, 14), Enum.Material.SmoothPlastic)
	screen.Reflectance = 0.08
	-- alt şerit + güç ışığı
	Util.part(m, "Chin", Vector3.new(W + 1.2, 0.7, 1.05), base * CFrame.new(0, L - 0.05, 0.3), Color3.fromRGB(30, 30, 36), Enum.Material.SmoothPlastic)
	local led = Util.part(m, "PowerLed", Vector3.new(0.3, 0.2, 0.1), base * CFrame.new(W / 2 - 0.6, L - 0.05, -0.25), Color3.fromRGB(90, 255, 130), Enum.Material.Neon)
	led.CanCollide = false
	-- sahibi olmayanlar için sabit yazı
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Idle"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = screen
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextSize = 48
	t.TextColor3 = Color3.fromRGB(120, 200, 255)
	t.Text = "🐟 FISH POOL TV"
	t.Parent = gui
	m.PrimaryPart = screen
	m.Parent = model
	return m
end

-- Var olan adalara havuz TV'si ekle
function Islands.AddScreens(cfg)
	local folder = Workspace:FindFirstChild("PrivateIslands")
	for i = 1, cfg.Ring.count do
		local model = folder and folder:FindFirstChild("Island" .. i)
		if model then
			tv(model, cfg, Layout.frame(cfg, i))
		end
	end
end

local function trees(model, cfg, f, rng)
	local g = cfg.GrassY
	for k = 1, 5 do
		local t = rng:NextNumber(-0.7, 0.7)
		local p = Layout.arcPoint(cfg, f, t)
		local r = Layout.radiusAt(cfg, t)
		local ang = rng:NextNumber(0, math.pi * 2)
		local q = p + Vector3.new(math.cos(ang), 0, math.sin(ang)) * rng:NextNumber(0, r * 0.6)
		-- kulübenin olduğu sırt orta noktasından uzak dur
		local hutP = Layout.arcPoint(cfg, f, 0) + f.back * 6
		if (q - hutP).Magnitude > 14 then
			local gy = Util.groundY(q.X, q.Z)
			if gy and gy > 4 and gy < 8 then
				Decor.palm(model, Vector3.new(q.X, g, q.Z), rng)
			end
		end
	end
end

function Islands.Build(cfg)
	local folder = Util.fresh("Folder", "PrivateIslands")
	for i = 1, cfg.Ring.count do
		local f = Layout.frame(cfg, i)
		local rng = Random.new(cfg.Seed * 100 + i)
		local model = Instance.new("Model")
		model.Name = "Island" .. i
		model:SetAttribute("Index", i)
		-- havuz bölgesi: ağın içinde kalan su
		local poolCenter = f.bay + f.u * 2
		local pool = Util.zone(model, "Pool", Vector3.new(50, 10, 50), CFrame.lookAt(Vector3.new(poolCenter.X, -5, poolCenter.Z), Vector3.new(poolCenter.X + f.u.X, -5, poolCenter.Z + f.u.Z)))
		Util.billboard(pool, "FISH POOL", 12, 160)
		pool.CanQuery = true
		net(model, cfg, f)
		local d = dock(model, cfg, f)
		paths(cfg, f)
		hut(model, cfg, f, i)
		book(model, cfg, f)
		spawnPoint(model, cfg, f)
		trees(model, cfg, f, rng)
		tv(model, cfg, f)
		model.PrimaryPart = pool
		model.Parent = folder
		if i % 3 == 0 then
			task.wait()
		end
	end
	return folder
end

-- Balık noktaları: kanal (Near), halka dışı (Mid) ve açık deniz (Far)
function Islands.Spots(cfg)
	-- Atoll alt klasörüne dokunma (Atoll.lua kurar)
	local folder = Workspace:FindFirstChild("FishingSpots")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "FishingSpots"
		folder.Parent = Workspace
	end
	for _, c in folder:GetChildren() do
		if c.Name ~= "Atoll" then
			c:Destroy()
		end
	end
	local colors = { Near = Color3.fromRGB(120, 235, 160), Mid = Color3.fromRGB(255, 214, 120), Far = Color3.fromRGB(255, 130, 130) }
	for kind, s in cfg.Spots do
		for i = 1, s.count do
			local a = math.rad(s.offset + (i - 1) * 360 / s.count)
			local x, z = math.cos(a) * s.radius, math.sin(a) * s.radius
			local p = Util.cyl(folder, kind .. i, 0.4, 24, CFrame.new(x, 0.3, z) * CFrame.Angles(0, 0, math.pi / 2), colors[kind], Enum.Material.Neon)
			p.Transparency = 0.7
			p.CanCollide = false
			p.CanQuery = false
			p:SetAttribute("SpotType", kind)
			p:SetAttribute("Ocean", "Warm")
			Util.billboard(p, kind == "Near" and "Near" or (kind == "Mid" and "Mid" or "Far"), 6, 70)
		end
	end
	return folder
end

return Islands
