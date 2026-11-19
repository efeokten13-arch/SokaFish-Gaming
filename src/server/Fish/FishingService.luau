-- Balık tutma döngüsü (server tarafı). Her adımı server yönetir ve doğrular:
--   CastRequest -> (bekle) -> FishBite -> HookRequest -> FishHooked -> ReelResult -> FishCaught
-- Client sadece "attım", "bastım", "bitti" der; balığı, zamanlamayı ve sonucu server belirler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Fish = require(Config:WaitForChild("Fish"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Cfg = require(Config:WaitForChild("Fishing"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Server = script.Parent.Parent
local FishService = require(Server.Fish.FishService)
local DataService = require(Server.Data.DataService)
local BoatService = require(Server.Boat.BoatService)
local FishingVisuals = require(Server.Fish.FishingVisuals)

local FishingService = {}

type Session = {
	state: string, -- "waiting" | "bite" | "reeling"
	fishId: string,
	spot: BasePart,
	biteAt: number?,
	reelStart: number?,
}

local sessions: { [Player]: Session } = {}
local rng = Random.new()

local function isValidSpot(spot: any): boolean
	local folder = Workspace:FindFirstChild("FishingSpots")
	return folder ~= nil and typeof(spot) == "Instance" and spot:IsA("BasePart") and spot:IsDescendantOf(folder)
end

local function distanceTo(player: Player, spot: BasePart): number
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return math.huge
	end
	return (root.Position - spot.Position).Magnitude
end

local function endSession(player: Player, reason: string)
	sessions[player] = nil
	FishingVisuals.End(player)
	Remotes.Event("FishingEnded"):FireClient(player, reason)
end

local function onCast(player: Player, spot: any)
	-- Eski bir oturum takılı kaldıysa temizle (client zaman aşımına düşmüş olabilir)
	sessions[player] = nil
	if not isValidSpot(spot) then
		Remotes.Event("FishingEnded"):FireClient(player, "far")
		return
	end
	if distanceTo(player, spot) > Cfg.CastRange then
		Remotes.Event("FishingEnded"):FireClient(player, "far")
		return
	end

	local data = DataService.Get(player)
	if not data then
		Remotes.Event("FishingEnded"):FireClient(player, "invalid")
		return
	end
	if #data.storage >= BoatService.GetSlotCount(data.boat) then
		Remotes.Event("FishingEnded"):FireClient(player, "full")
		return
	end

	local spotType = spot:GetAttribute("SpotType") or "Near"
	local ocean = spot:GetAttribute("Ocean") or "Warm"
	local luck = FishService.GetLuck(data.rod, data.bait, spotType)
	local fishId = FishService.Roll(ocean, spotType, luck)
	if not fishId then
		Remotes.Event("FishingEnded"):FireClient(player, "nofish")
		return
	end

	local session: Session = { state = "waiting", fishId = fishId, spot = spot }
	sessions[player] = session
	FishingVisuals.Cast(player, spot, data.rod)

	task.delay(rng:NextNumber(Cfg.WaitMin, Cfg.WaitMax), function()
		if sessions[player] ~= session or session.state ~= "waiting" then
			return
		end
		session.state = "bite"
		session.biteAt = os.clock()
		Remotes.Event("FishBite"):FireClient(player)
		FishingVisuals.Bite(player)

		task.delay(Cfg.BiteWindow + Cfg.LatencyGrace, function()
			if sessions[player] == session and session.state == "bite" then
				endSession(player, "late")
			end
		end)
	end)
end

local function onHook(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	if s.state == "waiting" then
		endSession(player, "early")
		return
	end
	if s.state ~= "bite" then
		return
	end
	if os.clock() - (s.biteAt :: number) > Cfg.BiteWindow + Cfg.LatencyGrace then
		endSession(player, "late")
		return
	end

	s.state = "reeling"
	s.reelStart = os.clock()
	local def = Fish[s.fishId]
	local r = (Rarities :: any)[def.rarity]
	FishingVisuals.Hooked(player)
	Remotes.Event("FishHooked"):FireClient(player, {
		rarity = def.rarity,
		barSpeed = r.barSpeed,
		targetSize = r.targetSize,
	})
end

local function onReel(player: Player, success: any)
	local s = sessions[player]
	if not s or s.state ~= "reeling" then
		return
	end
	if success ~= true then
		endSession(player, "escaped")
		return
	end

	-- Hile kontrolü: bar fiziksel olarak bundan hızlı dolamaz
	local elapsed = os.clock() - (s.reelStart :: number)
	local minTime = (1 - Cfg.StartProgress) / Cfg.ProgressGain * 0.85
	if elapsed < minTime or elapsed > Cfg.MaxReelTime then
		endSession(player, "invalid")
		return
	end
	if distanceTo(player, s.spot) > Cfg.CastRange * 2 then
		endSession(player, "far")
		return
	end

	local data = DataService.Get(player)
	if not data or #data.storage >= BoatService.GetSlotCount(data.boat) then
		endSession(player, "full")
		return
	end

	table.insert(data.storage, s.fishId)
	-- koleksiyon kitabı: hangi türden kaç tane tutuldu
	local caught = (data :: any).caught
	caught[s.fishId] = (caught[s.fishId] or 0) + 1
	sessions[player] = nil
	FishingVisuals.Caught(player, s.fishId)
	Remotes.Event("FishCaught"):FireClient(player, s.fishId)
	DataService.Push(player)
end

function FishingService.Init()
	FishingVisuals.Init()
	Remotes.Event("CastRequest").OnServerEvent:Connect(onCast)
	Remotes.Event("HookRequest").OnServerEvent:Connect(onHook)
	Remotes.Event("ReelResult").OnServerEvent:Connect(onReel)
	Players.PlayerRemoving:Connect(function(p)
		sessions[p] = nil
	end)
end

return FishingService
