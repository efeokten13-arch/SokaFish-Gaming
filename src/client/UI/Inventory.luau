--!strict
-- Envanter (teknedeki balıklar).
--   Solda yuvarlak buton -> panel açılır: her balığın modeli, adı, nadirliği ve satış fiyatı.
--   Veri server'dan gelir: açılışta GetPlayerData, sonra her değişiklikte DataUpdated.
--   Kısayol: G (F balık tutma, E ProximityPrompt için kullanılıyor)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Fish = require(Config:WaitForChild("Fish"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Boats = require(Config:WaitForChild("Boats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FishModelBuilder = require(Shared:WaitForChild("FishModelBuilder"))

local Inventory = {}

local TOGGLE_KEY = Enum.KeyCode.G

local COLOR_BG = Color3.fromRGB(18, 30, 46)
local COLOR_ROW = Color3.fromRGB(32, 48, 68)
local COLOR_EMPTY = Color3.fromRGB(26, 38, 54)
local COLOR_ACCENT = Color3.fromRGB(30, 140, 210)
local COLOR_FULL = Color3.fromRGB(220, 70, 60)
local COLOR_PRICE = Color3.fromRGB(255, 215, 90)
local COLOR_MUTED = Color3.fromRGB(140, 155, 175)

local toggleButton: TextButton
local badge: TextLabel
local panel: Frame
local panelScale: UIScale
local titleLabel: TextLabel
local list: ScrollingFrame
local totalLabel: TextLabel
local isOpen = false

-- Yardımcılar ----------------------------------------------------------------

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, name: string, value: string, color: Color3, font: Enum.Font): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Text = value
	t.TextColor3 = color
	t.Font = font
	t.TextScaled = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = parent
	return t
end

-- Veri DataService.Payload formatında gelir (slots, protectedSlots dahil)
local function slotCount(data: any): number
	if data and data.slots then
		return data.slots
	end
	local boat = data and (Boats :: any)[data.boat]
	return if boat then boat.slots else 3
end

-- Satırlar -------------------------------------------------------------------

-- Balığı yandan gösteren küçük 3D önizleme
local function fishViewport(parent: Instance, fishId: string)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.Size = UDim2.new(0, 64, 1, -8)
	vp.Position = UDim2.fromOffset(10, 4)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.Parent = parent

	local model = FishModelBuilder.Build(fishId)
	if not model then
		return
	end
	-- Balık -Z'ye bakar; 90° çevirince yan profili kameraya döner
	model:PivotTo(CFrame.Angles(0, math.rad(90), 0))
	model.Parent = vp

	local center, size = model:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(center.Position + Vector3.new(0, maxDim * 0.15, maxDim * 1.5), center.Position)
	cam.Parent = vp
	vp.CurrentCamera = cam
end

local function fishRow(index: number, fishId: string, protected: boolean)
	local def = Fish[fishId]
	if not def then
		return
	end
	local rarity = (Rarities :: any)[def.rarity]
	local rarityColor: Color3 = if rarity then rarity.color else Color3.new(1, 1, 1)

	local row = Instance.new("Frame")
	row.Name = "Slot" .. index
	row.LayoutOrder = index
	row.Size = UDim2.new(1, 0, 0, 68)
	row.BackgroundColor3 = COLOR_ROW
	corner(row, UDim.new(0, 10))
	stroke(row, rarityColor, 1.5)
	row.Parent = list

	-- Sol kenarda nadirlik rengi şeridi
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(0, 5, 1, -16)
	stripe.Position = UDim2.fromOffset(0, 8)
	stripe.BackgroundColor3 = rarityColor
	stripe.BorderSizePixel = 0
	corner(stripe, UDim.new(1, 0))
	stripe.Parent = row

	fishViewport(row, fishId)

	local name = def.displayName .. (if protected then "  🔒" else "")
	local nameLabel = label(row, "FishName", name, Color3.new(1, 1, 1), Enum.Font.GothamBold)
	nameLabel.Size = UDim2.new(1, -170, 0, 24)
	nameLabel.Position = UDim2.fromOffset(84, 9)

	local rarityLabel = label(row, "Rarity", def.rarity, rarityColor, Enum.Font.GothamBold)
	rarityLabel.Size = UDim2.new(1, -170, 0, 18)
	rarityLabel.Position = UDim2.fromOffset(84, 38)

	local priceLabel = label(row, "Price", "$" .. def.sell, COLOR_PRICE, Enum.Font.GothamBlack)
	priceLabel.TextXAlignment = Enum.TextXAlignment.Right
	priceLabel.Size = UDim2.new(0, 72, 0, 24)
	priceLabel.Position = UDim2.new(1, -84, 0, 9)

	local incomeLabel = label(row, "Income", def.perMinute .. "$/min", COLOR_MUTED, Enum.Font.Gotham)
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Right
	incomeLabel.Size = UDim2.new(0, 72, 0, 16)
	incomeLabel.Position = UDim2.new(1, -84, 0, 39)
end

local function emptyRow(index: number, protected: boolean)
	local row = Instance.new("Frame")
	row.Name = "Slot" .. index
	row.LayoutOrder = index
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundColor3 = COLOR_EMPTY
	corner(row, UDim.new(0, 10))
	row.Parent = list

	local value = if protected then "🔒 Korumalı slot (boş)" else "Boş slot"
	local t = label(row, "Empty", value, COLOR_MUTED, Enum.Font.Gotham)
	t.Size = UDim2.new(1, -24, 0, 18)
	t.Position = UDim2.fromOffset(14, 11)
end

-- Veri gelince listeyi baştan çiz
local function refresh(data: any)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local storage: { string } = if data then data.storage else {}
	local slots = slotCount(data)
	local protectedCount: number = if data and data.protectedSlots then data.protectedSlots else Boats.ProtectedSlots
	local total = 0

	for i = 1, math.max(slots, #storage) do
		local protected = i <= protectedCount
		local fishId = storage[i]
		if fishId then
			fishRow(i, fishId, protected)
			total += if Fish[fishId] then Fish[fishId].sell else 0
		else
			emptyRow(i, protected)
		end
	end

	titleLabel.Text = string.format("Envanter  %d/%d", #storage, slots)
	badge.Text = string.format("%d/%d", #storage, slots)
	badge.BackgroundColor3 = if #storage >= slots then COLOR_FULL else COLOR_ACCENT
	totalLabel.Text = "Toplam değer: $" .. total
end

-- Aç / kapat -------------------------------------------------------------------

local function setOpen(open: boolean)
	isOpen = open
	panel.Visible = open
	if open then
		panelScale.Scale = 0.9
		TweenService:Create(panelScale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

-- Yeni balık gelince buton zıplar
local function pulse()
	local s = toggleButton:FindFirstChildOfClass("UIScale")
	if not s then
		return
	end
	s.Scale = 1.25
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryGui"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Yuvarlak envanter butonu (sol kenar, ortada)
	toggleButton = Instance.new("TextButton")
	toggleButton.Name = "InventoryButton"
	toggleButton.Size = UDim2.fromOffset(68, 68)
	toggleButton.AnchorPoint = Vector2.new(0, 0.5)
	toggleButton.Position = UDim2.new(0, 16, 0.5, 0)
	toggleButton.BackgroundColor3 = COLOR_ACCENT
	toggleButton.Text = "🐟"
	toggleButton.TextScaled = true
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.TextColor3 = Color3.new(1, 1, 1)
	corner(toggleButton, UDim.new(0.5, 0))
	stroke(toggleButton, Color3.new(1, 1, 1), 3)
	Instance.new("UIScale").Parent = toggleButton
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = toggleButton
	toggleButton.Parent = gui
	-- ortak tasarım (Theme): küçük cam buton, sol sütunda harita butonunun altında
	local Theme = require(script.Parent:WaitForChild("Theme"))
	Theme.StyleRound(toggleButton, "Fish")
	toggleButton.AnchorPoint = Vector2.new(0, 0.5)
	toggleButton.Position = Theme.LeftColumn(-1)

	-- Butonun köşesinde doluluk rozeti (dolunca kırmızı)
	badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.Size = UDim2.fromOffset(40, 22)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, 4, 0, 4)
	badge.BackgroundColor3 = COLOR_ACCENT
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Font = Enum.Font.GothamBold
	badge.TextScaled = true
	badge.Text = "0/3"
	corner(badge, UDim.new(1, 0))
	stroke(badge, Color3.new(1, 1, 1), 2)
	badge.Parent = toggleButton

	-- Panel (butonun sağında açılır)
	panel = Instance.new("Frame")
	panel.Name = "InventoryPanel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 84, 0.5, 0)
	panel.Size = UDim2.new(0.32, 0, 0.62, 0)
	panel.BackgroundColor3 = COLOR_BG
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	corner(panel, UDim.new(0, 14))
	stroke(panel, COLOR_ACCENT, 2)
	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	local limits = Instance.new("UISizeConstraint")
	limits.MinSize = Vector2.new(260, 240)
	limits.MaxSize = Vector2.new(360, 460)
	limits.Parent = panel
	panel.Parent = gui

	titleLabel = label(panel, "Title", "Envanter", Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	titleLabel.Size = UDim2.new(1, -70, 0, 28)
	titleLabel.Position = UDim2.fromOffset(16, 12)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(32, 32)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.BackgroundColor3 = COLOR_FULL
	close.Text = "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBlack
	close.TextScaled = true
	corner(close, UDim.new(0.5, 0))
	close.Parent = panel
	close.Activated:Connect(function()
		setOpen(false)
	end)

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(12, 52)
	list.Size = UDim2.new(1, -24, 1, -100)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Altta toplam satış değeri
	totalLabel = label(panel, "Total", "Toplam değer: $0", COLOR_PRICE, Enum.Font.GothamBold)
	totalLabel.Size = UDim2.new(1, -32, 0, 22)
	totalLabel.AnchorPoint = Vector2.new(0, 1)
	totalLabel.Position = UDim2.new(0, 16, 1, -14)
end

function Inventory.Init()
	buildUI()
	refresh(nil)

	toggleButton.Activated:Connect(function()
		setOpen(not isOpen)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == TOGGLE_KEY then
			setOpen(not isOpen)
		end
	end)

	Remotes.Event("DataUpdated").OnClientEvent:Connect(refresh)
	Remotes.Event("FishCaught").OnClientEvent:Connect(pulse)

	-- İlk veri (server henüz yüklemediyse nil döner, sonra DataUpdated gelir)
	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.Function("GetPlayerData"):InvokeServer()
		end)
		if ok and data then
			refresh(data)
		end
	end)
end

return Inventory
