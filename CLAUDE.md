# CLAUDE.md - Contexto rapido para Claude Code

## Empieza por aqui
- Lee `AGENTS.md` si necesitas detalle; este archivo es la version rapida para entrar a trabajar.
- Carga primero solo lo necesario: `project.yml`, `ROADMAP.md`, `Shared/Models/AudioTrack.swift`, ambos `WatchConnectivityManager`, `AudioPlayerManager` y `Shared/UI/ContentViewWatch.swift`.

## Rutas canonicas
- iOS: `RetroMusicAppiOS/RetroMusicAppiOS`
- watchOS: `RetroMusicAppWatch/RetroMusicAppWatch`
- UI compartida viva del watch: `Shared/UI/ContentViewWatch.swift`
- Modelos compartidos: `Shared/Models`
- Playback compartido: `Shared/Playback/AudioPlayerManager.swift`
- Configuracion del proyecto: `project.yml`
- Proyecto generado: `RetroMusic.xcodeproj`

## Lo que manda hoy en runtime
- El watch arranca desde `RetroMusicAppWatch/RetroMusicAppWatch/RetroMusicAppWatch.swift` y usa `ContentViewWatch` en `Shared/UI/ContentViewWatch.swift`.
- La libreria local del watch vive en `retromusic_tracks.json`.
- La libreria local del iPhone vive en `retromusic_folders.json`.
- `AudioPlayerManager` es el motor compartido para audio local del watch y radio live en iOS/watchOS.
- `WatchConnectivity` solo sirve para sync entre iPhone y watch; no participa en la radio del watch.

## Contrato de producto a respetar
- El iPhone prepara contenido; el Watch consume contenido sin iPhone.
- `Musica` y `Podcast` deben verse como playlist en el reloj.
- El playback local del watch necesita `play`, `pause`, `anterior`, `siguiente`, seek y barra desplazadora real.
- La radio puede seguir hardcodeada durante pruebas.
- `Pure Ibiza` es la emisora de referencia actual.
- URL canonica de `Pure Ibiza`: `https://pureibizaradio.streaming-pro.com:8028/stream.mp3`

## No te dejes arrastrar por estas trampas
- No edites `RetroMusic.xcodeproj`; edita `project.yml` y regenera.
- No tomes `RetroMusicAppWatch/RetroMusicAppWatch/ContentView.swift` como raiz real del watch; parece legacy/no usada.
- No vuelvas a usar Safari/web player como reproductor principal de radio iOS; la ruta nativa usa `AudioPlayerManager`.
- No dupliques emisoras por target; el catalogo vive en `Shared/Models/RadioStation.swift`.
- No reintroduzcas `UserDefaults` como persistencia principal de libreria.
- No dependas de `git status`; esta copia local puede no tener `.git`.

## Si el problema es autonomia del Apple Watch
- Separa primero audio local transferido vs radio.
- Audio local sin iPhone: revisar `storedFileName`, `retromusic_tracks.json`, `Documents` del watch y `AudioPlayerManager`.
- Radio sin iPhone: revisar `Shared/UI/ContentViewWatch.swift`, URLs reales del stream y la ruta `isLiveStream` en `AudioPlayerManager`.
- No mezcles un fallo de red del watch con un fallo de WatchConnectivity.

## Si el problema es radio
- La fuente de verdad del catalogo esta en `Shared/Models/RadioStation.swift`.
- iOS y watchOS reproducen radio con `AudioPlayerManager`, aunque el watch debe validarse con su propia red real.
- Antes de refactorizar, comprueba si el fallo es una URL mala, una incompatibilidad del stream o falta de estados de error/buffering.
- Usa `Pure Ibiza` como smoke test principal antes de culpar al reproductor.
- Si cambias catalogo de emisoras, revisa `RadioCatalog` y prueba iOS/watch.

## Routines o skills recomendadas
- `retromusic-context-loader`
- `retromusic-watch-sync-audit`
- `retromusic-watch-autonomous-debug`
- `retromusic-radio-stream-validation`
- `retromusic-xcodegen-guard`
- `retromusic-doc-drift-check`

## Verificacion minima
- `./scripts/generate_xcode_project.sh`
- Esquemas utiles: `RetroMusiciOS`, `RetroMusicWatch`, `RetroMusic`
- Confirmar targets `RetroMusiciOS` y `RetroMusicWatch`
- Probar libreria local del watch con el iPhone fuera de la ecuacion
- Probar radio del watch con conectividad propia y error visible si el stream falla
