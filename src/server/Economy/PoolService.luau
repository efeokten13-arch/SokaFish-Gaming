--!strict
-- Adadaki balık havuzu: balığı tekneden havuza koy (en fazla 5), saatlik gelir, offline kazanç, havuzda yüzen balıklar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Fish = require(Config:WaitForChild("Fish"))
local Economy = require(Config:WaitForChild("Economy"))
local FishModelBuilder = require(Shared:WaitForChild("FishModelBuilder"))
local DataService = require(script.Parent.Parent.Data.DataService)
local GuideService = require(script.Parent.Parent.Guide.GuideService)

local PoolService = {}

local GREEN = Color3.fromRGB(120, 230, 150)
local RED = Color3.fromRGB(255, 140, 120)
local carry: { [Player]: number } = {} -- küsuratlı gelir
local swimmers: { [Instance]: { { model: Model, r: number, a: number, speed: number, y: number } } } = {}

function PoolService.IncomePerMinute(data: any): number
	local total = 0
	for _, fishId in data.pool do
		total += Fish[fishId] and Fish[fishId].perMinute or 0
	end
	return total
end

function PoolService.OfflineEarnings(data: any): number
	local minutes = math.min((os.time() - data.lastOnline) / 60, Economy.OfflineEarningsCapHours * 60)
	return math.floor(PoolService.IncomePerMinute(data) * math.max(minutes, 0))
end

local function islandOf(player: Player): Instance?
	local folder = Workspace:FindFirstChild("PrivateIslands")
	if not folder then
		return nil
	end
	for _, island in folder:GetChildren() do
		if island:GetAttribute("OwnerUserId") == player.UserId then
			return island
		end
	end
	return nil
end

local function setLabel(island: Instance, text: string)
	local pool = island:FindFirstChild("Pool")
	local gui = pool and pool:FindFirstChildOfClass("BillboardGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = text
	end
end

-- Havuzdaki balıkları görsel olarak yüzdür
local function refreshVisuals(island: Instance, data: any?)
	local old = island:FindFirstChild("PoolFish")
	if old then
		old:Destroy()
	end
	swimmers[island] = nil
	if not data or #data.pool == 0 then
		setLabel(island, "FISH POOL")
		return
	end
	setLabel(island, "FISH POOL " .. #data.pool .. "/" .. Economy.PoolCapacity .. "  ·  $" .. PoolService.IncomePerMinute(data) .. "/min")
	local folder = Instance.new("Folder")
	folder.Name = "PoolFish"
	local list = {}
	for i, id in data.pool do
		local m = FishModelBuilder.Build(id)
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
				end
			end
			m.Parent = folder
			table.insert(list, { model = m, r = 6 + (i % 3) * 5, a = i * 1.3, speed = 0.35 + (i % 2) * 0.15, y = -1.2 - (i % 2) })
		end
	end
	folder.Parent = island
	swimmers[island] = list
end

local function deposit(player: Player, island: Instance)
	if island:GetAttribute("OwnerUserId") ~= player.UserId then
		DataService.Notify(player, "This is not your island", RED)
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	if #data.storage == 0 then
		DataService.Notify(player, "You have no fish on your boat. Go fishing first!", RED)
		return
	end
	local free = Economy.PoolCapacity - #data.pool
	if free <= 0 then
		DataService.Notify(player, "Your pool is full (" .. Economy.PoolCapacity .. " fish)", RED)
		return
	end
	local moved = 0
	while free > 0 and #data.storage > 0 do
		table.insert(data.pool, table.remove(data.storage, 1) :: string)
		free -= 1
		moved += 1
	end
	DataService.Notify(player, moved .. " fish added to your pool! Earning $" .. PoolService.IncomePerMinute(data) .. "/minute", GREEN)
	DataService.Push(player)
	refreshVisuals(island, data)
	GuideService.Event(player, "pool")
end

local function addPrompts(island: Instance)
	for _, name in { "Dock", "Spawn" } do
		local part = island:FindFirstChild(name)
		if part and part:IsA("BasePart") and not part:FindFirstChild("PoolPrompt") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "PoolPrompt"
			prompt.ActionText = "Put fish in pool"
			prompt.ObjectText = "Fish Pool"
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			prompt.Triggered:Connect(function(p)
				deposit(p, island)
			end)
		end
	end
	-- sahip değişince havuz görselini yenile
	island:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		local uid = island:GetAttribute("OwnerUserId")
		local owner = uid and Players:GetPlayerByUserId(uid :: number)
		refreshVisuals(island, owner and DataService.Get(owner))
	end)
end

-- Islands.Pool merkezine göre yüzen balıkları döndür
local function animate(t: number)
	for island, list in swimmers do
		local pool = island:FindFirstChild("Pool") :: BasePart?
		if pool then
			local c = pool.Position
			for _, f in list do
				local a = f.a + t * f.speed
				local pos = Vector3.new(c.X + math.cos(a) * f.r, f.y, c.Z + math.sin(a) * f.r)
				local nxt = Vector3.new(c.X + math.cos(a + 0.1) * f.r, f.y, c.Z + math.sin(a + 0.1) * f.r)
				f.model:PivotTo(CFrame.lookAt(pos, nxt))
			end
		end
	end
end

function PoolService.Init()
	task.spawn(function()
		local folder = Workspace:WaitForChild("PrivateIslands", 60)
		if not folder then
			return
		end
		for _, island in folder:GetChildren() do
			addPrompts(island)
		end
	end)

	-- girişte offline kazanç
	Players.PlayerAdded:Connect(function(p)
		local data = DataService.Wait(p)
		if data then
			local earned = PoolService.OfflineEarnings(data)
			if earned > 0 then
				data.money += earned
				DataService.Push(p)
				task.delay(3, function()
					DataService.Notify(p, "Your pool earned $" .. earned .. " while you were away!", GREEN)
				end)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		carry[p] = nil
	end)

	-- oyundayken gelir
	task.spawn(function()
		while true do
			task.wait(Economy.PoolTickSeconds)
			for _, p in Players:GetPlayers() do
				local data = DataService.Get(p)
				if data and #data.pool > 0 then
					local add = PoolService.IncomePerMinute(data) * Economy.PoolTickSeconds / 60 + (carry[p] or 0)
					local whole = math.floor(add)
					carry[p] = add - whole
					if whole > 0 then
						data.money += whole
						DataService.Push(p)
					end
				end
			end
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 / 15 then
			acc = 0
			animate(os.clock())
		end
	end)
end

return PoolService
