--!strict
-- Gemi topları: oyuncu kendi gemisinin güvertesinde bir topun yanına gider, nişan alır ve o topu ateşler.
-- Şimdilik hasar yok (gemi savaşı sistemi gelince eklenecek); mermi, patlama ve su sıçraması görsel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Cfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cannons"))
local Audio = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Audio"))

local CannonService = {}

local last: { [Player]: number } = {}
local balls = Instance.new("Folder")
balls.Name = "Cannonballs"
local hitHandler: ((Player, Instance, Vector3) -> boolean)? = nil -- gülle bir şeye çarpınca çağrılır; true dönerse varsayılan patlama çıkmaz

-- Kısa 3D ses: görünmez, çapalı küçük parça içinde çalar ve silinir
function CannonService.Sfx(pos: Vector3, id: string, volume: number?, speed: number?, life: number?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = pos
	local snd = Instance.new("Sound")
	snd.SoundId = id
	snd.Volume = volume or 1
	snd.PlaybackSpeed = speed or 1
	snd.RollOffMode = Enum.RollOffMode.InverseTapered
	snd.RollOffMinDistance = 30
	snd.RollOffMaxDistance = 700
	snd.Parent = p
	p.Parent = balls
	snd:Play()
	task.delay(life or 4, function()
		p:Destroy()
	end)
end

-- Eğitim servisi gibi sistemler gülle çarpmasını buradan dinler
function CannonService.SetHitHandler(fn: ((Player, Instance, Vector3) -> boolean)?)
	hitHandler = fn
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

local function shoot(player: Player, origin: Vector3, velocity: Vector3, ignore: Instance)
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
			local handled = hitHandler and hitHandler(player, hit.Instance, hit.Position)
			if not handled then
				boom(hit.Position)
			end
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

-- client: FireCannons:FireServer(barrel, yaw, pitch, ammoId). Oyuncu kendi gemisindeki bir topun yanında olmalı.
local function fire(player: Player, barrel: any, yaw: any, pitch: any, ammo: any)
	if typeof(barrel) ~= "Instance" or not barrel:IsA("BasePart") then
		return
	end
	if typeof(yaw) ~= "number" or yaw ~= yaw then
		yaw = 0
	end
	if typeof(pitch) ~= "number" or pitch ~= pitch then
		pitch = 0
	end
	local ammoOk = false
	for _, a in Cfg.Ammo do
		if a.id == ammo and not a.locked then
			ammoOk = true
		end
	end
	if not ammoOk then
		return
	end
	yaw = math.clamp(yaw, -math.rad(Cfg.MaxYawDeg), math.rad(Cfg.MaxYawDeg))
	pitch = math.clamp(pitch, math.rad(Cfg.MinPitchDeg), math.rad(Cfg.MaxPitchDeg))
	local now = os.clock()
	if last[player] and now - last[player] < Cfg.Cooldown - 0.15 then
		return
	end
	-- top oyuncunun kendi (toplu) gemisinde mi, oyuncu yanında mı?
	local boat = barrel:FindFirstAncestorWhichIsA("Model")
	while boat and not boat:GetAttribute("HasCannons") do
		boat = boat.Parent and boat.Parent:FindFirstAncestorWhichIsA("Model")
	end
	if not boat or boat:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	local hull = boat.PrimaryPart
	local weld = barrel:FindFirstChild("Hinge") :: Weld?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hull or not weld or not root or (root.Position - barrel.Position).Magnitude > Cfg.UseRange then
		return
	end
	last[player] = now
	local base = weld:GetAttribute("BaseC0") :: CFrame
	weld.C0 = base * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, pitch)
	local cf = hull.CFrame * weld.C0 * weld.C1:Inverse()
	local muzzle = (cf * CFrame.new(barrel.Size.X / 2 + 0.8, 0, 0)).Position
	flash(muzzle)
	CannonService.Sfx(muzzle, Audio.Cannon, 0.9, 0.95 + math.random() * 0.1, 4)
	shoot(player, muzzle, cf.RightVector * Cfg.Speed + Vector3.new(0, Cfg.Arc, 0) + hull.AssemblyLinearVelocity, boat)
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
