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
- [x] `transferFile` usa metadata ligera con artwork optimizado/omitido para mayor estabilidad.
- [x] `NowPlayingView` no pausa automaticamente al salir (reproduccion continua).
- [x] Seek forward/backward actualizado con limites y refresco inmediato de progreso.
- [x] Borrado de pista elimina archivo fisico en iPhone y Watch.

## Hecho en esta iteracion
- [x] Modernizar `project.yml`: target watchOS como `application` (single-target, sin watch2Extension legacy).
- [x] Modelo `AudioTrack` compartido en `Shared/Models/` (eliminada duplicacion iOS/watchOS).
- [x] Modelo `Folder` movido a `Shared/Models/`.
- [x] `AudioTrack` implementa `Equatable`.
- [x] Eliminado `NotificationController.swift` (API WatchKit deprecada en watchOS 10+).
- [x] Persistencia migrada de UserDefaults a archivos JSON en Documents (ambos targets).
- [x] Migracion automatica desde UserDefaults a JSON al primer arranque.
- [x] Limite de tamano de archivo: 200 MB por transferencia al Watch.
- [x] Feedback visual de transferencia en iOS: estados queued/transferring/sent/error.
- [x] Alertas de error visibles al usuario en importacion y transferencia.
- [x] Reproduccion con playlist: auto-avance al siguiente track cuando termina.
- [x] Botones previous/next track en NowPlayingView del Watch.
- [x] Remote Command Center soporta next/previous track.
- [x] Skip backward cambiado a 15s (mas ergonomico en watch).
- [x] `NowPlayingView` no reinicia track si ya esta reproduciendose el mismo.
- [x] Monitorizacion de transferencia con `didFinishFileTransfer` para errores.
- [x] `TARGETED_DEVICE_FAMILY` corregido a solo iPhone ("1").
- [x] `AudioPlayerManager` movido a `Shared/Playback` para radio nativa iOS/watchOS.
- [x] Radio iOS cambiada de Safari/web player a AVPlayer nativo con stream directo.
- [x] Limite real de transferencia ajustado a 200 MB.
- [x] Radio live con buffer inicial, errores visibles y reintentos cortos.
- [x] Marcado manual de pista como musica/podcast para corregir clasificacion.

## Fase 1 - Estabilidad de datos (alta prioridad)
- [x] Migrar persistencia de `AudioTrack.filePath` a `storedFileName` (ruta relativa/filename).
- [x] Crear migracion de compatibilidad para tracks ya guardados con URL absoluta.
- [x] Borrado seguro: cuando se elimina un track, borrar tambien el archivo local asociado.
- [x] Definir limites de tamano por archivo para proteger memoria y almacenamiento del reloj (200 MB).
- [x] Migrar persistencia de UserDefaults a JSON files en Documents.

### Criterio de salida Fase 1 - COMPLETADA
- Reiniciar app iOS/watch no rompe referencias de audio.
- No quedan archivos huerfanos tras borrar tracks.
- Archivos grandes son rechazados con mensaje visible.

## Fase 2 - Sync robusto y rapido (media-alta)
- [x] Deduplicacion basica en watch al recibir archivos repetidos (upsert por `id`/`storedFileName`).
- [x] Estado de sync en iPhone (en cola, enviando, enviado, error).
- [x] Manejo de fallos en transferencias con feedback al usuario.
- [ ] Batch send desde carpeta para envio masivo.
- [ ] Progreso porcentual de transferencia (bytes enviados/total).

### Criterio de salida Fase 2
- Reenviar la misma pista no duplica entries.
- El usuario ve progreso y errores de sincronizacion claramente.

## Fase 3 - UX retro iPod (media)
- [ ] Home con menu claro: `Music`, `Podcasts`, `Settings`.
- [ ] Jerarquia visual consistente iPod-classic (tipografia, espaciado, jerarquia de listas).
- [ ] Caratulas optimizadas/cache para reducir peso en watch.
- [ ] Mejoras de navegacion rapida (ultimas reproducidas, filtros basicos).

### Criterio de salida Fase 3
- Navegacion en watch en <= 3 taps para reproducir.
- UI consistente entre iOS y watch.

## Fase 4 - Limpieza de estructura de repo (alta)
- [x] Dejar solo un arbol fuente canonico.
- [x] Eliminar arboles duplicados.
- [x] Definir generacion estandar de proyecto Xcode con XcodeGen (`project.yml`).
- [x] Modernizar target watchOS a single-target application.
- [x] Modelo compartido en `Shared/Models/`.
- [x] Eliminar NotificationController deprecado.
- [ ] Generar y validar `RetroMusic.xcodeproj` en Mac (pendiente de ejecucion local en macOS).

### Criterio de salida Fase 4
- Un solo set de fuentes + modelos compartidos.
- Build reproducible en Mac sin ambiguedad de rutas.

## Riesgos abiertos
- Validacion final en dispositivo fisico pendiente, especialmente radio con red real del Apple Watch.
- Tracks legacy con URL absoluta previa pueden requerir reimport manual si el archivo original ya no existe.
