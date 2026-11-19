--!strict
-- Adadaki kulübelerin önündeki koleksiyon kitabı: basınca oyuncunun koleksiyon ekranı açılır.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local DataService = require(script.Parent.Parent.Data.DataService)

local BookService = {}

function BookService.Init()
	task.spawn(function()
		local folder = Workspace:WaitForChild("PrivateIslands", 60)
		if not folder then
			return
		end
		for _, island in folder:GetChildren() do
			local lectern = island:WaitForChild("Lectern", 5)
			local bk = lectern and lectern:FindFirstChild("Book") :: BasePart?
			if bk then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Open"
				prompt.ObjectText = "Collection Book"
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt.Parent = bk
				prompt.Triggered:Connect(function(player)
					local payload = DataService.Payload(player)
					if payload then
						Remotes.Event("OpenCollection"):FireClient(player, payload.caught)
					end
				end)
			end
		end
	end)
end

return BookService
