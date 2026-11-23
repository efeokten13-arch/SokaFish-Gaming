--!strict
-- Balık fedası (2. ada, Ana Tapınak). Temple Keeper'a git -> "Offer an Epic fish" (basılı tut).
--   * Çantada Epic balık yoksa: "Bring me an EPIC fish" uyarısı.
--   * Varsa: en ucuz Epic balık çantadan alınır, oyuncuya "AltarSacrifice" sahnesi gönderilir
--     (client/Effects/AltarCinematic: balık sunağa uçar, döner döner patlar, altın ışık oyuncuya iner).
--   * Ödül: Golden Blessing (data.goldenBlessing). Bir sonraki tutulan balık kesin "GoldenFish" olur
--     (FishingService.onCast). Balık kaçarsa kutsama kalır; Golden Fish çantaya girince biter.
--   Kutsama aktifken oyuncunun etrafında altın parıltı olur (herkes görür) ve HUD'da rozet çıkar.
-- Ayarlar: Config/Items.Altar
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage.Shared:WaitForChild("Config")
local Fish = require(Config:WaitForChild("Fish"))
local Items = require(Config:WaitForChild("Items"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local DataService = require(script.Parent.Parent.Data.DataService)

local AltarService = {}

local busy: { [Player]: boolean } = {}
local KEEPER_COLOR = Color3.fromRGB(255, 205, 90)

local function altarPart(): BasePart?
	local temple = Workspace:FindFirstChild("Atoll") and Workspace.Atoll:FindFirstChild("MainTemple")
	local bowl = temple and temple:FindFirstChild("AltarBowl")
	return if bowl and bowl:IsA("BasePart") then bowl else nil
end

-- Kutsama parıltısı: karakterin etrafında altın kıvılcımlar (server'da -> herkes görür)
local function setAura(player: Player, on: boolean)
	player:SetAttribute("GoldenBlessing", on or nil)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local old = root:FindFirstChild("BlessingAura")
	if old then
		old:Destroy()
	end
	if not on then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "BlessingAura"
	att.Parent = root
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 250, 200))
	p.LightEmission = 1
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	p.Lifetime = NumberRange.new(0.8, 1.4)
	p.Rate = 10
	p.Speed = NumberRange.new(0.5, 1.5)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Acceleration = Vector3.new(0, 2, 0)
	p.Parent = att
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 100)
	light.Range = 10
	light.Brightness = 1
	light.Parent = att
end

local function pickEpic(storage: { string }): number?
	local best, bestPrice = nil, math.huge
	for i, id in storage do
		local def = (Fish :: any)[id]
		if def and def.rarity == Items.Altar.Rarity and def.sell < bestPrice then
			best, bestPrice = i, def.sell
		end
	end
	return best
end

local function onOffer(player: Player, keeper: Model)
	if busy[player] then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local d = data :: any
	if d.goldenBlessing then
		DataService.Notify(player, "✨ You already carry the Golden Blessing. Go catch your Golden Fish!", KEEPER_COLOR)
		return
	end
	local slot = pickEpic(data.storage)
	if not slot then
		DataService.Notify(player, "Temple Keeper: \"Bring me an EPIC fish, and the sea gods will bless your next catch.\"", KEEPER_COLOR)
		return
	end
	local altar = altarPart()
	if not altar then
		return
	end
	busy[player] = true
	local fishId = table.remove(data.storage, slot) :: string
	d.goldenBlessing = true
	Remotes.Event("AltarSacrifice"):FireClient(player, fishId, altar, keeper)
	-- sahne bitince (kutsama ışığı oyuncuya inince) parıltı ve veri
	task.delay(Items.Altar.BlessAt, function()
		if player.Parent then
			setAura(player, true)
		end
	end)
	task.delay(Items.Altar.Duration, function()
		busy[player] = nil
		if player.Parent then
			DataService.Push(player)
		end
	end)
end

-- FishingService çağırır: kutsama varsa bu atışın balığı Golden Fish olur
function AltarService.ForcedFish(player: Player): string?
	local data = DataService.Get(player)
	if data and (data :: any).goldenBlessing then
		return Items.Altar.RewardFish
	end
	return nil
end

-- FishingService çağırır: Golden Fish çantaya girince kutsama biter
function AltarService.OnCaught(player: Player, fishId: string)
	local data = DataService.Get(player)
	if data and (data :: any).goldenBlessing and fishId == Items.Altar.RewardFish then
		(data :: any).goldenBlessing = nil
		setAura(player, false)
		DataService.Notify(player, "✨ The Golden Blessing is fulfilled! Offer another Epic fish for a new one.", KEEPER_COLOR)
	end
end

function AltarService.Init()
	local npcs = Workspace:FindFirstChild("NPCs")
	local keeper = npcs and npcs:FindFirstChild("Temple Keeper")
	if keeper and keeper:IsA("Model") then
		local root = keeper:FindFirstChild("HumanoidRootPart") or keeper.PrimaryPart or keeper:FindFirstChildWhichIsA("BasePart")
		if root then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "AltarPrompt"
			prompt.ActionText = "Offer an Epic fish"
			prompt.ObjectText = "Temple Keeper"
			prompt.HoldDuration = 0.8
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = root
			prompt.Triggered:Connect(function(p)
				onOffer(p, keeper)
			end)
		end
	else
		warn("[AltarService] Temple Keeper bulunamadı")
	end
	-- kayıtlı kutsaması olan oyuncu: girişte ve her doğuşta parıltı
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("HumanoidRootPart", 5)
			local data = DataService.Wait(player)
			if data and (data :: any).goldenBlessing then
				setAura(player, true)
			end
		end)
		task.spawn(function()
			local data = DataService.Wait(player)
			if data and (data :: any).goldenBlessing and player.Character then
				setAura(player, true)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		busy[p] = nil
	end)
end

return AltarService
