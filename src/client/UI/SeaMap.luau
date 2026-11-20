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
local ASPECT = 1.75 -- harita genişlik / yükseklik (yatay)

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
		local d = rng:NextNumber(0.01, 0.025)
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
		dot(map, rng:NextNumber(0.1, 0.9), rng:NextNumber(0.1, 0.9), rng:NextNumber(0.03, 0.08), PARCH_DARK, rng:NextNumber(0.75, 0.88))
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
	local c = frame(map, "Compass", UDim2.fromScale(0.11, 0.11 * ASPECT), UDim2.fromScale(0.11, 0.76), PARCH, 1)
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
	local anchor = label(map, "⚓", UDim2.fromScale(0.06, 0.1), UDim2.fromScale(0.87, 0.78), Color3.fromRGB(40, 90, 150), Enum.Font.GothamBold)
	anchor.ZIndex = 2
	local title = label(map, "SEA CHART", UDim2.fromScale(0.3, 0.1), UDim2.fromScale(0.35, 0.07), INK, Enum.Font.Fantasy)
	title.TextTransparency = 0.05
	-- dikiş izi (sağ üst köşe)
	for k = 0, 4 do
		local st = frame(map, "Stitch", UDim2.fromScale(0.004, 0.05), UDim2.fromScale(0.9 + k * 0.012, 0.06 + k * 0.025), INK, 0.2)
		st.Rotation = 35
	end
end

-- ada çizimi ---------------------------------------------------------------------

-- Tema renkleri: { gökyüzü üst, gökyüzü alt / su, kara, vurgu }
local THEMES = {
	tropical = { Color3.fromRGB(120, 200, 245), Color3.fromRGB(40, 175, 200), Color3.fromRGB(80, 170, 70), Color3.fromRGB(235, 215, 150) },
	coral = { Color3.fromRGB(110, 215, 225), Color3.fromRGB(30, 160, 175), Color3.fromRGB(225, 205, 150), Color3.fromRGB(235, 90, 150) },
	swamp = { Color3.fromRGB(110, 130, 110), Color3.fromRGB(50, 70, 55), Color3.fromRGB(45, 70, 40), Color3.fromRGB(90, 70, 45) },
	ice = { Color3.fromRGB(190, 225, 245), Color3.fromRGB(120, 175, 215), Color3.fromRGB(245, 250, 255), Color3.fromRGB(160, 200, 225) },
	volcano = { Color3.fromRGB(90, 30, 30), Color3.fromRGB(40, 20, 20), Color3.fromRGB(45, 40, 42), Color3.fromRGB(255, 110, 30) },
}

local function grey(c)
	local v = (c.R + c.G + c.B) / 3
	return Color3.new(v, v, v):Lerp(Color3.fromRGB(170, 160, 145), 0.4)
end

-- Yuvarlak portre: CanvasGroup + UICorner ile daire içinde kırpılır
local function drawIsland(parent, isl, locked)
	local art = Instance.new("CanvasGroup")
	art.Name = "Art"
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundColor3 = Color3.new(1, 1, 1)
	art.BorderSizePixel = 0
	art.ZIndex = 3
	art.Parent = parent
	corner(art)
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(95, 62, 36)
	frameStroke.Thickness = 4
	frameStroke.Parent = art
	if locked then
		art.GroupColor3 = Color3.fromRGB(150, 145, 140)
		art.GroupTransparency = 0.15
	end
	if isl.image ~= "" then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = isl.image
		img.ScaleType = Enum.ScaleType.Crop
		img.Parent = art
		return art
	end
	local th = THEMES[isl.theme or "tropical"] or THEMES.tropical
	local rng = Random.new(isl.seed * 31)
	local function f(name, size, pos, col, round)
		local x = frame(art, name, size, pos, col, 0)
		x.AnchorPoint = Vector2.new(0.5, 0.5)
		if round then
			corner(x)
		end
		return x
	end
	local function glyph(text, size, pos, col)
		local t = label(art, text, size, pos, col, Enum.Font.GothamBold)
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		return t
	end
	-- gökyüzü ve su
	local sky = f("Sky", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1))
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, th[1]), ColorSequenceKeypoint.new(0.55, th[1]:Lerp(th[2], 0.5)), ColorSequenceKeypoint.new(1, th[2]) })
	g.Rotation = 90
	g.Parent = sky
	local theme = isl.theme
	if theme == "tropical" then
		f("Sand", UDim2.fromScale(0.7, 0.24), UDim2.fromScale(0.5, 0.64), th[4], true)
		f("Hill", UDim2.fromScale(0.55, 0.3), UDim2.fromScale(0.5, 0.55), th[3], true)
		for k = -1, 1 do
			local px = 0.5 + k * 0.17
			f("Trunk", UDim2.fromScale(0.03, 0.2), UDim2.fromScale(px, 0.43), Color3.fromRGB(120, 80, 45)).Rotation = k * 10
			for j = -1, 1 do
				f("Leaf", UDim2.fromScale(0.15, 0.05), UDim2.fromScale(px + j * 0.06, 0.33 + math.abs(j) * 0.02), Color3.fromRGB(60, 140, 55), true).Rotation = j * 30
			end
		end
	elseif theme == "coral" then
		f("Ring", UDim2.fromScale(0.75, 0.32), UDim2.fromScale(0.5, 0.62), th[3], true)
		f("Lagoon", UDim2.fromScale(0.45, 0.16), UDim2.fromScale(0.5, 0.63), Color3.fromRGB(90, 220, 220), true)
		-- harabe
		f("Base", UDim2.fromScale(0.24, 0.05), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(150, 150, 140))
		for k = -1, 1 do
			f("Pillar", UDim2.fromScale(0.04, 0.16), UDim2.fromScale(0.5 + k * 0.08, 0.41), Color3.fromRGB(170, 170, 160))
		end
		f("Roof", UDim2.fromScale(0.28, 0.05), UDim2.fromScale(0.5, 0.32), Color3.fromRGB(150, 150, 140))
		for _ = 1, 14 do
			local cols = { th[4], Color3.fromRGB(160, 90, 220), Color3.fromRGB(255, 160, 90) }
			f("Coral", UDim2.fromScale(0.07, 0.07), UDim2.fromScale(rng:NextNumber(0.15, 0.85), rng:NextNumber(0.72, 0.9)), cols[rng:NextInteger(1, 3)], true)
		end
	elseif theme == "swamp" then
		f("Mud", UDim2.fromScale(1, 0.3), UDim2.fromScale(0.5, 0.86), th[4], false)
		for k = -1, 1 do
			local px = 0.5 + k * 0.25
			f("Trunk", UDim2.fromScale(0.05, 0.45), UDim2.fromScale(px, 0.6), Color3.fromRGB(60, 45, 30)).Rotation = k * 6
			f("Canopy", UDim2.fromScale(0.36, 0.2), UDim2.fromScale(px, 0.35), th[3], true)
			f("Canopy2", UDim2.fromScale(0.26, 0.16), UDim2.fromScale(px + 0.06, 0.28), th[3]:Lerp(Color3.new(0, 0, 0), 0.2), true)
			for j = 1, 2 do
				f("Moss", UDim2.fromScale(0.015, 0.12), UDim2.fromScale(px - 0.08 + j * 0.06, 0.48), Color3.fromRGB(80, 110, 70))
			end
		end
		local fog = f("Fog", UDim2.fromScale(1, 0.25), UDim2.fromScale(0.5, 0.72), Color3.fromRGB(200, 215, 200), false)
		fog.BackgroundTransparency = 0.6
	elseif theme == "ice" then
		glyph("▲", UDim2.fromScale(0.75, 0.6), UDim2.fromScale(0.42, 0.42), th[3])
		glyph("▲", UDim2.fromScale(0.55, 0.45), UDim2.fromScale(0.7, 0.5), Color3.fromRGB(220, 235, 250))
		for k = 0, 4 do
			f("Pine", UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.2 + k * 0.15, 0.66), Color3.fromRGB(50, 90, 80))
		end
		f("Sea", UDim2.fromScale(1, 0.3), UDim2.fromScale(0.5, 0.88), th[2], false)
		for _ = 1, 6 do
			f("Floe", UDim2.fromScale(rng:NextNumber(0.1, 0.2), 0.06), UDim2.fromScale(rng:NextNumber(0.15, 0.85), rng:NextNumber(0.78, 0.92)), Color3.fromRGB(240, 248, 255), true)
		end
	elseif theme == "volcano" then
		glyph("▲", UDim2.fromScale(0.9, 0.7), UDim2.fromScale(0.5, 0.5), th[3])
		f("Crater", UDim2.fromScale(0.14, 0.06), UDim2.fromScale(0.5, 0.26), th[4], true)
		for k = 1, 3 do
			f("Lava", UDim2.fromScale(0.03, 0.25), UDim2.fromScale(0.5 + (k - 2) * 0.09, 0.42), th[4]).Rotation = (k - 2) * 25
		end
		f("LavaSea", UDim2.fromScale(1, 0.22), UDim2.fromScale(0.5, 0.9), Color3.fromRGB(220, 70, 20), false)
		for k = 1, 3 do
			local s = f("Smoke", UDim2.fromScale(0.12 + k * 0.03, 0.1), UDim2.fromScale(0.5 + k * 0.05, 0.2 - k * 0.05), Color3.fromRGB(110, 90, 90), true)
			s.BackgroundTransparency = 0.3
		end
	end
	if locked then
		for _, d in art:GetDescendants() do
			if d:IsA("Frame") then
				d.BackgroundColor3 = grey(d.BackgroundColor3)
			elseif d:IsA("TextLabel") then
				d.TextColor3 = grey(d.TextColor3)
			end
		end
		g.Color = ColorSequence.new(grey(th[1]), grey(th[2]))
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
		-- kıvrım: rotaya dik yönde hafif S eğrisi (yükseklik birimiyle)
		local dx, dy = (b.x - a.x) * ASPECT, b.y - a.y
		local px, py = -dy / dist, dx / dist
		local bend = 0.06
		for k = 4, n - 4 do
			local t = k / n
			local off = math.sin(t * math.pi * 2) * bend
			local x = a.x + (b.x - a.x) * t + px * off / ASPECT
			local y = a.y + (b.y - a.y) * t + py * off
			local d = dot(folder, x, y, 0.006, unlockedLeg and INK or Color3.fromRGB(150, 130, 105), unlockedLeg and 0.05 or 0.35)
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
	m.num.Visible = open
	m.pin.BackgroundColor3 = open and (selected and GOLD or Color3.fromRGB(95, 62, 36)) or Color3.fromRGB(245, 238, 220)
	m.ring.Color = selected and GOLD or INK
	m.ring.Thickness = selected and 4 or 0
	m.ring.Transparency = selected and 0 or 1
	m.name.TextColor3 = open and (selected and Color3.fromRGB(150, 100, 10) or INK) or Color3.fromRGB(140, 130, 115)
	-- kilit durumu değiştiyse adayı yeniden çiz (renkli / gri)
	if m.drawnOpen ~= open then
		m.art:Destroy()
		m.art = drawIsland(m.button, isl, not open)
		m.art.ZIndex = 3
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
		b.Size = UDim2.fromScale(0.13, 0.13 * ASPECT)
		b.Position = UDim2.fromScale(isl.x, isl.y)
		b.ZIndex = 3
		b.Parent = map
		local art = drawIsland(b, isl, not isUnlocked(isl))
		-- seçim halkası
		local ringHolder = frame(b, "RingHolder", UDim2.fromScale(1.1, 1.1), UDim2.fromScale(-0.05, -0.05), PARCH, 1)
		ringHolder.ZIndex = 4
		corner(ringHolder)
		local ring = Instance.new("UIStroke")
		ring.Thickness = 0
		ring.Transparency = 1
		ring.Parent = ringHolder
		-- konum iğnesi
		local pin = dot(b, 0.86, 0.12, 0.26, Color3.fromRGB(95, 62, 36), 0, 1)
		pin.ZIndex = 5
		local ps = Instance.new("UIStroke")
		ps.Color = Color3.fromRGB(255, 245, 220)
		ps.Thickness = 2
		ps.Parent = pin
		-- numara
		local num = label(pin, tostring(i), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(1, 1, 1), Enum.Font.GothamBold)
		num.ZIndex = 6
		-- kilit
		local lock = label(pin, "🔒", UDim2.fromScale(0.75, 0.75), UDim2.fromScale(0.125, 0.125), INK, Enum.Font.GothamBold)
		lock.ZIndex = 6
		-- ad
		local name = label(b, isl.name, UDim2.fromScale(1.7, 0.2), UDim2.fromScale(-0.35, 1.06), INK, Enum.Font.Fantasy, 20)
		name.ZIndex = 6
		name.TextStrokeColor3 = PARCH
		name.TextStrokeTransparency = 0.3
		markers[isl.id] = { button = b, ring = ring, pin = pin, num = num, lock = lock, name = name, art = art, drawnOpen = isUnlocked(isl) }

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
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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

	mapFrame = frame(gui, "Map", UDim2.fromScale(0.86, 0.72), UDim2.fromScale(0.5, 0.44), PARCH, 0)
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
	x.Size = UDim2.fromScale(0.06, 0.06 * ASPECT)
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
	infoPanel = frame(mapFrame, "Info", UDim2.fromScale(0.5, 0.15), UDim2.new(0.5, 0, 1, 8), Color3.fromRGB(250, 236, 205), 0.05)
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
