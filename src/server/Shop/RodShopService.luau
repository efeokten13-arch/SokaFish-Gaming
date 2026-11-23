--!strict
-- Mağaza sunucusu: olta ve tekne alımı. Arayüz (client/UI/ShopUI) "ShopAction" remote'unu çağırır:
--   ShopAction:InvokeServer("Rods", rodId, "buy" | "equip")  -> ok, mesaj, yeniBakiye
--   ShopAction:InvokeServer("Boats", boatId, "buy" | "sail") -> ok, mesaj, yeniBakiye
-- Para ve sahiplik KONTROLÜ burada; client sadece ister. Fiyatlar: Config/Economy, Config/Boats.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Audio = require(Shared:WaitForChild("Config"):WaitForChild("Audio"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DataService = require(script.Parent.Parent.Data.DataService)
local GuideService = require(script.Parent.Parent.Guide.GuideService)
local BoatService = require(script.Parent.Parent.Boat.BoatService)

local RodShopService = {}

local GREEN = Color3.fromRGB(120, 230, 150)
local RED = Color3.fromRGB(255, 140, 120)
local IDLE_ANIM = "rbxassetid://507766666" -- Roblox varsayılan R15 bekleme animasyonu

local lastAction: { [Player]: number } = {}

-- Oltayı al / kuşan. Dönüş: ok, mesaj
local function rodAction(player: Player, rodId: string, action: string): (boolean, string)
	local data = DataService.Get(player) :: any
	local def = (Economy.Rods :: any)[rodId]
	if not data or not def then
		return false, "Unknown rod"
	end
	if table.find(data.ownedRods, rodId) then
		if action == "buy" then
			return false, "You already own this rod"
		end
		if data.rod ~= rodId then
			data.rod = rodId
			DataService.Notify(player, "Equipped " .. def.displayName, GREEN)
			DataService.Push(player)
		end
		GuideService.Event(player, "rod")
		return true, "Equipped " .. def.displayName
	end
	if action ~= "buy" then
		return false, "Buy it first"
	end
	if data.money < def.price then
		DataService.Notify(player, "Not enough money ($" .. def.price .. " needed)", RED)
		return false, "Not enough money"
	end
	data.money -= def.price
	table.insert(data.ownedRods, rodId)
	data.rod = rodId
	DataService.Notify(player, (if def.price > 0 then "Bought & equipped " else "Got your ") .. def.displayName .. "!", GREEN)
	DataService.Push(player)
	GuideService.Event(player, "rod")
	return true, "Bought " .. def.displayName
end

local function onShopAction(player: Player, kind: any, id: any, action: any): (boolean, string, number?)
	if type(kind) ~= "string" or type(id) ~= "string" or type(action) ~= "string" then
		return false, "Bad request", nil
	end
	-- hızlı tekrar (çift tıklama) engeli
	local now = os.clock()
	if now - (lastAction[player] or 0) < 0.25 then
		return false, "Slow down", nil
	end
	lastAction[player] = now
	local ok, msg
	if kind == "Rods" then
		ok, msg = rodAction(player, id, action)
	elseif kind == "Boats" then
		ok, msg = BoatService.Shop(player, id, action)
	else
		return false, "Unknown shop", nil
	end
	local data = DataService.Get(player) :: any
	return ok, msg, data and data.money
end

local function animateMerchant(shop: Instance)
	local npc = shop:FindFirstChild("RodMerchant")
	local hum = npc and npc:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local anim = Instance.new("Animation")
	anim.AnimationId = IDLE_ANIM
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		track.Looped = true
		track:Play()
	end
end


-- Dükkâna girince satıcı oyuncuya döner, "Hi there!" der (ses + balon), sonra kapıya bakmaya döner.
local function greetOnEntry(shop: Instance)
	local npc = shop:FindFirstChild("RodMerchant") :: Model?
	local root = npc and npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = npc and npc:FindFirstChild("Head") :: BasePart?
	if not (npc and root and head) then
		return
	end
	local home = root.CFrame -- kapıya bakan ilk duruş
	local inside: { [Player]: boolean } = {}
	local cooldown: { [Player]: number } = {}
	local turning = 0

	local function say(text: string)
		local gui = Instance.new("BillboardGui")
		gui.Name = "HiBubble"
		gui.Size = UDim2.fromOffset(220, 60)
		gui.StudsOffset = Vector3.new(0, 3.4, 0)
		gui.MaxDistance = 60
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundColor3 = Color3.fromRGB(255, 248, 225)
		t.TextColor3 = Color3.fromRGB(70, 44, 26)
		t.Font = Enum.Font.FredokaOne
		t.TextSize = 26
		t.Text = text
		t.Parent = gui
		Instance.new("UICorner", t).CornerRadius = UDim.new(0, 14)
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(86, 56, 34)
		st.Thickness = 3
		st.Parent = t
		gui.Adornee = head
		gui.Parent = head
		task.delay(3, function()
			gui:Destroy()
		end)
	end

	local function greet(player: Player, pos: Vector3)
		turning += 1
		local my = turning
		local look = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
		if look.Magnitude > 0.1 then
			TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(root.Position, root.Position + look) }):Play()
		end
		local snd = Instance.new("Sound")
		snd.SoundId = Audio.HoHo -- yaşlı balıkçının neşeli sesi (yer tutucu); kendi "Hi" sesin olunca Audio.RodHi ekle
		if (Audio :: any).RodHi then
			snd.SoundId = (Audio :: any).RodHi
		end
		snd.PlaybackSpeed = 1.3
		snd.Volume = 1
		snd.RollOffMaxDistance = 70
		snd.Parent = head
		snd:Play()
		game:GetService("Debris"):AddItem(snd, 4)
		say("Hi there! 🎣")
		task.delay(3.5, function()
			if turning == my then
				TweenService:Create(root, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { CFrame = home }):Play()
			end
		end)
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local origin = home
		for _, p in Players:GetPlayers() do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				local rel = origin:PointToObjectSpace(hrp.Position)
				-- merkez: satıcı; kapı -Z yönünde. Dükkân içi: yanlara +-15, arkaya 9, öne 16, yükseklik +-9
				local isIn = math.abs(rel.X) < 15 and rel.Z > -16 and rel.Z < 9 and math.abs(rel.Y) < 9
				if isIn and not inside[p] and os.clock() - (cooldown[p] or 0) > 20 then
					cooldown[p] = os.clock()
					greet(p, hrp.Position)
				end
				inside[p] = isIn
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		inside[p] = nil
		cooldown[p] = nil
	end)
end

function RodShopService.Init()
	Remotes.Function("ShopAction").OnServerInvoke = onShopAction
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		lastAction[p] = nil
	end)
	task.spawn(function()
		local shop = Workspace:WaitForChild("RodShop", 30)
		if not shop then
			warn("[RodShop] Workspace.RodShop yok (MapBuilder ile kurulmalı)")
			return
		end
		animateMerchant(shop)
		greetOnEntry(shop)
	end)
end

return RodShopService
