--!nonstrict
-- Atış eğitiminin hedef gemisi: küçük korsan gemisi, yanlarında ve yelkende nişan tahtası.
-- Parçalar çapa açıkken hareket ettirilir (PivotTo); hepsi CanCollide = false (oyuncunun gemisine çarpmasın), ama gülleler çarpar.
-- Ön yön: yerel -Z. "FireAnchor1..3": hasar alınca yanan / dumanlanan noktalar (başta kapalı).
local Util = require(script.Parent.Parent.MapBuilder.Util)

local PracticeShip = {}

local HULL = Color3.fromRGB(122, 84, 52)
local HULL_DARK = Color3.fromRGB(92, 62, 40)
local DECK = Color3.fromRGB(150, 108, 66)
local METAL = Color3.fromRGB(40, 40, 46)
local CLOTH = Color3.fromRGB(240, 226, 190)

local function bullseye(face: Enum.NormalId, parent: BasePart)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.LightInfluence = 0
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(320, 240)
	g.Parent = parent
	local cols = { Color3.fromRGB(205, 40, 40), Color3.fromRGB(250, 250, 250), Color3.fromRGB(205, 40, 40), Color3.fromRGB(250, 250, 250), Color3.fromRGB(205, 40, 40) }
	for k, sc in { 0.92, 0.72, 0.52, 0.32, 0.13 } do
		local c = Instance.new("Frame")
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Position = UDim2.fromScale(0.5, 0.5)
		c.Size = UDim2.fromScale(sc, sc)
		c.BackgroundColor3 = cols[k]
		c.BorderSizePixel = 0
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = 1
		ar.DominantAxis = Enum.DominantAxis.Height
		ar.Parent = c
		Instance.new("UICorner", c).CornerRadius = UDim.new(0.5, 0)
		c.Parent = g
	end
end

function PracticeShip.Build(cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "PracticeShip"
	local function blockPart(name, size, off, color, mat)
		local p = Util.part(m, name, size, cf * off, color, mat)
		p.CanCollide = false
		return p
	end
	local function ellipse(name, size, off, color)
		local p = Util.ball(m, name, size, cf * off, color, Enum.Material.WoodPlanks)
		p.CanCollide = false
		return p
	end
	local function cyl(name, len, dia, off, color, mat)
		local p = Util.cyl(m, name, len, dia, cf * off, color, mat)
		p.CanCollide = false
		return p
	end

	-- gövde: üç elips (pruva, orta, kıç) + güverte + bordalar
	ellipse("HullBow", Vector3.new(10, 7, 18), CFrame.new(0, 1.2, -12), HULL)
	local mid = ellipse("HullMid", Vector3.new(13, 8, 22), CFrame.new(0, 1.5, 0), HULL)
	ellipse("HullStern", Vector3.new(11, 7.4, 16), CFrame.new(0, 1.6, 11.5), HULL)
	blockPart("Deck", Vector3.new(10.4, 0.5, 26), CFrame.new(0, 5.2, -1), DECK, Enum.Material.WoodPlanks)
	for _, sx in { -5.3, 5.3 } do
		blockPart("Bulwark", Vector3.new(0.8, 2.2, 28), CFrame.new(sx, 6, -1), HULL_DARK, Enum.Material.WoodPlanks)
	end
	blockPart("SternCastle", Vector3.new(9.6, 3.4, 11), CFrame.new(0, 7.1, 12), HULL_DARK, Enum.Material.WoodPlanks)
	blockPart("SternRail", Vector3.new(10, 1, 0.6), CFrame.new(0, 9.2, 17.4), DECK, Enum.Material.Wood)
	cyl("Bowsprit", 12, 0.8, CFrame.new(0, 7, -20) * CFrame.Angles(0, math.pi / 2, 0.2), HULL_DARK, Enum.Material.Wood)

	-- direk, ana yelken (yanlara bakar, nişan tahtası olarak boyalı), flama
	cyl("Mast", 20, 1.1, CFrame.new(0, 14, -2) * CFrame.Angles(0, 0, math.pi / 2), HULL_DARK, Enum.Material.Wood)
	cyl("Boom", 17, 0.7, CFrame.new(0, 19.4, -2) * CFrame.Angles(0, math.pi / 2, 0), HULL_DARK, Enum.Material.Wood)
	local sail = blockPart("Sail", Vector3.new(0.4, 12, 16), CFrame.new(0, 13.2, -2), CLOTH, Enum.Material.Fabric)
	bullseye(Enum.NormalId.Right, sail)
	bullseye(Enum.NormalId.Left, sail)
	blockPart("Flag", Vector3.new(0.2, 3, 5), CFrame.new(0, 22.4, -4.5), Color3.fromRGB(24, 24, 28), Enum.Material.Fabric)
	local skull = Util.ball(m, "Skull", Vector3.new(1.5, 1.5, 1.5), cf * CFrame.new(0, 22.6, -4.5), Color3.fromRGB(245, 245, 240), Enum.Material.SmoothPlastic)
	skull.CanCollide = false

	-- yan gövdede nişan tahtaları
	for _, sx in { -1, 1 } do
		for k, spec in { { 6.4, Color3.fromRGB(205, 40, 40) }, { 4.6, Color3.fromRGB(250, 250, 250) }, { 3, Color3.fromRGB(205, 40, 40) }, { 1.4, Color3.fromRGB(250, 250, 250) } } do
			cyl("HullTarget", 0.3, spec[1], CFrame.new(sx * (6.05 + k * 0.05), 2.9, -3), spec[2], Enum.Material.SmoothPlastic)
		end
	end

	-- güvertede süs: toplar, fıçılar, fener
	for _, sx in { -1, 1 } do
		for _, z in { -6, 5 } do
			cyl("DeckCannon", 5, 1.4, CFrame.new(sx * 4.2, 6.1, z), METAL, Enum.Material.Metal)
		end
	end
	for _, z in { 9, 11, 13.5 } do
		cyl("Barrel", 2.6, 2.2, CFrame.new((z % 2 - 0.5) * 3, 6.5, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(110, 76, 48), Enum.Material.Wood)
	end
	local lamp = Util.ball(m, "Lantern", Vector3.new(1.4, 1.8, 1.4), cf * CFrame.new(0, 10.4, 17.2), Color3.fromRGB(255, 190, 90), Enum.Material.Neon)
	lamp.CanCollide = false
	Util.light(lamp, 1.4, 26, Color3.fromRGB(255, 190, 110))

	-- hasar noktaları: yangın + duman (başta kapalı)
	for i, off in { CFrame.new(0, 5.8, -8), CFrame.new(0, 5.8, 3), CFrame.new(0, 9.4, 12) } do
		local a = Util.zone(m, "FireAnchor" .. i, Vector3.new(1, 1, 1), cf * off)
		local fire = Instance.new("Fire")
		fire.Enabled = false
		fire.Size = 8
		fire.Heat = 6
		fire.Parent = a
		local smoke = Instance.new("Smoke")
		smoke.Enabled = false
		smoke.Size = 8
		smoke.Opacity = 0.7
		smoke.RiseVelocity = 8
		smoke.Color = Color3.fromRGB(70, 70, 74)
		smoke.Parent = a
	end

	m.PrimaryPart = mid
	m:SetAttribute("PracticeTarget", true)
	return m
end

return PracticeShip
