--!strict
-- Batık gemi enkazı: 2. adadaki her "Shipwreck" / "BigShipwreck" modelinin yanında suda yüzen bir
-- kurtarma yığını (sandık + tahtalar + varil) oluşturur. Tekneden "Salvage" ile toplanır:
-- tahta, metal, bazen inci (Config/Items.Wreck). Her oyuncu her enkazı CooldownMinutes'ta bir toplar.
-- Yığınlar oyun açılınca koddan kurulur (haritaya kaydedilmez), Workspace.Atoll.Salvage altına.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Items = require(ReplicatedStorage.Shared.Config:WaitForChild("Items"))
local DataService = require(script.Parent.Parent.Data.DataService)
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local Loot = require(script.Parent.Loot)

local WreckService = {}

local WATER_Y = -0.6 -- 2. adada su yüzeyi
local WRECK_NAMES = { Shipwreck = true, BigShipwreck = true }
local PUSH_DELAY = 5.0

local used: { [Player]: { [Instance]: number } } = {}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Yüzen kurtarma yığını: kırık sandık, 3 tahta, metal varil, parıltı
local function buildPile(at: Vector3, yaw: number, index: number): Model
	local m = Instance.new("Model")
	m.Name = "SalvagePile" .. index
	local base = CFrame.new(at.X, WATER_Y, at.Z) * CFrame.Angles(0, yaw, 0)
	local wood = Color3.fromRGB(110, 78, 48)
	local dark = Color3.fromRGB(70, 50, 32)
	local raft = part(m, "Raft", Vector3.new(7, 0.6, 5), base * CFrame.new(0, 0.1, 0), dark, Enum.Material.WoodPlanks)
	m.PrimaryPart = raft
	for i = -1, 1 do
		part(m, "Plank", Vector3.new(0.9, 0.35, 6.5), base * CFrame.new(i * 2.4, 0.5, 0.4) * CFrame.Angles(0, math.rad(i * 9), math.rad(i * 4)), wood, Enum.Material.WoodPlanks)
	end
	local crate = part(m, "Crate", Vector3.new(2.6, 2.2, 2.6), base * CFrame.new(-1.2, 1.6, -0.6) * CFrame.Angles(0, math.rad(18), math.rad(6)), wood, Enum.Material.Wood)
	part(m, "CrateBand", Vector3.new(2.7, 0.3, 2.7), crate.CFrame * CFrame.new(0, 0.6, 0), Color3.fromRGB(90, 90, 96), Enum.Material.Metal)
	local barrel = part(m, "Barrel", Vector3.new(2.6, 1.8, 1.8), base * CFrame.new(1.9, 1.3, 0.5) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 124, 132), Enum.Material.DiamondPlate)
	barrel.Shape = Enum.PartType.Cylinder
	-- yumuşak parıltı: "burada bir şey var"
	local glow = part(m, "Glow", Vector3.new(1, 1, 1), base * CFrame.new(0, 2.6, 0), Color3.fromRGB(255, 220, 140), Enum.Material.Neon)
	glow.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 130)
	light.Range = 14
	light.Brightness = 1.4
	light.Parent = glow
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Color = ColorSequence.new(Color3.fromRGB(255, 230, 160))
	sp.Size = NumberSequence.new(0.6, 0)
	sp.Lifetime = NumberRange.new(1, 1.6)
	sp.Rate = 4
	sp.Speed = NumberRange.new(0.5, 1.2)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.LightEmission = 1
	sp.Parent = glow
	-- sallanma için orijinal konumlar (client'ta hafif yüzme hareketi yok; server sabit tutar)
	return m
end

local function onSalvage(player: Player, pile: Model)
	if not DataService.Get(player) then
		return
	end
	local mine = used[player]
	if not mine then
		mine = {}
		used[player] = mine
	end
	local now = os.time()
	local cd = Items.Wreck.CooldownMinutes * 60
	local last = mine[pile]
	if last and now - last < cd then
		local left = math.ceil((cd - (now - last)) / 60)
		DataService.Notify(player, "Nothing left to salvage here. Come back in " .. left .. " min", Color3.fromRGB(255, 140, 120))
		return
	end
	mine[pile] = now
	local rewards, top = Loot.Roll("wreck")
	Loot.Grant(player, rewards)
	Remotes.Event("LootReveal"):FireClient(player, "wreck", pile, rewards, top)
	task.delay(PUSH_DELAY, function()
		if player.Parent then
			DataService.Push(player)
		end
	end)
end

function WreckService.Init()
	local atoll = Workspace:FindFirstChild("Atoll")
	if not atoll then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Salvage"
	local i = 0
	for _, wreck in atoll:GetChildren() do
		if wreck:IsA("Model") and WRECK_NAMES[wreck.Name] then
			i += 1
			local cf, size = wreck:GetBoundingBox()
			-- geminin yan tarafında (uzun kenar boyunca), gövdeye 7 stud uzakta
			local side = if size.X <= size.Z then cf.RightVector * (size.X / 2 + 7) else cf.LookVector * (size.Z / 2 + 7)
			local at = cf.Position + Vector3.new(side.X, 0, side.Z)
			local pile = buildPile(at, math.atan2(side.X, side.Z), i)
			pile.Parent = folder
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "SalvagePrompt"
			prompt.ActionText = "Salvage"
			prompt.ObjectText = "Shipwreck Debris"
			prompt.HoldDuration = 1.2
			prompt.MaxActivationDistance = 18 -- tekneden de toplanabilsin
			prompt.RequiresLineOfSight = false
			prompt.Parent = pile.PrimaryPart
			prompt.Triggered:Connect(function(p)
				onSalvage(p, pile)
			end)
		end
	end
	folder.Parent = atoll
	Players.PlayerRemoving:Connect(function(p)
		used[p] = nil
	end)
end

return WreckService
