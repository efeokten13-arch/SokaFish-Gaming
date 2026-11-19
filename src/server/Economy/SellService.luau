--!strict
-- Main Hall'da balık satışı.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fish = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Fish"))

local SellService = {}

-- TODO: oyuncunun SellCounter'a yakın olduğunu kontrol et
-- TODO: SellRequest remote'unu bağla
function SellService.SellSlot(data: any, slotIndex: number): number
	local fishId = data.storage[slotIndex]
	if not fishId then
		return 0
	end
	local price = Fish[fishId] and Fish[fishId].sell or 0
	table.remove(data.storage, slotIndex)
	data.money += price
	return price
end

function SellService.Init() end

return SellService
