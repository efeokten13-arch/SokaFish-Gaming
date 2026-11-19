-- Balık tutmanın görsel tarafı (server'da, herkes görür):
--   olta karakterin elinde, savurma animasyonu, misina (Beam), şamandıra,
--   vurunca batma + sıçrama, çekerken titreme, yakalayınca balığın sudan çıkması.
-- FishingService her adımda buradaki fonksiyonları çağırır.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("Fishing"))
local RodModelBuilder = require(Shared:WaitForChild("RodModelBuilder"))
local FishModelBuilder = require(Shared:WaitForChild("FishModelBuilder"))

local FishingVisuals = {}

type State = {
	rod: Model?,
	rodId: string?,
	weld: Weld?,
	baseC0: CFrame?,
	rodTween: Tween?,
	bobber: BasePart?,
	bobBase: Vector3?,
	bobTween: Tween?,
	lastActive: number,
}

local states: { [Player]: State } = {}
local rng = Random.new()
local fxFolder: Folder? = nil

local function getFx(): Folder
	if not fxFolder or not fxFolder.Parent then
		local f = Workspace:FindFirstChild("FishingFX")
		if not f then
			f = Instance.new("Folder")
			f.Name = "FishingFX"
			f.Parent = Workspace
		end
		fxFolder = f :: Folder
	end
	return fxFolder :: Folder
end

local function getState(player: Player): State
	local st = states[player]
	if not st then
		st = { lastActive = os.clock() }
		states[player] = st
	end
	return st
end

local function removeBobber(st: State)
	if st.bobTween then
		st.bobTween:Cancel()
		st.bobTween = nil
	end
	if st.bobber then
		st.bobber:Destroy()
		st.bobber = nil
	end
	st.bobBase = nil
end

local function removeRod(st: State)
	if st.rodTween then
		st.rodTween:Cancel()
		st.rodTween = nil
	end
	if st.rod then
		st.rod:Destroy()
	end
	st.rod, st.weld, st.baseC0, st.rodId = nil, nil, nil, nil
end

-- Oltayı tutma pozisyonuna göre çevir. pitch > 0: uç yukarı/geri, < 0: uç aşağı/ileri
local function poseRod(st: State, pitch: number, time: number)
	if not st.weld or not st.baseC0 then
		return
	end
	if st.rodTween then
		st.rodTween:Cancel()
	end
	local tween = TweenService:Create(
		st.weld,
		TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = st.baseC0 * CFrame.Angles(math.rad(pitch), 0, 0) }
	)
	st.rodTween = tween
	tween:Play()
end

-- Spot'un üstünden aşağı ışın at: suya (veya zemine) çarptığı nokta
local function findWaterPoint(spot: BasePart, char: Model): Vector3
	local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, spot.Parent :: Instance, getFx() }
	params.IgnoreWater = false
	local hit = Workspace:Raycast(spot.Position + offset + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position else spot.Position + offset
end

local function makeBobber(tipAtt: Attachment): Part
	local b = Instance.new("Part")
	b.Name = "Bobber"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(0.45, 0.45, 0.45)
	b.Color = Color3.fromRGB(220, 50, 45)
	b.Material = Enum.Material.SmoothPlastic
	b.Anchored = true
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.CFrame = CFrame.new(tipAtt.WorldPosition)

	local top = Instance.new("Part")
	top.Name = "Top"
	top.Shape = Enum.PartType.Ball
	top.Size = Vector3.new(0.3, 0.3, 0.3)
	top.Color = Color3.new(1, 1, 1)
	top.Material = Enum.Material.SmoothPlastic
	top.CanCollide = false
	top.CanQuery = false
	top.CanTouch = false
	top.Massless = true
	top.CFrame = b.CFrame * CFrame.new(0, 0.16, 0)
	local w = Instance.new("WeldConstraint")
	w.Part0 = b
	w.Part1 = top
	w.Parent = top
	top.Parent = b

	local att = Instance.new("Attachment")
	att.Parent = b

	local line = Instance.new("Beam")
	line.Name = "Line"
	line.Attachment0 = tipAtt
	line.Attachment1 = att
	line.Width0 = 0.04
	line.Width1 = 0.04
	line.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
	line.Transparency = NumberSequence.new(0.15)
	line.FaceCamera = true
	line.LightInfluence = 0
	line.Segments = 1
	line.Parent = b

	local splash = Instance.new("ParticleEmitter")
	splash.Name = "Splash"
	splash.Enabled = false
	splash.Color = ColorSequence.new(Color3.fromRGB(210, 235, 255))
	splash.Size = NumberSequence.new(0.25, 0)
	splash.Lifetime = NumberRange.new(0.4, 0.6)
	splash.Speed = NumberRange.new(5, 8)
	splash.SpreadAngle = Vector2.new(35, 35)
	splash.Acceleration = Vector3.new(0, -30, 0)
	splash.EmissionDirection = Enum.NormalId.Top
	splash.Parent = b

	b.Parent = getFx()
	return b
end

local function startBob(st: State, pos: Vector3)
	if not st.bobber then
		return
	end
	if st.bobTween then
		st.bobTween:Cancel()
	end
	st.bobBase = pos
	st.bobber.CFrame = CFrame.new(pos)
	local tween = TweenService:Create(
		st.bobber,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) }
	)
	st.bobTween = tween
	tween:Play()
end

-- Public API ----------------------------------------------------------------

function FishingVisuals.Equip(player: Player, rodId: string)
	local st = getState(player)
	st.lastActive = os.clock()
	local char = player.Character
	if not char then
		return
	end
	if st.rod and st.rod.Parent == char and st.rodId == rodId then
		return
	end
	removeRod(st)

	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hand or not root then
		return
	end

	local rod = RodModelBuilder.Build(rodId)
	local handle = rod.PrimaryPart :: BasePart
	-- Elde, karakterin baktığı yöne doğru, ucu yukarı kalkık
	local desired = CFrame.new(hand.Position) * root.CFrame.Rotation * CFrame.Angles(math.rad(Cfg.RodRestPitch), 0, 0)
	rod:PivotTo(desired)

	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = hand.CFrame:Inverse() * desired
	weld.Parent = handle
	rod.Parent = char

	st.rod, st.rodId, st.weld, st.baseC0 = rod, rodId, weld, weld.C0
end

function FishingVisuals.Cast(player: Player, spot: BasePart, rodId: string)
	FishingVisuals.Equip(player, rodId)
	local st = getState(player)
	removeBobber(st)
	local char = player.Character
	local rod = st.rod
	if not char or not rod then
		return
	end
	local tipAtt = rod:FindFirstChild("TipAttachment", true) :: Attachment?
	if not tipAtt then
		return
	end

	poseRod(st, 50, 0.25) -- geri savur
	task.delay(0.25, function()
		if st.rod ~= rod then
			return
		end
		poseRod(st, -15, 0.18) -- ileri at
		local target = findWaterPoint(spot, char)
		local bobber = makeBobber(tipAtt)
		st.bobber = bobber

		local fly = TweenService:Create(
			bobber,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(target) }
		)
		fly.Completed:Connect(function(state)
			if state ~= Enum.PlaybackState.Completed or st.bobber ~= bobber then
				return
			end
			startBob(st, target)
			poseRod(st, 0, 0.4)
		end)
		fly:Play()
	end)
end

function FishingVisuals.Bite(player: Player)
	local st = states[player]
	if not st or not st.bobber or not st.bobBase then
		return
	end
	if st.bobTween then
		st.bobTween:Cancel()
	end
	local splash = st.bobber:FindFirstChild("Splash") :: ParticleEmitter?
	if splash then
		splash:Emit(14)
	end
	local tween = TweenService:Create(
		st.bobber,
		TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(st.bobBase - Vector3.new(0, 0.5, 0)) }
	)
	st.bobTween = tween
	tween:Play()
	poseRod(st, -10, 0.1)
end

function FishingVisuals.Hooked(player: Player)
	local st = states[player]
	if not st then
		return
	end
	-- Şamandıra su altında çırpınır
	if st.bobber and st.bobBase then
		if st.bobTween then
			st.bobTween:Cancel()
		end
		st.bobber.CFrame = CFrame.new(st.bobBase + Vector3.new(-0.3, -0.35, 0))
		local tween = TweenService:Create(
			st.bobber,
			TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ CFrame = CFrame.new(st.bobBase + Vector3.new(0.3, -0.25, 0.2)) }
		)
		st.bobTween = tween
		tween:Play()
	end
	-- Olta ucu gerilip titrer
	if st.weld and st.baseC0 then
		if st.rodTween then
			st.rodTween:Cancel()
		end
		st.weld.C0 = st.baseC0 * CFrame.Angles(math.rad(-4), 0, 0)
		local tween = TweenService:Create(
			st.weld,
			TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ C0 = st.baseC0 * CFrame.Angles(math.rad(-12), 0, 0) }
		)
		st.rodTween = tween
		tween:Play()
	end
end

function FishingVisuals.Caught(player: Player, fishId: string)
	local st = states[player]
	if not st then
		return
	end
	st.lastActive = os.clock()
	poseRod(st, 40, 0.3) -- oltayı kaldır

	local bobber = st.bobber
	local tipAtt = st.rod and st.rod:FindFirstChild("TipAttachment", true) :: Attachment?
	if bobber and tipAtt then
		if st.bobTween then
			st.bobTween:Cancel()
			st.bobTween = nil
		end
		st.bobber, st.bobBase = nil, nil

		-- Balık şamandıranın altında asılı, birlikte yukarı çıkar
		local fish = FishModelBuilder.Build(fishId)
		if fish and fish.PrimaryPart then
			local body = fish.PrimaryPart
			local L = body.Size.Z
			body.Anchored = false
			fish:PivotTo(CFrame.new(bobber.Position - Vector3.new(0, L * 0.5 + 0.3, 0)) * CFrame.Angles(math.rad(90), 0, 0))
			local w = Instance.new("WeldConstraint")
			w.Part0 = bobber
			w.Part1 = body
			w.Parent = body
			fish.Parent = getFx()
			task.delay(1.4, function()
				fish:Destroy()
			end)
		end

		local splash = bobber:FindFirstChild("Splash") :: ParticleEmitter?
		if splash then
			splash:Emit(20)
		end
		TweenService:Create(
			bobber,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(tipAtt.WorldPosition - Vector3.new(0, 1, 0)) }
		):Play()
		task.delay(1.4, function()
			bobber:Destroy()
		end)
	end

	task.delay(0.6, function()
		poseRod(st, 0, 0.4)
	end)
end

function FishingVisuals.End(player: Player)
	local st = states[player]
	if not st then
		return
	end
	st.lastActive = os.clock()
	removeBobber(st)
	poseRod(st, 0, 0.3)
end

function FishingVisuals.Init()
	local function cleanup(player: Player)
		local st = states[player]
		if st then
			removeBobber(st)
			removeRod(st)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			cleanup(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterRemoving:Connect(function()
			cleanup(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		cleanup(player)
		states[player] = nil
	end)

	-- Bir süre balık tutulmazsa olta elden kalkar
	task.spawn(function()
		while true do
			task.wait(1)
			for _, st in states do
				if st.rod and not st.bobber and os.clock() - st.lastActive > Cfg.RodHideDelay then
					removeRod(st)
				end
			end
		end
	end)
end

return FishingVisuals
