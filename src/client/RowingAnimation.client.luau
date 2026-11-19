-- RowingAnimation: draws a paddle for every occupied kayak and moves the rower's hands with it.
-- Everything here is cosmetic and runs on each player's own screen.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local active = {}

local function mkPart(parent, name, size, color, material, kind)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.CastShadow = true
	p.Size = size; p.Color = color; p.Material = material
	if kind == "cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif kind == "ellipsoid" then
		local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = p
	end
	p.Parent = parent
	return p
end

local function makePaddle()
	local m = Instance.new("Model"); m.Name = "LocalPaddle"
	local shaft = mkPart(m, "Shaft", Vector3.new(7.6, 0.28, 0.28), Color3.fromRGB(58, 58, 64), Enum.Material.Metal, "cylinder")
	local bladeL = mkPart(m, "BladeL", Vector3.new(2.1, 0.95, 0.1), Color3.fromRGB(232, 200, 70), Enum.Material.SmoothPlastic, "ellipsoid")
	local bladeR = mkPart(m, "BladeR", Vector3.new(2.1, 0.95, 0.1), Color3.fromRGB(232, 200, 70), Enum.Material.SmoothPlastic, "ellipsoid")
	local gripL = Instance.new("Attachment"); gripL.Name = "GripL"; gripL.Position = Vector3.new(-1.2, 0, 0); gripL.Parent = shaft
	local gripR = Instance.new("Attachment"); gripR.Name = "GripR"; gripR.Position = Vector3.new(1.2, 0, 0); gripR.Parent = shaft
	m.PrimaryPart = shaft
	m.Parent = workspace
	return {model = m, shaft = shaft, bladeL = bladeL, bladeR = bladeR, gripL = gripL, gripR = gripR}
end

local function makeIK(humanoid, rootPart, effector, target, pole)
	local ok, ik = pcall(function()
		local c = Instance.new("IKControl")
		c.Type = Enum.IKControlType.Position
		c.ChainRoot = rootPart
		c.EndEffector = effector
		c.Target = target
		if pole then c.Pole = pole end
		c.Weight = 1
		c.Enabled = true
		c.Parent = humanoid
		return c
	end)
	return ok and ik or nil
end

local function beginRowing(model, seat, humanoid)
	local s = {seat = seat, humanoid = humanoid, phase = 0, k = 0, ik = {}}
	s.paddle = makePaddle()
	local char = humanoid.Parent
	local ruA, rh = char:FindFirstChild("RightUpperArm"), char:FindFirstChild("RightHand")
	local luA, lh = char:FindFirstChild("LeftUpperArm"), char:FindFirstChild("LeftHand")
	if ruA and rh and luA and lh then
		table.insert(s.ik, makeIK(humanoid, ruA, rh, s.paddle.gripR, seat:FindFirstChild("ElbowR")))
		table.insert(s.ik, makeIK(humanoid, luA, lh, s.paddle.gripL, seat:FindFirstChild("ElbowL")))
	end
	return s
end

local function endRowing(model)
	local s = active[model]
	if not s then return end
	for _, ik in ipairs(s.ik) do if ik then ik:Destroy() end end
	if s.paddle then s.paddle.model:Destroy() end
	active[model] = nil
end

RunService.RenderStepped:Connect(function(dt)
	for _, model in ipairs(CollectionService:GetTagged("Kayak")) do
		local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
		local hum = seat and seat.Occupant
		local s = active[model]
		if hum and hum.Parent then
			if s and s.humanoid ~= hum then endRowing(model); s = nil end
			if not s then s = beginRowing(model, seat, hum); active[model] = s end

			local throttle = seat.ThrottleFloat
			local rate = model:GetAttribute("StrokeRate") or 2.9
			s.k += ((math.abs(throttle) > 0.05 and 1 or 0) - s.k) * math.min(1, dt * 6)
			s.phase += dt * rate * throttle

			-- one full cycle = right stroke then left stroke:
			-- the shaft tilts (blade dips) and sweeps back on the stroking side
			local yaw = s.k * 0.42 * math.cos(s.phase)
			local roll = -s.k * 0.55 * math.sin(s.phase)
			local cf = seat.CFrame * CFrame.new(0, 2.1, -0.8) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, roll)
			local p = s.paddle
			p.shaft.CFrame = cf
			p.bladeL.CFrame = cf * CFrame.new(-4.35, 0, 0)
			p.bladeR.CFrame = cf * CFrame.new(4.35, 0, 0)
		elseif s then
			endRowing(model)
		end
	end
end)
