--!nonstrict
-- MapBuilder: haritayı Config/Map.luau'daki ölçülerden kurar.
-- Studio'da (Edit modu) command bar'dan, aşamaları tek tek çalıştırın:
--   local B = require(game.ServerScriptService.Server.MapBuilder)
--   B.Sea() ; B.Land() ; B.Structures() ; B.Islands() ; B.Kayak() ; B.Decor() ; B.Environment()
-- Hepsi için: B.All()   (Önce boş bir place'te deneyin; her aşama eskisini silip yeniden kurar.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = {}

local function cfg()
	-- Clone: Map.luau'yu değiştirince eski önbellek kullanılmasın
	return require(ReplicatedStorage.Shared.Config.Map:Clone())
end

function Builder.Cfg()
	return cfg()
end

function Builder.Sea()
	require(script.Land).sea(cfg())
end

function Builder.Land()
	local c = cfg()
	local Land = require(script.Land)
	Land.islands(c)
end

return Builder
