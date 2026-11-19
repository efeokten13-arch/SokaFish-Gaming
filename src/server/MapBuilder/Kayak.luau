--!nonstrict
-- Başlangıç kayığı. BoatController.server.luau şunu bekler: "Kayak" tag'i, PrimaryPart = gövde, içinde VehicleSeat.
-- Gövdenin ileri yönü -Z (LookVector). Gövde merkezi su çizgisinden 0.65 stud yukarıda durur.
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Util = require(script.Parent.Util)

local Kayak = {}

local HULL = Color3.fromRGB(235, 190, 60)
local TRIM = Color3.fromRGB(92, 62, 40)
local DARK = Color3.fromRGB(46, 48, 54)

function Kayak.Build(cfg)
	local boats = Workspace:FindFirstChild("Boats") or Util.fresh("Folder", "Boats")
	local old = boats:FindFirstChild("Kayak")
	if old then old:Destroy() end

	local m = Instance.new("Model")
	m.Name = "Kayak"
	local origin = CFrame.new(0, 0.65, 0)

	local hull = Util.ball(m, "Hull", Vector3.new(3.4, 1.5, 12), origin, HULL, Enum.Material.SmoothPlastic)
	hull.Anchored = false
	hull.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.1, 1, 1)

	local function weld(p, cf)
		p.Anchored = false
		p.CFrame = origin * cf
		local w = Instance.new("WeldConstraint")
		w.Part0 = hull
		w.Part1 = p
		w.Parent = p
		p.Massless = true
		return p
	end

	-- kokpit kenarı (halka: dört kalas) ve sırt
	weld(Util.part(m, "RimL", Vector3.new(0.4, 0.5, 4), CFrame.new(), TRIM, Enum.Material.Wood), CFrame.new(-1.05, 0.7, 0.6))
	weld(Util.part(m, "RimR", Vector3.new(0.4, 0.5, 4), CFrame.new(), TRIM, Enum.Material.Wood), CFrame.new(1.05, 0.7, 0.6))
	weld(Util.part(m, "RimF", Vector3.new(2.5, 0.5, 0.4), CFrame.new(), TRIM, Enum.Material.Wood), CFrame.new(0, 0.7, -1.4))
	weld(Util.part(m, "RimB", Vector3.new(2.5, 0.5, 0.4), CFrame.new(), TRIM, Enum.Material.Wood), CFrame.new(0, 0.7, 2.6))
	weld(Util.part(m, "Stripe", Vector3.new(0.35, 0.2, 9.5), CFrame.new(), DARK, Enum.Material.SmoothPlastic), CFrame.new(0, 0.74, 0))
	weld(Util.ball(m, "Bow", Vector3.new(0.6, 0.6, 0.6), CFrame.new(), DARK, Enum.Material.SmoothPlastic), CFrame.new(0, 0.2, -5.9))

	-- oturak (VehicleSeat sadece girdi için; görünür koltuk gibi)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 0.5, 2)
	seat.Color = TRIM
	seat.Material = Enum.Material.Wood
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = m
	weld(seat, CFrame.new(0, 0.55, 0.9))
	for _, side in { { "ElbowR", 1.7 }, { "ElbowL", -1.7 } } do
		local a = Instance.new("Attachment")
		a.Name = side[1]
		a.Position = Vector3.new(side[2], 1.4, -0.4)
		a.Parent = seat
	end

	m.PrimaryPart = hull
	m:SetAttribute("BoatId", "Kayak")
	CollectionService:AddTag(m, "Kayak")

	-- iskele slot 1'in önünde, açık denize bakar (+X)
	local spawn = Workspace.Pier:FindFirstChild("BoatSpawn")
	local p = spawn and spawn.Position or Vector3.new(352, 0, -45)
	m:PivotTo(CFrame.lookAt(Vector3.new(p.X, 0.65, p.Z), Vector3.new(p.X + 1, 0.65, p.Z)))
	m.Parent = boats
	return m
end

return Kayak
