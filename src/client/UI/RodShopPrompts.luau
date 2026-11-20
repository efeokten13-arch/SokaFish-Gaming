--!strict
-- Dükkân düğmelerinin yazısını bu oyuncuya göre ayarlar (olta dükkânı + iskeledeki tekneler).
--   Olta: alınmamışsa "Buy $X" (basılı tut), alınmışsa "Owned · Equip", kuşanılıysa "Owned ✓ Equipped".
--   Tekne: alınmamışsa "Buy $X" (basılı tut), alınmışsa "Owned · Sail".
-- Server zaten ikinci kez para almaz; bu sadece oyuncu ne olduğunu görsün diye.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Economy = require(Config:WaitForChild("Economy"))
local Boats = require(Config:WaitForChild("Boats"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local RodShopPrompts = {}

local BUY_HOLD = 0.8

local ownedRods: { string } = { Economy.StarterRod }
local ownedBoats: { string } = {}
local equipped = Economy.StarterRod

local function money(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local r, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = r
		if k == 0 then
			break
		end
	end
	return "$" .. s
end

local function refresh(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	if prompt.Name == "BuyPrompt" then
		local id = prompt:GetAttribute("RodId")
		local def = type(id) == "string" and (Economy.Rods :: any)[id]
		if not def then
			return
		end
		if id == equipped then
			prompt.ActionText = "Owned ✓ Equipped"
			prompt.HoldDuration = 0
		elseif table.find(ownedRods, id :: string) then
			prompt.ActionText = "Owned · Equip"
			prompt.HoldDuration = 0
		else
			prompt.ActionText = if def.price > 0 then "Buy " .. money(def.price) else "Take FREE"
			prompt.HoldDuration = if def.price > 0 then BUY_HOLD else 0
		end
	elseif prompt.Name == "BoatPrompt" then
		local id = prompt:GetAttribute("BoatId")
		local info = type(id) == "string" and (Boats :: any)[id]
		if not info then
			return
		end
		if table.find(ownedBoats, id :: string) then
			prompt.ActionText = "Owned · Sail"
			prompt.HoldDuration = 0.3
		else
			prompt.ActionText = "Buy " .. money(info.price)
			prompt.HoldDuration = BUY_HOLD
		end
	end
end

local function refreshAll()
	for _, d in Workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and (d.Name == "BuyPrompt" or d.Name == "BoatPrompt") then
			refresh(d)
		end
	end
end

function RodShopPrompts.Init()
	Remotes.Event("DataUpdated").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if type(data.ownedRods) == "table" then
			ownedRods = data.ownedRods
		end
		if type(data.ownedBoats) == "table" then
			ownedBoats = data.ownedBoats
		end
		equipped = data.rod or equipped
		refreshAll()
	end)
	-- StreamingEnabled: dükkân / iskele sonradan yüklenebilir
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			refresh(d)
		end
	end)
	refreshAll()
end

return RodShopPrompts
