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
local Props = require(script.Parent.Props)
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
	-- 3D raf: yan çerçeveler, üst başlık, alt sehpa (pano düz kalmasın)
	for _, sx in { -2.3, 2.3 } do
		Util.part(m, "RackSide", Vector3.new(0.45, 11.2, 1.7), cf * CFrame.new(sx, 8.9, -0.65), Color3.fromRGB(110, 76, 46), Enum.Material.Wood)
	end
	Util.part(m, "RackTop", Vector3.new(5.1, 0.5, 2), cf * CFrame.new(0, 14.6, -0.8), Color3.fromRGB(110, 76, 46), Enum.Material.Wood)
	Util.part(m, "RackShelf", Vector3.new(4.6, 0.35, 1.6), cf * CFrame.new(0, 3.62, -0.75), Color3.fromRGB(110, 76, 46), Enum.Material.Wood)
	Props.deco(Util.part(m, "RackGlass", Vector3.new(4.15, 10.4, 0.1), cf * CFrame.new(0, 9.1, -1.45), Color3.fromRGB(200, 230, 245), Enum.Material.Glass), false).Transparency = 0.85

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
	local plaque = Util.part(m, "Plaque", Vector3.new(4.2, 2.9, 0.3), cf * CFrame.new(0, 2.0, -0.35), Color3.fromRGB(60, 42, 28), Enum.Material.Wood)
	Util.part(m, "PlaqueFrame", Vector3.new(4.8, 3.4, 0.3), cf * CFrame.new(0, 2.0, -0.1), Color3.fromRGB(140, 100, 56), Enum.Material.Wood)
	for _, sx in { -1.9, 1.9 } do
		Props.deco(Util.part(m, "Nail", Vector3.new(0.2, 0.2, 0.1), cf * CFrame.new(sx, 3.25, -0.52), Color3.fromRGB(200, 160, 70), Enum.Material.Metal), false)
	end
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
	p.Name = "ShopPrompt" -- basınca client/UI/ShopUI açılır (Kind/Id attribute'ları), alım server'da ShopAction ile
	p.ObjectText = def.displayName
	p.ActionText = "Inspect"
	p.HoldDuration = 0
	p.MaxActivationDistance = 7
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p:SetAttribute("Kind", "Rods")
	p:SetAttribute("Id", rodId)
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
		for _, d in head:GetChildren() do
			if d:IsA("BillboardGui") then
				d:Destroy()
			end
		end
		Util.billboard(head, "Rod Merchant", 2.4, 200).MaxDistance = 40
	end
	if root and not root:FindFirstChild("ShopPrompt") then
		local p = Instance.new("ProximityPrompt")
		p.Name = "ShopPrompt"
		p.ObjectText = "Rod Merchant"
		p.ActionText = "Browse Rods"
		p.HoldDuration = 0
		p.MaxActivationDistance = 12
		p.RequiresLineOfSight = false
		p.KeyboardKeyCode = Enum.KeyCode.E
		p:SetAttribute("Kind", "Rods")
		p.Parent = root
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
	-- desenli, püsküllü halı
	local RUG = Color3.fromRGB(150, 50, 45)
	Props.deco(Util.part(f, "Rug", Vector3.new(12, 0.1, 9), at(0, F + 0.25, 1), RUG, Enum.Material.Fabric), false)
	Props.deco(Util.part(f, "RugBorder", Vector3.new(11, 0.12, 8), at(0, F + 0.27, 1), Color3.fromRGB(214, 170, 80), Enum.Material.Fabric), false)
	Props.deco(Util.part(f, "RugInner", Vector3.new(10, 0.14, 7), at(0, F + 0.29, 1), Color3.fromRGB(40, 70, 110), Enum.Material.Fabric), false)
	for k = -2, 2 do
		Props.deco(Util.part(f, "RugDiamond", Vector3.new(1.4, 0.16, 1.4), at(k * 1.9, F + 0.31, 1) * CFrame.Angles(0, math.rad(45), 0), k % 2 == 0 and Color3.fromRGB(214, 170, 80) or RUG, Enum.Material.Fabric), false)
	end
	for _, sz in { -1, 1 } do
		for k = -11, 11 do
			Props.deco(Util.part(f, "Fringe", Vector3.new(0.15, 0.08, 0.7), at(k * 0.52, F + 0.24, 1 + sz * 4.85), Color3.fromRGB(235, 220, 180), Enum.Material.Fabric), false)
		end
	end

	-- giriş sundurması: yükseltilmiş ahşap zemin, direkler, çizgili tente
	local PZ = -D / 2 - 4.2
	Util.part(f, "Porch", Vector3.new(DOOR_W + 10, 1, 7.4), at(0, F - 0.5, PZ + 0.5), Color3.fromRGB(150, 108, 70), Enum.Material.WoodPlanks)
	Util.part(f, "PorchStep", Vector3.new(DOOR_W + 2, 1, 2), at(0, F - 1.5, PZ - 4), Color3.fromRGB(130, 94, 62), Enum.Material.WoodPlanks)
	for _, sx in { -1, 1 } do
		Util.part(f, "PorchPost", Vector3.new(0.9, 9, 0.9), at(sx * (DOOR_W / 2 + 4.3), F + 4.5, PZ - 2.6), DARK, Enum.Material.Wood)
		Util.part(f, "PorchRail", Vector3.new(0.4, 0.4, 5.6), at(sx * (DOOR_W / 2 + 4.3), F + 2.6, PZ + 0.3), DARK, Enum.Material.Wood)
		Props.lantern(f, at(sx * (DOOR_W / 2 + 4.3), F + 7.2, PZ - 3.5))
		Props.deco(Util.part(f, "LanternArm", Vector3.new(0.3, 0.3, 1.4), at(sx * (DOOR_W / 2 + 4.3), F + 8.2, PZ - 3.1), DARK, Enum.Material.Wood))
	end
	Util.part(f, "PorchBeam", Vector3.new(DOOR_W + 10, 0.6, 0.6), at(0, F + 9, PZ - 2.6), DARK, Enum.Material.Wood)
	local stripes = 9
	for k = 0, stripes - 1 do
		local col = k % 2 == 0 and Color3.fromRGB(196, 60, 50) or Color3.fromRGB(245, 240, 228)
		local x = -(DOOR_W + 10) / 2 + (k + 0.5) * (DOOR_W + 10) / stripes
		Props.deco(Util.part(f, "Awning", Vector3.new((DOOR_W + 10) / stripes, 0.25, 7), at(x, F + 9.9, PZ + 0.6) * CFrame.Angles(math.rad(-15), 0, 0), col, Enum.Material.Fabric))
		Props.deco(Util.wedge(f, "AwningFlap", Vector3.new((DOOR_W + 10) / stripes, 0.7, 0.25), at(x, F + 8.6, PZ - 2.85), col, Enum.Material.Fabric))
	end
	Props.barrel(f, at(-DOOR_W / 2 - 2.6, F, PZ + 2.2), Random.new(5))
	Props.crateStack(f, at(DOOR_W / 2 + 1.8, F, PZ + 2.2), Random.new(6), 2)

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
		Util.part(f, "WindowFrame", Vector3.new(5.5, 0.5, 1.6), at(x, F + 8.95, -D / 2 + 0.5), DARK, Enum.Material.Wood)
		for _, wx in { -2.6, 2.6 } do
			Util.part(f, "WindowFrame", Vector3.new(0.45, 4.2, 1.6), at(x + wx, F + 7, -D / 2 + 0.5), DARK, Enum.Material.Wood)
		end
		Util.part(f, "WindowCross", Vector3.new(0.25, 3.5, 1.3), at(x, F + 7, -D / 2 + 0.5), DARK, Enum.Material.Wood)
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
	Util.part(f, "Ridge", Vector3.new(RW + 0.6, 0.9, 1.4), at(0, F + H + 0.6 + RH + 0.3, 0), DARK, Enum.Material.Wood)
	for _, sz in { -1, 1 } do
		Util.part(f, "Eave", Vector3.new(RW, 0.6, 0.6), at(0, F + H + 0.4, sz * (RD / 2 - 0.3)), DARK, Enum.Material.Wood)
		for x = -W / 2, W / 2 + 0.1, W / 7 do
			Props.deco(Util.part(f, "Rafter", Vector3.new(0.6, 0.6, 2.6), at(x, F + H + 0.1, sz * (D / 2 + 0.9)), DARK, Enum.Material.Wood))
		end
	end
	local chim = Util.part(f, "Chimney", Vector3.new(2.6, 6, 2.6), at(W / 2 - 6, F + H + 4.5, D / 4), Color3.fromRGB(130, 120, 112), Enum.Material.Cobblestone)
	Util.part(f, "ChimneyCap", Vector3.new(3.2, 0.5, 3.2), chim.CFrame * CFrame.new(0, 3.2, 0), Color3.fromRGB(90, 86, 82), Enum.Material.Slate)


	-- çatının tepesinde KOCAMAN olta: YAN duruyor (mahya boyunca soldan sağa, ~50° eğik), ucundan dev balık sarkar
	local ridgeY = F + H + 0.6 + RH + 0.9
	local tilt = math.rad(52)
	local function onRoof(len)
		return at(-15 + len * math.sin(tilt), ridgeY + len * math.cos(tilt), 1.5 - len * 0.08).Position
	end
	local basePos = onRoof(0)
	local midPos = onRoof(17)
	local tipPos = onRoof(31)
	Util.rod(f, "GiantRodLower", basePos, midPos, 1.7, Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
	Util.rod(f, "GiantRodUpper", midPos, tipPos, 0.9, Color3.fromRGB(150, 100, 56), Enum.Material.Wood)
	Util.rod(f, "GiantRodHandle", basePos, onRoof(6), 2.1, Color3.fromRGB(200, 160, 80), Enum.Material.Wood)
	for _, len in { 8.5, 14, 20, 26 } do
		Util.rod(f, "GiantRodRing", onRoof(len), onRoof(len + 0.7), len < 17 and 2.0 or 1.2, Color3.fromRGB(255, 205, 80), Enum.Material.Metal)
	end
	-- makara: kapıya bakan yüzünde
	local axis = (base - base.Position) * CFrame.Angles(0, math.pi / 2, 0)
	local reelPos = onRoof(9) + base.LookVector * 1.9
	Util.cyl(f, "GiantReel", 1.6, 4.6, CFrame.new(reelPos) * axis, Color3.fromRGB(190, 190, 200), Enum.Material.Metal)
	Util.cyl(f, "GiantReelHub", 2.2, 1.6, CFrame.new(reelPos) * axis, Color3.fromRGB(255, 205, 80), Enum.Material.Metal)
	-- misina: uçtan aşağı, ucunda dev balık
	local lineEnd = tipPos + Vector3.new(0, -13, 0)
	Util.rod(f, "GiantLine", tipPos, lineEnd, 0.18, Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic)
	local fishCF = CFrame.new(lineEnd + Vector3.new(0, -4.2, 0)) * (base - base.Position) * CFrame.Angles(0, 0, math.rad(-80)) -- ağzından asılı: baş yukarı
	Util.ball(f, "GiantFish", Vector3.new(10, 4.6, 3), fishCF, Color3.fromRGB(240, 130, 50), Enum.Material.SmoothPlastic)
	Util.ball(f, "GiantFishBelly", Vector3.new(7.4, 2.2, 2.9), fishCF * CFrame.new(0, -0.9, 0.12), Color3.fromRGB(255, 232, 190), Enum.Material.SmoothPlastic)
	Util.ball(f, "GiantFishTail", Vector3.new(3, 4.6, 0.8), fishCF * CFrame.new(5.6, 0, 0), Color3.fromRGB(230, 100, 40), Enum.Material.SmoothPlastic)
	Util.ball(f, "GiantFishEye", Vector3.new(0.9, 0.9, 0.5), fishCF * CFrame.new(-3.3, 0.7, -1.4), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
	for _, d in f:GetChildren() do
		if d:IsA("BasePart") and d.Name:find("^Giant") then
			d.CanCollide = false
		end
	end

	-- tek tabela: girişin üstünde, çerçeveli, yanlarında asılı fenerler
	local roofSign = Util.part(f, "RoofSign", Vector3.new(20, 4.5, 0.6), at(0, F + H + 4.2, -D / 2 - 0.4) * CFrame.Angles(math.rad(-12), 0, 0), DARK, Enum.Material.Wood)
	Util.sign(roofSign, Enum.NormalId.Front, "🎣 ROD SHOP", Color3.fromRGB(255, 215, 90))
	Util.part(f, "RoofSignFrame", Vector3.new(21.2, 5.6, 0.4), roofSign.CFrame * CFrame.new(0, 0, 0.4), Color3.fromRGB(140, 100, 56), Enum.Material.Wood)
	for s2 = -1, 1, 2 do
		Util.part(f, "RoofSignPost", Vector3.new(0.6, 4, 0.6), at(s2 * 8, F + H + 2.4, -D / 2 + 0.6), DARK, Enum.Material.Wood)
		Props.deco(Util.part(f, "SignLanternArm", Vector3.new(0.3, 0.3, 1.6), at(s2 * 11.2, F + H + 5.6, -D / 2 - 0.6), DARK, Enum.Material.Wood))
		Props.lantern(f, at(s2 * 11.2, F + H + 4.4, -D / 2 - 1.3))
	end

	-- iç ışıklar: tavandan halatla sarkan fenerler
	for _, x in { -10, 0, 10 } do
		for _, z in { -5, 3 } do
			Props.deco(Util.part(f, "LanternRope", Vector3.new(0.15, 1.6, 0.15), at(x, F + H - 0.8, z), Color3.fromRGB(196, 172, 122), Enum.Material.Fabric), false)
			Props.lantern(f, at(x, F + H - 2.5, z), 1.1)
		end
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

	-- tezgâh + satıcı: odanın TAM ORTASINDA (x=0, z=0); tezgâh kapıya paralel, satıcı arkasında kapıya bakar
	local cz = 0
	Util.part(f, "Counter", Vector3.new(9, 3.6, 2.6), at(0, F + 1.8, cz), Color3.fromRGB(120, 80, 48), Enum.Material.WoodPlanks)
	Util.part(f, "CounterTop", Vector3.new(9.6, 0.4, 3.2), at(0, F + 3.8, cz), DARK, Enum.Material.Wood)
	-- yazar kasa
	Util.part(f, "Register", Vector3.new(1.6, 1.1, 1.8), at(-2.6, F + 4.55, cz), Color3.fromRGB(176, 136, 60), Enum.Material.Metal)
	Props.deco(Util.part(f, "RegisterTop", Vector3.new(0.9, 0.5, 1.6), at(-2.6, F + 5.3, cz - 0.2) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(150, 110, 50), Enum.Material.Metal))
	Props.deco(Util.part(f, "Keys", Vector3.new(1.2, 0.15, 0.9), at(-2.6, F + 5.15, cz - 0.5) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(240, 235, 220), Enum.Material.SmoothPlastic))
	-- olta kutuları
	Props.tackleBox(f, at(1.4, F + 4, cz), Color3.fromRGB(60, 120, 80))
	Props.tackleBox(f, at(3.4, F + 4, cz) * CFrame.Angles(0, 0.2, 0), Color3.fromRGB(170, 60, 50))
	-- tezgâhın ön yüzündeki görünmez düğme: arayüzü açar (satıcıya da aynı düğme konur)
	local counterPoint = Util.part(f, "CounterPoint", Vector3.new(8, 3, 1), at(0, F + 3, cz - 2.2))
	counterPoint.Transparency = 1
	counterPoint.CanCollide = false
	counterPoint.CanTouch = false
	local cp = Instance.new("ProximityPrompt")
	cp.Name = "ShopPrompt"
	cp.ObjectText = "Rod Merchant"
	cp.ActionText = "Browse Rods"
	cp.HoldDuration = 0
	cp.MaxActivationDistance = 12
	cp.RequiresLineOfSight = false
	cp.KeyboardKeyCode = Enum.KeyCode.E
	cp:SetAttribute("Kind", "Rods")
	cp.Parent = counterPoint
	-- köşelerde fıçılar ve olta kovaları
	local rr = Random.new(7)
	for _, c in { { -W / 2 + 2.5, -D / 2 + 3 }, { W / 2 - 2.6, -D / 2 + 2.6 } } do
		Props.barrel(f, at(c[1], F, c[2]), rr)
	end
	Props.bucket(f, at(-W / 2 + 2, F, D / 2 - 2.6), true)
	Props.bucket(f, at(W / 2 - 5, F, -D / 2 + 2.4))
	-- cam vitrin dolabı: yem ve iğneler
	local gx, gz = -8.8, 5
	Util.part(f, "CaseBase", Vector3.new(5, 2.6, 2.6), at(gx, F + 1.3, gz), Color3.fromRGB(110, 76, 46), Enum.Material.Wood)
	local glass = Util.part(f, "CaseGlass", Vector3.new(4.8, 1.6, 2.4), at(gx, F + 3.4, gz), Color3.fromRGB(200, 230, 245), Enum.Material.Glass)
	glass.Transparency = 0.7
	Props.deco(Util.part(f, "CaseTop", Vector3.new(5.1, 0.25, 2.7), at(gx, F + 4.3, gz), Color3.fromRGB(110, 76, 46), Enum.Material.Wood))
	for k = 0, 4 do
		local col = ({ Color3.fromRGB(240, 90, 80), Color3.fromRGB(250, 200, 60), Color3.fromRGB(80, 200, 220), Color3.fromRGB(150, 230, 90), Color3.fromRGB(230, 120, 220) })[k + 1]
		Props.deco(Util.ball(f, "Lure", Vector3.new(0.7, 0.35, 0.35), at(gx - 1.8 + k * 0.9, F + 2.85, gz + (k % 2) * 0.6 - 0.3), col, Enum.Material.SmoothPlastic), false)
	end
	merchant(f, at(0, F, cz + 3.4)) -- -Z (kapı) yönüne bakar

	return f
end

return RodShop
