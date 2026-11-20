-- Sadece Studio'da çalışır: test için oyuncuya para vermek.
-- Studio'da (Server) command bar'dan:
--   game.ServerStorage.DevGiveMoney:Fire("KullanıcıAdı", 100000)
-- Canlı oyunda hiçbir şey yapmaz.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local DataService = require(script.Parent.Parent.Data.DataService)

local ev = ServerStorage:FindFirstChild("DevGiveMoney") or Instance.new("BindableEvent")
ev.Name = "DevGiveMoney"
ev.Parent = ServerStorage

ev.Event:Connect(function(name, amount)
	local player = Players:FindFirstChild(name) or Players:GetPlayers()[1]
	local data = player and DataService.Wait(player)
	if data and type(amount) == "number" then
		data.money += amount
		DataService.Push(player)
		DataService.Notify(player, "[Dev] +$" .. amount, Color3.fromRGB(255, 214, 80))
		print("[DevAdmin]", player.Name, "money =", data.money)
	end
end)
