--!strict
-- Tekne: spawn, depolama slotları, batma.
-- Not: Arkadaşının yaptığı kano scripti şimdilik Studio'da kalabilir.
-- Rojo'ya geçince o script buraya (veya client/Boat'a) taşınır.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Boats = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Boats"))

local BoatService = {}

function BoatService.GetSlotCount(boatId: string): number
	local boat = (Boats :: any)[boatId]
	return boat and boat.slots or 3
end

-- TODO: tekne spawn (Pier.BoatSpawn)
-- TODO: tekne batınca korumalı slot dışındaki balıkları sil

function BoatService.Init() end

return BoatService
