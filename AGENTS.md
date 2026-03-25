# AGENTS.md - Guia operativa RetroMusic

## Objetivo del proyecto
- App iOS + watchOS tipo iPod clasico para reproducir musica/podcasts.
- iPhone 16 envia contenido al Apple Watch Series 9.
- Prioridades del producto: simple, intuitivo, transferencia rapida y estable.

## Rutas fuente canonicas (usar estas)
- iOS: `RetroMusicAppiOS/RetroMusicAppiOS`
- watchOS: `RetroMusicAppWatch/RetroMusicAppWatch`
- Modelos compartidos: `Shared/Models` (AudioTrack, Folder, TransferTrackMetadata)
- Audio compartido: `Shared/Audio` (AudioPlayerManager)
- UI compartida: `Shared/UI` (IPodTheme, IPodProgressBar, IPodMenuRow, IPodClickWheel)

## Estado de estructura
- Arboles duplicados legacy eliminados.
- Ya no debe recrearse ninguna ruta anidada duplicada.
- Configuracion de proyecto declarativa en `project.yml` (XcodeGen).
- Target watchOS modernizado: tipo `application` (single-target, sin watch2Extension legacy).
- `AudioTrack`, `Folder` y `TransferTrackMetadata` viven en `Shared/Models/` y se compilan en ambos targets.
- `AudioPlayerManager` vive en `Shared/Audio/` y se compila en ambos targets.
- `IPodClickWheel.swift` tiene guard `#if os(iOS)` y se excluye del target watchOS en `project.yml`.
- `NotificationController` eliminado (API WatchKit deprecada en watchOS 10+).

## Estado tecnico ya aplicado
- `transferFile` en iOS no depende de `isReachable`.
- Import de audio en iOS copia archivo a `Documents`.
- `ContentView` iOS sin side-effects dentro de `body`.
- `NowPlayingView` mantiene reproduccion al salir de la vista (sin pausa automatica).
- `NowPlayingView` no reinicia track si ya esta reproduciendo el mismo.
- Slider del watch hace `seek(toProgress:)`.
- `AudioTrack` persiste `storedFileName` (con compatibilidad de decode para `filePath` legacy).
- `AudioTrack` implementa `Equatable` por `id`.
- `transferFile` envia metadata ligera (sin portada binaria) y el watch hace `upsert` para evitar duplicados.
- Al borrar pistas se elimina tambien el archivo fisico en `Documents` (iPhone y Watch).
- Persistencia migrada de `UserDefaults` a archivos JSON en `Documents` (iOS: `retromusic_folders.json`, watchOS: `retromusic_tracks.json`), con migracion automatica desde UserDefaults.
- Limite de tamano de archivo: 50 MB por transferencia al Watch.
- Feedback visual de transferencia en iOS: estados idle/queued/transferring/sent/error con indicadores en la lista.
- Alertas de error visibles al usuario en importacion y transferencia.
- Reproduccion con playlist: auto-avance al siguiente track, botones prev/next en NowPlayingView.
- Remote Command Center soporta next/previous track, skip forward/backward, y scrubbing (changePlaybackPosition).
- Monitoreo de transferencias por delegation pura (`didFinish:fileTransfer:error:`), sin polling.
- Thread safety con `NSLock` para `activeTransfers` en iOS `WatchConnectivityManager`.
- Memory leaks corregidos: `[weak self]` en remote commands, `playerItemObservation` limpio, observer de fin de track vinculado al playerItem.
- Shuffle y Repeat (off/all/one) en ambas plataformas.
- Reproduccion directa en iOS con `iOSNowPlayingView` y click wheel funcional.
- Menu principal iOS: Music, Playlists, Podcasts, Artists, Settings, About.
- Mini barra "Now Playing" en menu principal.
- Batch send: enviar todos los tracks de una carpeta al Watch.
- Artwork comprimido a max 300px y JPEG 0.7 para eficiencia.
- DocumentPicker soporta seleccion multiple.
- Validacion de nombres de carpeta (no vacio, no duplicado).
- Empty states en Watch y Podcasts.

## Reglas de implementacion para futuras iteraciones
1. WatchConnectivity
- Usar `sendMessage` solo para tiempo real (`isReachable`).
- Usar `transferFile` para envio diferido; validar `isPaired`, `isWatchAppInstalled`, `activationState`.
- Siempre validar tamano de archivo antes de transferir (max 50 MB).
- Monitorear transferencias con `didFinish:fileTransfer:error:` (NO polling).
- Usar `NSLock` o similar para thread safety en `activeTransfers`.

2. Importacion de archivos iOS
- Nunca persistir URL temporal del picker.
- Siempre copiar el archivo a `Documents` y guardar esa ruta local.
- Mostrar error visible al usuario si la importacion falla.
- Comprimir artwork al importar (max 300px, JPEG 0.7).

3. SwiftUI
- No mutar `@State` dentro de `body`.
- Inicializacion de datos en `onAppear`/funciones de carga.

4. Reproduccion (ambas plataformas)
- No usar `playPause()` para pausar por ciclo de vida de vista.
- Exponer metodos explicitos (`pause`, `seek`, `playNextTrack`, `playPreviousTrack`).
- Siempre pasar playlist completa al AudioPlayerManager.
- Usar `[weak self]` en todos los closures del AudioPlayerManager.
- Vincular observer de `AVPlayerItemDidPlayToEndTime` al playerItem especifico (no globalmente).

5. Persistencia de AudioTrack
- Persistencia principal: `storedFileName` (ruta relativa), no URL absoluta.
- Reconstruir URL con `documentsDirectory.appendingPathComponent(storedFileName)`.
- Usar archivos JSON en Documents, NO UserDefaults (para evitar problemas con artworkData grandes).

6. Modelos compartidos
- `AudioTrack`, `Folder` y `TransferTrackMetadata` deben estar en `Shared/Models/`.
- `AudioPlayerManager` debe estar en `Shared/Audio/`.
- No duplicar modelos ni managers en cada target.
- `IPodClickWheel` usa `#if os(iOS)` y se excluye de watchOS.

## Checklist de QA antes de cerrar cambios
- Importar audio desde Files/iCloud y reiniciar app iOS: el track sigue valido.
- Transferir con watch desconectado y reconectar: `transferFile` entra en cola y llega.
- Abrir/cerrar `NowPlayingView`: no arranca reproduccion involuntaria.
- Mover slider: cambia posicion real de reproduccion.
- Reiniciar watch app: biblioteca recibida sigue visible y reproducible.
- Verificar que el feedback de transferencia muestra estado correcto (cola, enviando, enviado, error).
- Verificar que archivos > 50 MB son rechazados con mensaje visible.
- Verificar que al terminar un track se reproduce el siguiente automaticamente.
- Verificar botones prev/next en NowPlayingView (iOS y Watch).
- Verificar shuffle y repeat en ambas plataformas.
- Verificar click wheel funcional en iOS (menu, prev, next, play/pause).
- Verificar reproduccion directa en iOS al tocar un track.
- Verificar mini barra "Now Playing" en menu principal iOS.
- Verificar batch send de carpeta completa al Watch.
- Verificar que artwork se comprime correctamente.
- Verificar seleccion multiple en DocumentPicker.
- Verificar validacion de nombre de carpeta vacio/duplicado.
- Verificar empty states en Watch y Podcasts.

## Ejecucion en Mac (recordatorio)
- Este repo usa `project.yml` para generar `RetroMusic.xcodeproj`.
- Comando oficial: `./scripts/generate_xcode_project.sh`.
- Requiere: `brew install xcodegen`.
- Targets esperados:
  - `RetroMusiciOS` (iPhone 16 simulator/device)
  - `RetroMusicWatch` (Apple Watch Series 9 simulator/device, single-target application)

## Plan vigente
- Ver `ROADMAP.md` para fases y criterios de salida.
