--!nonstrict
-- Koleksiyon kitabı: tüm balık türleri. Tutulanlar renkli ve bilgili, tutulmayanlar "???".
-- Adadaki kulübenin önündeki kitaba basınca server "OpenCollection" gönderir.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Fish = require(Config:WaitForChild("Fish"))
local Rarities = require(Config:WaitForChild("Rarities"))
local FishModelBuilder = require(Shared:WaitForChild("FishModelBuilder"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local CollectionBook = {}

local player = Players.LocalPlayer
local PAPER = Color3.fromRGB(246, 236, 210)
local INK = Color3.fromRGB(70, 48, 30)
local COVER = Color3.fromRGB(150, 45, 40)

local gui, panel, grid, title

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function text(parent, str, size, pos, color, font, ts)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Text = str
	t.TextColor3 = color
	t.Font = font or Enum.Font.GothamBold
	t.TextScaled = true
	t.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = ts or 18
	c.Parent = t
	return t
end

-- sıralama: nadirlik sırası, sonra satış fiyatı
local function sortedIds()
	local rank = {}
	for i, r in Rarities.Order do
		rank[r] = i
	end
	local ids = {}
	for id in Fish do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local ra, rb = rank[Fish[a].rarity] or 0, rank[Fish[b].rarity] or 0
		if ra ~= rb then
			return ra < rb
		end
		return Fish[a].sell < Fish[b].sell
	end)
	return ids
end

local function viewport(parent, id, known)
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(1, -16, 0, 74)
	vp.Position = UDim2.fromOffset(8, 8)
	vp.BackgroundColor3 = known and Color3.fromRGB(215, 235, 245) or Color3.fromRGB(205, 195, 170)
	vp.Ambient = known and Color3.fromRGB(200, 200, 200) or Color3.new(0, 0, 0)
	vp.LightColor = known and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	corner(vp, 8)
	vp.Parent = parent
	local model = FishModelBuilder.Build(id)
	if not model then
		return
	end
	if not known then
		-- tutulmamış balık: siyah siluet
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = Color3.new(0, 0, 0)
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
			end
		end
	end
	model:PivotTo(CFrame.Angles(0, math.rad(90), 0))
	model.Parent = vp
	local center, size = model:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(center.Position + Vector3.new(0, maxDim * 0.1, maxDim * 1.45), center.Position)
	cam.Parent = vp
	vp.CurrentCamera = cam
end

local function card(id, count, order)
	local def = Fish[id]
	local known = (count or 0) > 0
	local rar = Rarities[def.rarity]
	local c = Instance.new("Frame")
	c.Name = id
	c.LayoutOrder = order
	c.BackgroundColor3 = Color3.fromRGB(255, 250, 236)
	corner(c, 10)
	local st = Instance.new("UIStroke")
	st.Color = known and rar.color or Color3.fromRGB(190, 175, 145)
	st.Thickness = 3
	st.Parent = c
	viewport(c, id, known)
	text(c, known and def.displayName or "???", UDim2.new(1, -12, 0, 22), UDim2.fromOffset(6, 86), INK, Enum.Font.GothamBold, 18)
	local r = text(c, def.rarity, UDim2.new(1, -12, 0, 16), UDim2.fromOffset(6, 108), rar.color, Enum.Font.GothamBold, 14)
	r.TextStrokeTransparency = 0.6
	if known then
		text(c, "Sell $" .. def.sell .. "  ·  $" .. def.perMinute .. "/min", UDim2.new(1, -12, 0, 16), UDim2.fromOffset(6, 128), INK, Enum.Font.Gotham, 13)
		text(c, "Caught x" .. count, UDim2.new(1, -12, 0, 16), UDim2.fromOffset(6, 146), Color3.fromRGB(40, 120, 60), Enum.Font.GothamBold, 13)
	else
		text(c, "Not caught yet", UDim2.new(1, -12, 0, 16), UDim2.fromOffset(6, 136), Color3.fromRGB(140, 120, 95), Enum.Font.GothamMedium, 13)
	end
	c.Parent = grid
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "CollectionBookGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.7, 0, 0.75, 0)
	panel.BackgroundColor3 = COVER
	corner(panel, 16)
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(820, 620)
	lim.MinSize = Vector2.new(340, 320)
	lim.Parent = panel
	panel.Parent = gui

	local paper = Instance.new("Frame")
	paper.Position = UDim2.fromOffset(10, 10)
	paper.Size = UDim2.new(1, -20, 1, -20)
	paper.BackgroundColor3 = PAPER
	corner(paper, 12)
	paper.Parent = panel

	title = text(paper, "COLLECTION BOOK", UDim2.new(1, -80, 0, 36), UDim2.fromOffset(16, 10), INK, Enum.Font.FredokaOne, 30)
	title.TextXAlignment = Enum.TextXAlignment.Left

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
		gui.Enabled = false
	end)

	grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(12, 56)
	grid.Size = UDim2.new(1, -24, 1, -68)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = paper
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(170, 170)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = grid
end

function CollectionBook.Open(caught)
	caught = caught or {}
	for _, c in grid:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local ids = sortedIds()
	local found = 0
	for i, id in ids do
		if (caught[id] or 0) > 0 then
			found += 1
		end
		card(id, caught[id], i)
	end
	title.Text = "COLLECTION BOOK   " .. found .. "/" .. #ids
	gui.Enabled = true
end

function CollectionBook.Init()
	build()
	Remotes.Event("OpenCollection").OnClientEvent:Connect(CollectionBook.Open)
end

return CollectionBook
