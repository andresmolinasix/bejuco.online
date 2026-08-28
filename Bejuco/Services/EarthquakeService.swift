import Foundation

struct EarthquakeEvent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let magnitude: Double?
    let place: String?
    let occurredAt: Int64?
    let latitude: Double?
    let longitude: Double?
    let depth: Double?
    let url: String?

    var date: Date? {
        guard let occurredAt else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(occurredAt) / 1_000)
    }

    var isSignificant: Bool {
        (magnitude ?? 0) >= 4.5
    }
}

private struct USGSFeed: Decodable {
    let features: [USGSFeature]
}

private struct USGSFeature: Decodable {
    let id: String
    let properties: USGSProperties
    let geometry: USGSGeometry?
}

private struct USGSProperties: Decodable {
    let mag: Double?
    let place: String?
    let time: Int64?
    let title: String?
    let url: String?
}

private struct USGSGeometry: Decodable {
    let coordinates: [Double]?
}

struct EarthquakeService {
    let feedURLs = [
        URL(string: "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson")!,
        URL(string: "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson")!
    ]

    func fetchLatest() async throws -> [EarthquakeEvent] {
        var lastError: Error?
        for url in feedURLs {
            do {
                let events = try await fetch(url: url)
                if !events.isEmpty { return events }
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        return []
    }

    private func fetch(url: URL) async throws -> [EarthquakeEvent] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let feed = try JSONDecoder().decode(USGSFeed.self, from: data)
        return feed.features.map { feature in
            let coordinates = feature.geometry?.coordinates ?? []
            return EarthquakeEvent(
                id: feature.id,
                title: feature.properties.title ?? "Evento sísmico",
                magnitude: feature.properties.mag,
                place: feature.properties.place,
                occurredAt: feature.properties.time,
                latitude: coordinates.count > 1 ? coordinates[1] : nil,
                longitude: coordinates.isEmpty ? nil : coordinates[0],
                depth: coordinates.count > 2 ? coordinates[2] : nil,
                url: feature.properties.url
            )
        }
        .sorted { ($0.occurredAt ?? 0) > ($1.occurredAt ?? 0) }
    }
}
