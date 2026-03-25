# RetroMusic

Companion app iOS + watchOS (estetica retro iPod) para enviar y reproducir musica/podcasts desde iPhone a Apple Watch.

## Estructura actual
- `RetroMusicAppiOS/RetroMusicAppiOS`: codigo fuente iOS.
- `RetroMusicAppWatch/RetroMusicAppWatch`: codigo fuente watchOS extension.
- `project.yml`: configuracion XcodeGen para generar el proyecto Xcode.

## Generar proyecto en Mac
1. Instalar XcodeGen:
```bash
brew install xcodegen
```
2. Desde la raiz del repo:
```bash
./scripts/generate_xcode_project.sh
```
3. Abrir:
```bash
open RetroMusic.xcodeproj
```

## Ajustes iniciales en Xcode
1. Seleccionar `Team` en Signing para:
   - `RetroMusiciOS`
   - `RetroMusicWatchApp`
   - `RetroMusicWatchExtension`
2. Verificar bundle IDs si necesitas publicacion/App Store.
3. Ejecutar primero en iPhone Simulator y luego en Apple Watch Simulator vinculado.
