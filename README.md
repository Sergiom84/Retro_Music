# RetroMusic

App iOS + watchOS con estetica retro iPod para importar audio en iPhone, transferirlo al Apple Watch y reproducir musica, podcasts y radio.

## Estructura actual
- `RetroMusicAppiOS/RetroMusicAppiOS`: codigo fuente iOS
- `RetroMusicAppWatch/RetroMusicAppWatch`: codigo fuente watchOS
- `Shared/Models`: modelos compartidos (`AudioTrack`, `Folder`)
- `Shared/UI`: UI compartida del watch y componentes comunes
- `project.yml`: configuracion XcodeGen

## Generar proyecto en Mac
1. Instalar XcodeGen:
```bash
brew install xcodegen
```
2. Desde la raiz del proyecto:
```bash
./scripts/generate_xcode_project.sh
```
3. Abrir el proyecto:
```bash
open RetroMusic.xcodeproj
```

## Targets actuales
- `RetroMusiciOS`
- `RetroMusicWatch`

## Schemes utiles
- `RetroMusiciOS`
- `RetroMusicWatch`
- `RetroMusic`

## Notas utiles
- `RetroMusic.xcodeproj` es generado; la fuente de verdad es `project.yml`.
- Para contexto operativo de agentes, ver `AGENTS.md` y `CLAUDE.md`.
- El watch usa un target moderno single-target application; no hay `watch2Extension` legacy.
