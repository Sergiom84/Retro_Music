# RetroMusic Roadmap (iPhone 16 + Apple Watch Series 9)

## Estado actual (hecho en iteraciones previas)
- [x] iPhone: `transferFileToWatch` ya no depende de `isReachable`.
- [x] iPhone: validaciones de transferencia con `isPaired`, `isWatchAppInstalled`, `activationState`.
- [x] iPhone: al importar audio, se copia a `Documents` y se persiste la URL local.
- [x] iPhone: se elimino side-effect en `ContentView.body` para crear carpeta por defecto.
- [x] Watch: `NowPlayingView.onDisappear` ahora usa `pause()` explicito.
- [x] Watch: slider de progreso conectado con `seek(toProgress:)`.
- [x] Limpieza de arboles duplicados vacios aplicada.
- [x] Base de proyecto Xcode declarativa agregada (`project.yml` + script de generacion).
- [x] Persistencia de `AudioTrack` migrada a `storedFileName` con compatibilidad backward (`filePath` legacy).
- [x] `transferFile` usa metadata ligera (sin `artworkData`) para mayor estabilidad.
- [x] `NowPlayingView` no pausa automaticamente al salir (reproduccion continua).
- [x] Seek forward/backward actualizado con limites y refresco inmediato de progreso.
- [x] Borrado de pista elimina archivo fisico en iPhone y Watch.

## Hecho en iteracion anterior
- [x] Modernizar `project.yml`: target watchOS como `application` (single-target, sin watch2Extension legacy).
- [x] Modelo `AudioTrack` compartido en `Shared/Models/` (eliminada duplicacion iOS/watchOS).
- [x] Modelo `Folder` movido a `Shared/Models/`.
- [x] `AudioTrack` implementa `Equatable`.
- [x] Eliminado `NotificationController.swift` (API WatchKit deprecada en watchOS 10+).
- [x] Persistencia migrada de UserDefaults a archivos JSON en Documents (ambos targets).
- [x] Migracion automatica desde UserDefaults a JSON al primer arranque.
- [x] Limite de tamano de archivo: 50 MB por transferencia al Watch.
- [x] Feedback visual de transferencia en iOS: estados queued/transferring/sent/error.
- [x] Alertas de error visibles al usuario en importacion y transferencia.
- [x] Reproduccion con playlist: auto-avance al siguiente track cuando termina.
- [x] Botones previous/next track en NowPlayingView del Watch.
- [x] Remote Command Center soporta next/previous track.
- [x] Skip backward cambiado a 15s (mas ergonomico en watch).
- [x] `NowPlayingView` no reinicia track si ya esta reproduciendose el mismo.
- [x] Monitorizacion de transferencia con `didFinishFileTransfer` para errores.
- [x] `TARGETED_DEVICE_FAMILY` corregido a solo iPhone ("1").

## Hecho en esta iteracion
- [x] `TransferTrackMetadata` compartido en `Shared/Models/` (eliminada duplicacion iOS/watchOS).
- [x] `AudioPlayerManager` compartido en `Shared/Audio/` (eliminada duplicacion, usado en ambos targets).
- [x] Fix memory leaks: `[unowned self]` reemplazado por `[weak self]` en remote commands.
- [x] Fix memory leaks: `playerItemObservation` se limpia correctamente en `stopAudio()` y `deinit`.
- [x] Fix memory leaks: observer de `AVPlayerItemDidPlayToEndTime` vinculado al playerItem especifico.
- [x] Eliminado polling con `Thread.sleep` en iOS `WatchConnectivityManager`, reemplazado por delegation pura con `didFinish:fileTransfer:error:`.
- [x] Thread safety: `NSLock` para `activeTransfers` en iOS `WatchConnectivityManager`.
- [x] Fix force unwrap: `UTType("public.audio")!` reemplazado por `if let`.
- [x] Fix validacion: carpetas con nombre vacio son rechazadas; nombres duplicados se renombran automaticamente.
- [x] Swipe-to-delete en carpetas y tracks (iOS).
- [x] Swipe-to-delete y boton de borrado en watch.
- [x] Reproduccion en iOS: nuevo `iOSNowPlayingView` con artwork grande, controles completos.
- [x] Click wheel visual funcional en iOS (`IPodClickWheel`): MENU (back), prev, next, play/pause, select.
- [x] Menu principal iOS coincide con mockup: Music, Playlists, Podcasts, Artists, Settings, About.
- [x] Vista de Playlists con "All Songs" y carpetas.
- [x] Vista de Artists agrupada por artista.
- [x] Vista de Podcasts con deteccion mejorada.
- [x] Vista Settings con almacenamiento usado, tamano max de transferencia, estado del Watch.
- [x] Vista About con info de la app.
- [x] Mini barra "Now Playing" en menu principal cuando hay reproduccion activa.
- [x] Shuffle y Repeat (off/all/one) en ambas plataformas.
- [x] `AudioMetadataExtractor` mejorado: fallback robusto, heuristica de podcast mejorada (keywords + genero + duracion), compresion de artwork a max 300px.
- [x] `DocumentPicker` soporta seleccion multiple.
- [x] Batch send: boton para enviar toda la carpeta al Watch de una vez.
- [x] Fix `NowPlayingView` watch: no reinicia si ya esta reproduciendo el mismo track.
- [x] Empty state en Watch cuando no hay tracks.
- [x] Remote Command Center: soporte para `changePlaybackPositionCommand` (scrubbing).
- [x] `project.yml` actualizado: `MediaPlayer.framework` en iOS, excluir `IPodClickWheel.swift` de watchOS.
- [x] Guard contra `isImporting` para evitar race condition en importacion concurrente.

## Fase 1 - Estabilidad de datos - COMPLETADA
- [x] Migrar persistencia de `AudioTrack.filePath` a `storedFileName` (ruta relativa/filename).
- [x] Crear migracion de compatibilidad para tracks ya guardados con URL absoluta.
- [x] Borrado seguro: cuando se elimina un track, borrar tambien el archivo local asociado.
- [x] Definir limites de tamano por archivo para proteger memoria y almacenamiento del reloj (50 MB).
- [x] Migrar persistencia de UserDefaults a JSON files en Documents.

## Fase 2 - Sync robusto y rapido - COMPLETADA
- [x] Deduplicacion basica en watch al recibir archivos repetidos (upsert por `id`/`storedFileName`).
- [x] Estado de sync en iPhone (en cola, enviando, enviado, error).
- [x] Manejo de fallos en transferencias con feedback al usuario.
- [x] Batch send desde carpeta para envio masivo.
- [x] Delegation pura para monitoreo de transferencias (sin polling).

## Fase 3 - UX retro iPod - COMPLETADA
- [x] Home con menu claro: Music, Playlists, Podcasts, Artists, Settings, About.
- [x] Click wheel visual funcional en iOS.
- [x] Reproduccion directa en iOS con NowPlayingView.
- [x] Mini barra de reproduccion en menu principal.
- [x] Shuffle y Repeat (off/all/one).
- [x] Caratulas comprimidas para reducir peso en watch.
- [x] Empty states en watch y podcasts.

## Fase 4 - Limpieza de estructura de repo - COMPLETADA
- [x] Dejar solo un arbol fuente canonico.
- [x] Eliminar arboles duplicados.
- [x] Definir generacion estandar de proyecto Xcode con XcodeGen (`project.yml`).
- [x] Modernizar target watchOS a single-target application.
- [x] Modelo compartido en `Shared/Models/`.
- [x] AudioPlayerManager compartido en `Shared/Audio/`.
- [x] TransferTrackMetadata compartido en `Shared/Models/`.
- [x] Eliminar NotificationController deprecado.
- [ ] Generar y validar `RetroMusic.xcodeproj` en Mac (pendiente de ejecucion local en macOS).

## Riesgos abiertos
- Validacion final de build en Mac pendiente (este entorno no ejecuta Xcode).
- Tracks legacy con URL absoluta previa pueden requerir reimport manual si el archivo original ya no existe.
