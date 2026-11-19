--!nonstrict
-- Korsan hazine haritası: ada seçimi ve kilit sistemi.
-- Ayarlar: src/shared/Config/SeaMap.luau (adalar, konumlar, seviyeler, görseller).
-- Sadece arayüz; yolculuk isteği SeaMapService'e gider (server kilidi tekrar kontrol eder).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SeaMap = require(Shared:WaitForChild("Config"):WaitForChild("SeaMap"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local SeaMapUI = {}

local player = Players.LocalPlayer
local ASPECT = 0.8 -- harita genişlik / yükseklik

-- Renkler
local PARCH = Color3.fromRGB(233, 211, 166)
local PARCH_DARK = Color3.fromRGB(196, 160, 108)
local INK = Color3.fromRGB(78, 52, 30)
local BURN = Color3.fromRGB(58, 36, 20)
local GOLD = Color3.fromRGB(240, 190, 60)
local SAND = Color3.fromRGB(228, 196, 130)
local GRASS = Color3.fromRGB(116, 150, 78)
local GREY_SAND = Color3.fromRGB(186, 176, 160)
local GREY_GRASS = Color3.fromRGB(150, 148, 140)
local RED = Color3.fromRGB(170, 50, 40)

local gui, dim, mapFrame, scale, tooltip, infoPanel, infoName, infoDesc, sailButton
local markers = {} -- id -> { button, ring, lock, art }
local selectedId = nil
local boatLevel = 0
local isOpen = false
local pulseTween

-- yardımcılar ------------------------------------------------------------------

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(1, 0)
	c.Parent = p
	return c
end

local function frame(parent, name, size, pos, color, transp)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transp or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(parent, text, size, pos, color, font, maxSize)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Text = text
	t.TextColor3 = color
	t.Font = font or Enum.Font.Fantasy
	t.TextScaled = true
	t.Parent = parent
	if maxSize then
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = maxSize
		c.Parent = t
	end
	return t
end

-- yuvarlak nokta: genişlik scale'i, yükseklik haritanın en-boy oranına göre
local function dot(parent, x, y, d, color, transp, ar)
	local f = frame(parent, "Dot", UDim2.fromScale(d, d * (ar or ASPECT)), UDim2.fromScale(x, y), color, transp)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(f)
	return f
end

local function isUnlocked(isl)
	return boatLevel >= isl.level
end

-- parşömen -----------------------------------------------------------------------

local function buildParchment(map)
	if SeaMap.ParchmentImage ~= "" then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = SeaMap.ParchmentImage
		img.ScaleType = Enum.ScaleType.Stretch
		img.Parent = map
		return
	end
	map.BackgroundColor3 = PARCH
	corner(map, UDim.new(0.02, 0))
	-- kenarlara doğru koyulaşan renk
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PARCH_DARK),
		ColorSequenceKeypoint.new(0.12, PARCH),
		ColorSequenceKeypoint.new(0.88, PARCH),
		ColorSequenceKeypoint.new(1, PARCH_DARK),
	})
	grad.Rotation = 90
	grad.Parent = map
	-- yanık kenar şeritleri
	local function edge(size, pos, rot)
		local e = frame(map, "Edge", size, pos, BURN, 0)
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		g.Rotation = rot
		g.Parent = e
	end
	edge(UDim2.fromScale(1, 0.05), UDim2.fromScale(0, 0), 90)
	edge(UDim2.fromScale(1, 0.05), UDim2.fromScale(0, 0.95), -90)
	edge(UDim2.fromScale(0.06, 1), UDim2.fromScale(0, 0), 0)
	edge(UDim2.fromScale(0.06, 1), UDim2.fromScale(0.94, 0), 180)
	-- yırtık kenarlar: kenarlardan "ısırılmış" koyu parçalar
	local rng = Random.new(77)
	for i = 1, 26 do
		local side = i % 4
		local t = rng:NextNumber(0.03, 0.97)
		local d = rng:NextNumber(0.018, 0.045)
		local x, y
		if side == 0 then
			x, y = t, rng:NextNumber(-0.004, 0.006)
		elseif side == 1 then
			x, y = t, 1 - rng:NextNumber(-0.004, 0.006)
		elseif side == 2 then
			x, y = rng:NextNumber(-0.005, 0.008), t
		else
			x, y = 1 - rng:NextNumber(-0.005, 0.008), t
		end
		dot(map, x, y, d, BURN, 0.3)
	end
	-- lekeler
	for _ = 1, 9 do
		dot(map, rng:NextNumber(0.1, 0.9), rng:NextNumber(0.1, 0.9), rng:NextNumber(0.05, 0.14), PARCH_DARK, rng:NextNumber(0.75, 0.88))
	end
	-- iç çerçeve çizgisi
	local border = frame(map, "Border", UDim2.fromScale(0.92, 0.94), UDim2.fromScale(0.04, 0.03), PARCH, 1)
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = 2
	st.Transparency = 0.35
	st.Parent = border
	corner(border, UDim.new(0.015, 0))
end

-- süsler: pusula, kafatası, çapa, dalgalar ---------------------------------------

local function buildCompass(map)
	local c = frame(map, "Compass", UDim2.fromScale(0.2, 0.2 * ASPECT), UDim2.fromScale(0.13, 0.78), PARCH, 1)
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	local ring = frame(c, "Ring", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1), PARCH_DARK, 0.4)
	corner(ring)
	local rs = Instance.new("UIStroke")
	rs.Color = INK
	rs.Thickness = 2
	rs.Parent = ring
	-- 8 kollu yıldız: dönmüş ince elmaslar
	for k = 0, 7 do
		local long = k % 2 == 0
		local arm = frame(c, "Arm", UDim2.fromScale(long and 0.1 or 0.07, long and 0.95 or 0.62), UDim2.fromScale(0.5, 0.5), k % 4 == 0 and RED or INK, 0)
		arm.AnchorPoint = Vector2.new(0.5, 0.5)
		arm.Rotation = k * 45
		corner(arm, UDim.new(0.5, 0))
	end
	dot(c, 0.5, 0.5, 0.12, GOLD, 0, 1)
	local n = label(c, "N", UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.35, -0.3), INK, Enum.Font.Fantasy)
	n.TextStrokeTransparency = 1
end

local function buildDecor(map)
	label(map, "☠", UDim2.fromScale(0.12, 0.1), UDim2.fromScale(0.83, 0.05), INK, Enum.Font.GothamBold)
	label(map, "⚓", UDim2.fromScale(0.11, 0.09), UDim2.fromScale(0.83, 0.86), INK, Enum.Font.GothamBold)
	local title = label(map, "SEA CHART", UDim2.fromScale(0.34, 0.055), UDim2.fromScale(0.07, 0.04), INK, Enum.Font.Fantasy)
	title.TextTransparency = 0.05
	-- dalgalar
	local rng = Random.new(5)
	for _ = 1, 16 do
		local w = label(map, "~", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(rng:NextNumber(0.07, 0.88), rng:NextNumber(0.1, 0.92)), INK, Enum.Font.Gotham)
		w.TextTransparency = 0.55
		w.ZIndex = 1
	end
end

-- ada çizimi ---------------------------------------------------------------------

local function drawIsland(parent, isl, locked)
	local art = frame(parent, "Art", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), PARCH, 1)
	if isl.image ~= "" then
		local img = Instance.new("ImageLabel")
		img.Name = "Image"
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = isl.image
		img.ImageColor3 = locked and Color3.fromRGB(150, 150, 150) or Color3.new(1, 1, 1)
		img.ImageTransparency = locked and 0.35 or 0
		img.Parent = art
		return art
	end
	local rng = Random.new(isl.seed * 31)
	local sand = locked and GREY_SAND or SAND
	local grass = locked and GREY_GRASS or GRASS
	local alpha = locked and 0.35 or 0
	-- kum lekeleri (dış hat mürekkep)
	local blobs = {}
	for i = 1, 3 do
		local w = rng:NextNumber(0.45, 0.7)
		local h = w * rng:NextNumber(0.6, 0.9)
		local x = 0.5 + rng:NextNumber(-0.18, 0.18)
		local y = 0.55 + rng:NextNumber(-0.12, 0.12)
		local b = frame(art, "Sand", UDim2.fromScale(w, h), UDim2.fromScale(x, y), sand, alpha)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		corner(b)
		local st = Instance.new("UIStroke")
		st.Color = INK
		st.Thickness = 2
		st.Transparency = locked and 0.6 or 0.15
		st.Parent = b
		table.insert(blobs, { x = x, y = y, w = w, h = h })
	end
	-- çimen (kumun içinde)
	for _, b in blobs do
		local g = frame(art, "Grass", UDim2.fromScale(b.w * 0.62, b.h * 0.6), UDim2.fromScale(b.x, b.y - b.h * 0.05), grass, alpha)
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		corner(g)
	end
	-- dağ veya palmiye
	if rng:NextNumber() < 0.5 then
		local m = label(art, "▲", UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.33, 0.25), locked and GREY_GRASS or Color3.fromRGB(110, 86, 60), Enum.Font.GothamBold)
		m.TextTransparency = alpha
	end
	local px, py = 0.5 + rng:NextNumber(-0.15, 0.15), 0.42
	local trunk = frame(art, "Trunk", UDim2.fromScale(0.04, 0.22), UDim2.fromScale(px, py), locked and GREY_SAND or Color3.fromRGB(120, 80, 45), alpha)
	trunk.AnchorPoint = Vector2.new(0.5, 0)
	trunk.Rotation = 8
	for k = -1, 1 do
		local leaf = frame(art, "Leaf", UDim2.fromScale(0.18, 0.06), UDim2.fromScale(px + k * 0.07, py + math.abs(k) * 0.03), locked and GREY_GRASS or Color3.fromRGB(70, 125, 55), alpha)
		leaf.AnchorPoint = Vector2.new(0.5, 0.5)
		leaf.Rotation = k * 30
		corner(leaf)
	end
	return art
end

-- rota (noktalı) --------------------------------------------------------------------

local function buildRoutes(map)
	local folder = Instance.new("Folder")
	folder.Name = "Routes"
	folder.Parent = map
	for i = 1, #SeaMap.Islands - 1 do
		local a, b = SeaMap.Islands[i], SeaMap.Islands[i + 1]
		local unlockedLeg = isUnlocked(b)
		-- yükseklik birimi cinsinden mesafe
		local dist = math.sqrt(((b.x - a.x) * ASPECT) ^ 2 + (b.y - a.y) ^ 2)
		local n = math.floor(dist / 0.022)
		-- hafif kıvrım: ortaya doğru yana bük
		local bend = (i % 2 == 0) and 0.04 or -0.04
		for k = 2, n - 2 do
			local t = k / n
			local x = a.x + (b.x - a.x) * t + math.sin(t * math.pi) * bend
			local y = a.y + (b.y - a.y) * t
			local d = dot(folder, x, y, 0.009, unlockedLeg and INK or Color3.fromRGB(150, 130, 105), unlockedLeg and 0.05 or 0.35)
			d.ZIndex = 2
			d.Parent = map
			d.Name = "RouteDot"
		end
	end
	folder:Destroy() -- noktalar haritaya bağlandı; klasör sadece geçici
end

-- bilgi kutuları ----------------------------------------------------------------------

local tooltipToken = 0
local function showTooltip(isl, text)
	tooltipToken += 1
	local my = tooltipToken
	tooltip.Position = UDim2.fromScale(math.clamp(isl.x, 0.22, 0.78), math.clamp(isl.y - 0.09, 0.08, 0.9))
	tooltip.Msg.Text = text
	tooltip.Visible = true
	tooltip.UIScale.Scale = 0.6
	TweenService:Create(tooltip.UIScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.6, function()
		if tooltipToken == my then
			tooltip.Visible = false
		end
	end)
end

local function refreshInfo()
	local isl = selectedId and SeaMap.Get(selectedId)
	if not isl then
		infoPanel.Visible = false
		return
	end
	infoPanel.Visible = true
	infoName.Text = isl.name
	infoDesc.Text = isl.description
	sailButton.Text = isl.travel and "SET SAIL" or "COMING SOON"
	sailButton.AutoButtonColor = isl.travel ~= nil
	sailButton.BackgroundColor3 = isl.travel and RED or Color3.fromRGB(140, 120, 100)
end

-- işaretler ---------------------------------------------------------------------------

local function styleMarker(isl)
	local m = markers[isl.id]
	if not m then
		return
	end
	local open = isUnlocked(isl)
	local selected = selectedId == isl.id
	m.lock.Visible = not open
	m.pin.BackgroundColor3 = open and (selected and GOLD or RED) or Color3.fromRGB(130, 125, 118)
	m.ring.Color = selected and GOLD or INK
	m.ring.Thickness = selected and 4 or 0
	m.ring.Transparency = selected and 0 or 1
	m.name.TextColor3 = open and (selected and Color3.fromRGB(150, 100, 10) or INK) or Color3.fromRGB(140, 130, 115)
	-- kilit durumu değiştiyse adayı yeniden çiz (renkli / gri)
	if m.drawnOpen ~= open then
		m.art:Destroy()
		m.art = drawIsland(m.button, isl, not open)
		m.drawnOpen = open
	end
end

local function select(id)
	selectedId = id
	for _, isl in SeaMap.Islands do
		styleMarker(isl)
	end
	if pulseTween then
		pulseTween:Cancel()
	end
	local m = markers[id]
	if m then
		m.ring.Thickness = 4
		pulseTween = TweenService:Create(m.ring, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 7 })
		pulseTween:Play()
	end
	refreshInfo()
end

local function buildMarkers(map)
	for i, isl in SeaMap.Islands do
		local b = Instance.new("TextButton")
		b.Name = isl.id
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Size = UDim2.fromScale(0.17, 0.17 * ASPECT)
		b.Position = UDim2.fromScale(isl.x, isl.y)
		b.ZIndex = 3
		b.Parent = map
		local art = drawIsland(b, isl, not isUnlocked(isl))
		-- seçim halkası
		local ringHolder = frame(b, "RingHolder", UDim2.fromScale(1.08, 1.08), UDim2.fromScale(-0.04, -0.04), PARCH, 1)
		corner(ringHolder)
		local ring = Instance.new("UIStroke")
		ring.Thickness = 0
		ring.Transparency = 1
		ring.Parent = ringHolder
		-- konum iğnesi
		local pin = dot(b, 0.5, 0.58, 0.16, RED, 0, 1)
		pin.ZIndex = 5
		local ps = Instance.new("UIStroke")
		ps.Color = Color3.fromRGB(255, 245, 220)
		ps.Thickness = 2
		ps.Parent = pin
		-- numara
		local num = label(pin, tostring(i), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(1, 1, 1), Enum.Font.GothamBold)
		num.ZIndex = 6
		-- kilit
		local lock = label(b, "🔒", UDim2.fromScale(0.36, 0.36), UDim2.fromScale(0.62, 0.02), INK, Enum.Font.GothamBold)
		lock.ZIndex = 6
		-- ad
		local name = label(b, isl.name, UDim2.fromScale(1.5, 0.22), UDim2.fromScale(-0.25, 0.92), INK, Enum.Font.Fantasy, 20)
		name.ZIndex = 6
		name.TextStrokeColor3 = PARCH
		name.TextStrokeTransparency = 0.3
		markers[isl.id] = { button = b, ring = ring, pin = pin, lock = lock, name = name, art = art, drawnOpen = isUnlocked(isl) }

		b.Activated:Connect(function()
			if isUnlocked(isl) then
				select(isl.id)
			else
				showTooltip(isl, string.format(SeaMap.LockedMessage, isl.level))
			end
		end)
	end
end

-- aç / kapa ------------------------------------------------------------------------------

local function open()
	if isOpen then
		return
	end
	isOpen = true
	gui.Enabled = true
	dim.BackgroundTransparency = 1
	scale.Scale = 0.75
	mapFrame.Rotation = -3
	TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(mapFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Rotation = 0 }):Play()
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	local t = TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.7 })
	t:Play()
	t.Completed:Once(function()
		if not isOpen then
			gui.Enabled = false
		end
	end)
end

-- seviye değişince kilitleri güncelle ----------------------------------------------------

local function setLevel(level)
	if level == boatLevel then
		return
	end
	local newly = {}
	for _, isl in SeaMap.Islands do
		if isl.level > boatLevel and isl.level <= level then
			table.insert(newly, isl)
		end
	end
	boatLevel = level
	-- rotaları yeniden çiz
	for _, c in mapFrame:GetChildren() do
		if c.Name == "RouteDot" then
			c:Destroy()
		end
	end
	buildRoutes(mapFrame)
	for _, isl in SeaMap.Islands do
		styleMarker(isl)
	end
	if #newly > 0 then
		showTooltip(newly[1], "New island unlocked: " .. newly[1].name .. "!")
	end
end

-- kurulum ---------------------------------------------------------------------------------

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "SeaMapGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	dim = frame(gui, "Dim", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 1)
	dim.Active = true
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			close()
		end
	end)

	mapFrame = frame(gui, "Map", UDim2.fromScale(0.92, 0.78), UDim2.fromScale(0.5, 0.45), PARCH, 0)
	mapFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mapFrame.ClipsDescendants = false
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = ASPECT
	ar.AspectType = Enum.AspectType.FitWithinMaxSize
	ar.Parent = mapFrame
	scale = Instance.new("UIScale")
	scale.Parent = mapFrame

	buildParchment(mapFrame)
	buildDecor(mapFrame)
	buildCompass(mapFrame)
	buildRoutes(mapFrame)
	buildMarkers(mapFrame)

	-- kapat (haritanın sağ üst köşesinin dışında)
	local x = Instance.new("TextButton")
	x.Name = "Close"
	x.AnchorPoint = Vector2.new(0.5, 0.5)
	x.Position = UDim2.new(1, 6, 0, -6)
	x.Size = UDim2.fromScale(0.1, 0.1 * ASPECT)
	x.BackgroundColor3 = RED
	x.Text = "X"
	x.TextScaled = true
	x.Font = Enum.Font.GothamBold
	x.TextColor3 = Color3.new(1, 1, 1)
	x.ZIndex = 20
	corner(x)
	local xs = Instance.new("UIStroke")
	xs.Color = PARCH
	xs.Thickness = 3
	xs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	xs.Parent = x
	local xp = Instance.new("UIPadding")
	xp.PaddingTop = UDim.new(0.2, 0)
	xp.PaddingBottom = UDim.new(0.2, 0)
	xp.Parent = x
	x.Parent = mapFrame
	x.Activated:Connect(close)

	-- kilit bilgi kutusu
	tooltip = frame(mapFrame, "Tooltip", UDim2.fromScale(0.5, 0.08), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(60, 38, 22), 0.05)
	tooltip.AnchorPoint = Vector2.new(0.5, 1)
	tooltip.ZIndex = 15
	tooltip.Visible = false
	corner(tooltip, UDim.new(0.25, 0))
	local ts = Instance.new("UIStroke")
	ts.Color = GOLD
	ts.Thickness = 2
	ts.Parent = tooltip
	Instance.new("UIScale").Parent = tooltip
	local msg = label(tooltip, "", UDim2.fromScale(0.92, 0.7), UDim2.fromScale(0.04, 0.15), Color3.fromRGB(255, 236, 190), Enum.Font.GothamBold, 22)
	msg.Name = "Msg"
	msg.ZIndex = 16

	-- seçili ada paneli (altta)
	-- haritanın hemen altında
	infoPanel = frame(mapFrame, "Info", UDim2.fromScale(0.9, 0.11), UDim2.new(0.5, 0, 1, 10), Color3.fromRGB(250, 236, 205), 0.05)
	infoPanel.AnchorPoint = Vector2.new(0.5, 0)
	infoPanel.ZIndex = 10
	corner(infoPanel, UDim.new(0.2, 0))
	local ips = Instance.new("UIStroke")
	ips.Color = INK
	ips.Thickness = 2
	ips.Parent = infoPanel
	infoName = label(infoPanel, "", UDim2.fromScale(0.6, 0.42), UDim2.fromScale(0.04, 0.08), INK, Enum.Font.Fantasy, 26)
	infoName.TextXAlignment = Enum.TextXAlignment.Left
	infoName.ZIndex = 11
	infoDesc = label(infoPanel, "", UDim2.fromScale(0.62, 0.38), UDim2.fromScale(0.04, 0.54), Color3.fromRGB(110, 80, 50), Enum.Font.Gotham, 16)
	infoDesc.TextXAlignment = Enum.TextXAlignment.Left
	infoDesc.ZIndex = 11
	sailButton = Instance.new("TextButton")
	sailButton.AnchorPoint = Vector2.new(1, 0.5)
	sailButton.Position = UDim2.fromScale(0.97, 0.5)
	sailButton.Size = UDim2.fromScale(0.3, 0.7)
	sailButton.BackgroundColor3 = RED
	sailButton.TextColor3 = Color3.new(1, 1, 1)
	sailButton.Font = Enum.Font.GothamBold
	sailButton.TextScaled = true
	sailButton.Text = "SET SAIL"
	sailButton.ZIndex = 12
	corner(sailButton, UDim.new(0.3, 0))
	local sp = Instance.new("UIPadding")
	sp.PaddingTop = UDim.new(0.2, 0)
	sp.PaddingBottom = UDim.new(0.2, 0)
	sp.Parent = sailButton
	sailButton.Parent = infoPanel
	sailButton.Activated:Connect(function()
		local isl = selectedId and SeaMap.Get(selectedId)
		if not isl then
			return
		end
		if not isl.travel then
			showTooltip(isl, SeaMap.ComingSoonMessage)
			return
		end
		local folder = ReplicatedStorage:FindFirstChild("SeaMapRemotes")
		local ev = folder and folder:FindFirstChild("Travel")
		if ev then
			ev:FireServer(isl.id)
			close()
		end
	end)

	-- sol taraftaki harita butonu (envanter butonunun üstünde)
	local hud = Instance.new("ScreenGui")
	hud.Name = "SeaMapButtonGui"
	hud.ResetOnSpawn = false
	hud.DisplayOrder = 4
	hud.Parent = player.PlayerGui
	local Theme = require(script.Parent:WaitForChild("Theme"))
	local btn = Theme.Button(hud, "MapButton", "🗺️", "Map", Theme.LeftColumn(-2))
	btn.Activated:Connect(function()
		if isOpen then
			close()
		else
			open()
		end
	end)
end

function SeaMapUI.Init()
	build()
	select(SeaMap.Islands[1].id)

	Remotes.Event("DataUpdated").OnClientEvent:Connect(function(data)
		if data then
			setLevel(SeaMap.BoatLevel(data.ownedBoats))
		end
	end)
	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.Function("GetPlayerData"):InvokeServer()
		end)
		if ok and data then
			setLevel(SeaMap.BoatLevel(data.ownedBoats))
		end
	end)
	-- M tuşu ile de aç/kapa, Esc ile kapat
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			if isOpen then
				close()
			else
				open()
			end
		end
	end)
end

return SeaMapUI
