--!nonstrict
-- Koleksiyon kitabı (ekranın sağ üst köşesindeki 📖 butonu). Solda ada sekmeleri, sağda o adanın 10 balığı:
-- 3D görsel, nadirlik, satış fiyatı, havuzdaki dakikalık geliri, kaç tane tutulduğu.
-- Tutulmamış balıklar karartılmış görünür ("Not caught yet"). Balık listesi: shared/Config/Fish.luau (island, order).
-- Veri: DataUpdated (caught tablosu). Eski "kulübedeki kitap" (OpenCollection) de bu ekranı açar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Fish = require(Config:WaitForChild("Fish"))
local Rarities = require(Config:WaitForChild("Rarities"))
local FishModelBuilder = require(Shared:WaitForChild("FishModelBuilder"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local CollectionBook = {}

local player = Players.LocalPlayer
local PAPER = Color3.fromRGB(246, 236, 210)
local PAPER2 = Color3.fromRGB(236, 222, 190)
local INK = Color3.fromRGB(70, 48, 30)
local COVER = Color3.fromRGB(120, 52, 36)
local GOLD = Color3.fromRGB(214, 160, 60)
local GREEN = Color3.fromRGB(40, 130, 70)

-- Ada sekmeleri (island numarası Config/Fish.luau'daki island alanı)
local ISLANDS = {
	{ n = 1, name = "Warm Waters", icon = "🏝️" },
	{ n = 2, name = "Mermaid Island", icon = "🧜" },
	{ n = 3, name = "???", icon = "🔒", locked = true },
}

local gui, panel, grid, header, progressLbl, button
local tabs = {}
local current = 1
local caught = {}
local spinning = {}

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
	return c
end

local function label(parent, str, size, pos, color, font, maxSize, align)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Text = str
	t.TextColor3 = color
	t.Font = font or Enum.Font.GothamBold
	t.TextScaled = true
	t.TextXAlignment = align or Enum.TextXAlignment.Center
	t.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize or 16
	c.Parent = t
	return t
end

local function fishOf(island)
	local ids = {}
	for id, def in Fish do
		if def.island == island and not def.retired then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return (Fish[a].order or 0) < (Fish[b].order or 0)
	end)
	return ids
end

local function countCaught(island)
	local ids = fishOf(island)
	local n = 0
	for _, id in ids do
		if (caught[id] or 0) > 0 then
			n += 1
		end
	end
	return n, #ids
end

local function money(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- 3D önizleme (3/4 açıdan, yavaşça döner)
local function viewport(parent, id, known)
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(1, -10, 0, 84)
	vp.Position = UDim2.fromOffset(5, 21)
	vp.BackgroundColor3 = known and Color3.fromRGB(190, 225, 240) or Color3.fromRGB(170, 160, 140)
	vp.Ambient = known and Color3.fromRGB(190, 190, 200) or Color3.fromRGB(150, 150, 160)
	vp.LightColor = known and Color3.new(1, 1, 1) or Color3.fromRGB(170, 170, 180)
	vp.LightDirection = Vector3.new(-1, -1.4, -0.8)
	corner(vp, 8)
	vp.Parent = parent
	local model = FishModelBuilder.Build(id)
	if not model then
		return
	end
	if not known then
		-- tutulmamış: karartılmış (şekli görünür, renkleri değil)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = d.Color:Lerp(Color3.fromRGB(70, 66, 80), 0.68)
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
			elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
				d.Enabled = false
			end
		end
	end
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	model:TranslateBy(-cf.Position)
	local base = model:GetPivot()
	local dim = math.max(size.X, size.Y, size.Z)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	cam.CFrame = CFrame.lookAt(Vector3.new(dim * 1.25, dim * 0.45, -dim * 0.75), Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam
	table.insert(spinning, { model = model, base = base, a = math.random() * 6 })
end

local function card(id, order)
	local def = Fish[id]
	local count = caught[id] or 0
	local known = count > 0
	local rar = Rarities[def.rarity]
	local c = Instance.new("Frame")
	c.Name = id
	c.LayoutOrder = order
	c.BackgroundColor3 = Color3.fromRGB(255, 251, 240)
	corner(c, 10)
	local st = Instance.new("UIStroke")
	st.Color = known and rar.color or Color3.fromRGB(190, 175, 145)
	st.Thickness = known and 3 or 2
	st.Parent = c
	-- üstte nadirlik şeridi
	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, 0, 0, 18)
	strip.BackgroundColor3 = rar.color
	strip.BackgroundTransparency = known and 0 or 0.4
	strip.Parent = c
	corner(strip, 10)
	label(strip, string.upper(def.rarity), UDim2.new(1, -8, 1, -2), UDim2.fromOffset(4, 1), Color3.fromRGB(30, 30, 40), Enum.Font.GothamBlack, 12)
	label(c, "#" .. (def.order or order), UDim2.fromOffset(30, 14), UDim2.new(1, -34, 0, 2), Color3.fromRGB(30, 30, 40), Enum.Font.GothamBold, 11, Enum.TextXAlignment.Right)
	viewport(c, id, known)
	label(c, def.displayName, UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 107), INK, Enum.Font.FredokaOne, 16)
	label(c, "💰 Sells $" .. money(def.sell), UDim2.new(1, -10, 0, 14), UDim2.fromOffset(6, 127), INK, Enum.Font.GothamBold, 12, Enum.TextXAlignment.Left)
	label(c, "⏱ Pool $" .. money(def.perMinute) .. "/min", UDim2.new(1, -10, 0, 14), UDim2.fromOffset(6, 143), INK, Enum.Font.GothamBold, 12, Enum.TextXAlignment.Left)
	if known then
		label(c, "✔ Caught ×" .. count, UDim2.new(1, -10, 0, 14), UDim2.fromOffset(6, 160), GREEN, Enum.Font.GothamBlack, 12, Enum.TextXAlignment.Left)
	else
		label(c, "Not caught yet", UDim2.new(1, -10, 0, 14), UDim2.fromOffset(6, 160), Color3.fromRGB(150, 125, 95), Enum.Font.GothamMedium, 12, Enum.TextXAlignment.Left)
	end
	c.Parent = grid
end

local function refreshTabs()
	for _, t in tabs do
		local sel = t.n == current
		t.button.BackgroundColor3 = sel and PAPER or PAPER2
		t.stroke.Color = sel and GOLD or Color3.fromRGB(180, 160, 120)
		t.stroke.Thickness = sel and 3 or 1.5
		if t.count then
			local n, total = countCaught(t.n)
			t.count.Text = n .. " / " .. total
		end
	end
end

local function showIsland(n)
	current = n
	spinning = {}
	for _, c in grid:GetChildren() do
		if c:IsA("Frame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local info
	for _, i in ISLANDS do
		if i.n == n then
			info = i
		end
	end
	if info and info.locked then
		header.Text = "ISLAND " .. n .. "  —  ???"
		progressLbl.Text = ""
		local l = label(grid, "🔒  Sink the enemy ship behind the Castle Gate to unlock the next island!", UDim2.new(1, -20, 0, 60), UDim2.fromOffset(10, 40), INK, Enum.Font.FredokaOne, 22)
		l.TextWrapped = true
		refreshTabs()
		return
	end
	local ids = fishOf(n)
	for i, id in ids do
		card(id, i)
	end
	local found, total = countCaught(n)
	header.Text = "ISLAND " .. n .. "  —  " .. string.upper(info and info.name or "")
	progressLbl.Text = found .. " / " .. total .. " caught"
	refreshTabs()
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "CollectionBookGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.new(0.86, 0, 0.82, 0)
	panel.BackgroundColor3 = COVER
	corner(panel, 18)
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(1040, 640)
	lim.MinSize = Vector2.new(360, 300)
	lim.Parent = panel
	panel.Parent = gui
	local cst = Instance.new("UIStroke")
	cst.Color = Color3.fromRGB(70, 28, 18)
	cst.Thickness = 3
	cst.Parent = panel

	-- sol: ada sekmeleri
	local side = Instance.new("Frame")
	side.Position = UDim2.fromOffset(12, 12)
	side.Size = UDim2.new(0, 150, 1, -24)
	side.BackgroundTransparency = 1
	side.Parent = panel
	local title = label(side, "📖 FISH BOOK", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 0), Color3.fromRGB(255, 230, 170), Enum.Font.FredokaOne, 22)
	title.TextStrokeTransparency = 0.6
	local list = Instance.new("Frame")
	list.Position = UDim2.fromOffset(0, 40)
	list.Size = UDim2.new(1, 0, 1, -40)
	list.BackgroundTransparency = 1
	list.Parent = side
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = list
	for i, isl in ISLANDS do
		local b = Instance.new("TextButton")
		b.LayoutOrder = i
		b.Size = UDim2.new(1, 0, 0, 62)
		b.Text = ""
		b.AutoButtonColor = true
		b.BackgroundColor3 = PAPER2
		corner(b, 10)
		local st = Instance.new("UIStroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = b
		label(b, isl.icon, UDim2.fromOffset(30, 30), UDim2.fromOffset(6, 16), INK, Enum.Font.GothamBold, 26)
		label(b, "ISLAND " .. isl.n, UDim2.new(1, -44, 0, 16), UDim2.fromOffset(40, 6), Color3.fromRGB(140, 100, 60), Enum.Font.GothamBlack, 12, Enum.TextXAlignment.Left)
		label(b, isl.name, UDim2.new(1, -44, 0, 20), UDim2.fromOffset(40, 21), INK, Enum.Font.FredokaOne, 16, Enum.TextXAlignment.Left)
		local count
		if not isl.locked then
			count = label(b, "0 / 10", UDim2.new(1, -44, 0, 14), UDim2.fromOffset(40, 42), GREEN, Enum.Font.GothamBold, 12, Enum.TextXAlignment.Left)
		end
		b.Parent = list
		b.Activated:Connect(function()
			showIsland(isl.n)
		end)
		table.insert(tabs, { n = isl.n, button = b, stroke = st, count = count })
	end

	-- sağ: sayfa
	local paper = Instance.new("Frame")
	paper.Position = UDim2.fromOffset(172, 12)
	paper.Size = UDim2.new(1, -184, 1, -24)
	paper.BackgroundColor3 = PAPER
	corner(paper, 12)
	paper.Parent = panel

	header = label(paper, "ISLAND 1", UDim2.new(1, -200, 0, 32), UDim2.fromOffset(16, 10), INK, Enum.Font.FredokaOne, 26, Enum.TextXAlignment.Left)
	progressLbl = label(paper, "", UDim2.fromOffset(130, 22), UDim2.new(1, -190, 0, 16), GREEN, Enum.Font.GothamBlack, 16, Enum.TextXAlignment.Right)

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(36, 36)
	close.BackgroundColor3 = COVER
	close.Text = "X"
	close.Font = Enum.Font.GothamBold
	close.TextSize = 20
	close.TextColor3 = Color3.new(1, 1, 1)
	corner(close, 18)
	close.Parent = paper
	close.Activated:Connect(function()
		CollectionBook.Close()
	end)

	grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(8, 48)
	grid.Size = UDim2.new(1, -16, 1, -54)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = paper
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(134, 180)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.Parent = grid

	-- köşe butonu (sağ üst)
	local hud = Instance.new("ScreenGui")
	hud.Name = "CollectionButtonGui"
	hud.ResetOnSpawn = false
	hud.DisplayOrder = 3
	hud.Parent = player.PlayerGui
	button = Theme.Button(hud, "BookButton", "📖", "Fish Book", UDim2.new(1, -18, 0, 18), Vector2.new(1, 0))
	button.Activated:Connect(function()
		if gui.Enabled then
			CollectionBook.Close()
		else
			CollectionBook.Open()
		end
	end)
end

function CollectionBook.Close()
	gui.Enabled = false
	spinning = {}
	for _, c in grid:GetChildren() do
		if c:IsA("Frame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	Theme.SetActive(button, false)
end

function CollectionBook.Open(caughtFromServer)
	if type(caughtFromServer) == "table" then
		caught = caughtFromServer
	end
	gui.Enabled = true
	Theme.SetActive(button, true)
	showIsland(current)
end

function CollectionBook.Init()
	build()
	Remotes.Event("OpenCollection").OnClientEvent:Connect(CollectionBook.Open)
	Remotes.Event("DataUpdated").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.caught) == "table" then
			caught = payload.caught
			if gui.Enabled then
				refreshTabs()
				progressLbl.Text = (function()
					local n, t = countCaught(current)
					return n .. " / " .. t .. " caught"
				end)()
			end
		end
	end)
	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.Function("GetPlayerData"):InvokeServer()
		end)
		if ok and type(data) == "table" and type(data.caught) == "table" then
			caught = data.caught
		end
	end)
	-- B tuşu kitabı açar / kapar
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.B then
			if gui.Enabled then
				CollectionBook.Close()
			else
				CollectionBook.Open()
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not gui.Enabled then
			return
		end
		for _, s in spinning do
			s.a += dt * 0.6
			if s.model.Parent then
				s.model:PivotTo(CFrame.Angles(0, s.a, 0) * s.base)
			end
		end
	end)
end

return CollectionBook
