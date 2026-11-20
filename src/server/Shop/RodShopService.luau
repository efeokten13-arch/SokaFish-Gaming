--!strict
-- Olta dükkânı: vitrindeki "BuyPrompt"a basınca olta alınır; zaten sahipse kuşanılır.
-- Vitrinler MapBuilder/RodShop ile kurulur (Workspace.RodShop.Displays).
-- Düğme yazıları her oyuncuda farklıdır (Buy / Equip / Equipped): client/UI/RodShopPrompts ayarlar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local DataService = require(script.Parent.Parent.Data.DataService)

local RodShopService = {}

local GREEN = Color3.fromRGB(120, 230, 150)
local RED = Color3.fromRGB(255, 140, 120)
local IDLE_ANIM = "rbxassetid://507766666" -- Roblox varsayılan R15 bekleme animasyonu

local function onPrompt(player: Player, rodId: string)
	local data = DataService.Get(player) :: any
	local def = (Economy.Rods :: any)[rodId]
	if not data or not def then
		return
	end
	if table.find(data.ownedRods, rodId) then
		if data.rod == rodId then
			DataService.Notify(player, def.displayName .. " is already equipped", GREEN)
			return
		end
		data.rod = rodId
		DataService.Notify(player, "Equipped " .. def.displayName, GREEN)
		DataService.Push(player)
		return
	end
	if data.money < def.price then
		DataService.Notify(player, "Not enough money ($" .. def.price .. " needed)", RED)
		return
	end
	data.money -= def.price
	table.insert(data.ownedRods, rodId)
	data.rod = rodId
	DataService.Notify(player, "Bought & equipped " .. def.displayName .. "!", GREEN)
	DataService.Push(player)
end

local function hook(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") or prompt.Name ~= "BuyPrompt" then
		return
	end
	local rodId = prompt:GetAttribute("RodId")
	if type(rodId) ~= "string" then
		return
	end
	prompt.Triggered:Connect(function(player)
		onPrompt(player, rodId)
	end)
end

local function animateMerchant(shop: Instance)
	local npc = shop:FindFirstChild("RodMerchant")
	local hum = npc and npc:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local anim = Instance.new("Animation")
	anim.AnimationId = IDLE_ANIM
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		track.Looped = true
		track:Play()
	end
end

function RodShopService.Init()
	task.spawn(function()
		local shop = Workspace:WaitForChild("RodShop", 30)
		if not shop then
			warn("[RodShop] Workspace.RodShop yok (MapBuilder ile kurulmalı)")
			return
		end
		for _, d in shop:GetDescendants() do
			hook(d)
		end
		shop.DescendantAdded:Connect(hook)
		animateMerchant(shop)
	end)
end

return RodShopService
