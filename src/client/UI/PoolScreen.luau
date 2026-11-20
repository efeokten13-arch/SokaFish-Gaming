--!nonstrict
-- Adadaki havuz TV'si (sadece ada sahibi görür ve kullanır):
--   havuzdaki her balığın 3D resmi, adı, nadirliği ve dakikalık kazancı + "Take" (tekneye al) butonu,
--   altta "Teleport to Fish Market" butonu. TV modeli: MapBuilder/Islands (PoolTV.Screen).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Fish = require(Config:WaitForChild("Fish"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Economy = require(Config:WaitForChild("Economy"))
local FishModelBuilder = require(Shared:WaitForChild("FishModelBuilder"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PoolScreen = {}

local player = Players.LocalPlayer
local gui, header, income, grid, emptyLabel
local pool = {}
local screenPart = nil
local spinning = {} -- { viewport camera, model, angle }

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
end

local function myScreen()
	local folder = Workspace:FindFirstChild("PrivateIslands")
	for _, isl in folder and folder:GetChildren() or {} do
		if isl:GetAttribute("OwnerUserId") == player.UserId then
			local tv = isl:FindFirstChild("PoolTV")
			return tv and tv:FindFirstChild("Screen")
		end
	end
	return nil
end

local function bigButton(parent, text, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(300, 54)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 26
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	round(b, 14)
	local st = Instance.new("UIStroke")
	st.Color = Color3.new(1, 1, 1)
	st.Thickness = 2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = b
	b.Parent = parent
	return b
end

local function build()
	gui = Instance.new("SurfaceGui")
	gui.Name = "PoolScreenGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50 -- 16x11 stud -> 800x550
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.ZOffset = 2
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(26, 46, 80), Color3.fromRGB(8, 12, 22))
	grad.Rotation = 90
	grad.Parent = bg

	header = Instance.new("TextLabel")
	header.Position = UDim2.fromOffset(24, 14)
	header.Size = UDim2.new(1, -48, 0, 50)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.FredokaOne
	header.TextSize = 40
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = Color3.new(1, 1, 1)
	header.Text = "🐟 MY FISH POOL"
	header.Parent = bg

	income = Instance.new("TextLabel")
	income.AnchorPoint = Vector2.new(1, 0)
	income.Position = UDim2.new(1, -24, 0, 18)
	income.Size = UDim2.fromOffset(330, 44)
	income.BackgroundColor3 = Color3.fromRGB(255, 196, 64)
	income.Font = Enum.Font.FredokaOne
	income.TextSize = 28
	income.TextColor3 = Color3.fromRGB(60, 40, 10)
	income.Parent = bg
	round(income, 12)

	grid = Instance.new("Frame")
	grid.Position = UDim2.fromOffset(20, 78)
	grid.Size = UDim2.new(1, -40, 0, 380)
	grid.BackgroundTransparency = 1
	grid.Parent = bg
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(140, 370) -- 5 balık tek satıra sığar
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	emptyLabel = Instance.new("TextLabel")
	emptyLabel.Size = UDim2.fromScale(1, 1)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Font = Enum.Font.FredokaOne
	emptyLabel.TextSize = 34
	emptyLabel.TextWrapped = true
	emptyLabel.TextColor3 = Color3.fromRGB(170, 200, 230)
	emptyLabel.Text = "Your pool is empty!\nCatch fish and put them in the pool on your dock.\nEach fish earns coins every minute 💰"
	emptyLabel.Parent = grid

	local footer = Instance.new("Frame")
	footer.AnchorPoint = Vector2.new(0.5, 1)
	footer.Position = UDim2.new(0.5, 0, 1, -12)
	footer.Size = UDim2.new(1, -40, 0, 58)
	footer.BackgroundTransparency = 1
	footer.Parent = bg
	local fl = Instance.new("UIListLayout")
	fl.FillDirection = Enum.FillDirection.Horizontal
	fl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	fl.Padding = UDim.new(0, 20)
	fl.Parent = footer
	local tp = bigButton(footer, "🏪 Teleport to Fish Market", Color3.fromRGB(46, 110, 170))
	tp.Size = UDim2.fromOffset(420, 54)
	tp.Activated:Connect(function()
		Remotes.Event("TeleportRequest"):FireServer("Market")
	end)
end

local function card(i, fishId)
	local def = Fish[fishId]
	if not def then
		return
	end
	local rar = Rarities[def.rarity]
	local col = rar and rar.color or Color3.new(1, 1, 1)
	local c = Instance.new("Frame")
	c.Name = "Fish" .. i
	c.LayoutOrder = i
	c.BackgroundColor3 = Color3.fromRGB(24, 34, 56)
	round(c, 14)
	local st = Instance.new("UIStroke")
	st.Color = col
	st.Thickness = 3
	st.Parent = c

	-- 3D fotoğraf
	local vp = Instance.new("ViewportFrame")
	vp.Position = UDim2.fromOffset(6, 6)
	vp.Size = UDim2.new(1, -12, 0, 140)
	vp.BackgroundColor3 = Color3.fromRGB(40, 90, 130)
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.Parent = c
	round(vp, 10)
	local model = FishModelBuilder.Build(fishId)
	if model then
		model.Parent = vp
		local cf, size = model:GetBoundingBox()
		model:TranslateBy(-cf.Position) -- merkez = (0,0,0)
		local cam = Instance.new("Camera")
		local dist = math.max(size.X, size.Y, size.Z) * 0.85
		cam.CFrame = CFrame.lookAt(Vector3.new(0, dist * 0.2, dist), Vector3.zero)
		cam.Parent = vp
		vp.CurrentCamera = cam
		table.insert(spinning, { model = model, a = i, base = model:GetPivot() })
	end

	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromOffset(6, 152)
	name.Size = UDim2.new(1, -12, 0, 56)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextSize = 24
	name.TextWrapped = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = def.displayName
	name.Parent = c

	local r = Instance.new("TextLabel")
	r.Position = UDim2.fromOffset(6, 206)
	r.Size = UDim2.new(1, -12, 0, 26)
	r.BackgroundTransparency = 1
	r.Font = Enum.Font.FredokaOne
	r.TextSize = 22
	r.TextColor3 = col
	r.Text = def.rarity
	r.Parent = c

	local earn = Instance.new("TextLabel")
	earn.Position = UDim2.fromOffset(10, 238)
	earn.Size = UDim2.new(1, -20, 0, 40)
	earn.BackgroundColor3 = Color3.fromRGB(255, 196, 64)
	earn.Font = Enum.Font.FredokaOne
	earn.TextSize = 26
	earn.TextColor3 = Color3.fromRGB(60, 40, 10)
	earn.Text = money(def.perMinute) .. "/min"
	earn.Parent = c
	round(earn, 10)

	local takeBtn = Instance.new("TextButton")
	takeBtn.AnchorPoint = Vector2.new(0.5, 1)
	takeBtn.Position = UDim2.new(0.5, 0, 1, -10)
	takeBtn.Size = UDim2.new(1, -20, 0, 50)
	takeBtn.BackgroundColor3 = Color3.fromRGB(70, 170, 90)
	takeBtn.Font = Enum.Font.FredokaOne
	takeBtn.TextSize = 22
	takeBtn.TextColor3 = Color3.new(1, 1, 1)
	takeBtn.Text = "🎒 Take"
	takeBtn.Parent = c
	round(takeBtn, 10)
	takeBtn.Activated:Connect(function()
		Remotes.Event("PoolTake"):FireServer(i)
	end)
	c.Parent = grid
end

local function render()
	for _, ch in grid:GetChildren() do
		if ch:IsA("Frame") then
			ch:Destroy()
		end
	end
	spinning = {}
	local total = 0
	for i, id in pool do
		card(i, id)
		total += Fish[id] and Fish[id].perMinute or 0
	end
	emptyLabel.Visible = #pool == 0
	header.Text = "🐟 MY FISH POOL  " .. #pool .. "/" .. Economy.PoolCapacity
	income.Text = "💰 " .. money(total) .. " / minute"
end

function PoolScreen.Init()
	build()
	render()
	Remotes.Event("DataUpdated").OnClientEvent:Connect(function(data)
		if type(data) == "table" and type(data.pool) == "table" then
			pool = data.pool
			render()
		end
	end)
	-- ada sahipliği / streaming: ekranı bul ve bağla
	task.spawn(function()
		while true do
			local s = myScreen()
			if s ~= screenPart then
				screenPart = s
				gui.Adornee = s
				gui.Enabled = s ~= nil
				local idle = s and s:FindFirstChild("Idle")
				if idle then
					idle.Enabled = false
				end
			end
			task.wait(2)
		end
	end)
	-- balık fotoğrafları yavaşça dönsün
	RunService.RenderStepped:Connect(function(dt)
		if not gui.Enabled then
			return
		end
		for _, sp in spinning do
			sp.a += dt * 0.8
			if sp.model.Parent then
				sp.model:PivotTo(CFrame.Angles(0, sp.a, 0) * sp.base)
			end
		end
	end)
end

return PoolScreen
