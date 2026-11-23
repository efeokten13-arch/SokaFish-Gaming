--!nonstrict
-- Mağaza arayüzü (olta dükkânı + tekne dükkânı): sol liste, ortada dönen 3D model, sağda istatistik çubukları
-- (şu anki eşyanla kıyas) ve büyük satın al / kuşan / yelken butonu.
-- Açılış: ProximityPrompt adı "ShopPrompt" (Attribute Kind = "Rods" | "Boats", Id = seçili eşya).
-- Alım server'da: Remotes "ShopAction". Satın alınca para sesi çalar (Config/Audio.Purchase).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Economy = require(Config:WaitForChild("Economy"))
local Boats = require(Config:WaitForChild("Boats"))
local Shop = require(Config:WaitForChild("Shop"))
local Audio = require(Config:WaitForChild("Audio"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RodModelBuilder = require(Shared:WaitForChild("RodModelBuilder"))
local SoundController = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("SoundController"))

local ShopUI = {}

local player = Players.LocalPlayer

-- renkler
local WOOD = Color3.fromRGB(86, 56, 34)
local WOOD_DARK = Color3.fromRGB(52, 33, 20)
local PAPER = Color3.fromRGB(236, 224, 196)
local CARD = Color3.fromRGB(222, 205, 168)
local INK = Color3.fromRGB(70, 44, 26)
local GOLD = Color3.fromRGB(255, 201, 70)
local GREEN = Color3.fromRGB(84, 190, 92)
local BLUE = Color3.fromRGB(70, 140, 225)
local ORANGE = Color3.fromRGB(240, 150, 50)
local GREY = Color3.fromRGB(140, 132, 120)
local RED = Color3.fromRGB(215, 80, 70)
local BAR_BG = Color3.fromRGB(38, 26, 18)
local BAR_FILL = Color3.fromRGB(96, 205, 100)

local RARITY_TIER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }

-- oyuncu verisi
local data = { money = 0, ownedRods = { Economy.StarterRod }, ownedBoats = {}, rod = Economy.StarterRod, boat = Boats.Starter }

-- arayüz durumu
local gui, panel, scale, backdrop
local listFrame, titleLabel, subLabel, moneyLabel, bigView, bigCam, nameLabel, tagLabel, descLabel
local badgeLabel, tierLabel, statsFrame, vsLabel, priceLabel, hintLabel, actionBtn, actionText
local kind = "Rods"
local selected = nil
local cards = {}
local current = nil -- büyük görünümdeki model bilgisi { model, off, radius, kind }
local angle, dragging, lastX, zoom = 0.6, false, 0, 1
local busy = false
local open = false

local function money(n)
	local s = tostring(math.floor(n))
	while true do
		local r, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = r
		if k == 0 then
			break
		end
	end
	return "$" .. s
end

local function round(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = obj
	return c
end

local function stroke(obj, color, thick, mode)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thick
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

local function label(parent, text, size, color, font, pos, sz, align)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextSize = size
	t.TextColor3 = color
	t.Font = font or Enum.Font.GothamBold
	t.Position = pos or UDim2.new()
	t.Size = sz or UDim2.fromScale(1, 1)
	t.TextXAlignment = align or Enum.TextXAlignment.Left
	t.Parent = parent
	return t
end

-- eşya bilgileri ------------------------------------------------------------------------------

local function items()
	if kind == "Rods" then
		return Economy.RodOrder
	end
	return Boats.ShopOrder
end

local function info(id)
	if kind == "Rods" then
		local d = Economy.Rods[id]
		return {
			name = d.displayName,
			price = d.price,
			tier = RARITY_TIER[d.rarity] or 1,
			rarity = d.rarity,
			color = Economy.RarityColors[d.rarity] or PAPER,
			desc = Shop.RodDesc[id],
		}
	end
	local b = Boats[id]
	local tiers = { "Common", "Common", "Uncommon", "Rare" }
	local rar = tiers[b.order] or "Common"
	return {
		name = b.displayName,
		price = b.price,
		tier = b.order,
		rarity = rar,
		color = Economy.RarityColors[rar] or PAPER,
		desc = Shop.BoatDesc[id],
	}
end

local function owned(id)
	return table.find(kind == "Rods" and data.ownedRods or data.ownedBoats, id) ~= nil
end

local function currentId()
	return if kind == "Rods" then data.rod else data.boat
end

-- istatistikler: { etiket, değer, en yüksek, format }
local function stats(id)
	if kind == "Rods" then
		local d = Economy.Rods[id]
		return {
			{ "Luck", d.luck, Shop.RodMax.luck, function(v) return string.format("x%.2f", v) end },
			{ "Length", d.length, Shop.RodMax.length, function(v) return string.format("%.1f", v) end },
			{ "Rarity", RARITY_TIER[d.rarity] or 1, 6, function(v) return tostring(v) end },
		}
	end
	local b = Boats[id]
	return {
		{ "Speed", b.speed, Shop.BoatMax.speed, function(v) return tostring(math.floor(v)) end },
		{ "Storage", b.slots, Shop.BoatMax.slots, function(v) return tostring(v) end },
		{ "Oceans", #b.oceans, Shop.BoatMax.oceans, function(v) return tostring(v) end },
	}
end

-- 3D önizleme ----------------------------------------------------------------------------------

local function makeModel(id)
	local m
	if kind == "Rods" then
		m = RodModelBuilder.Build(id)
	else
		local folder = ReplicatedStorage:FindFirstChild("BoatPreviews")
		local src = folder and folder:FindFirstChild(id)
		m = src and src:Clone()
	end
	if not m then
		return nil
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		elseif d:IsA("Beam") or d:IsA("Attachment") or d:IsA("Script") or d:IsA("Sound") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	local bbcf, size = m:GetBoundingBox()
	return { model = m, off = m:GetPivot():ToObjectSpace(bbcf), radius = math.max(size.Magnitude / 2, 1), kind = kind }
end

local function pose(p, yaw)
	local rot = CFrame.Angles(0, yaw, 0)
	if p.kind == "Rods" then
		rot = rot * CFrame.Angles(0, 0, math.rad(-18)) * CFrame.Angles(math.rad(90), 0, 0)
	end
	p.model:PivotTo(rot * p.off:Inverse())
end

local function fillViewport(vp, id, yaw, camDist)
	for _, c in vp:GetChildren() do
		if c:IsA("Model") or c:IsA("Camera") then
			c:Destroy()
		end
	end
	local p = makeModel(id)
	if not p then
		return nil
	end
	pose(p, yaw)
	p.model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 38
	cam.Parent = vp
	vp.CurrentCamera = cam
	local d = p.radius * camDist
	cam.CFrame = CFrame.lookAt(Vector3.new(0, d * 0.28, d), Vector3.zero)
	p.cam = cam
	return p
end

local function styleViewport(vp)
	vp.Ambient = Color3.fromRGB(150, 150, 160)
	vp.LightColor = Color3.fromRGB(255, 244, 224)
	vp.LightDirection = Vector3.new(-0.5, -1, -0.6)
	vp.BackgroundTransparency = 1
end

-- sağ panel ------------------------------------------------------------------------------------

local function refreshRight()
	local id = selected
	if not id then
		return
	end
	local inf = info(id)
	nameLabel.Text = string.upper(inf.name)
	tagLabel.Text = inf.desc and inf.desc.tag or ""
	descLabel.Text = inf.desc and inf.desc.text or ""
	badgeLabel.Text = string.upper(inf.rarity)
	badgeLabel.Parent.BackgroundColor3 = inf.color
	tierLabel.Text = "TIER " .. inf.tier

	local cur = currentId()
	local isCur = cur == id
	vsLabel.Text = if isCur then "YOUR CURRENT " .. (kind == "Rods" and "ROD" or "BOAT") else "VS YOUR " .. string.upper(info(cur).name)
	for _, c in statsFrame:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local mine, base = stats(id), stats(cur)
	for i, s in mine do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 34)
		row.LayoutOrder = i
		row.Parent = statsFrame
		label(row, s[1], 18, INK, Enum.Font.GothamBold, UDim2.new(), UDim2.new(0.3, 0, 1, 0))
		local bg = Instance.new("Frame")
		bg.BackgroundColor3 = BAR_BG
		bg.Position = UDim2.fromScale(0.3, 0.2)
		bg.Size = UDim2.fromScale(0.36, 0.6)
		bg.Parent = row
		round(bg, 8)
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = BAR_FILL
		fill.Size = UDim2.fromScale(0, 1)
		fill.Parent = bg
		round(fill, 8)
		TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(s[2] / s[3], 0.04, 1), 1) }):Play()
		label(row, s[4](s[2]), 18, INK, Enum.Font.GothamBold, UDim2.fromScale(0.67, 0), UDim2.fromScale(0.17, 1), Enum.TextXAlignment.Right)
		local delta = s[2] - base[i][2]
		if not isCur and math.abs(delta) > 0.001 then
			local txt = (delta > 0 and "+" or "-") .. s[4](math.abs(delta)):gsub("^x", "")
			label(row, txt, 16, delta > 0 and Color3.fromRGB(40, 150, 60) or RED, Enum.Font.GothamBold, UDim2.fromScale(0.84, 0), UDim2.fromScale(0.16, 1), Enum.TextXAlignment.Right)
		end
	end
	if kind == "Boats" then
		local b = Boats[id]
		hintLabel.Text = "Oceans: " .. table.concat(b.oceans, ", ")
	else
		hintLabel.Text = "Higher luck = better chance of rare fish"
	end

	-- alt: fiyat + buton
	local have = owned(id)
	if have then
		priceLabel.Text = if kind == "Rods" and cur == id then "EQUIPPED" else "OWNED"
		priceLabel.TextColor3 = GREEN
	else
		priceLabel.Text = if inf.price > 0 then money(inf.price) else "FREE"
		priceLabel.TextColor3 = if data.money >= inf.price then GOLD else RED
	end
	if kind == "Rods" then
		if have and cur == id then
			actionText.Text, actionBtn.BackgroundColor3 = "EQUIPPED ✓", GREY
		elseif have then
			actionText.Text, actionBtn.BackgroundColor3 = "EQUIP", BLUE
		elseif data.money >= inf.price then
			actionText.Text, actionBtn.BackgroundColor3 = if inf.price > 0 then "BUY ROD" else "TAKE FREE", GREEN
		else
			actionText.Text, actionBtn.BackgroundColor3 = "NEED " .. money(inf.price - data.money) .. " MORE", GREY
		end
	else
		if have then
			actionText.Text, actionBtn.BackgroundColor3 = "SAIL", ORANGE
		elseif data.money >= inf.price then
			actionText.Text, actionBtn.BackgroundColor3 = "BUY SHIP", GREEN
		else
			actionText.Text, actionBtn.BackgroundColor3 = "NEED " .. money(inf.price - data.money) .. " MORE", GREY
		end
	end
	moneyLabel.Text = money(data.money)
end

local function refreshCards()
	for id, c in cards do
		local inf = info(id)
		local have = owned(id)
		local sel = id == selected
		c.stroke.Color = if sel then GOLD else WOOD_DARK
		c.stroke.Thickness = if sel then 4 else 2
		c.frame.BackgroundColor3 = if sel then Color3.fromRGB(246, 228, 160) else CARD
		if kind == "Rods" and data.rod == id then
			c.status.Text, c.status.TextColor3 = "EQUIPPED", GREEN
		elseif have then
			c.status.Text, c.status.TextColor3 = "OWNED", BLUE
		else
			c.status.Text = if inf.price > 0 then money(inf.price) else "FREE"
			c.status.TextColor3 = if data.money >= inf.price then Color3.fromRGB(190, 130, 20) else RED
		end
	end
end

local function select(id)
	selected = id
	angle = 0.6
	zoom = 1
	if current then
		current.model:Destroy()
	end
	current = fillViewport(bigView, id, angle, 2.6)
	bigCam = current and current.cam
	refreshCards()
	refreshRight()
end

local function buildList()
	for _, c in listFrame:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	cards = {}
	for i, id in items() do
		local inf = info(id)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, -8, 0, 84)
		f.LayoutOrder = i
		f.BackgroundColor3 = CARD
		f.Parent = listFrame
		round(f, 14)
		local st = stroke(f, WOOD_DARK, 2)
		local iconBg = Instance.new("Frame")
		iconBg.Size = UDim2.fromOffset(66, 66)
		iconBg.Position = UDim2.fromOffset(9, 9)
		iconBg.BackgroundColor3 = Color3.fromRGB(150, 158, 170)
		iconBg.Parent = f
		round(iconBg, 10)
		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.fromScale(1, 1)
		styleViewport(vp)
		vp.Parent = iconBg
		fillViewport(vp, id, 0.7, 2.5)
		label(f, inf.name, 20, INK, Enum.Font.FredokaOne, UDim2.fromOffset(86, 8), UDim2.new(1, -96, 0, 26))
		label(f, "Tier " .. inf.tier .. " · " .. inf.rarity, 14, Color3.fromRGB(120, 96, 70), Enum.Font.GothamMedium, UDim2.fromOffset(86, 34), UDim2.new(1, -96, 0, 18))
		local status = label(f, "", 20, GOLD, Enum.Font.FredokaOne, UDim2.fromOffset(86, 54), UDim2.new(1, -96, 0, 24))
		local btn = Instance.new("TextButton")
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.Size = UDim2.fromScale(1, 1)
		btn.ZIndex = 5
		btn.Parent = f
		btn.Activated:Connect(function()
			SoundController.Play(Audio.Click, 0.25, 1.4)
			select(id)
		end)
		cards[id] = { frame = f, stroke = st, status = status }
	end
end

-- satın alma -----------------------------------------------------------------------------------

local function shake(obj)
	local p = obj.Position
	task.spawn(function()
		for _, dx in { 8, -8, 5, -5, 0 } do
			obj.Position = p + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		obj.Position = p
	end)
end

local function close()
	if not open then
		return
	end
	open = false
	TweenService:Create(backdrop, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
	local t = TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 })
	t:Play()
	t.Completed:Once(function()
		if not open then
			gui.Enabled = false
		end
	end)
end

local function doAction()
	if busy or not selected then
		return
	end
	local id = selected
	local inf = info(id)
	local have = owned(id)
	local action
	if kind == "Rods" then
		if have and data.rod == id then
			return
		end
		action = if have then "equip" else "buy"
	else
		action = if have then "sail" else "buy"
	end
	if action == "buy" and data.money < inf.price then
		shake(actionBtn)
		return
	end
	busy = true
	local ok, msg, newMoney = pcall(function()
		return Remotes.Function("ShopAction"):InvokeServer(kind, id, action)
	end)
	-- pcall (ok, (başarılı, mesaj, bakiye)) -> açılım
	local success, message, balance
	if ok then
		success, message, balance = msg, newMoney, nil
	end
	busy = false
	if not ok then
		shake(actionBtn)
		return
	end
	if success then
		if action == "buy" then
			SoundController.Play(Audio.Purchase, 0.9)
			if inf.price > 0 then
				SoundController.Play(Audio.Click, 0.4, 0.8)
			end
		else
			SoundController.Play(Audio.Click, 0.5, 1.2)
		end
		local pop = TweenService:Create(actionBtn, TweenInfo.new(0.08), { Size = UDim2.new(1, 0, 0, 68) })
		pop:Play()
		pop.Completed:Wait()
		TweenService:Create(actionBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = UDim2.new(1, 0, 0, 62) }):Play()
		if action == "sail" then
			close()
		end
	else
		shake(actionBtn)
	end
end

-- arayüzü kur ----------------------------------------------------------------------------------

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	backdrop = Instance.new("TextButton")
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Parent = gui

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.9)
	panel.BackgroundColor3 = WOOD
	panel.Parent = backdrop
	round(panel, 26)
	stroke(panel, GOLD, 4)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1.72
	ar.Parent = panel
	local sc = Instance.new("UISizeConstraint")
	sc.MaxSize = Vector2.new(1180, 690)
	sc.Parent = panel
	scale = Instance.new("UIScale")
	scale.Parent = panel

	-- üst bant
	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0.14, 0)
	top.Parent = panel
	local pill = Instance.new("Frame")
	pill.BackgroundColor3 = WOOD_DARK
	pill.Position = UDim2.fromScale(0.03, 0.2)
	pill.Size = UDim2.fromScale(0.2, 0.6)
	pill.Parent = top
	round(pill, 20)
	local coin = Instance.new("Frame")
	coin.BackgroundColor3 = GOLD
	coin.SizeConstraint = Enum.SizeConstraint.RelativeYY
	coin.Size = UDim2.fromScale(0.8, 0.8)
	coin.Position = UDim2.fromScale(0.04, 0.1)
	coin.Parent = pill
	round(coin, 100)
	stroke(coin, Color3.fromRGB(190, 130, 20), 3)
	label(coin, "$", 26, Color3.fromRGB(150, 95, 10), Enum.Font.FredokaOne, nil, nil, Enum.TextXAlignment.Center).TextScaled = true
	moneyLabel = label(pill, "$0", 30, GOLD, Enum.Font.FredokaOne, UDim2.fromScale(0.28, 0), UDim2.fromScale(0.68, 1))
	moneyLabel.TextScaled = true
	titleLabel = label(top, "ROD SHOP", 48, GOLD, Enum.Font.FredokaOne, UDim2.fromScale(0.25, 0.02), UDim2.fromScale(0.5, 0.64), Enum.TextXAlignment.Center)
	titleLabel.TextScaled = true
	stroke(titleLabel, WOOD_DARK, 4, Enum.ApplyStrokeMode.Contextual)
	subLabel = label(top, "", 18, Color3.fromRGB(250, 235, 200), Enum.Font.GothamBold, UDim2.fromScale(0.25, 0.66), UDim2.fromScale(0.5, 0.28), Enum.TextXAlignment.Center)
	subLabel.TextScaled = true
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.TextScaled = true
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.BackgroundColor3 = RED
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.fromScale(0.985, 0.1)
	closeBtn.SizeConstraint = Enum.SizeConstraint.RelativeYY
	closeBtn.Size = UDim2.fromScale(0.8, 0.8)
	closeBtn.Parent = top
	round(closeBtn, 100)
	stroke(closeBtn, Color3.fromRGB(255, 220, 200), 3)
	closeBtn.Activated:Connect(close)

	-- gövde
	local body = Instance.new("Frame")
	body.BackgroundColor3 = PAPER
	body.Position = UDim2.fromScale(0.02, 0.14)
	body.Size = UDim2.fromScale(0.96, 0.84)
	body.Parent = panel
	round(body, 20)
	stroke(body, WOOD_DARK, 3)

	-- sol: liste
	listFrame = Instance.new("ScrollingFrame")
	listFrame.BackgroundTransparency = 1
	listFrame.Position = UDim2.fromScale(0.015, 0.03)
	listFrame.Size = UDim2.fromScale(0.3, 0.94)
	listFrame.ScrollBarThickness = 6
	listFrame.CanvasSize = UDim2.new()
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = body
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 8)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = listFrame

	-- orta: 3D görünüm + yazılar
	local centerBox = Instance.new("Frame")
	centerBox.BackgroundColor3 = Color3.fromRGB(110, 170, 220)
	centerBox.Position = UDim2.fromScale(0.34, 0.03)
	centerBox.Size = UDim2.fromScale(0.35, 0.56)
	centerBox.ClipsDescendants = true
	centerBox.Parent = body
	round(centerBox, 18)
	stroke(centerBox, WOOD_DARK, 4)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(150, 205, 245), Color3.fromRGB(70, 130, 190))
	grad.Rotation = 90
	grad.Parent = centerBox
	bigView = Instance.new("ViewportFrame")
	bigView.Size = UDim2.fromScale(1, 1)
	styleViewport(bigView)
	bigView.Parent = centerBox
	local badge = Instance.new("Frame")
	badge.BackgroundColor3 = PAPER
	badge.Position = UDim2.fromOffset(10, 10)
	badge.Size = UDim2.fromScale(0.34, 0.1)
	badge.Parent = centerBox
	round(badge, 16)
	stroke(badge, WOOD_DARK, 2)
	badgeLabel = label(badge, "COMMON", 18, WOOD_DARK, Enum.Font.FredokaOne, nil, nil, Enum.TextXAlignment.Center)
	badgeLabel.TextScaled = true
	local tierBadge = Instance.new("Frame")
	tierBadge.BackgroundColor3 = WOOD_DARK
	tierBadge.AnchorPoint = Vector2.new(1, 0)
	tierBadge.Position = UDim2.new(1, -10, 0, 10)
	tierBadge.Size = UDim2.fromScale(0.3, 0.1)
	tierBadge.Parent = centerBox
	round(tierBadge, 16)
	tierLabel = label(tierBadge, "TIER 1", 18, Color3.new(1, 1, 1), Enum.Font.FredokaOne, nil, nil, Enum.TextXAlignment.Center)
	tierLabel.TextScaled = true
	local drag = label(centerBox, "Drag to rotate · Scroll to zoom", 14, Color3.new(1, 1, 1), Enum.Font.GothamBold, UDim2.fromScale(0, 0.92), UDim2.fromScale(1, 0.07), Enum.TextXAlignment.Center)
	drag.TextTransparency = 0.15
	stroke(drag, Color3.new(0, 0, 0), 1.5, Enum.ApplyStrokeMode.Contextual)

	centerBox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			lastX = input.Position.X
		end
	end)
	centerBox.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not open then
			return
		end
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			angle += (input.Position.X - lastX) * 0.012
			lastX = input.Position.X
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			local pos = UserInputService:GetMouseLocation()
			local abs, sz = centerBox.AbsolutePosition, centerBox.AbsoluteSize
			if pos.X > abs.X and pos.X < abs.X + sz.X and pos.Y > abs.Y and pos.Y < abs.Y + sz.Y + 36 then
				zoom = math.clamp(zoom - input.Position.Z * 0.1, 0.55, 1.6)
			end
		end
	end)

	nameLabel = label(body, "", 44, WOOD_DARK, Enum.Font.FredokaOne, UDim2.fromScale(0.34, 0.6), UDim2.fromScale(0.35, 0.12), Enum.TextXAlignment.Center)
	nameLabel.TextScaled = true
	tagLabel = label(body, "", 22, Color3.fromRGB(60, 120, 60), Enum.Font.GothamBold, UDim2.fromScale(0.34, 0.725), UDim2.fromScale(0.35, 0.07), Enum.TextXAlignment.Center)
	tagLabel.TextScaled = true
	descLabel = label(body, "", 18, INK, Enum.Font.GothamMedium, UDim2.fromScale(0.35, 0.8), UDim2.fromScale(0.33, 0.17), Enum.TextXAlignment.Center)
	descLabel.TextWrapped = true
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextScaled = true
	local dsc = Instance.new("UITextSizeConstraint")
	dsc.MaxTextSize = 20
	dsc.Parent = descLabel

	-- sağ: istatistikler + satın al
	vsLabel = label(body, "VS YOUR ROD", 22, Color3.fromRGB(120, 96, 70), Enum.Font.FredokaOne, UDim2.fromScale(0.72, 0.03), UDim2.fromScale(0.26, 0.07))
	vsLabel.TextScaled = true
	statsFrame = Instance.new("Frame")
	statsFrame.BackgroundTransparency = 1
	statsFrame.Position = UDim2.fromScale(0.72, 0.11)
	statsFrame.Size = UDim2.fromScale(0.27, 0.4)
	statsFrame.Parent = body
	local sl = Instance.new("UIListLayout")
	sl.Padding = UDim.new(0, 6)
	sl.SortOrder = Enum.SortOrder.LayoutOrder
	sl.Parent = statsFrame
	hintLabel = label(body, "", 15, Color3.fromRGB(120, 96, 70), Enum.Font.GothamMedium, UDim2.fromScale(0.72, 0.52), UDim2.fromScale(0.27, 0.08))
	hintLabel.TextWrapped = true
	hintLabel.TextYAlignment = Enum.TextYAlignment.Top

	priceLabel = label(body, "$0", 48, GOLD, Enum.Font.FredokaOne, UDim2.fromScale(0.72, 0.64), UDim2.fromScale(0.27, 0.1), Enum.TextXAlignment.Center)
	priceLabel.TextScaled = true
	stroke(priceLabel, WOOD_DARK, 3, Enum.ApplyStrokeMode.Contextual)
	actionBtn = Instance.new("TextButton")
	actionBtn.Text = ""
	actionBtn.AutoButtonColor = true
	actionBtn.BackgroundColor3 = GREEN
	actionBtn.AnchorPoint = Vector2.new(0.5, 1)
	actionBtn.Position = UDim2.fromScale(0.855, 0.96)
	actionBtn.Size = UDim2.new(0.27, 0, 0, 62)
	actionBtn.Parent = body
	round(actionBtn, 16)
	stroke(actionBtn, Color3.fromRGB(30, 80, 35), 4)
	actionText = label(actionBtn, "BUY", 30, Color3.new(1, 1, 1), Enum.Font.FredokaOne, nil, nil, Enum.TextXAlignment.Center)
	actionText.TextScaled = true
	stroke(actionText, Color3.fromRGB(30, 60, 30), 2.5, Enum.ApplyStrokeMode.Contextual)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = actionBtn
	actionBtn.Activated:Connect(doAction)
end

-- aç / kapat -----------------------------------------------------------------------------------

function ShopUI.Open(shopKind, selectId)
	if not gui then
		return
	end
	kind = shopKind
	local m = Shop.Merchants[kind]
	titleLabel.Text = kind == "Rods" and "ROD SHOP" or "BOAT SHOP"
	subLabel.Text = m.name .. " · " .. m.subtitle
	vsLabel.Text = ""
	buildList()
	gui.Enabled = true
	open = true
	scale.Scale = 0.85
	backdrop.BackgroundTransparency = 1
	TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local start = selectId
	if not start or not (kind == "Rods" and Economy.Rods[start] or kind == "Boats" and Boats[start]) then
		start = currentId()
	end
	select(start)
end

function ShopUI.Init()
	build()
	local function apply(d)
		if type(d) ~= "table" then
			return
		end
		data.money = d.money or data.money
		data.ownedRods = d.ownedRods or data.ownedRods
		data.ownedBoats = d.ownedBoats or data.ownedBoats
		data.rod = d.rod or data.rod
		data.boat = d.boat or data.boat
		if open then
			refreshCards()
			refreshRight()
		end
	end
	Remotes.Event("DataUpdated").OnClientEvent:Connect(apply)
	task.spawn(function()
		local ok, d = pcall(function()
			return Remotes.Function("GetPlayerData"):InvokeServer()
		end)
		if ok then
			apply(d)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not open or not current then
			return
		end
		if not dragging then
			angle += dt * 0.7
		end
		pose(current, angle)
		if bigCam then
			local d = current.radius * 2.6 * zoom
			bigCam.CFrame = CFrame.lookAt(Vector3.new(0, d * 0.28, d), Vector3.zero)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if open and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			close()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or prompt.Name ~= "ShopPrompt" then
			return
		end
		ShopUI.Open(prompt:GetAttribute("Kind") or "Rods", prompt:GetAttribute("Id"))
	end)
end

return ShopUI
