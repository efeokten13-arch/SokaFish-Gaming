--!nonstrict
-- ESKİ: tekneler artık Boat/BoatModels.luau'da üretilir ve iskeleden satın alınır (BoatService).
-- Bu dosya geriye dönük uyumluluk için duruyor; silinebilir.
local Kayak = {}
function Kayak.Build()
	warn("[MapBuilder] Kayak.Build kullanılmıyor; tekneler BoatService ile satılıyor")
end
return Kayak
