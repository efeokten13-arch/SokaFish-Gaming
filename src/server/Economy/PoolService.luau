--!strict
-- Adadaki balık havuzu: saatlik gelir + offline kazanç.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Fish = require(Config:WaitForChild("Fish"))
local Economy = require(Config:WaitForChild("Economy"))

local PoolService = {}

function PoolService.IncomePerHour(data: any): number
	local total = 0
	for _, fishId in data.pool do
		total += Fish[fishId] and Fish[fishId].perHour or 0
	end
	return total
end

-- Oyuncu girişte çağrılır: offline geçen süre kadar gelir ver (üst sınırlı)
function PoolService.OfflineEarnings(data: any): number
	local hours = math.min((os.time() - data.lastOnline) / 3600, Economy.OfflineEarningsCapHours)
	return math.floor(PoolService.IncomePerHour(data) * hours)
end

-- TODO: PoolRequest remote'u (storage -> pool, kapasite kontrolü)
-- TODO: oyundayken her X saniyede bir gelir ekle

function PoolService.Init() end

return PoolService
