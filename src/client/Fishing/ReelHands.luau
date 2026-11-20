--!nonstrict
-- Tüm oyuncuların oltasında: balık çekilirken (rod "Reeling" özelliği) sol el makara kolunu daire çizerek çevirir.
-- Sol elin makarayı tutması (IKControl) server'da kurulur: server/Fish/FishingVisuals.Equip
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReelHands = {}

function ReelHands.Init()
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		for _, p in Players:GetPlayers() do
			local rod = p.Character and p.Character:FindFirstChild("Rod")
			local grip = rod and rod:FindFirstChild("ReelGrip", true)
			if grip then
				local base = grip:GetAttribute("Base")
				if base then
					if rod:GetAttribute("Reeling") then
						local a = t * 11
						grip.Position = base + Vector3.new(-0.08, math.sin(a) * 0.32, math.cos(a) * 0.32)
					else
						grip.Position = base
					end
				end
			end
		end
	end)
end

return ReelHands
