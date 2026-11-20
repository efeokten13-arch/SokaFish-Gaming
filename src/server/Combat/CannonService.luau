--!strict
-- Gemi topları: oyuncu kendi gemisinin dümenindeyken bir yandaki topları ateşler.
-- Şimdilik hasar yok (gemi savaşı sistemi gelince eklenecek); mermi, patlama ve su sıçraması görsel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Cfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cannons"))

local CannonService = {}

local last: { [Player]: number } = {}
local balls = Instance.new("Folder")
balls.Name = "Cannonballs"

local function boatOf(player: Player): Model?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local model = seat and seat:FindFirstAncestorWhichIsA("Model")
	while model and not model:GetAttribute("HasCannons") do
		model = model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model")
	end
	if model and model:GetAttribute("OwnerUserId") == player.UserId then
		return model
	end
	return nil
end

local function flash(pos: Vector3)
	local f = Instance.new("Part")
	f.Shape = Enum.PartType.Ball
	f.Size = Vector3.new(2, 2, 2)
	f.Anchored = true
	f.CanCollide = false
	f.CanQuery = false
	f.Material = Enum.Material.Neon
	f.Color = Color3.fromRGB(255, 170, 60)
	f.Position = pos
	f.Parent = balls
	local l = Instance.new("PointLight")
	l.Color = f.Color
	l.Range = 16
	l.Brightness = 3
	l.Parent = f
	TweenService:Create(f, TweenInfo.new(0.25), { Size = Vector3.new(4, 4, 4), Transparency = 1 }):Play()
	task.delay(0.3, function()
		f:Destroy()
	end)
end

local function splash(pos: Vector3)
	for k = 1, 6 do
		local d = Instance.new("Part")
		d.Shape = Enum.PartType.Ball
		d.Size = Vector3.new(1.4, 1.4, 1.4)
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.Material = Enum.Material.SmoothPlastic
		d.Color = Color3.fromRGB(235, 248, 255)
		d.Transparency = 0.2
		d.Position = Vector3.new(pos.X, 0.3, pos.Z)
		d.Parent = balls
		local a = k / 6 * math.pi * 2
		local target = d.Position + Vector3.new(math.cos(a) * 3, 5 + (k % 2) * 3, math.sin(a) * 3)
		TweenService:Create(d, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Position = target, Transparency = 1, Size = Vector3.new(0.5, 0.5, 0.5) }):Play()
		task.delay(0.55, function()
			d:Destroy()
		end)
	end
end

local function boom(pos: Vector3)
	local e = Instance.new("Explosion")
	e.Position = pos
	e.BlastRadius = Cfg.BlastRadius
	e.BlastPressure = 0
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Parent = balls
end

local function shoot(origin: Vector3, velocity: Vector3, ignore: Instance)
	local b = Instance.new("Part")
	b.Name = "Cannonball"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(1.2, 1.2, 1.2)
	b.Color = Color3.fromRGB(30, 30, 34)
	b.Material = Enum.Material.Metal
	b.Anchored = true
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.Position = origin
	b.Parent = balls
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore, balls }
	params.IgnoreWater = true
	local pos, vel, t = origin, velocity, 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		t += dt
		local nextVel = vel - Vector3.new(0, Cfg.Gravity * dt, 0)
		local nextPos = pos + (vel + nextVel) * 0.5 * dt
		local hit = Workspace:Raycast(pos, nextPos - pos, params)
		if hit then
			conn:Disconnect()
			b:Destroy()
			boom(hit.Position)
			return
		end
		if nextPos.Y <= 0 then
			conn:Disconnect()
			b:Destroy()
			splash(nextPos)
			return
		end
		if t > Cfg.Lifetime then
			conn:Disconnect()
			b:Destroy()
			return
		end
		pos, vel = nextPos, nextVel
		b.Position = pos
	end)
end

local function fire(player: Player, side: any, yaw: any)
	if side ~= "Left" and side ~= "Right" then
		return
	end
	if typeof(yaw) ~= "number" or yaw ~= yaw then
		yaw = 0
	end
	local maxYaw = math.rad(Cfg.MaxYawDeg)
	yaw = math.clamp(yaw, -maxYaw, maxYaw)
	local now = os.clock()
	if last[player] and now - last[player] < Cfg.Cooldown then
		return
	end
	local boat = boatOf(player)
	local hull = boat and boat.PrimaryPart
	local folder = boat and boat:FindFirstChild("Cannons")
	if not boat or not hull or not folder then
		return
	end
	last[player] = now
	local list = {}
	for _, b in folder:GetChildren() do
		if b:IsA("BasePart") and b:GetAttribute("Side") == side then
			table.insert(list, b)
		end
	end
	for i, barrel in list do
		task.delay((i - 1) * 0.12, function()
			local weld = barrel:FindFirstChild("Hinge") :: Weld?
			if not weld or not hull.Parent then
				return
			end
			local base = weld:GetAttribute("BaseC0") :: CFrame
			weld.C0 = base * CFrame.Angles(0, yaw, 0)
			local cf = hull.CFrame * weld.C0 * weld.C1:Inverse()
			local dir = cf.RightVector
			local muzzle = (cf * CFrame.new(barrel.Size.X / 2 + 0.8, 0, 0)).Position
			flash(muzzle)
			shoot(muzzle, dir * Cfg.Speed + Vector3.new(0, Cfg.Arc, 0) + hull.AssemblyLinearVelocity, boat)
		end)
	end
end

function CannonService.Init()
	balls.Parent = Workspace
	local folder = ReplicatedStorage:FindFirstChild("CombatRemotes") or Instance.new("Folder")
	folder.Name = "CombatRemotes"
	folder.Parent = ReplicatedStorage
	local ev = folder:FindFirstChild("FireCannons") or Instance.new("RemoteEvent")
	ev.Name = "FireCannons"
	ev.Parent = folder
	;(ev :: RemoteEvent).OnServerEvent:Connect(fire)
	Players.PlayerRemoving:Connect(function(p)
		last[p] = nil
	end)
end

return CannonService
