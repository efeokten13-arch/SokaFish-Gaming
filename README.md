# SokaFish-Gaming

Roblox fishing game. Oyun tasarımı: [docs/game-design.md](docs/game-design.md)

## Nasıl çalışıyoruz

- **Scriptler (kod) bu depoda.** `src/` klasörü Rojo ile Roblox Studio'ya aktarılır.
  - `src/server` -> ServerScriptService.Server
  - `src/client` -> StarterPlayer.StarterPlayerScripts.Client
  - `src/shared` -> ReplicatedStorage.Shared
- **Harita ve modeller (ada, iskele, kayık) Studio'da, Team Create ile.** Place dosyaları (`.rbxl`) Git'e girmez.
- Scriptleri **sadece depodaki dosyadan** düzenleyin, Studio'nun içinden değil. Yoksa Rojo bağlanınca değişiklikler ezilir.
- Her kişi kendi branch'inde çalışır, sonra Pull Request ile birleştirilir.
- **Gizli bilgiler (API anahtarı, şifre) depoya asla yazılmaz.**

## Kurulum (herkes bir kez)

1. [GitHub Desktop](https://desktop.github.com) ve [Visual Studio Code](https://code.visualstudio.com) kur.
2. Bu depoyu GitHub Desktop ile clone'la.
3. VS Code'da **Rojo** eklentisini kur.
4. Roblox Studio'da Rojo eklentisini (plugin) kur.
5. VS Code'da depo klasörünü aç, alt çubuktan Rojo sunucusunu başlat, Studio'da Rojo eklentisinde **Connect**'e bas.

## Klasörler

```
default.project.json   Rojo ayarı (hangi klasör Studio'da nereye gider)
src/server/            sunucu scriptleri (BoatController)
src/client/            oyuncu tarafı scriptleri (RowingAnimation)
src/shared/            ortak kodlar ve ayarlar
docs/                  tasarım notları
```
