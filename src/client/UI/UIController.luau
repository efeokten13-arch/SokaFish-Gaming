-- HUD: üst ortada para ve depo göstergesi, altında kısa bildirimler.
-- UI tamamen koddan kurulur. Envanter (ayrı script) aynı DataUpdated verisini kullanır.
--
-- Başka client scriptleri bildirim göstermek için:
--   local UIController = require(script.Parent.UI.UIController)   -- yolu kendi yerinize göre
--   UIController.Notify("Mesaj", Color3.fromRGB(255, 200, 60))
-- Server'dan: DataService.Notify(player, "Mesaj", renk)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local UIController = {}

local COLOR_PANEL = Color3.fromRGB(20, 30, 45)
local COLOR_GOLD = Color3.fromRGB(255, 200, 60)
local COLOR_OK = Color3.fromRGB(110, 210, 120)
local COLOR_FULL = Color3.fromRGB(235, 85, 70)

local gui, moneyLabel, storageLabel, storagePill, toastHolder
local shownMoney = 0
local lastMoney: number? = nil
local lastFull = false
local moneyValue = Instance.new("NumberValue")

-- 1250 -> "1,250"
local function formatNumber(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

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

local function makePill(name: string, width: number): (Frame, TextLabel)
	local pill = Instance.new("Frame")
	pill.Name = name
	pill.Size = UDim2.fromOffset(width, 40)
	pill.BackgroundColor3 = COLOR_PANEL
	pill.BackgroundTransparency = 0.2
	corner(pill, UDim.new(0.5, 0))
	stroke(pill, Color3.new(1, 1, 1), 2)

	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.Size = UDim2.new(1, -48, 1, -10)
	label.Position = UDim2.fromOffset(40, 5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = pill
	return pill, label
end

local function buildUI()
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local bar = Instance.new("Frame")
	bar.Name = "TopBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.Size = UDim2.fromOffset(330, 40)
	bar.BackgroundTransparency = 1
	bar.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	-- Para
	local moneyPill
	moneyPill, moneyLabel = makePill("Money", 180)
	moneyPill.LayoutOrder = 1
	local coin = Instance.new("Frame")
	coin.Size = UDim2.fromOffset(24, 24)
	coin.Position = UDim2.fromOffset(10, 8)
	coin.BackgroundColor3 = COLOR_GOLD
	corner(coin, UDim.new(0.5, 0))
	stroke(coin, Color3.fromRGB(200, 140, 20), 2)
	coin.Parent = moneyPill
	moneyLabel.Text = "0"
	moneyPill.Parent = bar

	-- Depo
	storagePill, storageLabel = makePill("Storage", 120)
	storagePill.LayoutOrder = 2
	local fishIcon = Instance.new("TextLabel")
	fishIcon.Size = UDim2.fromOffset(28, 28)
	fishIcon.Position = UDim2.fromOffset(8, 6)
	fishIcon.BackgroundTransparency = 1
	fishIcon.Text = "🐟"
	fishIcon.TextScaled = true
	fishIcon.Parent = storagePill
	storageLabel.Text = "0/3"
	storagePill.Parent = bar

	-- Bildirimler (HUD'un altında, alt alta)
	toastHolder = Instance.new("Frame")
	toastHolder.Name = "Toasts"
	toastHolder.AnchorPoint = Vector2.new(0.5, 0)
	toastHolder.Position = UDim2.new(0.5, 0, 0, 58)
	toastHolder.Size = UDim2.fromOffset(360, 140)
	toastHolder.BackgroundTransparency = 1
	toastHolder.Parent = gui

	local tl = Instance.new("UIListLayout")
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tl.Padding = UDim.new(0, 6)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = toastHolder
end

-- Para sayacı yukarı/aşağı akarak değişir
moneyValue.Changed:Connect(function(v)
	shownMoney = v
	if moneyLabel then
		moneyLabel.Text = formatNumber(v)
	end
end)

local function floatDelta(delta: number)
	local moneyPill = moneyLabel.Parent :: Frame
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(120, 26)
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 1, 2)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Text = (if delta > 0 then "+" else "-") .. formatNumber(math.abs(delta))
	label.TextColor3 = if delta > 0 then COLOR_OK else COLOR_FULL
	label.Parent = moneyPill
	local tween = TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, 30),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		label:Destroy()
	end)
	tween:Play()
end

local function pulse(frame: Frame)
	local s = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Parent = frame
	s.Scale = 1.15
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function UIController.Notify(text: string, color: Color3?)
	if not toastHolder then
		return
	end
	-- En fazla 3 bildirim
	local toasts = {}
	for _, c in toastHolder:GetChildren() do
		if c:IsA("Frame") then
			table.insert(toasts, c)
		end
	end
	if #toasts >= 3 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end

	local toast = Instance.new("Frame")
	toast.Size = UDim2.fromOffset(340, 34)
	toast.BackgroundColor3 = COLOR_PANEL
	toast.BackgroundTransparency = 0.15
	toast.LayoutOrder = math.floor(os.clock() * 1000)
	corner(toast, UDim.new(0, 8))

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 1, -8)
	label.Position = UDim2.fromOffset(8, 4)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = toast
	toast.Parent = toastHolder

	task.delay(2.5, function()
		if not toast.Parent then
			return
		end
		local fade = TweenInfo.new(0.4)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
		local t = TweenService:Create(label, fade, { TextTransparency = 1 })
		t.Completed:Connect(function()
			toast:Destroy()
		end)
		t:Play()
	end)
end

local function applyData(data: any)
	if type(data) ~= "table" then
		return
	end

	-- Para
	local money = data.money or 0
	if lastMoney ~= nil and money ~= lastMoney then
		floatDelta(money - lastMoney)
		pulse(moneyLabel.Parent :: Frame)
	end
	lastMoney = money
	TweenService:Create(moneyValue, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Value = money,
	}):Play()

	-- Depo
	local count = #(data.storage or {})
	local slots = data.slots or 3
	storageLabel.Text = count .. "/" .. slots
	local full = count >= slots
	storageLabel.TextColor3 = if full then COLOR_FULL else Color3.new(1, 1, 1)
	local s = storagePill:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = if full then COLOR_FULL else Color3.new(1, 1, 1)
	end
	if full and not lastFull then
		pulse(storagePill)
		UIController.Notify("Depo doldu! Satmak için limana dön", COLOR_FULL)
	end
	lastFull = full
end

function UIController.Init()
	buildUI()
	require(script.Parent:WaitForChild("Inventory")).Init()

	Remotes.Event("DataUpdated").OnClientEvent:Connect(applyData)
	Remotes.Event("Notify").OnClientEvent:Connect(function(text, color)
		UIController.Notify(text, color)
	end)

	-- İlk veriyi iste (server yüklenmeden önce girdiysek DataUpdated kaçmış olabilir)
	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.Function("GetPlayerData"):InvokeServer()
		end)
		if ok and data and lastMoney == nil then
			applyData(data)
		end
	end)
end

return UIController
