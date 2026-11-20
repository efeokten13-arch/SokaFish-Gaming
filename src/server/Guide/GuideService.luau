--!strict
-- Yeni oyuncu rehberi (öğretici sohbetinden sonra): adım adım ok + görev yazısı.
--   1 rod   : Rod Shop'a git, ilk oltanı (bedava) al
--   2 boat  : Boat Shop'a git, ilk tekneni al
--   3 fish  : denizde bir balık tut (balık tutma ipuçları client'ta)
--   4 pool  : adana git, balığı havuza koy (adanın tepeden sinematiği client'ta)
--   5 bitti
-- Kayıt: data.guide (0 = sohbet bitmedi). Diğer servisler adım tamamlanınca GuideService.Event(player, ad) çağırır.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local DataService = require(script.Parent.Parent.Data.DataService)
local MapService = require(script.Parent.Parent.Map.MapService)

local GuideService = {}

GuideService.DONE = 5

local STEPS = {
	[1] = { id = "rod", event = "rod", text = "Get your first fishing rod at the Rod Shop (it's FREE!)" },
	[2] = { id = "boat", event = "boat", text = "Buy your first boat at the Boat Shop" },
	[3] = { id = "fish", event = "catch", text = "Sail out and catch your first fish!" },
	[4] = { id = "pool", event = "pool", text = "Sail to your island and put your fish in the pool" },
}

local GREEN = Color3.fromRGB(120, 230, 150)

local function rodShopTarget(): BasePart?
	local shop = Workspace:FindFirstChild("RodShop")
	local displays = shop and shop:FindFirstChild("Displays")
	local first = displays and displays:FindFirstChild("BranchRod")
	return (first and first:FindFirstChild("BuyPoint")) :: BasePart? or (shop and shop:FindFirstChild("Floor")) :: BasePart?
end

local function boatShopTarget(): BasePart?
	local pier = Workspace:FindFirstChild("Pier")
	local showroom = pier and pier:FindFirstChild("Showroom")
	local first = showroom and showroom:FindFirstChild("Rowboat") :: Model?
	return first and first.PrimaryPart
end

local function islandTarget(player: Player): BasePart?
	local island = MapService.GetIsland(player)
	return island and ((island:FindFirstChild("Dock") or island:FindFirstChild("Spawn")) :: BasePart?)
end

-- O adımın okunu ve görev yazısını gönder
local function announce(player: Player, step: number)
	local s = STEPS[step]
	if not s then
		Remotes.Event("GuideStep"):FireClient(player, "done", nil)
		Remotes.Event("GuideTarget"):FireClient(player, nil)
		return
	end
	local target: BasePart? = nil
	if s.id == "rod" then
		target = rodShopTarget()
	elseif s.id == "boat" then
		target = boatShopTarget()
	elseif s.id == "pool" then
		target = islandTarget(player)
	end
	local island = MapService.GetIsland(player)
	Remotes.Event("GuideStep"):FireClient(player, s.id, s.text, island and island:FindFirstChild("Pool"))
	if target then
		local label = if s.id == "rod" then "Rod Shop" elseif s.id == "boat" then "Boat Shop" else "Your island"
		Remotes.Event("GuideTarget"):FireClient(player, target, label)
	else
		Remotes.Event("GuideTarget"):FireClient(player, nil)
	end
end

function GuideService.Step(player: Player): number
	local data = DataService.Get(player) :: any
	return data and (data.guide or 0) or 0
end

-- Öğretici sohbeti bitince
function GuideService.Start(player: Player)
	local data = DataService.Get(player) :: any
	if not data then
		return
	end
	if (data.guide or 0) < 1 then
		data.guide = 1
	end
	-- oltası zaten varsa (eski kayıt) o adımı atla
	while STEPS[data.guide] and STEPS[data.guide].id == "rod" and #data.ownedRods > 0 do
		data.guide += 1
	end
	while STEPS[data.guide] and STEPS[data.guide].id == "boat" and #data.ownedBoats > 0 do
		data.guide += 1
	end
	DataService.Push(player)
	announce(player, data.guide)
end

-- Oyuna tekrar girişte kaldığı adımı tekrar göster
function GuideService.Resume(player: Player)
	local step = GuideService.Step(player)
	if step >= 1 and step < GuideService.DONE then
		task.delay(2, announce, player, step)
	end
end

-- Bir şey oldu (rod / boat / catch / pool): şu anki adımın olayıysa sonraki adıma geç
function GuideService.Event(player: Player, event: string)
	local data = DataService.Get(player) :: any
	if not data then
		return
	end
	local step = data.guide or 0
	local s = STEPS[step]
	if not s or s.event ~= event then
		return
	end
	data.guide = step + 1
	DataService.Push(player)
	local nextStep = STEPS[data.guide]
	if nextStep then
		DataService.Notify(player, "✅ Nice job! Next: " .. nextStep.text, GREEN)
	else
		DataService.Notify(player, "🎉 You're a real fisher now! Your pool earns coins every minute.", GREEN)
	end
	task.delay(1.2, announce, player, data.guide)
end

function GuideService.Init() end

return GuideService
