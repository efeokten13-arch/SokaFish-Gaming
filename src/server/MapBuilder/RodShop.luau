--!nonstrict
-- Ana adadaki olta dükkânı (Rod Shop): büyük kulübe, kapısı plazaya bakar.
-- İçeride arka duvarda 7 olta vitrini (isim, nadirlik, fiyat, şans) + tezgâh arkasında kaslı satıcı.
-- Satın alma / kuşanma: server/Shop/RodShopService (vitrinlerdeki "BuyPrompt"lara bağlanır).
-- 3D oltalar: ReplicatedStorage.Assets.Rods, satıcı: ServerStorage.NPCTemplates.RodMerchant (place dosyasında)
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Util = require(script.Parent.Util)
local Land = require(script.Parent.Land)
local Decor = require(script.Parent.Decor)
local Economy = require(ReplicatedStorage.Shared.Config.Economy:Clone())
local RodModelBuilder = require(ReplicatedStorage.Shared.RodModelBuilder)

local RodShop = {}

local POS = Vector2.new(-135, 70)
local W, D, H = 34, 26, 15 -- genişlik (yerel X), derinlik (yerel Z), duvar yüksekliği
local DOOR_W, DOOR_H = 10, 10

local WALL = Color3.fromRGB(182, 132, 86)
local DARK = Color3.fromRGB(92, 62, 40)
local ROOF = Color3.fromRGB(176, 84, 60)
local STONE = Color3.fromRGB(150, 150, 156)
local FLOOR = Color3.fromRGB(150, 105, 66)
local CREAM = Color3.fromRGB(255, 244, 214)

local function label(parent, text, y, h, color, font)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.04, y)
	t.Size = UDim2.fromScale(0.92, h)
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.FredokaOne
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.4
	t.Parent = parent
	return t
end

local function money(n)
	local s = tostring(math.floor(n))
	while true do
		local r, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = r
		if k == 0 then
			break
		end
	end
	return "$" .. s
end

-- Vitrin: pano + olta + bilgi plakası + satın alma düğmesi
local function display(f, cf, rodId)
	local def = Economy.Rods[rodId]
	local rarityColor = Economy.RarityColors[def.rarity] or CREAM
	local m = Instance.new("Model")
	m.Name = rodId
	m.Parent = f

	Util.part(m, "Board", Vector3.new(4.2, 10.6, 0.3), cf * CFrame.new(0, 8.8, 0), DARK, Enum.Material.Wood)
	local strip = Util.part(m, "RarityStrip", Vector3.new(4.2, 0.35, 0.36), cf * CFrame.new(0, 14.0, 0), rarityColor, Enum.Material.Neon)
	strip.CanCollide = false
	Util.part(m, "Peg", Vector3.new(0.3, 0.3, 0.8), cf * CFrame.new(0, 4.6, -0.5), Color3.fromRGB(70, 50, 30), Enum.Material.Wood)

	-- olta (dik, ucu yukarı)
	local len = def.length * 1.35 -- vitrinde elde olduğundan büyük görünür
	local rod = RodModelBuilder.Build(rodId, len)
	for _, d in rod:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	rod.Name = "Rod"
	-- olta kendi ekseni etrafında döndürülür: en ince göründüğü açı seçilir (makara panoya gömülmesin)
	local function depth(c)
		local lo, hi = math.huge, -math.huge
		for _, d in rod:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				local h = d.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local wp = d.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
							local z = c:PointToObjectSpace(wp).Z
							lo, hi = math.min(lo, z), math.max(hi, z)
						end
					end
				end
			end
		end
		return lo, hi
	end
	local bestCF, bestD, bestHi = nil, math.huge, 0
	for k = 0, 11 do
		local test = cf * CFrame.new(0, 3.9 + len * 0.12, 0) * CFrame.Angles(0, k * math.pi / 6, 0) * CFrame.Angles(math.rad(90), 0, 0)
		rod:PivotTo(test)
		local lo, hi = depth(cf)
		if hi - lo < bestD then
			bestCF, bestD, bestHi = test, hi - lo, hi
		end
	end
	-- arka yüzü panonun önüne gelsin (pano ön yüzü z = -0.15)
	rod:PivotTo(CFrame.new(cf.LookVector * (bestHi + 0.3)) * bestCF)
	rod.Parent = m

	-- bilgi plakası
	local plaque = Util.part(m, "Plaque", Vector3.new(4.2, 2.9, 0.3), cf * CFrame.new(0, 2.0, -0.05), Color3.fromRGB(60, 42, 28), Enum.Material.Wood)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 50
	g.LightInfluence = 0.2
	g.Parent = plaque
	label(g, def.displayName, 0.04, 0.27, CREAM)
	label(g, def.rarity, 0.31, 0.22, rarityColor)
	label(g, if def.price > 0 then money(def.price) else "FREE", 0.53, 0.22, Color3.fromRGB(255, 215, 90))
	label(g, string.format("Luck x%.2f", def.luck), 0.76, 0.2, Color3.fromRGB(150, 230, 255))

	-- satın alma düğmesi (görünmez parça)
	local hit = Util.part(m, "BuyPoint", Vector3.new(3, 4, 1), cf * CFrame.new(0, 3.5, -1.5))
	hit.Transparency = 1
	hit.CanCollide = false
	hit.CanTouch = false
	local p = Instance.new("ProximityPrompt")
	p.Name = "BuyPrompt"
	p.ObjectText = def.displayName
	p.ActionText = if def.price > 0 then "Buy " .. money(def.price) else "Equip"
	p.HoldDuration = 0.8 -- yanlışlıkla almasınlar: basılı tutmak gerekir (sahip olunca client 0 yapar)
	p.MaxActivationDistance = 6
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p:SetAttribute("RodId", rodId)
	p.Parent = hit
	return m
end

local function merchant(f, cf)
	local templates = ServerStorage:FindFirstChild("NPCTemplates")
	local t = templates and templates:FindFirstChild("RodMerchant")
	if not t then
		warn("[RodShop] ServerStorage.NPCTemplates.RodMerchant yok; satıcı konmadı")
		return
	end
	local npc = t:Clone()
	npc.Name = "RodMerchant"
	local _, size = npc:GetBoundingBox()
	local root = npc:FindFirstChild("HumanoidRootPart")
	for _, d in npc:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == root
			d.CanCollide = false
		end
	end
	npc:PivotTo(cf * CFrame.new(0, size.Y / 2, 0))
	local hum = npc:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	npc.Parent = f
	local head = npc:FindFirstChild("Head") or root
	if head then
		Util.billboard(head, "Rod Merchant", 2.4, 200)
	end
	return npc
end

function RodShop.Build(cfg)
	local g = cfg.GrassY
	local plaza = Vector3.new(cfg.Plaza.x, 0, cfg.Plaza.z)
	local base = CFrame.lookAt(Vector3.new(POS.X, 0, POS.Y), plaza) -- -Z = kapı = plazaya doğru
	local F = g + 1 -- zemin üstü

	-- eski kulübe ve etrafındaki süsleri kaldır (yeni bina geniş)
	local props = Workspace:FindFirstChild("MainIslandProps")
	for _, folder in { props, Workspace:FindFirstChild("Vegetation"), Workspace:FindFirstChild("MainVegetation") } do
		if folder then
			for _, c in folder:GetChildren() do
				local p = if c:IsA("Model") then c:GetPivot().Position elseif c:IsA("BasePart") then c.Position else nil
				if p and (Vector2.new(p.X, p.Z) - POS).Magnitude < 25 then
					c:Destroy()
				end
			end
		end
	end

	Land.paintDisc(POS.X, POS.Y, 24, Enum.Material.Ground)

	-- plazadan kapıya giden yol + yolun/görüşün önündeki palmiye, fener, saksıları kaldır
	local doorPos = (base * CFrame.new(0, 0, -D / 2 - 5)).Position
	local toShop = (Vector3.new(doorPos.X, 0, doorPos.Z) - plaza).Unit
	local plazaEdge = plaza + toShop * (cfg.Plaza.radius - 4)
	local function nearLine(p: Vector3)
		local a, b = Vector2.new(plazaEdge.X, plazaEdge.Z), Vector2.new(doorPos.X, doorPos.Z)
		local q = Vector2.new(p.X, p.Z)
		local t = math.clamp((q - a):Dot(b - a) / (b - a).Magnitude ^ 2, 0, 1)
		return (q - (a + (b - a) * t)).Magnitude
	end
	for _, folder in { props, Workspace:FindFirstChild("Nature"), Workspace:FindFirstChild("Plaza") } do
		if folder then
			for _, c in folder:GetDescendants() do
				if c:IsA("Model") and c.Parent and (c.Name:lower():find("palm") or c.Name:lower():find("lamp") or c.Name:lower():find("planter") or c.Name:lower():find("bush")) then
					if nearLine(c:GetPivot().Position) < 9 then
						c:Destroy()
					end
				end
			end
		end
	end
	Land.wavyPath(plazaEdge, Vector3.new(doorPos.X, 0, doorPos.Z), 4.5, Enum.Material.Sand, 77, 3, 1)
	local f = Util.fresh("Model", "RodShop")
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end

	-- zemin
	Util.part(f, "Foundation", Vector3.new(W + 2, 3, D + 2), at(0, F - 1.5, 0), STONE, Enum.Material.Cobblestone)
	Util.part(f, "Floor", Vector3.new(W - 2, 0.2, D - 2), at(0, F + 0.1, 0), FLOOR, Enum.Material.WoodPlanks)
	Util.part(f, "Step", Vector3.new(DOOR_W + 2, 1, 3), at(0, F - 0.5, -D / 2 - 2.5), STONE, Enum.Material.Cobblestone)
	local rug = Util.part(f, "Rug", Vector3.new(12, 0.1, 9), at(0, F + 0.25, 1), Color3.fromRGB(150, 50, 45), Enum.Material.Fabric)
	rug.CanCollide = false

	-- duvarlar
	local wy = F + H / 2
	Util.part(f, "WallBack", Vector3.new(W, H, 1), at(0, wy, D / 2 - 0.5), WALL, Enum.Material.WoodPlanks)
	Util.part(f, "WallLeft", Vector3.new(1, H, D), at(-W / 2 + 0.5, wy, 0), WALL, Enum.Material.WoodPlanks)
	Util.part(f, "WallRight", Vector3.new(1, H, D), at(W / 2 - 0.5, wy, 0), WALL, Enum.Material.WoodPlanks)
	local sideW = (W - DOOR_W) / 2
	for s = -1, 1, 2 do
		local x = s * (DOOR_W / 2 + sideW / 2)
		Util.part(f, "WallFront", Vector3.new(sideW, H, 1), at(x, wy, -D / 2 + 0.5), WALL, Enum.Material.WoodPlanks)
		local win = Util.part(f, "Window", Vector3.new(4.5, 3.5, 1.2), at(x, F + 7, -D / 2 + 0.5), Color3.fromRGB(150, 210, 235), Enum.Material.Glass)
		win.Transparency = 0.4
		Util.part(f, "WindowFrame", Vector3.new(5.3, 0.4, 1.4), at(x, F + 5.1, -D / 2 + 0.5), DARK, Enum.Material.Wood)
		-- köşe dikmeleri
		Util.part(f, "Post", Vector3.new(1.4, H + 0.5, 1.4), at(s * W / 2, F + H / 2, -D / 2), DARK, Enum.Material.Wood)
		Util.part(f, "Post", Vector3.new(1.4, H + 0.5, 1.4), at(s * W / 2, F + H / 2, D / 2), DARK, Enum.Material.Wood)
		Util.part(f, "DoorPost", Vector3.new(0.8, DOOR_H, 1.4), at(s * (DOOR_W / 2 + 0.2), F + DOOR_H / 2, -D / 2 + 0.5), DARK, Enum.Material.Wood)
	end
	Util.part(f, "Lintel", Vector3.new(DOOR_W, H - DOOR_H, 1), at(0, F + DOOR_H + (H - DOOR_H) / 2, -D / 2 + 0.5), WALL, Enum.Material.WoodPlanks)

	-- çatı (iki eğimli yüz, mahya X boyunca)
	local RW, RD, RH = W + 4, D + 4, 6
	Util.part(f, "Ceiling", Vector3.new(W + 1, 0.6, D + 1), at(0, F + H + 0.3, 0), DARK, Enum.Material.Wood)
	Util.wedge(f, "RoofFront", Vector3.new(RW, RH, RD / 2), at(0, F + H + 0.6 + RH / 2, -RD / 4), ROOF, Enum.Material.Slate)
	Util.wedge(f, "RoofBack", Vector3.new(RW, RH, RD / 2), at(0, F + H + 0.6 + RH / 2, RD / 4) * CFrame.Angles(0, math.pi, 0), ROOF, Enum.Material.Slate)

	-- tabela
	local sign = Util.part(f, "Sign", Vector3.new(15, 3.4, 0.5), at(0, F + DOOR_H + 2.6, -D / 2 - 0.3), DARK, Enum.Material.Wood)
	Util.sign(sign, Enum.NormalId.Front, "ROD SHOP", Color3.fromRGB(255, 215, 90))

	-- çatıda büyük tabela + uzaktan görünen yazı
	local roofSign = Util.part(f, "RoofSign", Vector3.new(20, 4.5, 0.6), at(0, F + H + 4.2, -D / 2 - 0.4) * CFrame.Angles(math.rad(-12), 0, 0), DARK, Enum.Material.Wood)
	Util.sign(roofSign, Enum.NormalId.Front, "🎣 ROD SHOP", Color3.fromRGB(255, 215, 90))
	for s2 = -1, 1, 2 do
		Util.part(f, "RoofSignPost", Vector3.new(0.6, 4, 0.6), at(s2 * 8, F + H + 2.4, -D / 2 + 0.6), DARK, Enum.Material.Wood)
	end
	local bb = Util.billboard(roofSign, "🎣 ROD SHOP", 5, 260)
	bb.Size = UDim2.fromOffset(260, 48)
	bb.MaxDistance = 400
	local bbText = bb:FindFirstChildOfClass("TextLabel")
	if bbText then
		bbText.TextColor3 = Color3.fromRGB(255, 215, 90)
	end

	-- iç ışıklar
	for _, x in { -10, 0, 10 } do
		local lamp = Util.part(f, "Lamp", Vector3.new(1.2, 1.2, 1.2), at(x, F + H - 1.2, 2), Color3.fromRGB(255, 220, 150), Enum.Material.Neon, Enum.PartType.Ball)
		lamp.CanCollide = false
		local l = Instance.new("PointLight")
		l.Brightness = 1.4
		l.Range = 18
		l.Color = Color3.fromRGB(255, 220, 170)
		l.Parent = lamp
	end

	-- vitrinler: ilk 3 olta sol duvarda (kapıdan girince), kalan 4'ü arka duvarda; aralar eşit
	local displays = Instance.new("Folder")
	displays.Name = "Displays"
	displays.Parent = f
	for i, id in Economy.RodOrder do
		local cf
		if i <= 3 then
			-- sol duvar (yerel +X), içe bakar; kapıya yakından arkaya doğru
			cf = at(W / 2 - 1.25, F, -6 + (i - 1) * 6) * CFrame.Angles(0, math.pi / 2, 0)
		else
			-- arka duvar, soldan sağa
			cf = at(12 - (i - 4) * 8, F, D / 2 - 1.25)
		end
		display(displays, cf, id)
	end

	-- tezgâh + satıcı (sol önde, odanın ortasına bakar)
	local cx, cz = -W / 2 + 6, -3
	Util.part(f, "Counter", Vector3.new(2.6, 3.6, 10), at(cx, F + 1.8, cz), Color3.fromRGB(120, 80, 48), Enum.Material.WoodPlanks)
	Util.part(f, "CounterTop", Vector3.new(3.2, 0.4, 10.6), at(cx, F + 3.8, cz), DARK, Enum.Material.Wood)
	Util.part(f, "CashBox", Vector3.new(1.6, 1, 1.4), at(cx, F + 4.5, cz - 2.5), Color3.fromRGB(200, 160, 60), Enum.Material.Metal)
	Decor.barrel(f, base * Vector3.new(-W / 2 + 2.5, F, -D / 2 + 3))
	Decor.crate(f, base * Vector3.new(W / 2 - 3, F, -D / 2 + 3), 0.3)
	merchant(f, at(-W / 2 + 3, F, cz) * CFrame.Angles(0, -math.pi / 2, 0))

	-- kapı önü fenerleri
	Decor.lamp(f, base * Vector3.new(-DOOR_W / 2 - 3, F - 1, -D / 2 - 3))
	Decor.lamp(f, base * Vector3.new(DOOR_W / 2 + 3, F - 1, -D / 2 - 3))
	return f
end

return RodShop
