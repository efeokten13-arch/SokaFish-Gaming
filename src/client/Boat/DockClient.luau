--!nonstrict
-- İskele yardımcıları (client). Server tarafı: server/Boat/DockService
--   1) Merdiven: suda yüzerken bir merdivenin dibine gelince karakter merdivenden yukarı çıkar ve güverteye adım atar.
--      (Roblox yüzme halinden tırmanmaya geçmediği için TrussPart tek başına yetmiyor.)
--   2) Düğmeler: yürürken "⛵ Board boat" (B), kendi teknende otururken "⚓ Dock here" (E) görünür.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DockClient = {}

local player = Players.LocalPlayer

local REACH = 3.5 -- merdiven dibine bu kadar yakın olunca tırmanmaya başla (stud, yatay)
local CLIMB_SPEED = 9 -- stud/sn

local climbing = false
local lastSeated: boolean? = nil

local function extras()
	return Workspace:FindFirstChild("DockExtras")
end

-- Kendi teknende mi oturuyorsun?
local function inOwnBoat(hum: Humanoid?): boolean
	local seat = hum and hum.SeatPart
	if not seat or not seat:IsA("VehicleSeat") then
		return false
	end
	local boats = Workspace:FindFirstChild("Boats")
	for _, b in boats and boats:GetChildren() or {} do
		if seat:IsDescendantOf(b) then
			return b:GetAttribute("OwnerUserId") == player.UserId
		end
	end
	return false
end

-- Düğmeleri duruma göre göster/gizle (sadece bu oyuncunun ekranında)
local function applyPrompts(seated: boolean)
	local ex = extras()
	local points = ex and ex:FindFirstChild("BoardPoints")
	for _, anchor in points and points:GetChildren() or {} do
		local board = anchor:FindFirstChild("BoardPrompt")
		local dock = anchor:FindFirstChild("DockPrompt")
		if board then
			board.Enabled = not seated
		end
		if dock then
			dock.Enabled = seated
		end
	end
end

-- Karakteri merdivenden yukarı taşı, sonra güverteye bir adım at
local function climb(root: BasePart, hum: Humanoid, ladder: Instance)
	climbing = true
	local edge: Vector3 = ladder:GetAttribute("Edge")
	local out: Vector3 = ladder:GetAttribute("Out")
	local top: number = ladder:GetAttribute("Top")
	local hug = edge + out * 1.6 -- merdivenin hemen önü (sudaki taraf)
	local face = -out -- iskeleye bak
	local stops = {
		Vector3.new(hug.X, root.Position.Y, hug.Z),
		Vector3.new(hug.X, top + 3, hug.Z),
		Vector3.new(edge.X - out.X * 2.5, top + 3, edge.Z - out.Z * 2.5), -- güverteye adım
	}
	root.Anchored = true
	hum:ChangeState(Enum.HumanoidStateType.Climbing)
	local from = root.Position
	for _, to in stops do
		local dist = (to - from).Magnitude
		local dur = math.max(dist / CLIMB_SPEED, 0.12)
		local t = 0
		while t < dur do
			t += RunService.Heartbeat:Wait()
			local p = from:Lerp(to, math.min(t / dur, 1))
			root.CFrame = CFrame.lookAt(p, p + face)
		end
		from = to
	end
	root.Anchored = false
	hum:ChangeState(Enum.HumanoidStateType.Landed)
	task.wait(0.3)
	climbing = false
end

local function tryClimb(root: BasePart, hum: Humanoid)
	if climbing or hum.SeatPart or hum.Health <= 0 then
		return
	end
	-- sadece sudayken (yüzerken ya da güverte seviyesinin altındayken)
	local swimming = hum:GetState() == Enum.HumanoidStateType.Swimming
	if not swimming and root.Position.Y > 3 then
		return
	end
	local ex = extras()
	local ladders = ex and ex:FindFirstChild("Ladders")
	for _, l in ladders and ladders:GetChildren() or {} do
		local edge = l:GetAttribute("Edge")
		local out = l:GetAttribute("Out")
		local top = l:GetAttribute("Top")
		if edge and out and top and root.Position.Y < top - 1 then
			local base = edge + out * 1.2
			if Vector2.new(root.Position.X - base.X, root.Position.Z - base.Z).Magnitude <= REACH then
				task.spawn(climb, root, hum, l)
				return
			end
		end
	end
end

function DockClient.Init()
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or not root then
			return
		end
		local seated = inOwnBoat(hum)
		if seated ~= lastSeated then
			lastSeated = seated
			applyPrompts(seated)
		end
		tryClimb(root, hum)
	end)
	-- iskele noktaları server açılınca kurulur; geldiklerinde düğmeleri doğru duruma getir
	task.spawn(function()
		local ex = Workspace:WaitForChild("DockExtras", 120)
		if ex then
			ex.DescendantAdded:Connect(function(d)
				if d:IsA("ProximityPrompt") then
					applyPrompts(lastSeated == true)
				end
			end)
			applyPrompts(lastSeated == true)
		end
	end)
end

return DockClient
