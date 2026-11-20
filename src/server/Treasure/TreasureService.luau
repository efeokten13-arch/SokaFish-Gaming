--!strict
-- Hazine sandıkları ("TreasureChest" tag'li modeller): basılı tutup aç, para kazan.
-- Her oyuncu her sandığı RespawnMinutes'ta bir açabilir. Kapak açılıp kapanır (herkes görür).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Cfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Treasure"))
local DataService = require(script.Parent.Parent.Data.DataService)

local TreasureService = {}

local opened: { [Player]: { [Instance]: number } } = {}
local rng = Random.new()

local function animateLid(model: Model)
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
	TweenService:Create(lid, TweenInfo.new(0.4, Enum.EasingStyle.Back), { CFrame = open }):Play()
	if glow then
		TweenService:Create(glow, TweenInfo.new(0.3), { Transparency = 0.1 }):Play()
	end
	task.delay(3, function()
		TweenService:Create(lid, TweenInfo.new(0.4), { CFrame = closed }):Play()
		if glow then
			TweenService:Create(glow, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		model:SetAttribute("Animating", nil)
	end)
end

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
	local tier = Cfg.Tiers[model:GetAttribute("Tier") :: string] or Cfg.Tiers.Small
	local gold = rng:NextInteger(tier.min, tier.max)
	data.money += gold
	DataService.Push(player)
	DataService.Notify(player, "Treasure! +$" .. gold, Color3.fromRGB(255, 214, 80))
	animateLid(model)
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
	Players.PlayerRemoving:Connect(function(p)
		opened[p] = nil
	end)
end

return TreasureService
