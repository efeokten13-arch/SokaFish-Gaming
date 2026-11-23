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
local GuideService = require(Server.Guide.GuideService)
local StormService = require(Server.Weather.StormService)
local StormsCfg = require(game:GetService("ReplicatedStorage").Shared.Config.Storms)
local SchoolService = require(Server.Fish.SchoolService)
local SchoolsCfg = require(Config:WaitForChild("FishSchools"))
local DataService = require(Server.Data.DataService)
local BoatService = require(Server.Boat.BoatService)
local FishingVisuals = require(Server.Fish.FishingVisuals)
local FishingWater = require(Shared:WaitForChild("FishingWater"))
local Loot = require(Server.Treasure.Loot)
local AltarService = require(Server.Map.AltarService)

local FishingService = {}

type Session = {
	state: string, -- "waiting" | "bite" | "reeling"
	fishId: string,
	spot: BasePart,
	biteAt: number?,
	reelStart: number?,
}

local sessions: { [Player]: Session } = {}
local openCasts: { [Player]: BasePart } = {} -- açık denize atılan oltanın geçici görünmez noktası

local castFolder = Instance.new("Folder")
castFolder.Name = "OpenWaterCasts"

local function clearOpenCast(player: Player)
	local p = openCasts[player]
	if p then
		p:Destroy()
		openCasts[player] = nil
	end
end

-- Açık deniz noktası için geçici spot parçası
local function openWaterSpot(player: Player, pos: Vector3): BasePart
	clearOpenCast(player)
	local p = Instance.new("Part")
	p.Name = player.Name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = Vector3.new(pos.X, 0.3, pos.Z)
	local ocean, spotType = FishingWater.Classify(pos)
	p:SetAttribute("SpotType", spotType)
	p:SetAttribute("Ocean", ocean)
	p.Parent = castFolder
	openCasts[player] = p
	return p
end
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
	clearOpenCast(player)
	FishingVisuals.End(player)
	Remotes.Event("FishingEnded"):FireClient(player, reason)
end

-- Balık çantaya girer (normal çekme sonunda ve kutsamalı atışta doğrudan)
local function landFish(player: Player, s: Session)
	local data = DataService.Get(player)
	if not data or #data.storage >= BoatService.GetSlotCount(data.boat) then
		endSession(player, "full")
		return
	end

	clearOpenCast(player)
	table.insert(data.storage, s.fishId)
	-- koleksiyon kitabı: hangi türden kaç tane tutuldu
	local caught = (data :: any).caught
	caught[s.fishId] = (caught[s.fishId] or 0) + 1
	sessions[player] = nil
	FishingVisuals.Caught(player, s.fishId)
	-- ikinci değer: bu tür ilk kez mi tutuldu (client büyük gösterim yapar)
	Remotes.Event("FishCaught"):FireClient(player, s.fishId, caught[s.fishId] == 1)
	-- nadir balık: düşük ihtimalle inci (Config/Items.FishPearls)
	local def = Fish[s.fishId]
	local pearls = if def then Loot.FishPearls(player, def.rarity) else 0
	if pearls > 0 then
		DataService.Notify(player, "🦪 Lucky! +" .. pearls .. " pearl" .. (if pearls > 1 then "s" else "") .. " from the fish", Color3.fromRGB(205, 150, 255))
	end
	AltarService.OnCaught(player, s.fishId)
	DataService.Push(player)
	GuideService.Event(player, "catch")
end

local function onCast(player: Player, spot: any)
	-- Eski bir oturum takılı kaldıysa temizle (client zaman aşımına düşmüş olabilir)
	sessions[player] = nil
	clearOpenCast(player)
	local hotspot = false
	if typeof(spot) == "Vector3" then
		-- açık deniz: nokta oyuncunun yakınında ve gerçekten su mu?
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or spot ~= spot then
			Remotes.Event("FishingEnded"):FireClient(player, "invalid")
			return
		end
		local flat = Vector2.new(spot.X - root.Position.X, spot.Z - root.Position.Z).Magnitude
		if flat > Cfg.CastRange + 4 then
			Remotes.Event("FishingEnded"):FireClient(player, "far")
			return
		end
		if not FishingWater.IsWater(spot) then
			Remotes.Event("FishingEnded"):FireClient(player, "notwater")
			return
		end
		spot = openWaterSpot(player, spot)
	else
		if not isValidSpot(spot) then
			Remotes.Event("FishingEnded"):FireClient(player, "far")
			return
		end
		if distanceTo(player, spot) > Cfg.CastRange then
			Remotes.Event("FishingEnded"):FireClient(player, "far")
			return
		end
		hotspot = true
	end

	local data = DataService.Get(player)
	if not data then
		Remotes.Event("FishingEnded"):FireClient(player, "invalid")
		return
	end
	-- oltası yoksa (yeni oyuncu): önce Rod Shop
	if not table.find((data :: any).ownedRods, data.rod) then
		DataService.Notify(player, "You need a fishing rod! Get a FREE one at the Rod Shop.", Color3.fromRGB(255, 140, 120))
		Remotes.Event("FishingEnded"):FireClient(player, "invalid")
		return
	end
	-- olta dümen çarkından seçilmemişse atılamaz (client/UI/Hotbar)
	if player:GetAttribute("Equipped") ~= "Rod" then
		Remotes.Event("FishingEnded"):FireClient(player, "norod")
		return
	end
	if #data.storage >= BoatService.GetSlotCount(data.boat) then
		Remotes.Event("FishingEnded"):FireClient(player, "full")
		return
	end

	local spotType = spot:GetAttribute("SpotType") or "Near"
	local ocean = spot:GetAttribute("Ocean") or "Warm"
	local luck = FishService.GetLuck(data.rod, data.bait, spotType) * (if hotspot then Cfg.HotspotLuck else 1)
	-- yağmur bulutunun altı: nadir balık şansı artar
	if StormService.IsUnderStorm(spot.Position) then
		luck *= StormsCfg.Luck
	end
	-- balık sürüsünün içi (martılar + zıplayan balıklar): nadir balık şansı artar
	if SchoolService.IsInSchool(spot.Position) then
		luck *= SchoolsCfg.Luck
	end
	-- tapınak kutsaması: bu atış kesin Golden Fish (Map/AltarService)
	local forced = AltarService.ForcedFish(player)
	local fishId = forced or FishService.Roll(ocean, spotType, luck)
	if not fishId then
		Remotes.Event("FishingEnded"):FireClient(player, "nofish")
		return
	end

	local session: Session = { state = "waiting", fishId = fishId, spot = spot }
	sessions[player] = session
	FishingVisuals.Cast(player, spot, data.rod)

	-- kutsamalı atış: client su altı sahnesini oynar, sahne bitince balık doğrudan yakalanır (BAS / çekme yok)
	local waitTime = rng:NextNumber(Cfg.WaitMin, Cfg.WaitMax)
	if forced then
		waitTime = Cfg.GoldenCastWait
		Remotes.Event("GoldenCast"):FireClient(player, spot.Position)
	end
	task.delay(waitTime, function()
		if sessions[player] ~= session or session.state ~= "waiting" then
			return
		end
		-- kutsamalı atış: tıklama / çekme yok, Golden Fish doğrudan çantaya girer
		if forced then
			landFish(player, session)
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

	landFish(player, s)
end

function FishingService.Init()
	FishingVisuals.Init()
	castFolder.Parent = Workspace
	Remotes.Event("CastRequest").OnServerEvent:Connect(onCast)
	Remotes.Event("HookRequest").OnServerEvent:Connect(onHook)
	Remotes.Event("ReelResult").OnServerEvent:Connect(onReel)
	-- Dümen çarkı: "Rod" = olta ele, nil = eller boş
	Remotes.Event("EquipTool").OnServerEvent:Connect(function(player, tool)
		if tool == "Rod" then
			local data = DataService.Get(player)
			if not data or not table.find((data :: any).ownedRods, data.rod) then
				player:SetAttribute("Equipped", nil)
				DataService.Notify(player, "You need a fishing rod! Get a FREE one at the Rod Shop.", Color3.fromRGB(255, 140, 120))
				return
			end
			player:SetAttribute("Equipped", "Rod")
			FishingVisuals.Equip(player, data.rod)
		else
			player:SetAttribute("Equipped", nil)
			if sessions[player] then
				endSession(player, "stowed")
			end
			FishingVisuals.Unequip(player)
		end
	end)
	local function onCharacter(player: Player)
		player.CharacterAdded:Connect(function(char)
			-- yeniden doğunca olta seçili kaldıysa tekrar ele ver
			if player:GetAttribute("Equipped") == "Rod" then
				char:WaitForChild("RightHand", 5)
				char:WaitForChild("HumanoidRootPart", 5)
				local data = DataService.Get(player)
				if data and player:GetAttribute("Equipped") == "Rod" then
					FishingVisuals.Equip(player, data.rod)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(onCharacter)
	for _, p in Players:GetPlayers() do
		onCharacter(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		sessions[p] = nil
		clearOpenCast(p)
	end)
end

return FishingService
