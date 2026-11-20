--!strict
-- Bulut konumu: server ve client aynı formülü kullanır (ağdan konum göndermeye gerek yok).
-- Her bulut ReplicatedStorage.Storms içinde bir Configuration; özellikleri:
--   FromX, FromZ, ToX, ToZ: şu anki yolun başı ve sonu
--   T0: yolun başladığı an (workspace:GetServerTimeNow()), Dur: süre (sn)
local Workspace = game:GetService("Workspace")

local StormPath = {}

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t) -- yavaş başla, yavaş dur
end

-- Bulut merkezinin deniz seviyesindeki konumu (Y = 0)
function StormPath.Position(storm: Instance, now: number?): Vector3
	local t = now or Workspace:GetServerTimeNow()
	local fx, fz = storm:GetAttribute("FromX") :: number?, storm:GetAttribute("FromZ") :: number?
	local tx, tz = storm:GetAttribute("ToX") :: number?, storm:GetAttribute("ToZ") :: number?
	local t0, dur = storm:GetAttribute("T0") :: number?, storm:GetAttribute("Dur") :: number?
	if not (fx and fz and tx and tz and t0 and dur) then
		return Vector3.zero
	end
	local a = smooth((t - t0) / math.max(dur, 0.01))
	return Vector3.new(fx + (tx - fx) * a, 0, fz + (tz - fz) * a)
end

return StormPath
