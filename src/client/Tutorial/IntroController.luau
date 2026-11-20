--!nonstrict
-- Giriş öğreticisi: yeni oyuncu girince kamera yaşlı balıkçıya (Old Finn) yaklaşır, çocuklara uygun kısa bir sohbet başlar.
--   1) "Ho ho! Are you lost?"  -> cevap butonları
--   2) Ada sahiplenme ("Yes, please!" -> server IntroAction "claim")
--   3) Uzaktan sinematik: Rod Shop, Boat Shop, Fish Market (etrafında döner)
--   4) Bitiş -> server IntroAction "done" -> ada / harita / ışınlanma butonları açılır
-- Öğretici bitene kadar: karakter yürümez, diğer arayüzler gizli, IslandButton / MainButton / MapButton kapalı.
-- Metinler aşağıdaki SCRIPT tablosunda; sırayı ve yazıları oradan değiştirin.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Audio = require(Shared:WaitForChild("Config"):WaitForChild("Audio"))

local IntroController = {}

local player = Players.LocalPlayer
local NAME = "Old Finn"
local LOCKED = { "IslandButton", "MainButton", "MapButton" } -- öğretici bitene kadar gizli

local running = false
local introDone = nil -- nil = henüz bilinmiyor

---------------------------------------------------------------------------------------------
-- Butonları kilitle / aç
---------------------------------------------------------------------------------------------
local function applyLocks()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local show = introDone == true
	for _, d in pg:GetDescendants() do
		if d:IsA("GuiButton") and table.find(LOCKED, d.Name) then
			d.Visible = show
		end
	end
end

---------------------------------------------------------------------------------------------
-- Kamera çekimleri: her biri t (çekimin başından beri sn) -> CFrame
---------------------------------------------------------------------------------------------
local function find(path)
	local inst = Workspace
	for _, name in path do
		inst = inst and inst:FindFirstChild(name)
	end
	return inst
end

local function fisherHead()
	return find({ "OldFisherman", "Head" })
end

local SHOTS = {}

-- Yaşlı balıkçının yüzüne yakın çekim (hafif nefes alır gibi sallanır)
SHOTS.fisher = function(t)
	local head = fisherHead()
	if not head then
		return nil
	end
	local npc = head.Parent
	local torso = npc:FindFirstChild("Torso") or head
	local face = -torso.CFrame.LookVector -- yüzü -Z'ye bakar (sakal -Z tarafında)
	local look = torso.CFrame.LookVector
	local front = Vector3.new(look.X, 0, look.Z).Unit
	local side = front:Cross(Vector3.yAxis)
	local eye = head.Position + front * 7.5 + side * 2.2 + Vector3.new(0, 1 + math.sin(t * 0.8) * 0.15, 0)
	return CFrame.lookAt(eye, head.Position + Vector3.new(0, -0.3, 0))
end

-- Uzaktan ana çekim: adanın üstünden plazaya
SHOTS.overview = function(t)
	local head = fisherHead()
	local c = head and head.Position or Vector3.new(-20, 6, 18)
	local a = 0.6 + t * 0.03
	return CFrame.lookAt(c + Vector3.new(math.cos(a) * 150, 95, math.sin(a) * 150), c)
end

-- Rod Shop: tabelaya önden uzaktan, yavaşça yaklaşır
SHOTS.rodshop = function(t)
	local sign = find({ "RodShop", "RoofSign" })
	if not sign then
		return nil
	end
	local out = Vector3.new(sign.CFrame.LookVector.X, 0, sign.CFrame.LookVector.Z).Unit
	local dist = math.max(26, 46 - t * 2.2)
	local side = out:Cross(Vector3.yAxis)
	return CFrame.lookAt(sign.Position + out * dist + side * 8 + Vector3.new(0, 4, 0), sign.Position - Vector3.new(0, 7, 0))
end

-- Boat Shop: kayıkhane ve iskele
SHOTS.boatshop = function(t)
	local sign = find({ "BoatHouse", "Sign" })
	if not sign then
		return nil
	end
	local target = sign.Position - Vector3.new(0, 5, 0)
	local a = math.rad(118) - t * 0.03
	return CFrame.lookAt(target + Vector3.new(math.cos(a) * 30, 11, math.sin(a) * 30), target)
end

-- Fish Market: etrafında yavaşça döner
SHOTS.market = function(t)
	local plat = find({ "FishMarket", "Platform" })
	if not plat then
		return nil
	end
	local c = plat.Position + Vector3.new(0, 4, 0)
	local a = math.rad(70) + t * 0.32
	return CFrame.lookAt(c + Vector3.new(math.cos(a) * 52, 24, math.sin(a) * 52), c)
end

---------------------------------------------------------------------------------------------
-- Sohbet metni. choices: { {yazı, sonraki adım} }; action: adım başlarken yapılacak iş
---------------------------------------------------------------------------------------------
local SCRIPT = {
	start = {
		shot = "fisher",
		text = "Ho ho! Ahoy there, little sailor! Are you lost?",
		choices = { { "Yes... where am I?", "where" }, { "Who are you?", "who" } },
	},
	who = {
		shot = "fisher",
		text = "Ho ho! I'm Old Finn, the oldest fisherman on all these islands!",
		choices = { { "Nice to meet you! Where am I?", "where" } },
	},
	where = {
		shot = "overview",
		text = "Ho ho! This is Sunny Harbor, the happiest fishing island in the whole sea!",
		choices = { { "Wow! Can I go fishing too?", "home" } },
	},
	home = {
		shot = "fisher",
		text = "Ho ho! Of course you can! Every fisher needs a home. Would you like an island of your very own?",
		choices = { { "Yes, please!", "claim" } },
	},
	claim = {
		shot = "fisher",
		action = "claim",
		text = "Ho ho! Hooray! Island {N} is all yours now!",
		choices = { { "Thank you, Finn!", "rod" } },
	},
	rod = {
		shot = "rodshop",
		text = "Ho ho! No fishing rod? Get one right here at the Rod Shop, kiddo! Shiny new rods catch rarer fish!",
		choices = { { "Cool!", "boat" } },
	},
	boat = {
		shot = "boatshop",
		text = "Ho ho! You'll need a boat to sail to your island. The little rowboat costs just $1!",
		choices = { { "Got it!", "market" } },
	},
	market = {
		shot = "market",
		text = "Ho ho! When your boat is full of fish, bring them here to the Fish Market and sell them for shiny coins!",
		choices = { { "Okay!", "bye" } },
	},
	bye = {
		shot = "fisher",
		text = "Ho ho! That's everything, little sailor. Now go catch some fish! Good luck!",
		choices = { { "Let's go!", nil } },
	},
}

---------------------------------------------------------------------------------------------
-- Arayüz
---------------------------------------------------------------------------------------------
local gui, panel, nameTag, textLabel, choiceRow, bars = nil, nil, nil, nil, nil, {}

local function buildUI()
	gui = Instance.new("ScreenGui")
	gui.Name = "IntroGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- sinema bantları
	for i, y in { 0, 1 } do
		local b = Instance.new("Frame")
		b.Name = "Bar" .. i
		b.AnchorPoint = Vector2.new(0, y)
		b.Position = UDim2.fromScale(0, y)
		b.Size = UDim2.new(1, 0, 0, 0)
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.Parent = gui
		bars[i] = b
	end

	panel = Instance.new("Frame")
	panel.Name = "Dialog"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.new(0.9, 0, 0, 170)
	panel.BackgroundColor3 = Color3.fromRGB(255, 246, 225)
	panel.BackgroundTransparency = 0.04
	panel.Parent = gui
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(760, 220)
	size.Parent = panel
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 18)
	c.Parent = panel
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(120, 82, 50)
	st.Thickness = 4
	st.Parent = panel

	nameTag = Instance.new("TextLabel")
	nameTag.AnchorPoint = Vector2.new(0, 0.5)
	nameTag.Position = UDim2.new(0, 22, 0, 0)
	nameTag.Size = UDim2.fromOffset(150, 38)
	nameTag.BackgroundColor3 = Color3.fromRGB(46, 110, 150)
	nameTag.Font = Enum.Font.FredokaOne
	nameTag.TextSize = 22
	nameTag.TextColor3 = Color3.new(1, 1, 1)
	nameTag.Text = "🎣 " .. NAME
	nameTag.Parent = panel
	local nc = Instance.new("UICorner")
	nc.CornerRadius = UDim.new(0, 12)
	nc.Parent = nameTag

	textLabel = Instance.new("TextLabel")
	textLabel.Position = UDim2.new(0, 24, 0, 28)
	textLabel.Size = UDim2.new(1, -48, 0, 70)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextSize = 24
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Top
	textLabel.TextColor3 = Color3.fromRGB(60, 40, 25)
	textLabel.Parent = panel

	choiceRow = Instance.new("Frame")
	choiceRow.AnchorPoint = Vector2.new(1, 1)
	choiceRow.Position = UDim2.new(1, -18, 1, -16)
	choiceRow.Size = UDim2.new(1, -36, 0, 48)
	choiceRow.BackgroundTransparency = 1
	choiceRow.Parent = panel
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Padding = UDim.new(0, 12)
	list.Parent = choiceRow
end

local function setBars(on)
	for _, b in bars do
		TweenService:Create(b, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, on and 0.09 or 0, 0) }):Play()
	end
end

local function sound(id, volume, pitch)
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.7
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(8, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Satırı daktilo gibi yaz; ekrana dokunulursa hemen tamamla
local function typeText(text)
	local skip = false
	local conn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.Space then
			skip = true
		end
	end)
	textLabel.Text = text
	textLabel.MaxVisibleGraphemes = 0
	local n = utf8.len(text) or #text
	for i = 1, n do
		if skip then
			break
		end
		textLabel.MaxVisibleGraphemes = i
		task.wait(0.028)
	end
	textLabel.MaxVisibleGraphemes = -1
	conn:Disconnect()
end

-- Cevap butonlarını göster, birine basılınca onun sonraki adımını döndür
local function askChoices(choices)
	for _, c in choiceRow:GetChildren() do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	local picked = nil
	local ev = Instance.new("BindableEvent")
	for i, ch in choices do
		local b = Instance.new("TextButton")
		b.Name = "Choice" .. i
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.fromOffset(0, 46)
		b.BackgroundColor3 = i == 1 and Color3.fromRGB(70, 170, 90) or Color3.fromRGB(46, 110, 150)
		b.Font = Enum.Font.FredokaOne
		b.TextSize = 22
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = ch[1]
		b.AutoButtonColor = true
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 18)
		pad.PaddingRight = UDim.new(0, 18)
		pad.Parent = b
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 14)
		cc.Parent = b
		local s = Instance.new("UIStroke")
		s.Color = Color3.new(1, 1, 1)
		s.Thickness = 2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = b
		-- küçük zıplama
		local scale = Instance.new("UIScale")
		scale.Scale = 0.6
		scale.Parent = b
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		b.Parent = choiceRow
		b.Activated:Connect(function()
			if picked == nil then
				picked = ch
				ev:Fire()
			end
		end)
	end
	ev.Event:Wait()
	ev:Destroy()
	sound(Audio.Click, 0.5)
	for _, c in choiceRow:GetChildren() do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	return picked[2]
end

---------------------------------------------------------------------------------------------
-- Kamera sürücü
---------------------------------------------------------------------------------------------
local camConn
local shotName, shotStart = nil, 0
local fromCF, blendStart, BLEND = nil, 0, 1.8

local function setShot(name)
	local cam = Workspace.CurrentCamera
	fromCF = cam.CFrame
	blendStart = os.clock()
	shotName = name
	shotStart = os.clock()
end

local function startCamera()
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	camConn = RunService.RenderStepped:Connect(function()
		local fn = shotName and SHOTS[shotName]
		local target = fn and fn(os.clock() - shotStart)
		if not target then
			return
		end
		local a = math.clamp((os.clock() - blendStart) / BLEND, 0, 1)
		a = a * a * (3 - 2 * a)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = fromCF and fromCF:Lerp(target, a) or target
	end)
end

local function stopCamera()
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	local cam = Workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local back = CFrame.lookAt(root.Position - root.CFrame.LookVector * 12 + Vector3.new(0, 5, 0), root.Position + Vector3.new(0, 1.5, 0))
		local tw = TweenService:Create(cam, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = back })
		tw:Play()
		tw.Completed:Wait()
	end
	cam.CameraType = Enum.CameraType.Custom
end

---------------------------------------------------------------------------------------------
-- Karakteri dondur, diğer arayüzleri gizle
---------------------------------------------------------------------------------------------
local hidden = {}
local frozen

local function freeze(on)
	local ps = player:FindFirstChild("PlayerScripts")
	local pm = ps and ps:FindFirstChild("PlayerModule")
	if pm then
		local ok, mod = pcall(require, pm)
		local ctl = ok and mod and mod.GetControls and mod:GetControls()
		if ctl then
			if on then
				ctl:Disable()
			else
				ctl:Enable()
			end
		end
	end
	player:SetAttribute("InCutscene", on)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if on and hum then
		frozen = { hum = hum, walk = hum.WalkSpeed, jump = hum.JumpPower, jh = hum.JumpHeight }
		hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = 0, 0, 0
	elseif not on and frozen then
		if frozen.hum.Parent then
			frozen.hum.WalkSpeed, frozen.hum.JumpPower, frozen.hum.JumpHeight = 16, frozen.jump, frozen.jh
		end
		frozen = nil
	end
	-- kendi karakterin ve yön oku ışığı çekimlere girmesin
	if player.Character then
		for _, d in player.Character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = on and 1 or 0
			end
		end
	end
	local beacon = Workspace:FindFirstChild("GuideBeacon")
	if beacon then
		beacon.LocalTransparencyModifier = on and 1 or 0
	end
	local pg = player:FindFirstChild("PlayerGui")
	if on then
		hidden = {}
		for _, g in pg and pg:GetChildren() or {} do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end
	else
		for _, g in hidden do
			if g.Parent then
				g.Enabled = true
			end
		end
		hidden = {}
	end
end

-- Karakteri balıkçının önüne getir (öğretici sırasında yanında dursun)
local function placeNearFisher()
	local head = fisherHead()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not head or not root then
		return
	end
	local torso = head.Parent:FindFirstChild("Torso") or head
	local look = torso.CFrame.LookVector
	local front = Vector3.new(look.X, 0, look.Z).Unit
	local pos = Vector3.new(head.Position.X, root.Position.Y, head.Position.Z) + front * 6
	if (root.Position - pos).Magnitude > 40 then
		return -- uzaktaysa (ör. eski oyuncu balıkçıya sonradan konuşuyorsa) yerinden oynatma
	end
	player.Character:PivotTo(CFrame.lookAt(pos, Vector3.new(head.Position.X, pos.Y, head.Position.Z)))
end

---------------------------------------------------------------------------------------------
-- Akış
---------------------------------------------------------------------------------------------
local function run()
	if running then
		return
	end
	running = true
	gui.Enabled = true
	panel.Visible = false
	freeze(true)
	placeNearFisher()
	startCamera()
	setBars(true)
	-- açılış: ada üstünden balıkçıya iniş
	setShot("overview")
	BLEND = 1.2
	task.wait(1.6)
	BLEND = 1.8

	local step = "start"
	local islandN = "?"
	while step do
		local node = SCRIPT[step]
		if not node then
			break
		end
		if node.shot ~= shotName then
			setShot(node.shot)
			if node.shot ~= "fisher" then
				panel.Visible = false
				task.wait(1.3) -- uzaktaki yere uçuş
			end
		end
		if node.action == "claim" then
			local ok, n = pcall(function()
				return Remotes.Function("IntroAction"):InvokeServer("claim")
			end)
			islandN = ok and n or nil
		end
		local text = node.text
		if node.action == "claim" and not islandN then
			text = "Ho ho! Oh dear, every island is taken right now. Come back later, and I'll find one for you!"
		end
		text = text:gsub("{N}", tostring(islandN))
		panel.Visible = true
		sound(Audio.HoHo, 0.75, 0.95 + math.random() * 0.1)
		typeText(text)
		step = askChoices(node.choices)
	end

	panel.Visible = false
	setBars(false)
	pcall(function()
		Remotes.Function("IntroAction"):InvokeServer("done")
	end)
	introDone = true
	stopCamera()
	freeze(false)
	gui.Enabled = false
	applyLocks()
	running = false
end

function IntroController.Init()
	buildUI()
	applyLocks()
	-- yeni butonlar sonradan eklenirse de kilitli kalsın
	player:WaitForChild("PlayerGui").DescendantAdded:Connect(function(d)
		if d:IsA("GuiButton") and table.find(LOCKED, d.Name) then
			d.Visible = introDone == true
		end
	end)
	Remotes.Event("DataUpdated").OnClientEvent:Connect(function(data)
		if type(data) == "table" and data.introDone ~= nil and not running then
			introDone = data.introDone == true
			applyLocks()
		end
	end)
	Remotes.Event("IntroStart").OnClientEvent:Connect(function()
		task.spawn(run)
	end)
end

return IntroController
