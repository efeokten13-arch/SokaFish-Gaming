--!nonstrict
-- Teknelerin arkasında köpük izi. Sadece görsel, her oyuncunun kendi ekranında; tekne fiziğine dokunmaz.
-- "Kayak" tag'li her tekneye (BoatController'ın kullandığı tag) iki Trail eklenir; hız arttıkça belirginleşir.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local BoatWake = {}

local wakes = {} -- model -> { trails }

local function setup(model)
	if wakes[model] then
		return
	end
	local hull = model.PrimaryPart or model:WaitForChild("Hull", 5)
	if not hull then
		return
	end
	local half = hull.Size.Z / 2
	local width = hull.Size.X / 2
	local trails = {}
	for _, side in { -1, 1 } do
		local a0 = Instance.new("Attachment")
		a0.Name = "WakeA"
		a0.Position = Vector3.new(side * width * 0.9, -hull.Size.Y * 0.3, half * 0.85)
		a0.Parent = hull
		local a1 = Instance.new("Attachment")
		a1.Name = "WakeB"
		a1.Position = Vector3.new(side * width * 0.3, -hull.Size.Y * 0.3, half * 0.85)
		a1.Parent = hull
		local t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Lifetime = 1.6
		t.MinLength = 0.5
		t.FaceCamera = false
		t.LightEmission = 0.3
		t.Color = ColorSequence.new(Color3.fromRGB(245, 252, 255))
		t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.4) })
		t.Enabled = false
		t.Parent = hull
		table.insert(trails, t)
	end
	local wheel = model:FindFirstChild("Wheel")
	wakes[model] = { hull = hull, trails = trails, wheel = wheel and wheel:FindFirstChild("Hinge"), seat = model:FindFirstChildWhichIsA("VehicleSeat", true), spin = 0 }
end

function BoatWake.Init()
	for _, m in CollectionService:GetTagged("Kayak") do
		task.spawn(setup, m)
	end
	CollectionService:GetInstanceAddedSignal("Kayak"):Connect(function(m)
		task.spawn(setup, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Kayak"):Connect(function(m)
		wakes[m] = nil
	end)
	-- dümen tekerleği: sürücünün sağa/sola girdisine göre döner (sadece görsel)
	RunService.RenderStepped:Connect(function(dt)
		for _, w in wakes do
			if w.wheel and w.seat then
				local target = (w.seat.Occupant and w.seat.SteerFloat or 0) * 1.6
				w.spin += (target - w.spin) * math.min(1, dt * 6)
				local base = w.wheel:GetAttribute("BaseC0")
				if base then
					w.wheel.C0 = base * CFrame.Angles(w.spin, 0, 0)
				end
			end
		end
	end)
	-- 5 kez/saniye kontrol yeter
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		for model, w in wakes do
			if not w.hull.Parent then
				wakes[model] = nil
				continue
			end
			local speed = w.hull.AssemblyLinearVelocity.Magnitude
			local on = speed > 3
			local alpha = math.clamp(1 - speed / 22, 0.15, 0.7)
			for _, t in w.trails do
				t.Enabled = on
				t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, alpha), NumberSequenceKeypoint.new(1, 1) })
			end
		end
	end)
end

return BoatWake
