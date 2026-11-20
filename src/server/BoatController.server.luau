-- BoatController: floating, steering and driving for every model tagged "Kayak".
-- The player only gives input (W/S throttle, A/D steer) through the VehicleSeat.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local WATER_Y = 0
local FLOAT_HEIGHT = 0.65  -- hull centre above the waterline (settles lower when loaded)
local ACCEL = 18           -- default power; a model can override it with its own "Accel" attribute
local DRAG_FWD = 0.1
local DRAG_SIDE = 1.2      -- the long hull resists sideways drift
local STROKE_RATE = 2.9    -- rad/s, matches the rowing animation

local boats = {}

local function setupBoat(model)
	if boats[model] then return end
	local hull = model.PrimaryPart
	local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
	if not hull or not seat then return end

	local att = Instance.new("Attachment")
	att.Name = "BoatAttachment"
	att.Parent = hull

	local floatForce = Instance.new("VectorForce")
	floatForce.Name = "FloatForce"
	floatForce.Attachment0 = att
	floatForce.RelativeTo = Enum.ActuatorRelativeTo.World
	floatForce.ApplyAtCenterOfMass = true
	floatForce.Force = Vector3.zero
	floatForce.Parent = hull

	local driveForce = Instance.new("VectorForce")
	driveForce.Name = "DriveForce"
	driveForce.Attachment0 = att
	driveForce.RelativeTo = Enum.ActuatorRelativeTo.World
	driveForce.ApplyAtCenterOfMass = true
	driveForce.Force = Vector3.zero
	driveForce.Parent = hull

	local align = Instance.new("AlignOrientation")
	align.Name = "KeepUpright"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.RigidityEnabled = false
	align.MaxTorque = math.huge
	align.MaxAngularVelocity = math.huge
	align.Responsiveness = 20
	align.Parent = hull

	local hold = Instance.new("AlignPosition")
	hold.Name = "HoldWaterline"
	hold.Mode = Enum.PositionAlignmentMode.OneAttachment
	hold.Attachment0 = att
	hold.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	hold.MaxAxesForce = Vector3.new(0, math.huge, 0)
	hold.MaxVelocity = 25
	hold.Responsiveness = 25
	hold.RigidityEnabled = false
	hold.ApplyAtCenterOfMass = true
	hold.ReactionForceEnabled = false
	hold.Position = Vector3.new(0, WATER_Y + FLOAT_HEIGHT, 0)
	hold.Parent = hull

	local _, yaw = hull.CFrame:ToEulerAnglesYXZ()
	boats[model] = {hull = hull, seat = seat, float = floatForce, drive = driveForce, align = align, hold = hold, yaw = yaw, phase = 0, t = 0}
end

for _, m in ipairs(CollectionService:GetTagged("Kayak")) do setupBoat(m) end
CollectionService:GetInstanceAddedSignal("Kayak"):Connect(setupBoat)

RunService.Heartbeat:Connect(function(dt)
	for model, b in pairs(boats) do
		local hull = b.hull
		if not hull:IsDescendantOf(workspace) then
			boats[model] = nil
			continue
		end
		b.t += dt
		local mass = hull.AssemblyMass
		local vel = hull.AssemblyLinearVelocity
		local pos = hull.Position
		local g = workspace.Gravity

		-- buoyancy: cancel the boat's weight and let a constraint hold it on the waterline (with a gentle bob)
		b.float.Force = Vector3.new(0, mass * g, 0)
		b.hold.Position = Vector3.new(0, WATER_Y + FLOAT_HEIGHT + 0.05 * math.sin(b.t * 1.7), 0)

		-- input
		local occupied = b.seat.Occupant ~= nil
		local throttle = occupied and b.seat.ThrottleFloat or 0
		local steer = occupied and b.seat.SteerFloat or 0

		local look = hull.CFrame.LookVector
		look = Vector3.new(look.X, 0, look.Z)
		if look.Magnitude < 1e-3 then look = Vector3.new(0, 0, -1) end
		look = look.Unit
		local right = look:Cross(Vector3.yAxis)
		local vf, vr = vel:Dot(look), vel:Dot(right)
		local speedFactor = math.clamp(math.abs(vf) / 10, 0, 1)

		-- steering: right turn is clockwise (negative yaw).
		-- Dururken çok yavaş döner (yerinde fırıldak olmasın), hızlandıkça normal dönüş hızına çıkar.
		local turnIdle = model:GetAttribute("TurnIdle") or 0.18
		local turnMove = model:GetAttribute("TurnMove") or 0.95
		b.yaw -= steer * (turnIdle + turnMove * speedFactor) * dt
		local roll = -steer * speedFactor * 0.1
		b.align.CFrame = CFrame.Angles(0, b.yaw, 0) * CFrame.Angles(0, 0, roll)

		-- each paddle stroke gives a little surge, so the boat accelerates in pulses like a real kayak
		b.phase += dt * STROKE_RATE * math.abs(throttle)
		local pulse = 0.65 + 0.7 * math.abs(math.sin(b.phase))
		local power = model:GetAttribute("Accel") or ACCEL
		local acc = (throttle >= 0 and power or power * 0.5) * throttle * pulse
		-- en yüksek hız: Config/Boats -> speed (stud/sn). Sürtünme buna göre ayarlanır
		local top = model:GetAttribute("TopSpeed")
		local drag = if top and top > 0 then power * 1.1 / top else DRAG_FWD
		local f = look * (acc - drag * vf) + right * (-DRAG_SIDE * vr)
		b.drive.Force = f * mass
	end
end)
