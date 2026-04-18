# AGENTS.md - Guia operativa RetroMusic

## Objetivo del proyecto
- App iOS + watchOS con estetica iPod clasico para musica, podcasts y radio.
- Prioridades de producto: simplicidad, transferencias fiables, watch usable sin iPhone y radio estable.
- Foco actual: autonomia real del Apple Watch y robustez de radio en watchOS.

## Contrato funcional esperado
- El iPhone se usa para importar o descargar musica y podcasts y enviarlos al Apple Watch.
- El modo principal de uso es standalone en el reloj: una vez enviado el contenido, el usuario debe poder salir sin llevar el iPhone.
- En el watch, `Musica` y `Podcast` deben mostrarse y reproducirse como playlist.
- La reproduccion local en watch debe incluir `play`, `pause`, `anterior`, `siguiente`, `seek backward/forward` y barra desplazadora funcional.
- La radio en fase de pruebas puede seguir hardcodeada en codigo.
- Al entrar en `Radio` en el watch, el usuario selecciona una emisora y debe poder reproducirla sin depender del iPhone.
- Emisora de referencia en pruebas: `Pure Ibiza`.
- URL canonica actual de `Pure Ibiza`: `https://pureibizaradio.streaming-pro.com:8028/stream.mp3`

## Orden de lectura rapida
1. `project.yml`
2. `ROADMAP.md`
3. `Shared/Models/AudioTrack.swift`
4. `RetroMusicAppiOS/RetroMusicAppiOS/WatchConnectivityManager.swift`
5. `RetroMusicAppWatch/RetroMusicAppWatch/WatchConnectivityManager.swift`
6. `RetroMusicAppWatch/RetroMusicAppWatch/AudioPlayerManager.swift`
7. `Shared/UI/ContentViewWatch.swift`
8. `RetroMusicAppiOS/RetroMusicAppiOS/ContentView.swift`
9. `RetroMusicAppiOS/RetroMusicAppiOS/AudioTrackListView.swift`
10. `RetroMusicAppiOS/RetroMusicAppiOS/RadioListView.swift`

## Rutas canonicas
- iOS: `RetroMusicAppiOS/RetroMusicAppiOS`
- watchOS: `RetroMusicAppWatch/RetroMusicAppWatch`
- UI compartida viva: `Shared/UI`
- Modelos compartidos: `Shared/Models`
- Proyecto declarativo: `project.yml`
- Proyecto generado: `RetroMusic.xcodeproj` (no editar a mano)

## Mapa real del sistema
- `RetroMusicAppWatch/RetroMusicAppWatch/RetroMusicAppWatch.swift` arranca el reloj con `ContentViewWatch` desde `Shared/UI/ContentViewWatch.swift`.
- `RetroMusicAppWatch/RetroMusicAppWatch/ContentView.swift` existe, pero no es la raiz usada por la app; tratarlo como arbol legacy/no canonico salvo refactor explicito.
- iOS importa audio, lo copia a `Documents` y persiste carpetas en `retromusic_folders.json`.
- iOS envia audio al watch con `WCSession.transferFile`, metadata ligera y limite de 50 MB.
- watch recibe el fichero, lo mueve a `Documents`, hace upsert y persiste en `retromusic_tracks.json`.
- `AudioTrack` persiste `storedFileName`; `filePath` se reconstruye desde `Documents`.
- El motor unico de reproduccion del watch es `AudioPlayerManager`; tambien soporta radio con `isLiveStream`.
- La radio del watch vive hoy en `Shared/UI/ContentViewWatch.swift`.
- La radio del iPhone vive en `RetroMusicAppiOS/RetroMusicAppiOS/RadioListView.swift` y usa Safari/web player; no reproduce el mismo flujo que el watch.

## Estado tecnico confirmado en codigo
- `transferFile` en iOS no depende de `isReachable`.
- La importacion de audio en iOS copia el archivo a `Documents`.
- `AudioTrack` persiste `storedFileName` con compatibilidad de decode para `filePath` legacy.
- La libreria del watch usa JSON en `Documents` (`retromusic_tracks.json`) con migracion desde `UserDefaults`.
- La libreria del iPhone usa JSON en `Documents` (`retromusic_folders.json`) con migracion desde `UserDefaults`.
- El watch hace deduplicacion/upsert por `id` o `storedFileName` al recibir archivos.
- La reproduccion local del watch usa playlist, auto-avance y controles prev/next.
- La radio del watch usa `AudioPlayerManager` en modo `isLiveStream`, sin seek ni duracion fija.
- `scripts/generate_xcode_project.sh` es el comando oficial para regenerar el proyecto desde `project.yml`.

## Riesgos recurrentes detectados
- Autonomia del watch no es lo mismo que WatchConnectivity. Una vez transferido un track, la reproduccion local ya no depende del iPhone. La radio si depende de la red directa del reloj y de URLs de stream reales.
- Catalogo de radio duplicado. El watch usa emisoras en `Shared/UI/ContentViewWatch.swift`; iOS usa otras en `RetroMusicAppiOS/RetroMusicAppiOS/RadioListView.swift`. La URL de Global Radio no coincide entre ambos archivos.
- Para pruebas de radio, `Pure Ibiza` debe tratarse como referencia estable y su URL no debe cambiarse sin validacion manual en watch.
- `RetroMusicAppiOS/RetroMusicAppiOS/RadioListView.swift` contiene ramas `#if os(watchOS)` y un `RadioPlayer` que no forman parte del target watch. No usar ese codigo como fuente de verdad del reloj.
- Persistencia canonica: `retromusic_folders.json` en iOS y `retromusic_tracks.json` en watch. Cualquier referencia nueva a `UserDefaults` o a `watch_tracks.json` debe revisarse antes de reutilizarla.
- Falta observabilidad de radio live. El flujo actual no expone buffering, errores de `AVPlayerItem`, reconexion ni estado de red al usuario.
- Este workspace puede venir sin `.git`. No asumir `git status` ni diffs locales como paso obligatorio.
- Si documentacion y codigo discrepan, mandan `project.yml` y las rutas canonicas anteriores.

## Reglas de implementacion para futuras iteraciones
1. Estructura del proyecto
- No recrear arboles duplicados ni mover modelos fuera de `Shared/Models`.
- No editar `RetroMusic.xcodeproj` a mano; editar `project.yml` y regenerar.
- La UI raiz real del watch esta en `Shared/UI/ContentViewWatch.swift`.

2. WatchConnectivity
- Usar `sendMessage` solo para tiempo real y solo cuando `isReachable` sea necesario.
- Usar `transferFile` para envio diferido; validar `isPaired`, `isWatchAppInstalled`, `activationState` y existencia del fichero.
- Mantener el limite de 50 MB y mostrar errores visibles al usuario.

3. Importacion y persistencia
- Nunca persistir URLs temporales del picker.
- Siempre copiar a `Documents` y guardar `storedFileName`, no una URL absoluta nueva.
- Mantener la persistencia principal en JSON dentro de `Documents`, no en `UserDefaults`.

4. Reproduccion watchOS
- No usar side effects en `body`.
- No pausar por ciclo de vida usando `playPause()` por defecto; exponer metodos explicitos (`pause`, `seek`, `playNextTrack`, `playPreviousTrack`, `stopAudio`).
- Siempre pasar playlist completa al `AudioPlayerManager` para playback local.
- Para radio/live stream, extender `AudioPlayerManager`; no reactivar el `RadioPlayer` embebido en el archivo iOS.

5. Radio
- Hasta centralizar emisoras en un modelo compartido, cualquier cambio de catalogo exige revisar dos archivos: `Shared/UI/ContentViewWatch.swift` y `RetroMusicAppiOS/RetroMusicAppiOS/RadioListView.swift`.
- Para bugs de radio en watch, depurar primero la ruta del reloj y no la vista Safari de iOS.
- Mantener las URLs de radio hardcodeadas mientras el producto siga en fase de pruebas.
- `Pure Ibiza` es la emisora de smoke test y su URL canonica es `https://pureibizaradio.streaming-pro.com:8028/stream.mp3`.
- Validar formato del stream, TLS/ATS y comportamiento con red real del watch antes de tocar UI.
- Los fallos de stream deben terminar en feedback visible, no solo en `print`.

6. Modelos compartidos
- `AudioTrack` y `Folder` deben seguir viviendo en `Shared/Models/`.
- No duplicar modelos por target.

## Playbooks rapidos de diagnostico
### Si el problema es "no llega al watch"
- Revisar `RetroMusicAppiOS/RetroMusicAppiOS/WatchConnectivityManager.swift`.
- Confirmar tamano, fichero en `Documents`, metadata ligera y estado de `WCSession`.
- Revisar `RetroMusicAppWatch/RetroMusicAppWatch/WatchConnectivityManager.swift` para recepcion, move a `Documents` y upsert en `retromusic_tracks.json`.

### Si el problema es "el watch no reproduce sin iPhone"
- Separar primero si falla libreria local o radio.
- Para libreria local: revisar `storedFileName`, reconstruccion de `filePath`, existencia del fichero en `Documents` y `AudioPlayerManager`.
- Para radio: revisar solo `Shared/UI/ContentViewWatch.swift` y `AudioPlayerManager` en modo `isLiveStream`.

### Si el problema es "la radio falla"
- No asumir que es un bug de sync; la radio del watch no usa WatchConnectivity.
- Verificar que la URL usada por el watch es la correcta y no la del iPhone.
- Inspeccionar falta de estados de buffering/error antes de cambiar la arquitectura.

## Skills recomendadas para automatizar contexto
- `retromusic-context-loader`: abre `project.yml`, `ROADMAP.md`, modelos compartidos, ambos `WatchConnectivityManager`, `AudioPlayerManager` y `ContentViewWatch`; devuelve mapa corto del proyecto y drift detectado.
- `retromusic-watch-sync-audit`: valida `transferFile`, limite de 50 MB, rutas JSON, `storedFileName`, upsert y borrado fisico.
- `retromusic-watch-autonomous-debug`: separa fallos de libreria local, radio y dependencia accidental del iPhone.
- `retromusic-radio-stream-validation`: revisa catalogo de emisoras, detecta URLs divergentes entre iOS/watch y obliga a comprobar stream real, formato y feedback de error.
- `retromusic-xcodegen-guard`: valida `project.yml`, targets reales, script de generacion y evita tocar el `xcodeproj` generado.
- `retromusic-doc-drift-check`: compara `README.md`, `ROADMAP.md`, `AGENTS.md` y `CLAUDE.md` para detectar targets o rutas legacy.

## Checklist de QA antes de cerrar cambios
- Importar audio desde Files/iCloud en iOS y reiniciar la app: el track sigue valido.
- Transferir con watch desconectado y reconectar: `transferFile` entra en cola y llega.
- Con el iPhone fuera de la ecuacion, abrir biblioteca del watch y reproducir un track ya transferido.
- Verificar que `Musica` y `Podcast` se presentan como playlist en el watch.
- Reiniciar la app del watch: la biblioteca recibida sigue visible y reproducible.
- Abrir/cerrar `NowPlayingView`: no arranca reproduccion involuntaria ni reinicia el mismo track.
- Mover slider en un track local: cambia la posicion real de reproduccion.
- Abrir radio en el watch con conectividad propia del reloj: `Pure Ibiza` arranca sin depender del iPhone.
- Probar una URL de radio invalida o caida: el usuario recibe feedback claro.
- Verificar que archivos mayores de 50 MB se rechazan con mensaje visible.
- Verificar `play/pause`, `prev/next`, seek backward/forward y auto-avance al finalizar un track local.

## Ejecucion en Mac
- Instalar XcodeGen: `brew install xcodegen`
- Regenerar proyecto: `./scripts/generate_xcode_project.sh`
- Targets esperados:
- `RetroMusiciOS`
- `RetroMusicWatch`
- Schemes utiles:
- `RetroMusiciOS`
- `RetroMusicWatch`
- `RetroMusic`

## Fuente de verdad
- Si hay conflicto entre docs, manda este orden: `project.yml` -> codigo fuente canonico -> `ROADMAP.md` -> `AGENTS.md`/`CLAUDE.md` -> `README.md`.
