--!nonstrict
-- Tekne modellerini koddan üretir: Kayak, Rowboat, Sloop.
-- BoatController ile uyumlu: "Kayak" tag'i, PrimaryPart = Hull, içinde VehicleSeat. Tekne -Z'ye (LookVector) bakar.
--   BoatModels.Build(id, cframe, display)  -> display = true ise sabit vitrin modeli (sürülemez, tag yok)
local CollectionService = game:GetService("CollectionService")

local BoatsCfg = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Boats"))

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

-- Rowboat: AI ile üretilmiş ahşap kayık (ServerStorage.BoatTemplates.Rowboat) görüntü olarak,
-- fizik için görünmez gövde + zemin. Şablon yoksa eski basit kayık çizilir.
local ROWBOAT_MESH_Y = 0.55 -- mesh merkezinin gövde merkezine göre yüksekliği
BUILDERS.Rowboat = function(m)
	local storage = game:GetService("ServerStorage")
	local folder = storage:FindFirstChild("BoatTemplates")
	local template = folder and folder:FindFirstChild("Rowboat")
	local hull = newPart(m, "Hull", Vector3.new(6, 2.4, 15), WOOD, Enum.Material.WoodPlanks, "ball")
	local parts = {}
	if template then
		hull.Transparency = 1
		local floor = newPart(m, "Floor", Vector3.new(4.2, 0.3, 10), Color3.fromRGB(170, 122, 80), Enum.Material.WoodPlanks)
		floor.Transparency = 1
		table.insert(parts, { floor, CFrame.new(0, -1.05, 0) }) -- mesh'in iç tabanı
		local visual = template:Clone()
		visual.Name = "Visual"
		for _, d in visual:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
				d.CastShadow = true
			end
		end
		visual.Parent = m
		local pivot = visual:GetPivot()
		for _, d in visual:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, { d, CFrame.new(0, ROWBOAT_MESH_Y, 0) * pivot:ToObjectSpace(d.CFrame) })
			end
		end
		local st = seat(m, Vector3.new(2.4, 0.5, 2), DARK)
		st.Transparency = 1
		table.insert(parts, { st, CFrame.new(0, 1.1, 0) }) -- orta sıra (üstü 1.33)
		-- kürek yuvaları (RowingAnimation iki kürek takar)
		for _, sx in { -1, 1 } do
			local lock = newPart(m, sx < 0 and "OarlockL" or "OarlockR", Vector3.new(0.2, 0.2, 0.2), DARK)
			lock.Transparency = 1
			lock.CanCollide = false
			table.insert(parts, { lock, CFrame.new(sx * 2.75, 1.85, -0.9) }) -- küpeşte üstü ~1.6
		end
		return hull, parts
	end
	parts = {
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

-- Warship: AI ile üretilmiş mesh (ServerStorage.BoatTemplates.Warship).
-- Görünmez kutular fizik ve yürünen zemin: orta güverte (Hull), kıç ve pruva güverteleri.
-- Mesh sadece görüntü (çarpışmasız); mesh'in kendi çarpışması güverteyle uyuşmadığı için.
-- Şablon yoksa nil döner ve oyunun geri kalanı etkilenmez.
-- Ölçüler (su seviyesine göre, renkli plaka yöntemiyle):
--   pruva güvertesi (z -12..-3.4) ~6.8, orta çukur güverte (z -3.4..8.4) ~2.25, kıç güvertesi (z 9..16) ~8.8
local WARSHIP_HULL = Vector3.new(8, 3.2, 12) -- sadece fizik kökü (görünmez, çarpışmasız)
local WARSHIP_MESH_Y = 10.85 -- mesh merkezinin gövde merkezine göre yüksekliği
local W = -0.65 -- gövde merkezinden su seviyesine
-- Toplar: { z, güverte yüksekliği (sudan) } her iki yanda
-- Her yanda bir top, orta (çukur) güvertede, gövdedeki top deliği hizasında
local CANNONS = { { 1, 2.25 } }
local SIDE_X = 7.0 -- top namlusunun gövdeden çıktığı yer (bu yükseklikte gövde yarı genişliği)
local BARREL_LEN = 5
local OUTSIDE = 0.25 -- namlunun dışarıda kalan kısmı (çeyrek)

BUILDERS.Warship = function(m)
	local storage = game:GetService("ServerStorage")
	local folder = storage:FindFirstChild("BoatTemplates")
	local template = folder and folder:FindFirstChild("Warship")
	if not template then
		warn("[BoatModels] ServerStorage.BoatTemplates.Warship bulunamadı")
		return nil
	end
	local hull = newPart(m, "Hull", WARSHIP_HULL, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	hull.Transparency = 1
	hull.CanCollide = false
	local parts = {}
	-- görünmez zeminler: karakter bunların üstünde yürür
	local function block(name, size, cf)
		local f = newPart(m, name, size, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		f.Transparency = 1
		table.insert(parts, { f, cf })
		return f
	end
	local function floor(name, size, top, z)
		block(name, size, CFrame.new(0, W + top - size.Y / 2, z))
	end
	floor("DeckWell", Vector3.new(12, 3, 11.8), 2.25, 2.5)
	floor("DeckBow", Vector3.new(8, 3, 8.6), 6.8, -7.7)
	floor("DeckStern", Vector3.new(9, 3, 7), 8.8, 12.5)
	-- çukurun yan duvarları (denize yürüyüp düşülmesin)
	for _, side in { -1, 1 } do
		block("WellWall", Vector3.new(0.6, 7, 11.8), CFrame.new(side * 6.3, W + 2.25 + 3.5, 2.5))
	end
	-- rampalar: çukurdan pruva ve kıç güvertesine (WedgePart eğimi +Z yönüne yükselir)
	local function ramp(name, x, z0, z1, y0, y1)
		local len, rise = math.abs(z1 - z0), y1 - y0
		local wdg = Instance.new("WedgePart")
		wdg.Name = name
		wdg.Size = Vector3.new(2.4, rise, len)
		wdg.Transparency = 1
		wdg.Parent = m
		local cf = CFrame.new(x, W + y0 + rise / 2, (z0 + z1) / 2)
		if z1 < z0 then
			cf = cf * CFrame.Angles(0, math.pi, 0)
		end
		table.insert(parts, { wdg, cf })
	end
	ramp("RampBow", 2.5, 0.6, -3.4, 2.25, 6.8)
	ramp("RampStern", -2.5, 4.5, 9, 2.25, 8.8)
	local mesh = template:Clone()
	mesh.Name = "Visual"
	mesh:PivotTo(CFrame.new())
	for _, d in mesh:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			table.insert(parts, { d, CFrame.new(0, WARSHIP_MESH_Y, 0) * d.CFrame })
		end
	end
	mesh.Parent = m

	-- Kıçta dümen (dönen tekerlek) ve kaptan koltuğu
	local deckStern = W + 8.8
	table.insert(parts, { newPart(m, "WheelPost", Vector3.new(0.6, 3, 0.6), DARK, Enum.Material.Wood), CFrame.new(0, deckStern + 1.5, 10.6) })
	local wheel = newPart(m, "Wheel", Vector3.new(0.35, 3.6, 3.6), Color3.fromRGB(120, 78, 44), Enum.Material.Wood, "cyl")
	-- tekerlek ekseni gemi boyunca (Z); hinge ile kendi ekseninde döner
	table.insert(parts, { wheel, CFrame.new(0, deckStern + 3.4, 10.25) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new() })
	for k = 0, 3 do
		local spoke = newPart(m, "Spoke", Vector3.new(0.2, 4.6, 0.25), DARK, Enum.Material.Wood)
		table.insert(parts, { spoke, CFrame.new(0, deckStern + 3.4, 10.25) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(k * math.pi / 4, 0, 0), nil, "Wheel" })
	end
	table.insert(parts, { seat(m, Vector3.new(2.4, 0.5, 2), DARK), CFrame.new(0, deckStern + 0.25, 12.6) })

	-- Toplar: kızak (güvertede sabit) + namlu (hinge ile sağa sola döner)
	local cannons = Instance.new("Folder")
	cannons.Name = "Cannons"
	cannons.Parent = m
	for i, c in CANNONS do
		for _, side in { 1, -1 } do
			local y = W + c[2]
			local name = (side == 1 and "R" or "L") .. i
			local carriage = newPart(cannons, "Carriage" .. name, Vector3.new(2.6, 0.9, 2.2), Color3.fromRGB(110, 72, 42), Enum.Material.WoodPlanks)
			table.insert(parts, { carriage, CFrame.new(side * (SIDE_X - 2.4), y + 0.45, c[1]) })
			for _, dz in { -0.85, 0.85 } do
				local wh = newPart(cannons, "Wheel", Vector3.new(0.3, 1, 1), DARK, Enum.Material.Wood, "cyl")
				table.insert(parts, { wh, CFrame.new(side * (SIDE_X - 2.4), y + 0.5, c[1] + dz) * CFrame.Angles(0, math.pi / 2, 0) })
			end
			-- namlu: yerel +X dışarı bakar; merkez = çıkış noktası - (yarım - dışarıdaki kısım)
			local cx = side * (SIDE_X - BARREL_LEN * (0.5 - OUTSIDE))
			local barrel = newPart(cannons, "Barrel" .. name, Vector3.new(BARREL_LEN, 1.1, 1.1), Color3.fromRGB(52, 54, 60), Enum.Material.Metal, "cyl")
			barrel:SetAttribute("Side", side == 1 and "Right" or "Left")
			local rel = CFrame.new(cx, y + 1.35, c[1]) * CFrame.Angles(0, side == 1 and 0 or math.pi, 0)
			-- dönme noktası gövde duvarında
			table.insert(parts, { barrel, rel, CFrame.new(BARREL_LEN * (0.5 - OUTSIDE), 0, 0) })
			local ring = newPart(cannons, "Muzzle", Vector3.new(0.4, 1.4, 1.4), Color3.fromRGB(40, 40, 44), Enum.Material.Metal, "cyl")
			table.insert(parts, { ring, rel * CFrame.new(BARREL_LEN / 2 - 0.2, 0, 0), nil, barrel.Name })
		end
	end
	return hull, parts
end

local SETTINGS = {
	Rowboat = { accel = 15, strokeRate = 2.4, oars = true },
	Kayak = { accel = 22 },
	Sloop = { accel = 26, noPaddle = true },
	Warship = { accel = 30, noPaddle = true, cannons = true },
}

function BoatModels.Build(id: string, cf: CFrame, display: boolean?)
	local builder = BUILDERS[id]
	if not builder then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = id
	local hull, parts = builder(m)
	if not hull then
		m:Destroy()
		return nil
	end
	local origin = CFrame.new(0, 0.65, 0)
	hull.CFrame = origin
	if not display then
		hull.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.1, 1, 1)
	end
	for _, pc in parts do
		local p, rel, hinge, attach = pc[1], pc[2], pc[3], pc[4]
		p.CFrame = origin * rel
		if display then
			p.Anchored = true
		else
			p.Anchored = false
			p.Massless = true
			if hinge then
				-- dönebilen parça (top namlusu, dümen tekerleği): Weld.C0 değişerek döner
				local w = Instance.new("Weld")
				w.Name = "Hinge"
				w.Part0 = hull
				w.Part1 = p
				w.C0 = rel * hinge
				w.C1 = hinge
				w:SetAttribute("BaseC0", w.C0)
				w.Parent = p
			else
				local w = Instance.new("WeldConstraint")
				w.Part0 = (attach and m:FindFirstChild(attach, true)) or hull
				w.Part1 = p
				w.Parent = p
			end
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
		local cfgBoat = (BoatsCfg :: any)[id]
		if cfgBoat and cfgBoat.speed then
			m:SetAttribute("TopSpeed", cfgBoat.speed)
		end
		if cfgBoat and cfgBoat.turnIdle then
			m:SetAttribute("TurnIdle", cfgBoat.turnIdle)
		end
		if s.oars and m:FindFirstChild("OarlockL", true) then
			m:SetAttribute("Oars", true)
		end
		if s.strokeRate then
			m:SetAttribute("StrokeRate", s.strokeRate)
		end
		if s.noPaddle then
			m:SetAttribute("NoPaddle", true)
		end
		if s.cannons then
			m:SetAttribute("HasCannons", true)
		end
	end
	m:PivotTo(cf)
	if not display then
		CollectionService:AddTag(m, "Kayak")
	end
	return m
end

return BoatModels
