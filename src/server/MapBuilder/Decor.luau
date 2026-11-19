--!nonstrict
-- Küçük süsler: palmiye, sandık, fıçı, fener, balık heykeli.
local Util = require(script.Parent.Util)

local Decor = {}

local WOOD = Color3.fromRGB(139, 94, 60)
local DARK = Color3.fromRGB(92, 62, 40)
local STONE = Color3.fromRGB(150, 150, 156)
local LEAF = Color3.fromRGB(70, 150, 62)
local TRUNK = Color3.fromRGB(150, 110, 72)

function Decor.palm(parent, pos, rng)
	local m = Instance.new("Model")
	m.Name = "Palm"
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * rng:NextNumber(1.2, 2.6)
	local h = rng:NextNumber(11, 16)
	local base = Vector3.new(pos.X, pos.Y, pos.Z)
	local top = base + Vector3.new(lean.X, h, lean.Z)
	local prev = base
	for k = 1, 3 do
		local t = k / 3
		local nxt = base + Vector3.new(lean.X * t * t, h * t, lean.Z * t * t)
		Util.rod(m, "Trunk", prev, nxt, 1.6 - 0.35 * t, TRUNK, Enum.Material.Wood)
		prev = nxt
	end
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local tip = top + d * 8 + Vector3.new(0, -3.2, 0)
		local mid = (top + tip) / 2 + Vector3.new(0, 1.4, 0)
		local leaf = Util.part(m, "Leaf", Vector3.new(2.6, 0.25, (tip - top).Magnitude + 1), CFrame.lookAt(mid, tip), LEAF, Enum.Material.Grass)
		leaf.CanCollide = false
	end
	for k = 1, 3 do
		local c = Util.ball(m, "Coconut", Vector3.new(1.1, 1.1, 1.1), CFrame.new(top + Vector3.new(rng:NextNumber(-0.8, 0.8), -1, rng:NextNumber(-0.8, 0.8))), Color3.fromRGB(96, 66, 40))
		c.CanCollide = false
	end
	m.Parent = parent
	return m
end

function Decor.crate(parent, pos, yaw)
	local c = Util.part(parent, "Crate", Vector3.new(3, 3, 3), CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, yaw or 0, 0), WOOD, Enum.Material.WoodPlanks)
	return c
end

function Decor.barrel(parent, pos)
	local b = Util.cyl(parent, "Barrel", 3.4, 2.6, CFrame.new(pos + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Wood)
	return b
end

function Decor.lamp(parent, pos)
	local m = Instance.new("Model")
	m.Name = "Lamp"
	Util.pole(m, "Post", pos.X, pos.Z, pos.Y, pos.Y + 9, 0.7, DARK, Enum.Material.Metal)
	local bulb = Util.ball(m, "Bulb", Vector3.new(1.8, 1.8, 1.8), CFrame.new(pos.X, pos.Y + 9.6, pos.Z), Color3.fromRGB(255, 226, 150), Enum.Material.Neon)
	Util.light(bulb, 1.2, 28)
	m.Parent = parent
	return m
end

-- Balık heykeli: kaide + elips gövde + kuyruk + yüzgeç
function Decor.fishStatue(parent, pos, yaw)
	local m = Instance.new("Model")
	m.Name = "FishStatue"
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	Util.part(m, "Pedestal", Vector3.new(7, 4, 7), cf * CFrame.new(0, 2, 0), STONE, Enum.Material.Cobblestone)
	Util.part(m, "PedestalTop", Vector3.new(8, 1, 8), cf * CFrame.new(0, 4.5, 0), Color3.fromRGB(120, 120, 128), Enum.Material.Slate)
	local gold = Color3.fromRGB(226, 190, 96)
	local y0 = 9
	Util.ball(m, "Body", Vector3.new(11, 5.5, 3.4), cf * CFrame.new(0, y0, 0) * CFrame.Angles(0, 0, math.rad(20)), gold, Enum.Material.Metal)
	Util.ball(m, "Tail1", Vector3.new(4.5, 1, 3.6), cf * CFrame.new(-6.3, y0 + 3.2, 0) * CFrame.Angles(0, 0, math.rad(55)), gold, Enum.Material.Metal)
	Util.ball(m, "Tail2", Vector3.new(4.5, 1, 3.6), cf * CFrame.new(-6.3, y0 + 0.2, 0) * CFrame.Angles(0, 0, math.rad(-20)), gold, Enum.Material.Metal)
	Util.ball(m, "Fin", Vector3.new(3.5, 1.8, 0.6), cf * CFrame.new(0.5, y0 + 3.4, 0) * CFrame.Angles(0, 0, math.rad(15)), gold, Enum.Material.Metal)
	Util.ball(m, "Eye", Vector3.new(0.9, 0.9, 0.9), cf * CFrame.new(3.7, y0 + 1.8, 1.4), Color3.fromRGB(30, 30, 40), Enum.Material.Glass)
	Util.ball(m, "Eye2", Vector3.new(0.9, 0.9, 0.9), cf * CFrame.new(3.7, y0 + 1.8, -1.4), Color3.fromRGB(30, 30, 40), Enum.Material.Glass)
	m.Parent = parent
	return m
end

-- Balık ağı askısı: iki direk ve iplerden ağ
function Decor.netRack(parent, p0, p1, height)
	local m = Instance.new("Model")
	m.Name = "NetRack"
	for _, p in { p0, p1 } do
		Util.pole(m, "Pole", p.X, p.Z, p.Y, p.Y + height, 0.9, DARK, Enum.Material.Wood)
	end
	local top0, top1 = Vector3.new(p0.X, p0.Y + height, p0.Z), Vector3.new(p1.X, p1.Y + height, p1.Z)
	Util.rod(m, "Rope", top0, top1, 0.3, Color3.fromRGB(205, 190, 150), Enum.Material.Fabric)
	local n = math.floor((top1 - top0).Magnitude / 2)
	for i = 0, n do
		local a = top0:Lerp(top1, i / n)
		local len = height * (0.55 + 0.25 * math.abs(math.sin(i * 1.7)))
		local s = Util.part(m, "Strand", Vector3.new(0.2, len, 0.2), CFrame.new(a.X, a.Y - len / 2, a.Z), Color3.fromRGB(205, 190, 150), Enum.Material.Fabric)
		s.CanCollide = false
	end
	m.Parent = parent
	return m
end

return Decor
