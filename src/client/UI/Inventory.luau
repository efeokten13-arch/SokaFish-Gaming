--!nonstrict
-- Sırt çantası (teknedeki / üstümüzdeki balıklar) + Malzemeler satırı (tahta, metal, inci: yer kaplamaz).
--   Dümen çarkındaki 🎒 tutamağı (2) da çantayı açar: Inventory.Toggle()
--   Dümen çarkındaki 🎒 tutamağı (veya G) çantayı açar: her balık bir kutucuk (3D model, ad, fiyat). Dokununca seçilir.
--   Balık sayısı (ör. 3/5) o tutamağın üstünde rozet olarak durur. (Soldaki 🐟 butonu ve üstteki 🐟 göstergesi kaldırıldı.)
--   Alttaki butonlar bulunduğun yere göre değişir:
--     * Balık pazarının yanında: "Sell selected" / "Sell all"  (çanta pazara yaklaşınca kendiliğinden açılır)
--     * Kendi adandaki havuzun yanında: "To pool" / "All to pool"
--     * Başka yerde: sadece bakılır (nereye gideceğini söyler)
--   Server her işlemde yeri tekrar kontrol eder (SellService.SellFish, PoolService.PoolDeposit).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Fish = require(Config:WaitForChild("Fish"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Boats = require(Config:WaitForChild("Boats"))
local Economy = require(Config:WaitForChild("Economy"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FishModelBuilder = require(Shared:WaitForChild("FishModelBuilder"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local Inventory = {}

local TOGGLE_KEY = Enum.KeyCode.G
local POOL_RANGE = 60

local BG = Color3.fromRGB(18, 30, 46)
local TILE = Color3.fromRGB(32, 48, 68)
local EMPTY = Color3.fromRGB(24, 36, 52)
local ACCENT = Color3.fromRGB(30, 140, 210)
local FULL = Color3.fromRGB(220, 70, 60)
local GOLD = Color3.fromRGB(255, 205, 80)
local GREEN = Color3.fromRGB(70, 185, 100)
local MUTED = Color3.fromRGB(150, 165, 185)

local gui, toggleButton, badge, panel, panelScale, title, banner, grid, selLabel
local btnAll, btnSelected, btnSelectAll
local isOpen, autoOpened = false, false
local storage, slots, poolCount = {}, 3, 0
local materials = { wood = 0, metal = 0, pearls = 0 }
local matLabels = {} -- [alan] = TextLabel
local selected = {} -- [slot] = true
local place = "none" -- "market" | "pool" | "none"
local spinning = {}

---------------------------------------------------------------------------------------------
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function stroke(p, color, th)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = th
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function text(parent, str, size, pos, color, font, maxSize, align)
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

local function money(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. (out:gsub("^,", ""))
end

local function button(parent, str, color)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = str
	b.AutoButtonColor = true
	corner(b, 10)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = 18
	c.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = b
	b.Parent = parent
	return b
end

---------------------------------------------------------------------------------------------
-- Nerede duruyorum?
---------------------------------------------------------------------------------------------
local function myPool()
	local folder = Workspace:FindFirstChild("PrivateIslands")
	for _, isl in folder and folder:GetChildren() or {} do
		if isl:GetAttribute("OwnerUserId") == player.UserId then
			return isl:FindFirstChild("Pool")
		end
	end
	return nil
end

local function detectPlace()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return "none"
	end
	-- pazar: "SELL FISH" plakasının üstünde mi? (plakayı SellService koyar)
	local market = Workspace:FindFirstChild("FishMarket")
	for _, d in market and market:GetChildren() or {} do
		if d.Name == "SellPad" and d:IsA("BasePart") then
			local lp = d.CFrame:PointToObjectSpace(root.Position)
			if math.abs(lp.X) < d.Size.X / 2 + 1.2 and math.abs(lp.Z) < d.Size.Z / 2 + 0.8 and lp.Y > -1 and lp.Y < 7 then
				return "market"
			end
		end
	end
	local pool = myPool()
	if pool and pool:IsA("BasePart") and (pool.Position - root.Position).Magnitude < POOL_RANGE then
		return "pool"
	end
	return "none"
end

---------------------------------------------------------------------------------------------
-- Çizim
---------------------------------------------------------------------------------------------
local function selectedList()
	local out, total = {}, 0
	for i in selected do
		if storage[i] then
			table.insert(out, i)
			total += Fish[storage[i]] and Fish[storage[i]].sell or 0
		end
	end
	table.sort(out)
	return out, total
end

local function totalValue()
	local t = 0
	for _, id in storage do
		t += Fish[id] and Fish[id].sell or 0
	end
	return t
end

local function refreshBar()
	local list, total = selectedList()
	selLabel.Text = #list > 0 and ("Selected " .. #list .. "  ·  " .. money(total)) or ("Bag value " .. money(totalValue()))
	if place == "market" then
		banner.Text = "🐟 FISH MARKET  —  tap fish to choose what to sell"
		banner.TextColor3 = GOLD
		btnSelected.Visible, btnAll.Visible = true, true
		btnSelected.Text = "Sell selected  " .. money(total)
		btnAll.Text = "Sell all  " .. money(totalValue())
		btnSelected.BackgroundColor3 = Color3.fromRGB(225, 150, 40)
		btnAll.BackgroundColor3 = Color3.fromRGB(200, 110, 30)
	elseif place == "pool" then
		local free = Economy.PoolCapacity - poolCount
		banner.Text = "🏝️ YOUR POOL  " .. poolCount .. "/" .. Economy.PoolCapacity .. "  —  tap fish to keep in the pool" .. (free <= 0 and "  (pool full: sell one on the TV)" or "")
		banner.TextColor3 = Color3.fromRGB(140, 230, 170)
		btnSelected.Visible, btnAll.Visible = true, true
		btnSelected.Text = "To pool (" .. #list .. ")"
		btnAll.Text = "All to pool"
		btnSelected.BackgroundColor3 = GREEN
		btnAll.BackgroundColor3 = Color3.fromRGB(50, 150, 80)
	else
		banner.Text = "Sell at the Fish Market  ·  Keep fish in your island pool"
		banner.TextColor3 = MUTED
		btnSelected.Visible, btnAll.Visible = false, false
	end
	btnSelected.Active = #list > 0
	btnSelected.AutoButtonColor = #list > 0
	btnSelected.BackgroundTransparency = #list > 0 and 0 or 0.5
	btnAll.BackgroundTransparency = #storage > 0 and 0 or 0.5
	btnSelectAll.Text = (#list == #storage and #storage > 0) and "Clear" or "Select all"
	btnSelectAll.Visible = #storage > 0
end

local function tile(i, id)
	local def = Fish[id]
	local rar = def and Rarities[def.rarity]
	local t = Instance.new("TextButton")
	t.Name = "Slot" .. i
	t.LayoutOrder = i
	t.Text = ""
	t.AutoButtonColor = false
	t.BackgroundColor3 = TILE
	corner(t, 10)
	local st = stroke(t, rar and rar.color or MUTED, 2)
	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, 0, 0, 5)
	strip.BackgroundColor3 = rar and rar.color or MUTED
	strip.BorderSizePixel = 0
	strip.Parent = t
	local vp = Instance.new("ViewportFrame")
	vp.Position = UDim2.fromOffset(5, 9)
	vp.Size = UDim2.new(1, -10, 0, 62)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(200, 200, 210)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -1.4, -0.8)
	vp.Parent = t
	local model = FishModelBuilder.Build(id)
	if model then
		model.Parent = vp
		local cf, size = model:GetBoundingBox()
		model:TranslateBy(-cf.Position)
		local dim = math.max(size.X, size.Y, size.Z)
		local cam = Instance.new("Camera")
		cam.FieldOfView = 34
		cam.CFrame = CFrame.lookAt(Vector3.new(dim * 1.3, dim * 0.4, -dim * 0.6), Vector3.zero)
		cam.Parent = vp
		vp.CurrentCamera = cam
		table.insert(spinning, { model = model, base = model:GetPivot(), a = i })
	end
	text(t, def and def.displayName or id, UDim2.new(1, -8, 0, 16), UDim2.fromOffset(4, 73), Color3.new(1, 1, 1), Enum.Font.GothamBold, 13)
	text(t, money(def and def.sell or 0), UDim2.new(1, -8, 0, 16), UDim2.fromOffset(4, 91), GOLD, Enum.Font.GothamBlack, 14)
	-- seçim işareti
	local check = Instance.new("TextLabel")
	check.AnchorPoint = Vector2.new(1, 0)
	check.Position = UDim2.new(1, -4, 0, 8)
	check.Size = UDim2.fromOffset(24, 24)
	check.BackgroundColor3 = GREEN
	check.Text = "✓"
	check.Font = Enum.Font.GothamBlack
	check.TextScaled = true
	check.TextColor3 = Color3.new(1, 1, 1)
	check.Visible = false
	check.ZIndex = 3
	corner(check, 12)
	check.Parent = t
	local function show()
		local on = selected[i] == true
		check.Visible = on
		st.Thickness = on and 4 or 2
		st.Color = on and GREEN or (rar and rar.color or MUTED)
		t.BackgroundColor3 = on and Color3.fromRGB(40, 70, 60) or TILE
	end
	show()
	t.Activated:Connect(function()
		selected[i] = (not selected[i]) or nil
		show()
		refreshBar()
	end)
	t.Parent = grid
end

local function emptyTile(i)
	local t = Instance.new("Frame")
	t.Name = "Empty" .. i
	t.LayoutOrder = i
	t.BackgroundColor3 = EMPTY
	corner(t, 10)
	local st = stroke(t, Color3.fromRGB(60, 78, 100), 1.5)
	st.Transparency = 0.3
	text(t, "empty", UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0.5, -8), Color3.fromRGB(80, 98, 120), Enum.Font.GothamMedium, 13)
	t.Parent = grid
end

local function render()
	spinning = {}
	for _, c in grid:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i = 1, math.max(slots, #storage) do
		if storage[i] then
			tile(i, storage[i])
		else
			emptyTile(i)
		end
	end
	title.Text = "🎒 BACKPACK   " .. #storage .. "/" .. slots
	for field, l in matLabels do
		l.Text = tostring(materials[field] or 0)
	end
	refreshBar()
end

local function applyData(data)
	if type(data) ~= "table" then
		return
	end
	storage = data.storage or {}
	slots = data.slots or ((Boats :: any)[data.boat] and (Boats :: any)[data.boat].slots) or 3
	poolCount = data.pool and #data.pool or poolCount
	materials.wood, materials.metal, materials.pearls = data.wood or 0, data.metal or 0, data.pearls or 0
	selected = {}
	badge.Text = #storage .. "/" .. slots
	badge.BackgroundColor3 = #storage >= slots and FULL or ACCENT
	if isOpen then
		render()
	end
end

local function setOpen(open, auto)
	isOpen = open
	autoOpened = open and (auto == true) or false
	panel.Visible = open
	if toggleButton then
		local st = toggleButton:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = open and Color3.fromRGB(255, 214, 90) or Color3.fromRGB(230, 182, 72)
		end
	end
	if open then
		place = detectPlace()
		render()
		panelScale.Scale = 0.9
		TweenService:Create(panelScale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	else
		spinning = {}
		selected = {}
	end
end

local function pulse()
	local s = toggleButton and toggleButton:FindFirstChildOfClass("UIScale")
	if s then
		s.Scale = 1.25
		TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

---------------------------------------------------------------------------------------------
local function buildUI()
	gui = Instance.new("ScreenGui")
	gui.Name = "InventoryGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Balık sayısı rozeti: dümen çarkındaki 🎒 tutamağına takılır (Inventory.AttachButton, UI/Hotbar)
	badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.Size = UDim2.fromOffset(40, 22)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, 8, 1, 2)
	badge.BackgroundColor3 = ACCENT
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Font = Enum.Font.GothamBold
	badge.TextScaled = true
	badge.Text = "0/3"
	badge.ZIndex = 6
	corner(badge, 11)
	stroke(badge, Color3.new(1, 1, 1), 2)

	panel = Instance.new("Frame")
	panel.Name = "Backpack"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.56)
	panel.Size = UDim2.new(0.62, 0, 0.66, 0)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.04
	panel.Visible = false
	corner(panel, 16)
	stroke(panel, ACCENT, 3)
	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	local lim = Instance.new("UISizeConstraint")
	lim.MinSize = Vector2.new(320, 300)
	lim.MaxSize = Vector2.new(720, 510)
	lim.Parent = panel
	panel.Parent = gui

	title = text(panel, "🎒 BACKPACK", UDim2.new(1, -70, 0, 30), UDim2.fromOffset(16, 10), Color3.new(1, 1, 1), Enum.Font.FredokaOne, 26, Enum.TextXAlignment.Left)
	banner = text(panel, "", UDim2.new(1, -32, 0, 18), UDim2.fromOffset(16, 42), MUTED, Enum.Font.GothamBold, 14, Enum.TextXAlignment.Left)

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(34, 34)
	close.BackgroundColor3 = FULL
	close.Text = "X"
	close.Font = Enum.Font.GothamBlack
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	corner(close, 17)
	close.Parent = panel
	close.Activated:Connect(function()
		setOpen(false)
	end)

	-- Malzemeler: balık yeri kaplamaz, sadece sayı
	local mats = Instance.new("Frame")
	mats.Name = "Materials"
	mats.Position = UDim2.fromOffset(12, 66)
	mats.Size = UDim2.new(1, -24, 0, 34)
	mats.BackgroundColor3 = Color3.fromRGB(26, 40, 58)
	corner(mats, 10)
	mats.Parent = panel
	local ml = Instance.new("UIListLayout")
	ml.FillDirection = Enum.FillDirection.Horizontal
	ml.VerticalAlignment = Enum.VerticalAlignment.Center
	ml.Padding = UDim.new(0, 10)
	ml.SortOrder = Enum.SortOrder.LayoutOrder
	ml.Parent = mats
	local mp = Instance.new("UIPadding")
	mp.PaddingLeft = UDim.new(0, 10)
	mp.Parent = mats
	local head = text(mats, "MATERIALS", UDim2.fromOffset(90, 18), UDim2.new(), MUTED, Enum.Font.GothamBlack, 13, Enum.TextXAlignment.Left)
	head.LayoutOrder = 0
	for i, m in { { "wood", "🌲", "Wood", Color3.fromRGB(205, 150, 95) }, { "metal", "🔩", "Metal", Color3.fromRGB(140, 190, 255) }, { "pearls", "🦪", "Pearls", Color3.fromRGB(215, 170, 255) } } do
		local chip = Instance.new("Frame")
		chip.LayoutOrder = i
		chip.Size = UDim2.fromOffset(118, 26)
		chip.BackgroundColor3 = Color3.fromRGB(18, 30, 46)
		corner(chip, 13)
		stroke(chip, m[4], 1.5)
		text(chip, m[2], UDim2.fromOffset(22, 20), UDim2.fromOffset(6, 3), Color3.new(1, 1, 1), Enum.Font.GothamBold, 18)
		text(chip, m[3], UDim2.fromOffset(52, 18), UDim2.fromOffset(30, 4), m[4], Enum.Font.GothamBold, 13, Enum.TextXAlignment.Left)
		matLabels[m[1]] = text(chip, "0", UDim2.fromOffset(34, 18), UDim2.new(1, -38, 0, 4), Color3.new(1, 1, 1), Enum.Font.GothamBlack, 15, Enum.TextXAlignment.Right)
		chip.Parent = mats
	end

	grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(12, 108)
	grid.Size = UDim2.new(1, -24, 1, -174)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 5
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = panel
	local lay = Instance.new("UIGridLayout")
	lay.CellSize = UDim2.fromOffset(108, 112)
	lay.CellPadding = UDim2.fromOffset(8, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lay.Parent = grid

	-- alt çubuk
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 12, 1, -12)
	bar.Size = UDim2.new(1, -24, 0, 50)
	bar.BackgroundColor3 = Color3.fromRGB(26, 40, 58)
	corner(bar, 12)
	bar.Parent = panel
	selLabel = text(bar, "", UDim2.new(0.3, -10, 1, -12), UDim2.fromOffset(12, 6), GOLD, Enum.Font.GothamBlack, 16, Enum.TextXAlignment.Left)
	btnSelectAll = button(bar, "Select all", Color3.fromRGB(70, 90, 120))
	btnSelectAll.AnchorPoint = Vector2.new(1, 0.5)
	btnSelectAll.Position = UDim2.new(0.43, 0, 0.5, 0)
	btnSelectAll.Size = UDim2.new(0.15, 0, 1, -12)
	btnSelectAll:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 14
	btnSelected = button(bar, "Sell selected", Color3.fromRGB(225, 150, 40))
	btnSelected.AnchorPoint = Vector2.new(1, 0.5)
	btnSelected.Position = UDim2.new(0.72, -4, 0.5, 0)
	btnSelected.Size = UDim2.new(0.29, -6, 1, -12)
	btnAll = button(bar, "Sell all", Color3.fromRGB(200, 110, 30))
	btnAll.AnchorPoint = Vector2.new(1, 0.5)
	btnAll.Position = UDim2.new(1, -6, 0.5, 0)
	btnAll.Size = UDim2.new(0.27, -6, 1, -12)

	btnSelectAll.Activated:Connect(function()
		local list = selectedList()
		if #list == #storage then
			selected = {}
		else
			for i = 1, #storage do
				selected[i] = true
			end
		end
		render()
	end)
	btnSelected.Activated:Connect(function()
		local list = selectedList()
		if #list == 0 then
			return
		end
		if place == "market" then
			Remotes.Event("SellFish"):FireServer(list)
		elseif place == "pool" then
			Remotes.Event("PoolDeposit"):FireServer(list)
		end
	end)
	btnAll.Activated:Connect(function()
		if #storage == 0 then
			return
		end
		if place == "market" then
			Remotes.Event("SellFish"):FireServer(nil)
		elseif place == "pool" then
			Remotes.Event("PoolDeposit"):FireServer(nil)
		end
	end)
end

function Inventory.Toggle()
	if panel then
		setOpen(not isOpen)
	end
end

-- Dümen çarkı (UI/Hotbar) 🎒 tutamağını verir: rozet onun üstüne takılır, balık tutunca o zıplar.
-- (Tıklamayı Hotbar yönetir ve Inventory.Toggle çağırır.)
function Inventory.AttachButton(button: GuiObject, badgeParent: GuiObject?)
	toggleButton = button
	if badge then
		badge.Parent = badgeParent or button
	end
end

function Inventory.Init()
	buildUI()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == TOGGLE_KEY then
			setOpen(not isOpen)
		end
	end)
	Remotes.Event("DataUpdated").OnClientEvent:Connect(applyData)
	Remotes.Event("FishCaught").OnClientEvent:Connect(pulse)
	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.Function("GetPlayerData"):InvokeServer()
		end)
		if ok then
			applyData(data)
		end
	end)
	-- yer takibi: pazara gelince çanta kendiliğinden açılır, ayrılınca (kendiliğinden açıldıysa) kapanır
	task.spawn(function()
		while true do
			task.wait(0.3)
			if player:GetAttribute("InCutscene") then
				continue
			end
			local now = detectPlace()
			if now ~= place then
				local before = place
				place = now
				if now == "market" and not isOpen and #storage > 0 then
					setOpen(true, true)
				elseif before == "market" and isOpen and autoOpened then
					setOpen(false)
				elseif isOpen then
					refreshBar()
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not isOpen then
			return
		end
		for _, s in spinning do
			s.a += dt * 0.7
			if s.model.Parent then
				s.model:PivotTo(CFrame.Angles(0, s.a, 0) * s.base)
			end
		end
	end)
end

return Inventory
