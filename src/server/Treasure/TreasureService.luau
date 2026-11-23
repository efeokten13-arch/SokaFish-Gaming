--!strict
-- Hazine sandıkları ("TreasureChest" tag'li modeller): basılı tutup aç, 3 ödül kazan (Config/Items.Chest).
-- Her oyuncu her sandığı RespawnMinutes'ta bir açabilir.
-- Akış: ödüller hemen seçilip veriye yazılır -> açan oyuncuya LootReveal (Clash of Clans tarzı dokunarak açma:
--   client/Effects/LootReveal) -> oyuncu son dokunuşu yapınca client "LootRevealDone" der -> kapak açılır
--   (herkes görür) -> kartlar uçunca HUD güncellenir. Client cevap vermezse FALLBACK sn sonra kendiliğinden.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Cfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Treasure"))
local Items = require(ReplicatedStorage.Shared.Config:WaitForChild("Items"))
local DataService = require(script.Parent.Parent.Data.DataService)
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))
local Loot = require(script.Parent.Loot)

local PUSH_DELAY = 3.6 -- kapak açıldıktan sonra kartlar uçunca para / inci sayacı güncellenir
local FALLBACK = 40 -- client "açıldı" demezse bu kadar sn sonra kapak açılır, veri gönderilir

local animateLidRef: (Model, Color3?) -> ()
local pending: { [Player]: { model: Model, color: Color3?, done: boolean } } = {}

local function finish(player: Player, model: Instance?)
	local p = pending[player]
	if not p or p.done or (model ~= nil and p.model ~= model) then
		return
	end
	p.done = true
	pending[player] = nil
	animateLidRef(p.model, p.color)
	task.delay(PUSH_DELAY, function()
		if player.Parent then
			DataService.Push(player)
		end
	end)
end

local TreasureService = {}

local opened: { [Player]: { [Instance]: number } } = {}

local function animateLid(model: Model, color: Color3?)
	local lid = model:FindFirstChild("Lid") :: BasePart?
	local glow = model:FindFirstChild("Glow") :: BasePart?
	local closed = model:GetAttribute("LidClosed") :: CFrame?
	if not lid or not closed or model:GetAttribute("Animating") then
		return
	end
	model:SetAttribute("Animating", true)
	-- arka kenar etrafında açılır
	local hinge = closed * CFrame.new(0, -0.55, 1.55)
	local open = hinge * CFrame.Angles(math.rad(-100), 0, 0) * hinge:Inverse() * closed
	TweenService:Create(lid, TweenInfo.new(0.25, Enum.EasingStyle.Back), { CFrame = open }):Play()
	if glow then
		if color then
			glow.Color = color
		end
		TweenService:Create(glow, TweenInfo.new(0.3), { Transparency = 0.1 }):Play()
	end
	task.delay(4, function()
		TweenService:Create(lid, TweenInfo.new(0.4), { CFrame = closed }):Play()
		if glow then
			TweenService:Create(glow, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		model:SetAttribute("Animating", nil)
	end)
end

animateLidRef = animateLid

local function onOpen(player: Player, model: Model)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local mine = opened[player]
	if not mine then
		mine = {}
		opened[player] = mine
	end
	local now = os.time()
	local last = mine[model]
	if last and now - last < Cfg.RespawnMinutes * 60 then
		local left = math.ceil((Cfg.RespawnMinutes * 60 - (now - last)) / 60)
		DataService.Notify(player, "This chest is empty. Come back in " .. left .. " min", Color3.fromRGB(255, 140, 120))
		return
	end
	mine[model] = now
	local rewards, top = Loot.Roll("chest", model:GetAttribute("Tier") :: string?)
	Loot.Grant(player, rewards)
	finish(player, nil) -- önceki açılış yarım kaldıysa onu bitir
	local entry = { model = model, color = (Items.TierColors :: any)[top], done = false }
	pending[player] = entry
	Remotes.Event("LootReveal"):FireClient(player, "chest", model, rewards, top)
	task.delay(FALLBACK, function()
		if pending[player] == entry then
			finish(player, model)
		end
	end)
end

local function setup(model: Instance)
	if not model:IsA("Model") or model:FindFirstChild("ChestPrompt", true) then
		return
	end
	local base = model.PrimaryPart or model:FindFirstChild("Base")
	if not base then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChestPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Treasure Chest"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	prompt.Triggered:Connect(function(p)
		onOpen(p, model)
	end)
end

function TreasureService.Init()
	for _, m in CollectionService:GetTagged("TreasureChest") do
		setup(m)
	end
	CollectionService:GetInstanceAddedSignal("TreasureChest"):Connect(setup)
	Remotes.Event("LootRevealDone").OnServerEvent:Connect(function(player, model)
		if typeof(model) == "Instance" then
			finish(player, model)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		opened[p] = nil
		pending[p] = nil
	end)
end

return TreasureService
