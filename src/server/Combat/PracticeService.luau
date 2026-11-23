--!nonstrict
-- Kale kapısı + atış görevi (kapının arkasındaki "Gunnery Range"). Ayarlar: Config/Practice.luau, harita: MapBuilder/Atoll.Training.
--  * Anahtarı olan (data.hasGateKey) ve görevi bitirmemiş oyuncu kapıya dışarıdan yaklaşınca görev başlar (aynı anda tek oyuncu):
--    client sinematiği oynar (korsan çarkı çevirir, kapı açılır, aksiyon müziği) -> "sail": parlayan halkaya git
--    -> "fire": güvertedeki bir topla ateş et -> Cfg.Hits isabette düşman gemisi batar (anime final) -> "done": 3. ada açıldı.
--  * Kapı kanatları server'da hep kapalıdır; anahtarı olan oyuncu için client yerelde açar (GateCinematics).
--  * Hasar yok, ödül yok, kaybetme yok: sınırsız gülle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Cfg = require(ReplicatedStorage.Shared.Config.Practice)
local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local DataService = require(script.Parent.Parent.Data.DataService)
local CannonService = require(script.Parent.CannonService)
local PracticeShip = require(script.Parent.PracticeShip)

local PracticeService = {}

local frame: CFrame? = nil -- "TrainFrame": yerel -Z = körfezin içi (s), +X = sağ (u)
local ship: Model? = nil
local session: { player: Player, state: string, hits: number, last: number }? = nil
local sinking = false -- final sahnesi sürüyor
local broken = false -- gemi parçalandı (artık hareket ettirilmez)
local cur: CFrame? = nil
local list = 0 -- yatma (radyan)
local sinkY = 0 -- batma (stud)
local clock = 0
local pirate: Model? = nil
local pirateHead: BasePart? = nil
local cheerTrack: AnimationTrack? = nil
local fireSpotPart: BasePart? = nil
local lastNotice: { [Player]: number } = {}

local function loc(s: number, u: number, y: number?): CFrame
	return (frame :: CFrame) * CFrame.new(u, y or 0, -s)
end

-- dünya konumunu (s, u)'ya çevirir
local function su(pos: Vector3): (number, number)
	local lp = (frame :: CFrame):PointToObjectSpace(pos)
	return -lp.Z, lp.X
end

local function berthCF(): CFrame
	return loc(Cfg.Berth.s, Cfg.Berth.u, 0.5)
end

local function send(player: Player, data)
	if player and player.Parent then
		Remotes.Event("PracticeState"):FireClient(player, data)
	end
end

local function notify(player: Player, text: string)
	DataService.Notify(player, text, Color3.fromRGB(255, 214, 120))
end

local function noticeOnce(player: Player, text: string)
	local t = lastNotice[player]
	if t and os.clock() - t < 25 then
		return
	end
	lastNotice[player] = os.clock()
	notify(player, text)
end

local function syncAttributes(player: Player)
	local data = DataService.Get(player)
	if data then
		player:SetAttribute("HasGateKey", data.hasGateKey == true)
		player:SetAttribute("PracticeDone", data.practiceDone == true)
		player:SetAttribute("Island3Unlocked", data.island3Unlocked == true)
	end
end

-- Korsanın konuşma balonu ----------------------------------------------------------------------------------
local function bubble(text: string, seconds: number)
	if not pirateHead then
		return
	end
	local old = pirateHead:FindFirstChild("PirateBubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PirateBubble"
	gui.Size = UDim2.fromOffset(320, 78)
	gui.StudsOffset = Vector3.new(0, 3.8, 0)
	gui.MaxDistance = 90
	gui.Adornee = pirateHead
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(34, 28, 24)
	t.TextColor3 = Color3.fromRGB(255, 226, 150)
	t.Font = Enum.Font.FredokaOne
	t.TextSize = 21
	t.TextWrapped = true
	t.Text = text
	t.Parent = gui
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 16)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(214, 170, 70)
	st.Thickness = 3
	st.Parent = t
	gui.Parent = pirateHead
	task.delay(seconds, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

-- Gemi: kurma, hareket, hasar ------------------------------------------------------------------------------------
local function setRopes(visible: boolean)
	local f = Workspace:FindFirstChild("Atoll") and Workspace.Atoll:FindFirstChild("Training")
	if not f then
		return
	end
	for _, d in f:GetDescendants() do
		if d.Name == "MoorRope" then
			d.Transparency = visible and 0 or 1
		end
	end
end

local function buildShip()
	if ship then
		ship:Destroy()
	end
	local cf = berthCF()
	ship = PracticeShip.Build(cf)
	ship.Parent = Workspace
	cur = cf
	list, sinkY = 0, 0
	broken = false
	setRopes(true)
end

local function fireAnchor(i: number)
	return ship and ship:FindFirstChild("FireAnchor" .. i)
end

local function burn(i: number, fireSize: number, smokeSize: number)
	local a = fireAnchor(i)
	if not a then
		return
	end
	local fire = a:FindFirstChildOfClass("Fire")
	local smoke = a:FindFirstChildOfClass("Smoke")
	if fire and fireSize > 0 then
		fire.Enabled = true
		fire.Size = fireSize
	end
	if smoke then
		smoke.Enabled = true
		smoke.Size = smokeSize
	end
end

-- n = o ana kadarki isabet (1 .. Hits-1). Son isabet finaldir.
local function applyDamage(n: number)
	local k = n / math.max(Cfg.Hits - 1, 1) -- 0..1 arası hasar oranı
	burn(1, 8 + 8 * k, 12 + 8 * k)
	if k >= 0.5 then
		burn(2, 10 + 6 * k, 14 + 6 * k)
	end
	if k >= 0.99 then
		burn(3, 14, 18)
		sinkY = -1.2
		local sail = ship and ship:FindFirstChild("Sail")
		if sail then
			sail.Transparency = 1
			for _, g in sail:GetChildren() do
				if g:IsA("SurfaceGui") then
					g.Enabled = false
				end
			end
		end
	end
	list = math.rad(4 + 7 * k)
end

local function hitFx(pos: Vector3)
	CannonService.Sfx(pos, Audio.ShipHit, 0.7, 0.95 + math.random() * 0.15, 4)
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(3, 3, 3)
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 190, 80)
	flash.Position = pos
	flash.Parent = Workspace
	local l = Instance.new("PointLight")
	l.Color = flash.Color
	l.Range = 24
	l.Brightness = 4
	l.Parent = flash
	game:GetService("TweenService"):Create(flash, TweenInfo.new(0.35), { Size = Vector3.new(9, 9, 9), Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.5)
	for _ = 1, 7 do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.4 + math.random() * 0.5, 0.3, 1.4 + math.random() * 1.6)
		p.Color = Color3.fromRGB(140, 98, 60)
		p.Material = Enum.Material.WoodPlanks
		p.CanCollide = false
		p.CanQuery = false
		p.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.AssemblyLinearVelocity = Vector3.new(math.random(-30, 30), math.random(20, 45), math.random(-30, 30))
		p.AssemblyAngularVelocity = Vector3.new(math.random(-9, 9), math.random(-9, 9), math.random(-9, 9))
		p.Parent = Workspace
		Debris:AddItem(p, 2.5)
	end
end

local function cheer(seconds: number)
	if cheerTrack then
		cheerTrack:Play(0.2)
		task.delay(seconds, function()
			cheerTrack:Stop(0.3)
		end)
	end
end

local function endSession(reason: string?)
	local s = session
	if not s then
		return
	end
	session = nil
	send(s.player, { kind = "stop", reason = reason })
	Remotes.Event("GuideTarget"):FireClient(s.player, nil)
	if not sinking then
		buildShip()
	end
end

-- Final: gemi batar --------------------------------------------------------------------------------------------
local function breakup()
	if not ship then
		return
	end
	broken = true
	setRopes(false)
	local center = ship:GetPivot().Position + Vector3.new(0, 6, 0)
	for _, p in ship:GetDescendants() do
		if p:IsA("BasePart") then
			local away = p.Position - center
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(math.random() - 0.5, 0.2, math.random() - 0.5).Unit
			local heavy = p.Name:match("^Hull") ~= nil
			p.Anchored = false
			p.CanCollide = false
			local up = heavy and math.random(25, 45) or math.random(60, 120)
			local out = heavy and math.random(10, 26) or math.random(30, 75)
			p.AssemblyLinearVelocity = Vector3.new(away.X, 0, away.Z) * out + Vector3.new(0, up, 0)
			p.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
			pcall(function()
				p:SetNetworkOwner(nil)
			end)
		end
	end
	task.delay(Cfg.Finale.WreckLife - Cfg.Finale.Main, function()
		local wreck = ship
		if wreck then
			for _, p in wreck:GetDescendants() do
				if p:IsA("BasePart") then
					game:GetService("TweenService"):Create(p, TweenInfo.new(1.2), { Transparency = 1 }):Play()
				end
			end
		end
	end)
end

local function finale(player: Player)
	sinking = true
	local center = (ship :: Model):GetPivot()
	local data = DataService.Get(player)
	if data then
		data.practiceDone = true
		data.island3Unlocked = true
		DataService.Push(player)
	end
	local F = Cfg.Finale
	local now = Workspace:GetServerTimeNow()
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if p == player or (root and (root.Position - center.Position).Magnitude < Cfg.FarDistance) then
			Remotes.Event("PracticeFinale"):FireClient(p, { cf = center, trainee = p == player, t0 = now })
		end
	end
	task.delay(F.Main, breakup)
	task.delay(F.Main + 2.2, function()
		bubble(Cfg.DoneText, 5)
		cheer(2.8)
	end)
	task.delay(F.Total, function()
		syncAttributes(player)
		if session and session.player == player then
			send(player, { kind = "done" })
			session = nil
		end
	end)
	task.delay(F.Rebuild, function()
		sinking = false
		buildShip()
	end)
end

local function onHit(player: Player, hitInst: Instance, pos: Vector3): boolean
	if not ship or not hitInst:IsDescendantOf(ship) then
		return false
	end
	hitFx(pos)
	local s = session
	if sinking or broken or not s or s.player ~= player or s.state == "intro" then
		return true
	end
	s.last = os.clock()
	s.hits += 1
	if s.state == "sail" then
		s.state = "fire"
		Remotes.Event("GuideTarget"):FireClient(player, nil)
	end
	if s.hits >= Cfg.Hits then
		send(player, { kind = "hit", hits = s.hits, need = Cfg.Hits, last = true })
		finale(player)
		return true
	end
	applyDamage(s.hits)
	local text = s.hits == Cfg.Hits - 1 and Cfg.LastHitText or Cfg.HitText
	send(player, { kind = "hit", hits = s.hits, need = Cfg.Hits, text = text })
	bubble(text, 3)
	return true
end

local function hasCannonBoat(player: Player): boolean
	local boats = Workspace:FindFirstChild("Boats")
	for _, b in boats and boats:GetChildren() or {} do
		if b:GetAttribute("OwnerUserId") == player.UserId and b:GetAttribute("HasCannons") then
			return true
		end
	end
	return false
end

-- Görevi başlat. withIntro = kapı sinematiği oynasın mı (dışarıdan geldiyse evet)
local function begin(player: Player, withIntro: boolean)
	if sinking then
		noticeOnce(player, "Wait a moment, the old ship is still going down!")
		return
	end
	if session and session.player ~= player and session.player.Parent then
		noticeOnce(player, session.player.DisplayName .. " " .. Cfg.BusyText)
		return
	end
	if session then
		return
	end
	if not hasCannonBoat(player) then
		noticeOnce(player, "Bring your Warship! You need cannons for this.")
		return
	end
	buildShip()
	local s = { player = player, state = withIntro and "intro" or "sail", hits = 0, last = os.clock() }
	session = s
	local function toSail()
		if session ~= s then
			return
		end
		s.state = "sail"
		s.last = os.clock()
		send(player, { kind = "sail", text = Cfg.SailText, need = Cfg.Hits })
		if fireSpotPart then
			Remotes.Event("GuideTarget"):FireClient(player, fireSpotPart, "Firing spot")
		end
	end
	if withIntro then
		send(player, { kind = "intro", t0 = Workspace:GetServerTimeNow() })
		local I = Cfg.Intro
		task.delay(0.4, function()
			bubble(Cfg.IntroText1, I.ToPirate + I.Winch)
		end)
		task.delay(I.ToPirate, function()
			cheer(I.Winch)
		end)
		task.delay(I.ToPirate + I.Winch + I.Doors, function()
			bubble(Cfg.IntroText2, I.Talk + 1)
		end)
		task.delay(I.Total, toSail)
	else
		toSail()
	end
end

-- Kapıya yaklaşanları izle (0.5 sn'de bir)
local function watch()
	local s = session
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local data = DataService.Get(p)
		if root and data then
			local ps, pu = su(root.Position)
			local outside = ps < -5 and ps > -Cfg.GateTrigger and math.abs(pu) < 220
			local inBay = ps > 20 and ps < 340 and math.abs(pu) < 260
			if outside and ps > -80 and not data.hasGateKey then
				noticeOnce(p, Cfg.NoKeyText)
			elseif data.hasGateKey and not data.practiceDone and not (s and s.player == p) then
				if outside then
					begin(p, true)
				elseif inBay then
					begin(p, false)
				end
			end
			if s and s.player == p and s.state == "sail" and fireSpotPart then
				local d = Vector3.new(root.Position.X - fireSpotPart.Position.X, 0, root.Position.Z - fireSpotPart.Position.Z).Magnitude
				if d < Cfg.FireSpot.r then
					s.state = "fire"
					s.last = os.clock()
					Remotes.Event("GuideTarget"):FireClient(p, nil)
					send(p, { kind = "fire", text = Cfg.FireText, textTouch = Cfg.FireTextTouch, need = Cfg.Hits })
					bubble("Fire!", 3)
				end
			end
		end
	end
	if s and not sinking and s.state ~= "intro" and os.clock() - s.last > Cfg.IdleTimeout then
		endSession("timeout")
	end
end

-- Geliştirme (sadece Studio, Command Bar'dan Play sırasında):
--   game.ServerStorage.DevTraining:Fire()              -> anahtar ver, görevi sıfırla, Warship'i kapının dışına getir (tam akış testi)
--   game.ServerStorage.DevTraining:Fire(nil, "key")    -> sadece anahtar ver
--   game.ServerStorage.DevTraining:Fire(nil, "nokey")  -> anahtarı al
--   game.ServerStorage.DevTraining:Fire(nil, "reset")  -> görevi / 3. ada kilidini sıfırla
local function setupDev()
	local ev = ServerStorage:FindFirstChild("DevTraining") or Instance.new("BindableEvent")
	ev.Name = "DevTraining"
	ev.Parent = ServerStorage
	ev.Event:Connect(function(name, what)
		local player = (name and Players:FindFirstChild(name)) or Players:GetPlayers()[1]
		local data = player and DataService.Wait(player)
		if not data then
			return
		end
		if what == "key" then
			data.hasGateKey = true
		elseif what == "nokey" then
			data.hasGateKey = false
		elseif what == "reset" then
			data.practiceDone = false
			data.island3Unlocked = false
		else
			data.hasGateKey = true
			data.practiceDone = false
			data.island3Unlocked = false
			if session and session.player == player then
				endSession("dev")
			end
			if not table.find(data.ownedBoats, "Warship") then
				table.insert(data.ownedBoats, "Warship")
			end
			data.boat = "Warship"
			DataService.Push(player)
			local boatCF = loc(Cfg.PlayerStart.s, Cfg.PlayerStart.u, 0.65) * CFrame.Angles(0, 0, 0)
			local BoatService = require(script.Parent.Parent.Boat.BoatService)
			BoatService.BringTo(player, boatCF)
			task.wait(0.6)
			local boats = Workspace:FindFirstChild("Boats")
			for _, b in boats and boats:GetChildren() or {} do
				if b:GetAttribute("OwnerUserId") == player.UserId then
					local seat = b:FindFirstChildWhichIsA("VehicleSeat", true)
					local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if seat and hum then
						player.Character:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
						task.wait(0.2)
						seat:Sit(hum)
					end
				end
			end
			print("[Practice] anahtar verildi, gemi kapının dışına getirildi")
		end
		syncAttributes(player)
		DataService.Push(player)
		print("[Practice] dev:", what or "full", "key=", data.hasGateKey, "done=", data.practiceDone)
	end)
end

function PracticeService.Init()
	local training = Workspace:FindFirstChild("Atoll") and Workspace.Atoll:FindFirstChild("Training")
	local fr = training and training:FindFirstChild("TrainFrame")
	if not fr then
		warn("[Practice] Training haritası yok (Atoll 'training' aşamasını çalıştır)")
		return
	end
	frame = fr.CFrame
	fireSpotPart = training:FindFirstChild("FireSpot")
	CannonService.SetHitHandler(onHit)
	buildShip()

	-- korsan
	local npcs = Workspace:FindFirstChild("NPCs")
	pirate = npcs and npcs:FindFirstChild("Pirate Tutor")
	pirateHead = pirate and pirate:FindFirstChild("Head")
	if pirate then
		local hum = pirate:FindFirstChildWhichIsA("Humanoid") or pirate:FindFirstChildWhichIsA("AnimationController")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			local a = Instance.new("Animation")
			a.AnimationId = "rbxassetid://507770677" -- sevinç
			local ok, tr = pcall(function()
				return animator:LoadAnimation(a)
			end)
			if ok then
				cheerTrack = tr
				tr.Priority = Enum.AnimationPriority.Action
			end
		end
	end
	-- eski "korsanla konuş" düğmesi artık yok (görev kapıya gelince kendiliğinden başlar)
	local point = training:FindFirstChild("PirateTalkPoint")
	local oldPrompt = point and point:FindFirstChild("TalkPrompt")
	if oldPrompt then
		oldPrompt:Destroy()
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if ship and cur and not broken then
			local bob = math.sin(clock * 1.7) * 0.22
			ship:PivotTo(cur * CFrame.new(0, sinkY + bob, 0) * CFrame.Angles(math.sin(clock * 1.3) * 0.015, 0, list))
		end
		acc += dt
		if acc >= 0.5 then
			acc = 0
			watch()
		end
	end)
	local function added(p: Player)
		task.spawn(function()
			if DataService.Wait(p) then
				syncAttributes(p)
			end
		end)
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		added(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastNotice[p] = nil
		if session and session.player == p then
			endSession("left")
		end
	end)
	if RunService:IsStudio() then
		setupDev()
	end
end

return PracticeService
