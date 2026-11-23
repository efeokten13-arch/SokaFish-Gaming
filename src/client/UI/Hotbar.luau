--!nonstrict
-- Envanter çubuğu: alt ortada yarım gemi dümeni. Eşyalar dümenin tutamaklarında durur.
--   1 = Olta  -> dümen döner, olta tepeye gelir, parlar; olta ele alınır ve "At" butonu çıkar
--               (olta seçili değilken denizde bile "At" butonu çıkmaz: client/Fishing/ReelingController)
--   2 = Çanta -> balık çantasını açar (UI/Inventory)
--   Seçili tutamağa tekrar basınca olta bırakılır, dümen geri döner.
-- Server tarafı: Remotes "EquipTool" -> FishingService (oyuncunun "Equipped" attribute'u = "Rod" | nil)
-- İleride yeni araç eklemek için SLOTS listesine bir satır ekle (boş tutamaklar "knob").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))

local Hotbar = {}

local WOOD = Color3.fromRGB(122, 80, 42)
local WOOD_DARK = Color3.fromRGB(78, 50, 26)
local WOOD_LIGHT = Color3.fromRGB(168, 116, 64)
local BRASS = Color3.fromRGB(230, 182, 72)
local GLOW = Color3.fromRGB(255, 214, 90)

local RING_R = 78 -- dümen çemberinin yarıçapı
local HANDLE_R = 122 -- tutamakların merkeze uzaklığı
local HANDLE = 58 -- tutamak boyu

-- angle: tepeden saat yönünde derece. kind: "tool" (seçilir, dümen döner) | "action" (basınca iş yapar) | "knob" (süs)
local SLOTS = {
	{ angle = -60, kind = "knob" },
	{ angle = -30, kind = "tool", id = "Rod", icon = "🎣", key = Enum.KeyCode.One, keyText = "1" },
	{ angle = 0, kind = "knob" },
	{ angle = 30, kind = "action", id = "Bag", icon = "🎒", key = Enum.KeyCode.Two, keyText = "2", name = "Backpack" },
	{ angle = 60, kind = "knob" },
}

local gui, holder, rotor, nameLabel, hintLabel
local handles = {} -- [slot] = { button, icon, scale, stroke }
local selected = nil -- "Rod" | nil
local rodName = "Fishing Rod"
local hintOn = false
local inventory -- UI/Inventory (çanta aç/kapa)

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(0.5, 0)
	c.Parent = p
	return c
end

local function stroke(p, color, th, tr)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = th
	s.Transparency = tr or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function polar(angle, r)
	local a = math.rad(angle)
	return UDim2.new(0.5, math.sin(a) * r, 0.5, -math.cos(a) * r)
end

local function slotOf(id)
	for _, s in SLOTS do
		if s.id == id then
			return s
		end
	end
	return nil
end

---------------------------------------------------------------------------------------------
local function refreshLook()
	for slot, h in handles do
		local on = slot.kind == "tool" and selected == slot.id
		TweenService:Create(h.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = on and 1.22 or 1 }):Play()
		h.stroke.Color = on and GLOW or BRASS
		h.stroke.Thickness = on and 4 or 2.5
		h.button.BackgroundColor3 = on and Color3.fromRGB(150, 98, 46) or WOOD_DARK
		if h.glow then
			h.glow.Visible = on
		end
	end
	-- dümen döner: seçili araç tepeye gelir
	local target = 0
	local s = selected and slotOf(selected)
	if s then
		target = -s.angle
	end
	TweenService:Create(rotor, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = target }):Play()
	if selected == "Rod" then
		nameLabel.Text = rodName
		nameLabel.TextTransparency = 0
		nameLabel.TextStrokeTransparency = 0.4
		task.delay(1.6, function()
			if selected == "Rod" then
				TweenService:Create(nameLabel, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	else
		nameLabel.TextTransparency = 1
		nameLabel.TextStrokeTransparency = 1
	end
end

local function setSelected(id)
	if selected == id then
		return
	end
	selected = id
	Remotes.Event("EquipTool"):FireServer(id)
	refreshLook()
end

local function wobble()
	local r = rotor.Rotation
	local t1 = TweenService:Create(rotor, TweenInfo.new(0.12), { Rotation = r + 8 })
	t1:Play()
	t1.Completed:Once(function()
		TweenService:Create(rotor, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Rotation = r }):Play()
	end)
end

local function activate(slot)
	if player:GetAttribute("CannonAiming") or player:GetAttribute("InCutscene") then
		return
	end
	if slot.kind == "tool" then
		setSelected(if selected == slot.id then nil else slot.id)
	elseif slot.id == "Bag" then
		wobble()
		if inventory and inventory.Toggle then
			inventory.Toggle()
		end
	end
end

---------------------------------------------------------------------------------------------
local function buildHandle(slot)
	if slot.kind == "knob" then
		local k = Instance.new("Frame")
		k.Name = "Knob"
		k.AnchorPoint = Vector2.new(0.5, 0.5)
		k.Size = UDim2.fromOffset(26, 26)
		k.Position = polar(slot.angle, HANDLE_R - 18)
		k.BackgroundColor3 = WOOD
		corner(k)
		stroke(k, WOOD_DARK, 2)
		k.Parent = rotor
		return
	end
	local b = Instance.new("TextButton")
	b.Name = slot.id
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Size = UDim2.fromOffset(HANDLE, HANDLE)
	b.Position = polar(slot.angle, HANDLE_R)
	b.BackgroundColor3 = WOOD_DARK
	b.Text = ""
	b.AutoButtonColor = true
	b.ZIndex = 3
	corner(b)
	local st = stroke(b, BRASS, 2.5)
	local sc = Instance.new("UIScale")
	sc.Parent = b
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175))
	grad.Rotation = 90
	grad.Parent = b
	-- seçiliyken arkada yumuşak altın hale
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.45, 1.45)
	glow.BackgroundColor3 = GLOW
	glow.BackgroundTransparency = 0.7
	glow.ZIndex = 2
	corner(glow)
	stroke(glow, GLOW, 3, 0.5)
	glow.Visible = false
	glow.Parent = b
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.68, 0.68)
	icon.BackgroundTransparency = 1
	icon.Text = slot.icon
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBold
	icon.ZIndex = 4
	icon.Parent = b
	-- tuş numarası (küçük pirinç rozet)
	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0.5, 0.5)
	key.Position = UDim2.new(0.5, 0, 0, 2)
	key.Size = UDim2.fromOffset(20, 20)
	key.BackgroundColor3 = BRASS
	key.TextColor3 = WOOD_DARK
	key.Font = Enum.Font.GothamBlack
	key.TextScaled = true
	key.Text = slot.keyText or ""
	key.ZIndex = 5
	key.Visible = not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled
	corner(key)
	key.Parent = icon
	b.Parent = rotor
	b.Activated:Connect(function()
		activate(slot)
	end)
	handles[slot] = { button = b, icon = icon, scale = sc, stroke = st, glow = glow }
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "HotbarGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	holder = Instance.new("Frame")
	holder.Name = "Helm"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 1, -22) -- merkez ekranın altında: dümenin üst yarısı görünür
	holder.Size = UDim2.fromOffset(HANDLE_R * 2 + HANDLE, HANDLE_R * 2 + HANDLE)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = holder
	local function rescale()
		local vh = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.Y or 800
		uiScale.Scale = math.clamp(vh / 820, 0.62, 1)
	end
	rescale()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	rotor = Instance.new("Frame")
	rotor.Name = "Rotor"
	rotor.AnchorPoint = Vector2.new(0.5, 0.5)
	rotor.Position = UDim2.fromScale(0.5, 0.5)
	rotor.Size = UDim2.fromScale(1, 1)
	rotor.BackgroundTransparency = 1
	rotor.Parent = holder

	-- tekerlek parmakları (12 kol): merkezden tutamaklara uzanan tahta çubuklar
	for i = 0, 5 do
		local spoke = Instance.new("Frame")
		spoke.Name = "Spoke"
		spoke.AnchorPoint = Vector2.new(0.5, 0.5)
		spoke.Position = UDim2.fromScale(0.5, 0.5)
		spoke.Size = UDim2.fromOffset(9, (HANDLE_R - 20) * 2)
		spoke.Rotation = i * 30
		spoke.BackgroundColor3 = WOOD
		spoke.BorderSizePixel = 0
		corner(spoke, UDim.new(0, 4))
		stroke(spoke, WOOD_DARK, 1.5)
		spoke.Parent = rotor
	end
	-- çember (kalın tahta + pirinç çizgi)
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(RING_R * 2, RING_R * 2)
	ring.BackgroundTransparency = 1
	corner(ring)
	stroke(ring, WOOD, 14)
	ring.Parent = rotor
	local inner = ring:Clone()
	inner.Name = "RingBrass"
	inner:FindFirstChildOfClass("UIStroke").Color = BRASS
	inner:FindFirstChildOfClass("UIStroke").Thickness = 2
	inner.Size = UDim2.fromOffset(RING_R * 2 - 4, RING_R * 2 - 4)
	inner.Parent = rotor
	local outer = inner:Clone()
	outer.Name = "RingEdge"
	outer:FindFirstChildOfClass("UIStroke").Color = WOOD_DARK
	outer.Size = UDim2.fromOffset(RING_R * 2 + 30, RING_R * 2 + 30)
	outer.Parent = rotor
	-- göbek
	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(44, 44)
	hub.BackgroundColor3 = WOOD_LIGHT
	corner(hub)
	stroke(hub, BRASS, 3)
	hub.Parent = rotor

	for _, slot in SLOTS do
		buildHandle(slot)
	end
	-- dümen dönerken simgeler dik kalsın
	rotor:GetPropertyChangedSignal("Rotation"):Connect(function()
		for _, h in handles do
			h.icon.Rotation = -rotor.Rotation
		end
	end)

	nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.AnchorPoint = Vector2.new(0.5, 1)
	nameLabel.Position = UDim2.new(0.5, 0, 0.5, -HANDLE_R - HANDLE * 0.75)
	nameLabel.Size = UDim2.fromOffset(240, 24)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 22
	nameLabel.TextColor3 = GLOW
	nameLabel.TextTransparency = 1
	nameLabel.TextStrokeTransparency = 1
	nameLabel.Parent = holder

	-- ipucu: suyun yanında ama olta seçili değil
	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	hintLabel.Position = nameLabel.Position
	hintLabel.Size = UDim2.fromOffset(300, 26)
	hintLabel.BackgroundColor3 = Color3.fromRGB(20, 28, 42)
	hintLabel.BackgroundTransparency = 0.2
	hintLabel.Font = Enum.Font.GothamBold
	hintLabel.TextSize = 15
	hintLabel.TextColor3 = Color3.new(1, 1, 1)
	hintLabel.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then "🎣 Tap the rod to start fishing"
		else "🎣 Press 1 (or tap the rod) to fish"
	hintLabel.Visible = false
	corner(hintLabel, UDim.new(0, 10))
	hintLabel.Parent = holder
end

---------------------------------------------------------------------------------------------
function Hotbar.Init()
	build()
	local ok, inv = pcall(require, script.Parent:WaitForChild("Inventory"))
	if ok then
		inventory = inv
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or player:GetAttribute("CannonAiming") then
			return
		end
		for _, slot in SLOTS do
			if slot.key and input.KeyCode == slot.key then
				activate(slot)
			end
		end
	end)

	-- server kararı esastır (olta yoksa vs. geri alır)
	player:GetAttributeChangedSignal("Equipped"):Connect(function()
		local v = player:GetAttribute("Equipped")
		if v ~= selected then
			selected = v
			refreshLook()
		end
	end)

	local function applyData(data)
		if type(data) ~= "table" then
			return
		end
		local def = data.rod and Economy.Rods[data.rod]
		rodName = def and (def.displayName or def.name) or "Fishing Rod"
	end
	Remotes.Event("DataUpdated").OnClientEvent:Connect(applyData)

	-- ara sahnede / top nişanındayken dümen gizlenir; suyun yanında olta seçili değilse olta nabız atar
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		local hide = player:GetAttribute("InCutscene") == true or player:GetAttribute("CannonAiming") == true
		holder.Visible = not hide
		local wantHint = not hide and selected ~= "Rod" and player:GetAttribute("CanFishHere") == true
		if wantHint ~= hintOn then
			hintOn = wantHint
			hintLabel.Visible = wantHint
			if not wantHint then
				local h = handles[slotOf("Rod")]
				if h then
					h.scale.Scale = selected == "Rod" and 1.22 or 1
				end
			end
		end
		if hintOn then
			t += dt
			local h = handles[slotOf("Rod")]
			if h then
				h.scale.Scale = 1 + 0.12 * math.abs(math.sin(t * 4))
			end
		end
	end)
end

return Hotbar
