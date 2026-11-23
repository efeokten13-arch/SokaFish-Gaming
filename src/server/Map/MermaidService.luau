--!nonstrict
-- Deniz kızı Marina (2. ada, kayanın üstünde oturur). NPC Studio'da hazır: "Workspace.NPCs.Mermaid Marina".
--  * 2. adaya ilk gelen oyuncuya sinematik öğretici başlar (client/Tutorial/MermaidIntro); bitince en yakın sandığa ok.
--  * Sonradan E ile konuşunca öğretici tekrar oynar. Öğreticide oyuncu başına "mermaidDone" kaydedilir.
--  * Animasyonlar: oturma (döngü) + el sallama / işaret etme / sevinç (öğretici adımına göre client ister).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local DataService = require(script.Parent.Parent.Data.DataService)

local MermaidService = {}

local ANIM = {
	Sit = "rbxassetid://2506281703", -- R15 oturma
	Wave = "rbxassetid://95216477066555", -- kendi el sallaması (deniz kızı için üretilmişti)
	Point = "rbxassetid://507770453", -- işaret et
	Cheer = "rbxassetid://507770677", -- sevinç
}

local root: BasePart? = nil
local head: BasePart? = nil
local tracks: { [string]: AnimationTrack } = {}
local home: CFrame? = nil
local active: { [Player]: boolean } = {} -- öğreticisi şu an oynayanlar

local function bubble(text: string, seconds: number)
	if not head then
		return
	end
	local old = head:FindFirstChild("MarinaBubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "MarinaBubble"
	gui.Size = UDim2.fromOffset(300, 74)
	gui.StudsOffset = Vector3.new(0, 3.6, 0)
	gui.MaxDistance = 70
	gui.Adornee = head
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(235, 248, 250)
	t.TextColor3 = Color3.fromRGB(30, 80, 110)
	t.Font = Enum.Font.FredokaOne
	t.TextSize = 22
	t.TextWrapped = true
	t.Text = text
	t.Parent = gui
	Instance.new("UICorner", t).CornerRadius = UDim.new(0, 16)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(70, 150, 190)
	st.Thickness = 3
	st.Parent = t
	gui.Parent = head
	task.delay(seconds, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

local function gesture(name: string, seconds: number?)
	local tr = tracks[name]
	if not tr then
		return
	end
	tr.Priority = Enum.AnimationPriority.Action
	tr:Play(0.2)
	task.delay(seconds or 2.6, function()
		tr:Stop(0.3)
	end)
end

local function face(pos: Vector3?)
	if not root or not home then
		return
	end
	local target = home
	if pos then
		local look = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
		if look.Magnitude > 0.1 then
			target = CFrame.lookAt(root.Position, root.Position + look)
		end
	end
	TweenService:Create(root, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { CFrame = target.Rotation + root.Position }):Play()
end

-- en yakın hazine sandığı (atolde)
local function nearestChest(): BasePart?
	if not root then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, m in CollectionService:GetTagged("TreasureChest") do
		if m:IsA("Model") and m:IsDescendantOf(Workspace) then
			local pos = m:GetPivot().Position
			if pos.X > 3000 then
				local d = (pos - root.Position).Magnitude
				if d < bestD then
					best, bestD = m, d
				end
			end
		end
	end
	return best and (best.PrimaryPart or best:FindFirstChildWhichIsA("BasePart", true))
end

local function startTutorial(player: Player)
	if active[player] then
		return
	end
	active[player] = true
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	face(hrp and (hrp :: BasePart).Position)
	Remotes.Event("MermaidStart"):FireClient(player)
	-- güvenlik: client hiç dönmezse kilit kalmasın
	task.delay(240, function()
		active[player] = nil
	end)
end

-- Client'tan: ("mermaid", "Wave"|"Point"|"Cheer") jest | ("mermaid", "done") bitti
function MermaidService.Action(player: Player, what: any): any
	if what == "Wave" or what == "Point" or what == "Cheer" then
		gesture(what, 2.8)
		return true
	elseif what == "done" then
		local data = DataService.Get(player) :: any
		if data then
			data.mermaidDone = true
		end
		active[player] = nil
		face(nil)
		gesture("Cheer", 2.5)
		local chest = nearestChest()
		if chest then
			Remotes.Event("GuideTarget"):FireClient(player, chest, "Treasure chest")
			task.delay(90, function()
				if player.Parent then
					Remotes.Event("GuideTarget"):FireClient(player, nil)
				end
			end)
		end
		return true
	end
	return nil
end

local function setup(model: Model)
	root = model:WaitForChild("HumanoidRootPart") :: BasePart
	head = model:WaitForChild("Head") :: BasePart
	home = root.CFrame
	local hum = model:WaitForChild("Humanoid") :: Humanoid
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local old = model:FindFirstChild("NPCAnimator") -- eski "sürekli el sallar" betiği
	if old then
		old:Destroy()
	end
	for _, t in animator:GetPlayingAnimationTracks() do
		t:Stop(0)
	end
	for name, id in ANIM do
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, tr = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok and tr then
			tracks[name] = tr
		end
	end
	if tracks.Sit then
		tracks.Sit.Looped = true
		tracks.Sit.Priority = Enum.AnimationPriority.Idle
		tracks.Sit:Play()
	end

	-- konuşma düğmesi: yüzünün önünde görünmez nokta
	local pt = Instance.new("Part")
	pt.Name = "TalkPoint"
	pt.Size = Vector3.new(2, 4, 2)
	pt.Transparency = 1
	pt.Anchored = true
	pt.CanCollide = false
	pt.CanTouch = false
	pt.CanQuery = false
	pt.CFrame = CFrame.new(root.Position + root.CFrame.LookVector * 3.2)
	pt.Parent = model
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "TalkPrompt"
	pr.ObjectText = "Marina the Mermaid"
	pr.ActionText = "Talk"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.Parent = pt
	pr.Triggered:Connect(startTutorial)

	-- yaklaşan oyuncu: öğreticiyi görmediyse sinematik başlar; gördüyse sadece selam (3 dk'da bir)
	local seen: { [Player]: number } = {}
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		for _, p in Players:GetPlayers() do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local data = DataService.Get(p) :: any
			if hrp and data and data.introDone and not active[p] and (hrp.Position - root.Position).Magnitude < 45 then
				if not data.mermaidDone then
					if os.clock() - (seen[p] or -999) > 30 then
						seen[p] = os.clock()
						startTutorial(p)
					end
				elseif (hrp.Position - root.Position).Magnitude < 30 and os.clock() - (seen[p] or -999) > 180 then
					seen[p] = os.clock()
					face(hrp.Position)
					bubble("Hello, " .. p.DisplayName .. "! Come talk to me (E)", 5)
					gesture("Wave", 3)
					task.delay(5, function()
						face(nil)
					end)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		seen[p] = nil
		active[p] = nil
	end)
end

function MermaidService.Init()
	task.spawn(function()
		local folder = Workspace:WaitForChild("NPCs", 60)
		local m = folder and folder:WaitForChild("Mermaid Marina", 30)
		if m then
			setup(m)
		else
			warn("[Mermaid] Workspace.NPCs['Mermaid Marina'] bulunamadı")
		end
	end)
end

return MermaidService
