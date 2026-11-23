--!nonstrict
-- Balık sürüleri (client görseli): üstte dönen martılar, sudan zıplayan balıklar, köpüren su.
-- Sürülerin yeri ReplicatedStorage.FishSchools'tan gelir (server: SchoolService). Her şey sadece bu oyuncuda çizilir.
-- Oyuncu sürünün içindeyse ekranın üstünde "Fish school" yazısı çıkar (şans sunucuda uygulanır).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("FishSchools"))

local FishSchools = {}

local player = Players.LocalPlayer
local rng = Random.new()

local WHITE = Color3.fromRGB(245, 245, 240)
local GREY = Color3.fromRGB(175, 182, 190)
local FISH_COLORS = { Color3.fromRGB(200, 210, 220), Color3.fromRGB(120, 160, 190), Color3.fromRGB(230, 200, 120) }

local fxFolder: Folder
local visuals = {} -- [Configuration] = { model, center, gulls, splash, nextJump }
local jumps = {} -- sudan zıplayan balıklar: { part, from, to, t0, dur, height, visual }
local banner

local function part(parent, name, size, color, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape == "ball" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	elseif shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = parent
	return p
end

-- Martı: gövde, baş, gaga, kuyruk, iki kanat. Kanatlar her karede çırpılır.
local function buildGull(parent)
	local m = Instance.new("Model")
	m.Name = "Gull"
	local g = {
		body = part(m, "Body", Vector3.new(0.7, 0.6, 1.8), WHITE, "ball"),
		head = part(m, "Head", Vector3.new(0.55, 0.55, 0.55), WHITE, "ball"),
		beak = part(m, "Beak", Vector3.new(0.14, 0.14, 0.45), Color3.fromRGB(240, 170, 50)),
		tail = part(m, "Tail", Vector3.new(0.5, 0.08, 0.55), GREY),
		wingL = part(m, "WingL", Vector3.new(2.4, 0.08, 0.8), GREY),
		wingR = part(m, "WingR", Vector3.new(2.4, 0.08, 0.8), GREY),
		phase = rng:NextNumber(0, math.pi * 2),
		dir = if rng:NextNumber() < 0.5 then 1 else -1,
		radius = Cfg.GullRadius * rng:NextNumber(0.6, 1.2),
		height = Cfg.GullHeight + rng:NextNumber(-5, 6),
		speed = rng:NextNumber(9, 13), -- stud/sn
	}
	m.Parent = parent
	g.model = m
	g.parts = { g.body, g.head, g.beak, g.tail, g.wingL, g.wingR }
	return g
end

local function gullCFrames(g, center: Vector3, t: number, out)
	local w = g.speed / g.radius * g.dir
	local a = g.phase + t * w
	local pos = center + Vector3.new(math.cos(a) * g.radius, g.height + math.sin(t * 1.3 + g.phase) * 1.5, math.sin(a) * g.radius)
	local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) * g.dir
	local cf = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, 0.35 * g.dir) -- dönüşe doğru yatar
	-- bazen süzülür, bazen çırpar
	local amp = 0.6 * (0.45 + 0.55 * math.sin(t * 0.7 + g.phase))
	local flap = math.sin(t * 9 + g.phase) * amp
	table.insert(out, cf)
	table.insert(out, cf * CFrame.new(0, 0.25, -0.9))
	table.insert(out, cf * CFrame.new(0, 0.2, -1.3))
	table.insert(out, cf * CFrame.new(0, 0.05, 0.95))
	table.insert(out, cf * CFrame.new(-0.3, 0.15, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-1.2, 0, 0))
	table.insert(out, cf * CFrame.new(0.3, 0.15, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(1.2, 0, 0))
end

local function build(school: Configuration)
	local x, z = school:GetAttribute("X"), school:GetAttribute("Z")
	if not x or not z then
		return nil
	end
	local center = Vector3.new(x, 0, z)
	local model = Instance.new("Model")
	model.Name = school.Name

	-- köpüren su: hafif beyaz halka + yukarı kabarcıklar
	local foam = part(model, "Foam", Vector3.new(0.2, Cfg.Radius * 1.6, Cfg.Radius * 1.6), WHITE, "cyl")
	foam.CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	foam.Transparency = 0.82
	local bubbleArea = part(model, "Bubbles", Vector3.new(Cfg.Radius * 1.4, 0.2, Cfg.Radius * 1.4), WHITE)
	bubbleArea.Transparency = 1
	bubbleArea.CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0))
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Color = ColorSequence.new(WHITE)
	bubbles.Size = NumberSequence.new(0.7, 0)
	bubbles.Transparency = NumberSequence.new(0.2, 1)
	bubbles.Lifetime = NumberRange.new(0.6, 1)
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.Rate = 14
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Parent = bubbleArea

	-- sıçrama: zıplayan balık suya girip çıkarken buradan patlatılır
	local splash = part(model, "Splash", Vector3.new(1, 1, 1), WHITE)
	splash.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(Color3.fromRGB(215, 238, 255))
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, -35, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = splash

	local gulls = {}
	for _ = 1, Cfg.Gulls do
		table.insert(gulls, buildGull(model))
	end
	model.Parent = fxFolder
	return { model = model, center = center, gulls = gulls, splash = splash, emitter = emitter, nextJump = 0 }
end

local function remove(school)
	local v = visuals[school]
	if v then
		v.model:Destroy()
		visuals[school] = nil
	end
end

local function track(school: Instance)
	if not school:IsA("Configuration") then
		return
	end
	visuals[school] = build(school)
	school:GetAttributeChangedSignal("Seed"):Connect(function()
		remove(school)
		visuals[school] = build(school)
	end)
end

local function splashAt(v, pos: Vector3)
	v.splash.CFrame = CFrame.new(pos.X, 0.2, pos.Z)
	v.emitter:Emit(10)
end

local function startJump(v)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(0, Cfg.Radius * 0.8)
	local from = v.center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	local dir = rng:NextNumber(0, math.pi * 2)
	local len = rng:NextNumber(4, 8)
	local to = from + Vector3.new(math.cos(dir) * len, 0, math.sin(dir) * len)
	local fish = part(v.model, "JumpFish", Vector3.new(0.45, 0.55, 1.4), FISH_COLORS[rng:NextInteger(1, #FISH_COLORS)], "ball")
	fish.Reflectance = 0.2
	fish.CFrame = CFrame.new(from)
	splashAt(v, from)
	table.insert(jumps, { part = fish, from = from, to = to, t0 = os.clock(), dur = rng:NextNumber(0.7, 1.0), height = rng:NextNumber(2.5, 4.5), visual = v })
end

local function makeBanner()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FishSchoolGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")
	banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 138) -- fırtına yazısının (96) altında
	banner.Size = UDim2.fromOffset(400, 36)
	banner.BackgroundColor3 = Color3.fromRGB(30, 60, 80)
	banner.BackgroundTransparency = 0.25
	banner.Font = Enum.Font.FredokaOne
	banner.TextSize = 20
	banner.TextColor3 = Color3.fromRGB(150, 230, 255)
	banner.Text = string.format("🐦 Fish school: Rare fish x%g!", Cfg.Luck)
	banner.Visible = false
	banner.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = banner
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(150, 230, 255)
	st.Thickness = 1.5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = banner
end

local function update()
	local t = os.clock()
	local cam = Workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local inside = false

	local moveParts, moveCFrames = {}, {}
	for _, v in visuals do
		if root and root.Position.Y < 40 and Vector2.new(root.Position.X - v.center.X, root.Position.Z - v.center.Z).Magnitude <= Cfg.Radius then
			inside = true
		end
		-- uzaktaki sürüyü çizme
		local near = (camPos - v.center).Magnitude <= Cfg.DrawDistance
		if not near then
			if v.model.Parent then
				v.model.Parent = nil
			end
			continue
		end
		if not v.model.Parent then
			v.model.Parent = fxFolder
		end
		for _, g in v.gulls do
			local cfs = {}
			gullCFrames(g, v.center, t, cfs)
			for i, p in g.parts do
				table.insert(moveParts, p)
				table.insert(moveCFrames, cfs[i])
			end
		end
		if t >= v.nextJump then
			v.nextJump = t + rng:NextNumber(Cfg.JumpMin, Cfg.JumpMax)
			startJump(v)
		end
	end

	-- zıplayan balıklar: yay çizip suya geri girer
	for i = #jumps, 1, -1 do
		local j = jumps[i]
		local k = (t - j.t0) / j.dur
		-- bitti, sürü yer değiştirdi ya da sürü uzakta gizlendi
		if k >= 1 or not j.part.Parent or not j.visual.model.Parent then
			if k >= 1 and j.part.Parent and j.visual.model.Parent then
				splashAt(j.visual, j.to)
			end
			j.part:Destroy()
			table.remove(jumps, i)
		else
			local pos = j.from:Lerp(j.to, k) + Vector3.new(0, 4 * j.height * k * (1 - k), 0)
			local vel = (j.to - j.from) / j.dur + Vector3.new(0, 4 * j.height * (1 - 2 * k) / j.dur, 0)
			table.insert(moveParts, j.part)
			table.insert(moveCFrames, CFrame.lookAt(pos, pos + vel))
		end
	end

	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if banner then
		banner.Visible = inside
	end
end

function FishSchools.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "FishSchoolsFX"
	fxFolder.Parent = Workspace
	makeBanner()

	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("FishSchools", 30)
		if not folder then
			return
		end
		for _, s in folder:GetChildren() do
			track(s)
		end
		folder.ChildAdded:Connect(track)
		folder.ChildRemoved:Connect(remove)
	end)

	RunService.RenderStepped:Connect(update)
end

return FishSchools
