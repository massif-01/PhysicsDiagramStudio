import Foundation

struct DiagramRecord: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var prompt: String
    var createdAt: Date
    var slug: String
    var svgFilename: String
    var pngFilename: String
    var htmlFilename: String

    init(
        id: UUID = UUID(),
        title: String,
        prompt: String,
        createdAt: Date = Date(),
        slug: String,
        svgFilename: String,
        pngFilename: String,
        htmlFilename: String
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.createdAt = createdAt
        self.slug = slug
        self.svgFilename = svgFilename
        self.pngFilename = pngFilename
        self.htmlFilename = htmlFilename
    }
}
