--!nonstrict
-- Tekne modellerini koddan üretir: Kayak, Rowboat, Sloop.
-- BoatController ile uyumlu: "Kayak" tag'i, PrimaryPart = Hull, içinde VehicleSeat. Tekne -Z'ye (LookVector) bakar.
--   BoatModels.Build(id, cframe, display)  -> display = true ise sabit vitrin modeli (sürülemez, tag yok)
local CollectionService = game:GetService("CollectionService")

local BoatModels = {}

local WOOD = Color3.fromRGB(150, 102, 62)
local DARK = Color3.fromRGB(92, 62, 40)
local METAL = Color3.fromRGB(60, 62, 70)

local function newPart(m, name, size, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape == "ball" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.Wood
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

local function wedge(m, name, size, color, mat)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.Fabric
	p.Parent = m
	return p
end

local function seat(m, size, color)
	local s = Instance.new("VehicleSeat")
	s.Name = "Seat"
	s.Size = size
	s.Color = color
	s.Material = Enum.Material.Wood
	s.MaxSpeed = 0
	s.Torque = 0
	s.TurnSpeed = 0
	s.HeadsUpDisplay = false
	s.TopSurface = Enum.SurfaceType.Smooth
	s.BottomSurface = Enum.SurfaceType.Smooth
	s.Parent = m
	for _, side in { { "ElbowR", 1.7 }, { "ElbowL", -1.7 } } do
		local a = Instance.new("Attachment")
		a.Name = side[1]
		a.Position = Vector3.new(side[2], 1.4, -0.4)
		a.Parent = s
	end
	return s
end

-- Her tekne: { parça, yerel CFrame } listesi döndürür; Hull ilk eleman
local BUILDERS = {}

BUILDERS.Kayak = function(m)
	local hull = newPart(m, "Hull", Vector3.new(3.4, 1.5, 12), Color3.fromRGB(235, 190, 60), Enum.Material.Plastic, "ball")
	return hull, {
		{ newPart(m, "RimL", Vector3.new(0.4, 0.5, 4), DARK), CFrame.new(-1.05, 0.7, 0.6) },
		{ newPart(m, "RimR", Vector3.new(0.4, 0.5, 4), DARK), CFrame.new(1.05, 0.7, 0.6) },
		{ newPart(m, "RimF", Vector3.new(2.5, 0.5, 0.4), DARK), CFrame.new(0, 0.7, -1.4) },
		{ newPart(m, "RimB", Vector3.new(2.5, 0.5, 0.4), DARK), CFrame.new(0, 0.7, 2.6) },
		{ newPart(m, "Stripe", Vector3.new(0.35, 0.2, 9.5), METAL, Enum.Material.Plastic), CFrame.new(0, 0.74, 0) },
		{ seat(m, Vector3.new(2, 0.5, 2), DARK), CFrame.new(0, 0.55, 0.9) },
	}
end

BUILDERS.Rowboat = function(m)
	local hull = newPart(m, "Hull", Vector3.new(6, 2.4, 15), WOOD, Enum.Material.WoodPlanks, "ball")
	local parts = {
		{ newPart(m, "Floor", Vector3.new(4.2, 0.3, 10), Color3.fromRGB(170, 122, 80), Enum.Material.WoodPlanks), CFrame.new(0, 0.75, 0) },
		{ newPart(m, "BenchF", Vector3.new(4.6, 0.4, 1.2), DARK), CFrame.new(0, 1.2, -3.5) },
		{ newPart(m, "BenchB", Vector3.new(4.6, 0.4, 1.2), DARK), CFrame.new(0, 1.2, 4) },
		{ newPart(m, "Bow", Vector3.new(0.7, 0.7, 0.7), METAL, Enum.Material.Metal, "ball"), CFrame.new(0, 0.9, -7.3) },
		{ seat(m, Vector3.new(2.4, 0.5, 2), DARK), CFrame.new(0, 1.05, 0.8) },
	}
	-- küpeşte (kenar kalasları)
	for _, sx in { -1, 1 } do
		table.insert(parts, { newPart(m, "Gunwale", Vector3.new(0.4, 0.4, 10.5), DARK), CFrame.new(sx * 2.55, 1.1, 0) })
	end
	return hull, parts
end

BUILDERS.Sloop = function(m)
	local hull = newPart(m, "Hull", Vector3.new(9, 3.2, 26), Color3.fromRGB(235, 235, 228), Enum.Material.Wood, "ball")
	local parts = {
		{ newPart(m, "Stripe", Vector3.new(9.1, 0.5, 20), Color3.fromRGB(40, 90, 150), Enum.Material.Plastic, "ball"), CFrame.new(0, 0.2, 0) },
		{ newPart(m, "Deck", Vector3.new(6.6, 0.4, 19), Color3.fromRGB(170, 122, 80), Enum.Material.WoodPlanks), CFrame.new(0, 1.15, 0) },
		{ newPart(m, "Cabin", Vector3.new(4.6, 2.6, 5.5), Color3.fromRGB(230, 225, 210), Enum.Material.WoodPlanks), CFrame.new(0, 2.6, 2.5) },
		{ newPart(m, "CabinRoof", Vector3.new(5.2, 0.4, 6.1), DARK), CFrame.new(0, 4.05, 2.5) },
		{ newPart(m, "Window", Vector3.new(4.7, 0.9, 1.2), Color3.fromRGB(150, 210, 235), Enum.Material.Glass), CFrame.new(0, 3, 0.2) },
		{ newPart(m, "Mast", Vector3.new(22, 0.8, 0.8), DARK, Enum.Material.Wood, "cyl"), CFrame.new(0, 12.3, -3) * CFrame.Angles(0, 0, math.pi / 2) },
		{ newPart(m, "Boom", Vector3.new(0.5, 0.5, 9), DARK), CFrame.new(0, 4.6, 1.5) },
		{ wedge(m, "Sail", Vector3.new(0.25, 18, 9), Color3.fromRGB(250, 248, 240)), CFrame.new(0, 14, 1.5) * CFrame.Angles(0, math.pi, 0) },
		{ newPart(m, "Wheel", Vector3.new(0.3, 2.2, 2.2), DARK, Enum.Material.Wood, "cyl"), CFrame.new(0, 2.4, 7.4) * CFrame.Angles(0, math.pi / 2, 0) },
		{ seat(m, Vector3.new(2.4, 0.5, 2), DARK), CFrame.new(0, 1.6, 9) },
	}
	for _, sx in { -1, 1 } do
		table.insert(parts, { newPart(m, "Rail", Vector3.new(0.3, 1, 18), DARK), CFrame.new(sx * 3.4, 1.85, 0) })
	end
	return hull, parts
end

local SETTINGS = {
	Rowboat = { accel = 15, strokeRate = 2.4 },
	Kayak = { accel = 22 },
	Sloop = { accel = 26, noPaddle = true },
}

function BoatModels.Build(id: string, cf: CFrame, display: boolean?)
	local builder = BUILDERS[id]
	if not builder then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = id
	local hull, parts = builder(m)
	local origin = CFrame.new(0, 0.65, 0)
	hull.CFrame = origin
	if not display then
		hull.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.1, 1, 1)
	end
	for _, pc in parts do
		local p, rel = pc[1], pc[2]
		p.CFrame = origin * rel
		if display then
			p.Anchored = true
		else
			p.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = hull
			w.Part1 = p
			w.Parent = p
		end
		if p:IsA("VehicleSeat") and display then
			p.Disabled = true
		end
	end
	hull.Anchored = display == true
	m.PrimaryPart = hull
	m:SetAttribute("BoatId", id)
	local s = SETTINGS[id]
	if not display then
		m:SetAttribute("Accel", s.accel)
		if s.strokeRate then
			m:SetAttribute("StrokeRate", s.strokeRate)
		end
		if s.noPaddle then
			m:SetAttribute("NoPaddle", true)
		end
	end
	m:PivotTo(cf)
	if not display then
		CollectionService:AddTag(m, "Kayak")
	end
	return m
end

return BoatModels
