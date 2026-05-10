import Foundation

enum Slug {
    static func make(from title: String) -> String {
        let latin = title.applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) ?? title
        let allowed = CharacterSet.alphanumerics
        let parts = latin.lowercased().unicodeScalars.split { scalar in
            !allowed.contains(scalar)
        }
        let slug = parts.map(String.init).joined(separator: "-")
        return slug.isEmpty ? "physics-diagram" : String(slug.prefix(48))
    }
}
