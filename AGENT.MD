# AGENT.MD

Punto de entrada humano para agentes del repo.

- Codex y herramientas que entienden instrucciones de agente deben leer `AGENTS.md`.
- Claude Code debe leer `CLAUDE.md`.
- Si hay conflicto entre archivos, manda `project.yml` y el codigo fuente canonico.

## Mapa corto
- Build y targets: `project.yml`
- Modelos compartidos: `Shared/Models`
- Sync iPhone -> watch: ambos `WatchConnectivityManager`
- Playback local y radio nativa: `Shared/Playback/AudioPlayerManager.swift`
- UI raiz real del watch: `Shared/UI/ContentViewWatch.swift`

## Trampas conocidas
- `RetroMusic.xcodeproj` es generado.
- `RetroMusicAppWatch/RetroMusicAppWatch/ContentView.swift` no es la raiz real del watch.
- La radio del watch no depende del iPhone; depende de red propia del reloj y streams validos.
- El catalogo de radio esta centralizado en `Shared/Models/RadioStation.swift`.
- `Pure Ibiza` es la emisora de prueba principal: `https://pureibizaradio.streaming-pro.com:8028/stream.mp3`
