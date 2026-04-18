import Foundation

struct RadioStation: Identifiable, Equatable {
    let id: String
    let name: String
    let streamURL: URL
    let watchFallbackStreamURL: URL?
    let webPlayerURL: URL?
}

enum RadioCatalog {
    static let pureIbiza = RadioStation(
        id: "pure-ibiza",
        name: "Pure Ibiza",
        streamURL: URL(string: "https://pureibizaradio.streaming-pro.com:8028/stream.mp3")!,
        watchFallbackStreamURL: URL(string: "http://pureibizaradio.streaming-pro.com:8028/stream.mp3"),
        webPlayerURL: URL(string: "https://www.pureibizaradio.com/player/")
    )

    static let globalRadio = RadioStation(
        id: "global-radio",
        name: "Global Radio",
        streamURL: URL(string: "https://listenssl.ibizaglobalradio.com:8024/ibizaglobalradio.mp3")!,
        watchFallbackStreamURL: nil,
        webPlayerURL: URL(string: "https://www.ibizaglobalradio.com/player-popup.html")
    )

    static let stations: [RadioStation] = [
        pureIbiza,
        globalRadio
    ]
}
