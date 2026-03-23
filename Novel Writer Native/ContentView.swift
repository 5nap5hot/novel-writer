import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers
import Security

private let nativeBulletPrefix = "- "

enum NativeStorageAccessError: LocalizedError {
    case securityScopeUnavailable(URL)

    var errorDescription: String? {
        switch self {
        case let .securityScopeUnavailable(url):
            return "Folder access is no longer available for \(url.lastPathComponent). Choose Folder again to reconnect this Mac to the shared project location."
        }
    }
}

enum NativeDocumentImportError: LocalizedError {
    case unreadableWordDocument(details: String?)

    var errorDescription: String? {
        switch self {
        case let .unreadableWordDocument(details):
            if let details, !details.isEmpty {
                return "This Word document couldn't be read as importable text. \(details)"
            }
            return "This Word document couldn't be read as importable text."
        }
    }
}

enum NativeBuildInfo {
    static var displayVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let marketing = (info["CFBundleShortVersionString"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let build = (info["CFBundleVersion"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (marketing?.nilIfEmpty, build?.nilIfEmpty) {
        case let (version?, build?) where version != build:
            return "Version \(version) (\(build))"
        case let (version?, _):
            return "Version \(version)"
        case let (_, build?):
            return "Build \(build)"
        default:
            return "Development Build"
        }
    }
}

enum NativeTheme {
    private static func adaptive(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        }
    }

    static let paper1 = adaptive(
        light: NSColor(calibratedRed: 1.00, green: 0.984, blue: 0.961, alpha: 1),
        dark: NSColor(calibratedRed: 0.153, green: 0.118, blue: 0.098, alpha: 1)
    )
    static let paper2 = adaptive(
        light: NSColor(calibratedRed: 1.00, green: 0.980, blue: 0.957, alpha: 1),
        dark: NSColor(calibratedRed: 0.188, green: 0.145, blue: 0.122, alpha: 1)
    )
    static let paper3 = adaptive(
        light: NSColor(calibratedRed: 0.984, green: 0.965, blue: 0.933, alpha: 1),
        dark: NSColor(calibratedRed: 0.133, green: 0.106, blue: 0.090, alpha: 1)
    )
    static let ink1 = adaptive(
        light: NSColor(calibratedRed: 0.114, green: 0.106, blue: 0.094, alpha: 1),
        dark: NSColor(calibratedRed: 0.973, green: 0.937, blue: 0.894, alpha: 1)
    )
    static let ink2 = adaptive(
        light: NSColor(calibratedRed: 0.239, green: 0.173, blue: 0.110, alpha: 1),
        dark: NSColor(calibratedRed: 0.957, green: 0.918, blue: 0.863, alpha: 1)
    )
    static let ink3 = adaptive(
        light: NSColor(calibratedRed: 0.373, green: 0.306, blue: 0.251, alpha: 1),
        dark: NSColor(calibratedRed: 0.788, green: 0.706, blue: 0.631, alpha: 1)
    )
    static let muted = adaptive(
        light: NSColor(calibratedRed: 0.490, green: 0.361, blue: 0.271, alpha: 1),
        dark: NSColor(calibratedRed: 0.800, green: 0.722, blue: 0.651, alpha: 1)
    )
    static let accent = adaptive(
        light: NSColor(calibratedRed: 0.620, green: 0.310, blue: 0.176, alpha: 1),
        dark: NSColor(calibratedRed: 0.808, green: 0.482, blue: 0.263, alpha: 1)
    )
    static let accentStrong = adaptive(
        light: NSColor(calibratedRed: 0.482, green: 0.247, blue: 0.145, alpha: 1),
        dark: NSColor(calibratedRed: 0.675, green: 0.412, blue: 0.259, alpha: 1)
    )
    static let accentSoft = adaptive(
        light: NSColor(calibratedRed: 0.886, green: 0.765, blue: 0.667, alpha: 1),
        dark: NSColor(calibratedRed: 0.478, green: 0.380, blue: 0.310, alpha: 1)
    )
    static let selection = adaptive(
        light: NSColor(calibratedRed: 0.886, green: 0.765, blue: 0.667, alpha: 0.96),
        dark: NSColor(calibratedRed: 0.478, green: 0.380, blue: 0.310, alpha: 0.82)
    )
    static let panel = adaptive(
        light: NSColor(calibratedRed: 1.00, green: 0.979, blue: 0.953, alpha: 0.94),
        dark: NSColor(calibratedRed: 0.188, green: 0.145, blue: 0.122, alpha: 0.94)
    )
    static let panelSoft = adaptive(
        light: NSColor(calibratedRed: 0.984, green: 0.965, blue: 0.933, alpha: 0.88),
        dark: NSColor(calibratedRed: 0.153, green: 0.118, blue: 0.098, alpha: 0.88)
    )
    static let border = adaptive(
        light: NSColor(calibratedRed: 0.698, green: 0.600, blue: 0.525, alpha: 0.22),
        dark: NSColor(calibratedRed: 0.800, green: 0.722, blue: 0.651, alpha: 0.18)
    )
    static let divider = adaptive(
        light: NSColor(calibratedRed: 0.620, green: 0.310, blue: 0.176, alpha: 0.16),
        dark: NSColor(calibratedRed: 0.800, green: 0.722, blue: 0.651, alpha: 0.16)
    )
    static let primaryButtonText = NSColor(calibratedRed: 1.0, green: 0.976, blue: 0.941, alpha: 1)

    static var paper1Color: Color { Color(nsColor: paper1) }
    static var paper2Color: Color { Color(nsColor: paper2) }
    static var paper3Color: Color { Color(nsColor: paper3) }
    static var ink1Color: Color { Color(nsColor: ink1) }
    static var ink2Color: Color { Color(nsColor: ink2) }
    static var ink3Color: Color { Color(nsColor: ink3) }
    static var mutedColor: Color { Color(nsColor: muted) }
    static var accentColor: Color { Color(nsColor: accent) }
    static var accentSoftColor: Color { Color(nsColor: accentSoft) }
    static var selectionColor: Color { Color(nsColor: selection) }
    static var panelColor: Color { Color(nsColor: panel) }
    static var panelSoftColor: Color { Color(nsColor: panelSoft) }
    static var borderColor: Color { Color(nsColor: border) }
    static var dividerColor: Color { Color(nsColor: divider) }

    static func interfaceFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Avenir Next", size: size).weight(weight)
    }

    static func displayFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Iowan Old Style", size: size).weight(weight)
    }

    static var projectCardGradient: LinearGradient {
        LinearGradient(
            colors: [paper1Color, paper3Color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct NativeProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NativeTheme.interfaceFont(size: 13, weight: .semibold))
            .foregroundStyle(Color(nsColor: NativeTheme.primaryButtonText))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? NativeTheme.accentColor.opacity(0.88) : NativeTheme.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NativeTheme.accentSoftColor.opacity(0.45), lineWidth: 1)
            )
    }
}

struct NativeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
            .foregroundStyle(NativeTheme.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(NativeTheme.panelSoftColor.opacity(configuration.isPressed ? 0.72 : 1.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(NativeTheme.borderColor, lineWidth: 1)
            )
    }
}

struct NativeSecondaryIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(NativeTheme.accentColor)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(NativeTheme.panelSoftColor.opacity(configuration.isPressed ? 0.72 : 1.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(NativeTheme.borderColor, lineWidth: 1)
            )
    }
}

struct NativeCharacterStyleGuide: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var styleNotes: String
    var visualDescription: String
    var approvedWords: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case styleNotes
        case visualDescription
        case approvedWords
    }

    init(
        id: UUID,
        name: String,
        styleNotes: String,
        visualDescription: String = "",
        approvedWords: [String]
    ) {
        self.id = id
        self.name = name
        self.styleNotes = styleNotes
        self.visualDescription = visualDescription
        self.approvedWords = approvedWords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        styleNotes = try container.decodeIfPresent(String.self, forKey: .styleNotes) ?? ""
        visualDescription = try container.decodeIfPresent(String.self, forKey: .visualDescription) ?? ""
        approvedWords = try container.decodeIfPresent([String].self, forKey: .approvedWords) ?? []
    }
}

struct NativePodcastSetup: Equatable, Codable {
    var podcastTitle: String
    var hostDisplayName: String
    var websiteURL: String
    var applePodcastURL: String
    var spotifyURL: String
    var youtubeURL: String
    var newsletterURL: String
    var callToAction: String

    init(
        podcastTitle: String = "",
        hostDisplayName: String = "",
        websiteURL: String = "",
        applePodcastURL: String = "",
        spotifyURL: String = "",
        youtubeURL: String = "",
        newsletterURL: String = "",
        callToAction: String = ""
    ) {
        self.podcastTitle = podcastTitle
        self.hostDisplayName = hostDisplayName
        self.websiteURL = websiteURL
        self.applePodcastURL = applePodcastURL
        self.spotifyURL = spotifyURL
        self.youtubeURL = youtubeURL
        self.newsletterURL = newsletterURL
        self.callToAction = callToAction
    }
}

struct NativeChapterPodcastPrep: Equatable, Codable {
    var episodeTitle: String
    var previousEpisodeSummaryVoice: String
    var previousEpisodeSummary: String
    var introVoice: String
    var outroVoice: String
    var introText: String
    var outroText: String
    var podcastDescription: String
    var coverArtPrompt: String
    var facebookPost: String
    var tumblrPost: String
    var instagramPost: String
    var pinterestPost: String
    var redditPost: String
    var xPost: String

    init(
        episodeTitle: String = "",
        previousEpisodeSummaryVoice: String = "",
        previousEpisodeSummary: String = "",
        introVoice: String = "",
        outroVoice: String = "",
        introText: String = "",
        outroText: String = "",
        podcastDescription: String = "",
        coverArtPrompt: String = "",
        facebookPost: String = "",
        tumblrPost: String = "",
        instagramPost: String = "",
        pinterestPost: String = "",
        redditPost: String = "",
        xPost: String = ""
    ) {
        self.episodeTitle = episodeTitle
        self.previousEpisodeSummaryVoice = previousEpisodeSummaryVoice
        self.previousEpisodeSummary = previousEpisodeSummary
        self.introVoice = introVoice
        self.outroVoice = outroVoice
        self.introText = introText
        self.outroText = outroText
        self.podcastDescription = podcastDescription
        self.coverArtPrompt = coverArtPrompt
        self.facebookPost = facebookPost
        self.tumblrPost = tumblrPost
        self.instagramPost = instagramPost
        self.pinterestPost = pinterestPost
        self.redditPost = redditPost
        self.xPost = xPost
    }

    enum CodingKeys: String, CodingKey {
        case episodeTitle
        case previousEpisodeSummaryVoice
        case previousEpisodeSummary
        case introVoice
        case outroVoice
        case introText
        case outroText
        case podcastDescription = "podcastSummary"
        case coverArtPrompt
        case facebookPost
        case tumblrPost
        case instagramPost
        case pinterestPost
        case redditPost
        case xPost
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episodeTitle = try container.decodeIfPresent(String.self, forKey: .episodeTitle) ?? ""
        previousEpisodeSummaryVoice = try container.decodeIfPresent(String.self, forKey: .previousEpisodeSummaryVoice) ?? ""
        previousEpisodeSummary = try container.decodeIfPresent(String.self, forKey: .previousEpisodeSummary) ?? ""
        introVoice = try container.decodeIfPresent(String.self, forKey: .introVoice) ?? ""
        outroVoice = try container.decodeIfPresent(String.self, forKey: .outroVoice) ?? ""
        introText = try container.decodeIfPresent(String.self, forKey: .introText) ?? ""
        outroText = try container.decodeIfPresent(String.self, forKey: .outroText) ?? ""
        podcastDescription = try container.decodeIfPresent(String.self, forKey: .podcastDescription) ?? ""
        coverArtPrompt = try container.decodeIfPresent(String.self, forKey: .coverArtPrompt) ?? ""
        facebookPost = try container.decodeIfPresent(String.self, forKey: .facebookPost) ?? ""
        tumblrPost = try container.decodeIfPresent(String.self, forKey: .tumblrPost) ?? ""
        instagramPost = try container.decodeIfPresent(String.self, forKey: .instagramPost) ?? ""
        pinterestPost = try container.decodeIfPresent(String.self, forKey: .pinterestPost) ?? ""
        redditPost = try container.decodeIfPresent(String.self, forKey: .redditPost) ?? ""
        xPost = try container.decodeIfPresent(String.self, forKey: .xPost) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(episodeTitle, forKey: .episodeTitle)
        try container.encode(previousEpisodeSummaryVoice, forKey: .previousEpisodeSummaryVoice)
        try container.encode(previousEpisodeSummary, forKey: .previousEpisodeSummary)
        try container.encode(introVoice, forKey: .introVoice)
        try container.encode(outroVoice, forKey: .outroVoice)
        try container.encode(introText, forKey: .introText)
        try container.encode(outroText, forKey: .outroText)
        try container.encode(podcastDescription, forKey: .podcastDescription)
        try container.encode(coverArtPrompt, forKey: .coverArtPrompt)
        try container.encode(facebookPost, forKey: .facebookPost)
        try container.encode(tumblrPost, forKey: .tumblrPost)
        try container.encode(instagramPost, forKey: .instagramPost)
        try container.encode(pinterestPost, forKey: .pinterestPost)
        try container.encode(redditPost, forKey: .redditPost)
        try container.encode(xPost, forKey: .xPost)
    }
}

enum NativePodcastPrepSection: String, CaseIterable, Identifiable {
    case previousEpisodeSummary
    case intro
    case outro
    case podcastDescription
    case coverArtPrompt
    case facebook
    case tumblr
    case instagram
    case pinterest
    case reddit
    case x

    var id: String { rawValue }

    var title: String {
        switch self {
        case .previousEpisodeSummary: return "Previous Episode Summary"
        case .intro: return "Intro"
        case .outro: return "Outro"
        case .podcastDescription: return "Podcast Description"
        case .coverArtPrompt: return "Cover Art Prompt"
        case .facebook: return "Facebook"
        case .tumblr: return "Tumblr"
        case .instagram: return "Instagram"
        case .pinterest: return "Pinterest"
        case .reddit: return "Reddit"
        case .x: return "X"
        }
    }

    var jsonFieldName: String {
        switch self {
        case .previousEpisodeSummary: return "previous_episode_summary"
        case .intro: return "intro_text"
        case .outro: return "outro_text"
        case .podcastDescription: return "podcast_summary"
        case .coverArtPrompt: return "cover_art_prompt"
        case .facebook: return "facebook_post"
        case .tumblr: return "tumblr_post"
        case .instagram: return "instagram_post"
        case .pinterest: return "pinterest_post"
        case .reddit: return "reddit_post"
        case .x: return "x_post"
        }
    }

    var generationInstruction: String {
        switch self {
        case .previousEpisodeSummary:
            return "Generate only a concise but meaningful recap of the previous episode for use near the top of the intro. This is a true previously-on recap, not teaser copy, so it may mention the important events and emotional turn of the prior episode. Aim for roughly 60 to 100 words unless the episode was especially slight. First infer the dominant POV or voice in the previous episode, then write the recap from the opposite POV. If a recap voice is already selected, use that selected character voice for the recap."
        case .intro:
            return "Generate only the intro script and intro voice. Make it spoiler-safe, mention the podcast title plus episode number/title, and keep it welcoming without previewing episode events beat-by-beat."
        case .outro:
            return "Generate only the outro script and outro voice. Include the season/episode/title cleanly, reflect lightly on the episode, keep spoilers controlled, and use simple platform mentions instead of reading out full URLs."
        case .podcastDescription:
            return "Generate only the podcast description suitable for listings, show notes, or TV-guide-style episode copy. It should tease the episode without summarizing it, stay concise, accurate, spoiler-aware, and remain grounded only in explicit episode facts."
        case .coverArtPrompt:
            return "Generate only the cover art prompt for a single high-impact cinematic image suitable for AI image generation. After choosing the scene, double-check the prompt details against the episode text and any character visual descriptions."
        case .facebook:
            return "Generate only the Facebook post. It should feel native to Facebook and may be a little fuller than the shortest platforms."
        case .tumblr:
            return "Generate only the Tumblr post. It can be atmospheric and slightly more literary while still being post-ready."
        case .instagram:
            return "Generate only the Instagram post. Keep it concise, visually oriented, and suitable for caption use."
        case .pinterest:
            return "Generate only the Pinterest post. Focus on search-friendly, image-supportive copy."
        case .reddit:
            return "Generate only the Reddit post. Keep it platform-aware, non-hypey, and community-friendly."
        case .x:
            return "Generate only the X post. Keep it compact, punchy, and spoiler-aware."
        }
    }
}

private struct NativePodcastPrepSectionResponse: Decodable {
    let previousEpisodeSummaryVoice: String?
    let introVoice: String?
    let outroVoice: String?
    let text: String?

    enum CodingKeys: String, CodingKey {
        case previousEpisodeSummaryVoice = "previous_episode_summary_voice"
        case introVoice = "intro_voice"
        case outroVoice = "outro_voice"
        case text
    }
}

struct NativeAudioPronunciationReplacement: Identifiable, Equatable, Codable {
    let id: UUID
    var writtenForm: String
    var spokenForm: String
    var notes: String
    var isEnabled: Bool

    init(
        id: UUID,
        writtenForm: String,
        spokenForm: String,
        notes: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.writtenForm = writtenForm
        self.spokenForm = spokenForm
        self.notes = notes
        self.isEnabled = isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        writtenForm = try container.decodeIfPresent(String.self, forKey: .writtenForm) ?? ""
        spokenForm = try container.decodeIfPresent(String.self, forKey: .spokenForm) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

struct NativeProject: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var updatedAt: Date
    var styleNotes: String
    var approvedWords: [String]
    var narrativePerson: String
    var narrativeTense: String
    var genre: String
    var subgenre: String
    var storyPromise: String
    var pacingNotes: String
    var avoidNotes: String
    var continuityMemory: String
    var isPodcastProject: Bool
    var podcastSetup: NativePodcastSetup
    var characterStyles: [NativeCharacterStyleGuide]
    var audioPronunciationReplacements: [NativeAudioPronunciationReplacement]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case updatedAt
        case styleNotes
        case approvedWords
        case narrativePerson
        case narrativeTense
        case genre
        case subgenre
        case storyPromise
        case pacingNotes
        case avoidNotes
        case continuityMemory
        case isPodcastProject
        case podcastSetup
        case characterStyles
        case audioPronunciationReplacements
    }

    init(
        id: UUID,
        title: String,
        updatedAt: Date,
        styleNotes: String,
        approvedWords: [String],
        narrativePerson: String = "",
        narrativeTense: String = "",
        genre: String = "",
        subgenre: String = "",
        storyPromise: String = "",
        pacingNotes: String = "",
        avoidNotes: String = "",
        continuityMemory: String = "",
        isPodcastProject: Bool = false,
        podcastSetup: NativePodcastSetup = NativePodcastSetup(),
        characterStyles: [NativeCharacterStyleGuide] = [],
        audioPronunciationReplacements: [NativeAudioPronunciationReplacement] = []
    ) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
        self.styleNotes = styleNotes
        self.approvedWords = approvedWords
        self.narrativePerson = narrativePerson
        self.narrativeTense = narrativeTense
        self.genre = genre
        self.subgenre = subgenre
        self.storyPromise = storyPromise
        self.pacingNotes = pacingNotes
        self.avoidNotes = avoidNotes
        self.continuityMemory = continuityMemory
        self.isPodcastProject = isPodcastProject
        self.podcastSetup = podcastSetup
        self.characterStyles = characterStyles
        self.audioPronunciationReplacements = audioPronunciationReplacements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        styleNotes = try container.decodeIfPresent(String.self, forKey: .styleNotes) ?? ""
        approvedWords = try container.decodeIfPresent([String].self, forKey: .approvedWords) ?? []
        narrativePerson = try container.decodeIfPresent(String.self, forKey: .narrativePerson) ?? ""
        narrativeTense = try container.decodeIfPresent(String.self, forKey: .narrativeTense) ?? ""
        genre = try container.decodeIfPresent(String.self, forKey: .genre) ?? ""
        subgenre = try container.decodeIfPresent(String.self, forKey: .subgenre) ?? ""
        storyPromise = try container.decodeIfPresent(String.self, forKey: .storyPromise) ?? ""
        pacingNotes = try container.decodeIfPresent(String.self, forKey: .pacingNotes) ?? ""
        avoidNotes = try container.decodeIfPresent(String.self, forKey: .avoidNotes) ?? ""
        continuityMemory = try container.decodeIfPresent(String.self, forKey: .continuityMemory) ?? ""
        isPodcastProject = try container.decodeIfPresent(Bool.self, forKey: .isPodcastProject) ?? false
        podcastSetup = try container.decodeIfPresent(NativePodcastSetup.self, forKey: .podcastSetup) ?? NativePodcastSetup()
        characterStyles = try container.decodeIfPresent([NativeCharacterStyleGuide].self, forKey: .characterStyles) ?? []
        audioPronunciationReplacements = try container.decodeIfPresent([NativeAudioPronunciationReplacement].self, forKey: .audioPronunciationReplacements) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(styleNotes, forKey: .styleNotes)
        try container.encode(approvedWords, forKey: .approvedWords)
        try container.encode(narrativePerson, forKey: .narrativePerson)
        try container.encode(narrativeTense, forKey: .narrativeTense)
        try container.encode(genre, forKey: .genre)
        try container.encode(subgenre, forKey: .subgenre)
        try container.encode(storyPromise, forKey: .storyPromise)
        try container.encode(pacingNotes, forKey: .pacingNotes)
        try container.encode(avoidNotes, forKey: .avoidNotes)
        try container.encode(continuityMemory, forKey: .continuityMemory)
        try container.encode(isPodcastProject, forKey: .isPodcastProject)
        try container.encode(podcastSetup, forKey: .podcastSetup)
        try container.encode(characterStyles, forKey: .characterStyles)
        try container.encode(audioPronunciationReplacements, forKey: .audioPronunciationReplacements)
    }
}

struct NativeChapter: Identifiable, Equatable, Codable {
    let id: UUID
    let projectID: UUID
    var title: String
    var order: Int
    var podcastPrep: NativeChapterPodcastPrep

    enum CodingKeys: String, CodingKey {
        case id
        case projectID
        case title
        case order
        case podcastPrep
    }

    init(id: UUID, projectID: UUID, title: String, order: Int, podcastPrep: NativeChapterPodcastPrep = NativeChapterPodcastPrep()) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.order = order
        self.podcastPrep = podcastPrep
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        projectID = try container.decode(UUID.self, forKey: .projectID)
        title = try container.decode(String.self, forKey: .title)
        order = try container.decode(Int.self, forKey: .order)
        podcastPrep = try container.decodeIfPresent(NativeChapterPodcastPrep.self, forKey: .podcastPrep) ?? NativeChapterPodcastPrep()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(projectID, forKey: .projectID)
        try container.encode(title, forKey: .title)
        try container.encode(order, forKey: .order)
        try container.encode(podcastPrep, forKey: .podcastPrep)
    }
}

struct NativeScene: Identifiable, Equatable, Codable {
    let id: UUID
    let projectID: UUID
    var chapterID: UUID
    var title: String
    var order: Int
    var body: String
    var richTextRTF: Data?
}

struct NativeProjectBackupPackage: Codable {
    let exportedAt: Date
    let appVersion: String
    let project: NativeProject
    let chapters: [NativeChapter]
    let scenes: [NativeScene]
}

enum NativeExportPreset: String, CaseIterable, Identifiable {
    case standardManuscript
    case kdpPaperback
    case kdpHardcover

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standardManuscript:
            return "Standard Manuscript"
        case .kdpPaperback:
            return "KDP Paperback"
        case .kdpHardcover:
            return "KDP Hardcover"
        }
    }

    var outputFormat: NativeExportOutputFormat {
        switch self {
        case .standardManuscript:
            return .plainText
        case .kdpPaperback, .kdpHardcover:
            return .docx
        }
    }

    var panelTitle: String {
        switch self {
        case .standardManuscript:
            return "Export Standard Manuscript"
        case .kdpPaperback:
            return "Export KDP Paperback DOCX"
        case .kdpHardcover:
            return "Export KDP Hardcover DOCX"
        }
    }

    var panelMessage: String {
        switch self {
        case .standardManuscript:
            return "Save a readable manuscript export of this project."
        case .kdpPaperback:
            return "Save a DOCX tuned for KDP paperback defaults: 6 x 9 trim, chapter page breaks, readable body styling, and print-friendly spacing."
        case .kdpHardcover:
            return "Save a DOCX tuned for KDP hardcover defaults: 6 x 9 trim, chapter page breaks, readable body styling, and hardcover-safe page-count assumptions."
        }
    }

    var fileExtension: String {
        switch outputFormat {
        case .plainText:
            return "txt"
        case .docx:
            return "docx"
        }
    }

    var filenameSuffix: String {
        switch self {
        case .standardManuscript:
            return "manuscript"
        case .kdpPaperback:
            return "kdp-paperback"
        case .kdpHardcover:
            return "kdp-hardcover"
        }
    }
}

enum NativeExportOutputFormat {
    case plainText
    case docx
}

enum NativeBinderExportScope {
    case chapter(UUID)
    case scene(UUID)
    case selected

    var label: String {
        switch self {
        case .chapter:
            return "Chapter"
        case .scene:
            return "Scene"
        case .selected:
            return "Selected"
        }
    }
}

private struct NativeImportedSceneDraft {
    let title: String
    let body: String
    let richTextRTF: Data?
}

private struct NativeImportedChapterDraft {
    let title: String
    let scenes: [NativeImportedSceneDraft]
}

enum BinderSelectionKey: Equatable, Codable {
    case chapter(UUID)
    case scene(UUID)
}

enum BinderDropTarget: Equatable {
    case chapter(UUID)
    case scene(UUID)
}

enum NativeUndoPayload {
    case project(UUID)
    case chapter(UUID)
    case scene(UUID)
    case createdChapter(UUID)
    case createdScene(UUID)
}

struct NativeUndoState {
    let message: String
    let payload: NativeUndoPayload
}

enum NativeEditorFontSize: String, Codable, CaseIterable {
    case small
    case medium
    case large
    case extraLarge

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "XL"
        }
    }

    var pointSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        case .extraLarge: return 21
        }
    }
}

enum NativeEditorLineSpacing: String, Codable, CaseIterable {
    case single
    case oneAndHalf
    case double

    var label: String {
        switch self {
        case .single: return "Single"
        case .oneAndHalf: return "1.5"
        case .double: return "Double"
        }
    }

    var spacing: CGFloat {
        switch self {
        case .single: return 2
        case .oneAndHalf: return 8
        case .double: return 14
        }
    }
}

enum NativeEditorZoom: Double, Codable, CaseIterable {
    case x100 = 1.0
    case x125 = 1.25
    case x150 = 1.5
    case x175 = 1.75
    case x200 = 2.0
    case x250 = 2.5
    case x300 = 3.0

    var label: String {
        "\(Int((rawValue * 100).rounded()))%"
    }

    var scale: CGFloat {
        CGFloat(rawValue)
    }
}

enum NativeEditorTextColor: CaseIterable {
    case `default`
    case warm
    case blue
    case green
    case rose

    var label: String {
        switch self {
        case .default: return "Default"
        case .warm: return "Warm"
        case .blue: return "Blue"
        case .green: return "Green"
        case .rose: return "Rose"
        }
    }

    var color: NSColor {
        switch self {
        case .default: return .textColor
        case .warm: return NSColor(calibratedRed: 0.88, green: 0.77, blue: 0.59, alpha: 1)
        case .blue: return NSColor(calibratedRed: 0.60, green: 0.78, blue: 0.96, alpha: 1)
        case .green: return NSColor(calibratedRed: 0.67, green: 0.86, blue: 0.69, alpha: 1)
        case .rose: return NSColor(calibratedRed: 0.93, green: 0.69, blue: 0.76, alpha: 1)
        }
    }

    static func closestLabel(for color: NSColor?) -> String {
        guard let color else { return `default`.label }
        for option in allCases {
            if option.color.isVisuallyEqual(to: color) {
                return option.label
            }
        }
        return "Custom"
    }
}

enum NativeAssistantTextSize: String, CaseIterable {
    case small
    case medium
    case large

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var scale: CGFloat {
        switch self {
        case .small: return 0.92
        case .medium: return 1.0
        case .large: return 1.12
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        NativeTheme.interfaceFont(size: (size + 3) * scale, weight: weight)
    }
}

struct NativeAssistantMessage: Identifiable, Equatable {
    enum Role {
        case user
        case assistant
        case status
    }

    let id = UUID()
    let role: Role
    let text: String
}

struct NativeAssistantReviewIssue: Identifiable, Equatable {
    let id: UUID
    let sceneID: UUID
    let sceneTitle: String
    let category: String
    let quote: String
    let problem: String
    let recommendation: String
    let replacement: String?
    let range: NSRange
    let isStale: Bool
}

private struct NativeAssistantInfluenceLabel: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let tint: Color
}

private func adjustedReviewIssues(
    from issues: [NativeAssistantReviewIssue],
    afterReplacingIn sceneID: UUID,
    replacedRange: NSRange,
    replacementLength: Int,
    removing removedIssueID: UUID
) -> [NativeAssistantReviewIssue] {
    let delta = replacementLength - replacedRange.length
    return issues.compactMap { issue in
        guard issue.id != removedIssueID else { return nil }
        guard issue.sceneID == sceneID else { return issue }

        let issueStart = issue.range.location
        let issueEnd = NSMaxRange(issue.range)
        let replacedEnd = NSMaxRange(replacedRange)

        if issueEnd <= replacedRange.location {
            return issue
        }
        if issueStart >= replacedEnd {
            return NativeAssistantReviewIssue(
                id: issue.id,
                sceneID: issue.sceneID,
                sceneTitle: issue.sceneTitle,
                category: issue.category,
                quote: issue.quote,
                problem: issue.problem,
                recommendation: issue.recommendation,
                replacement: issue.replacement,
                range: NSRange(location: max(0, issue.range.location + delta), length: issue.range.length),
                isStale: issue.isStale
            )
        }

        return nil
    }
}

private func updateReviewIssuesForManualEdit(
    issues: [NativeAssistantReviewIssue],
    originalEditedRange: NSRange,
    replacementLength: Int,
    updatedText: String
) -> [NativeAssistantReviewIssue] {
    let delta = replacementLength - originalEditedRange.length
    let editedEnd = NSMaxRange(originalEditedRange)

    return issues.map { issue in
        let issueStart = issue.range.location
        let issueEnd = NSMaxRange(issue.range)

        if issueEnd <= originalEditedRange.location {
            return issue
        }

        if issueStart >= editedEnd {
            return NativeAssistantReviewIssue(
                id: issue.id,
                sceneID: issue.sceneID,
                sceneTitle: issue.sceneTitle,
                category: issue.category,
                quote: issue.quote,
                problem: issue.problem,
                recommendation: issue.recommendation,
                replacement: issue.replacement,
                range: NSRange(location: max(0, issue.range.location + delta), length: issue.range.length),
                isStale: issue.isStale
            )
        }

        if let rematchedRange = closestRange(of: issue.quote, in: updatedText, near: issue.range.location) {
            return NativeAssistantReviewIssue(
                id: issue.id,
                sceneID: issue.sceneID,
                sceneTitle: issue.sceneTitle,
                category: issue.category,
                quote: issue.quote,
                problem: issue.problem,
                recommendation: issue.recommendation,
                replacement: issue.replacement,
                range: rematchedRange,
                isStale: false
            )
        }

        return NativeAssistantReviewIssue(
            id: issue.id,
            sceneID: issue.sceneID,
            sceneTitle: issue.sceneTitle,
            category: issue.category,
            quote: issue.quote,
            problem: issue.problem,
            recommendation: issue.recommendation,
            replacement: issue.replacement,
            range: issue.range,
            isStale: true
        )
    }
}

private func closestRange(of needle: String, in haystack: String, near location: Int) -> NSRange? {
    let nsHaystack = haystack as NSString
    let allRanges = ranges(of: needle, in: nsHaystack)
    guard !allRanges.isEmpty else { return nil }
    return allRanges.min(by: { abs($0.location - location) < abs($1.location - location) })
}

private func ranges(of needle: String, in haystack: NSString) -> [NSRange] {
    guard !needle.isEmpty else { return [] }
    var foundRanges: [NSRange] = []
    var searchLocation = 0
    while searchLocation < haystack.length {
        let range = haystack.range(
            of: needle,
            options: [],
            range: NSRange(location: searchLocation, length: haystack.length - searchLocation)
        )
        guard range.location != NSNotFound, range.length > 0 else { break }
        foundRanges.append(range)
        searchLocation = range.location + max(range.length, 1)
    }
    return foundRanges
}

private func chapterKindName(for project: NativeProject) -> String {
    project.isPodcastProject ? "Episode" : "Chapter"
}

private func displayedChapterTitle(_ title: String, for project: NativeProject) -> String {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return project.isPodcastProject ? "Untitled Episode" : "Untitled Chapter" }

    let lowercased = trimmedTitle.lowercased()
    if project.isPodcastProject, lowercased.hasPrefix("chapter ") {
        return "Episode " + trimmedTitle.dropFirst("Chapter ".count)
    }
    if !project.isPodcastProject, lowercased.hasPrefix("episode ") {
        return "Chapter " + trimmedTitle.dropFirst("Episode ".count)
    }
    return trimmedTitle
}

struct NativeAssistantContext {
    let scopeTitle: String
    let scopeLabel: String
    let scopeText: String
    let scopeWordCount: Int
    let sceneCount: Int
    let selectedText: String?
    let hasLiveSelection: Bool
    let selectedWordCount: Int
    let projectStyleNotes: String
    let approvedWords: [String]
    let narrativePerson: String
    let narrativeTense: String
    let genre: String
    let subgenre: String
    let storyPromise: String
    let pacingNotes: String
    let avoidNotes: String
    let continuityMemory: String
    let relevantCharacterStyles: [NativeCharacterStyleGuide]
    let allCharacterStyles: [NativeCharacterStyleGuide]
}

struct NativeStyleGuideSuggestion: Equatable {
    let styleNotes: String
    let approvedWords: [String]
}

struct NativeCharacterStyleSuggestion: Equatable {
    let characterName: String
    let styleNotes: String
    let visualDescription: String
    let approvedWords: [String]
    let projectConsistencyNotes: [String]
}

struct NativeContinuityMemorySuggestion: Equatable {
    let summary: String
}

struct NativeSceneBreakSuggestion: Equatable {
    struct Scene: Equatable {
        let title: String
        let openingQuote: String
    }

    let chapterTitle: String
    let scenes: [Scene]
}

private struct NativePodcastPrepResponse: Decodable {
    let episodeTitle: String
    let previousEpisodeSummaryVoice: String
    let previousEpisodeSummary: String
    let introVoice: String
    let outroVoice: String
    let introText: String
    let outroText: String
    let podcastDescription: String
    let coverArtPrompt: String
    let facebookPost: String
    let tumblrPost: String
    let instagramPost: String
    let pinterestPost: String
    let redditPost: String
    let xPost: String

    enum CodingKeys: String, CodingKey {
        case episodeTitle = "episode_title"
        case previousEpisodeSummaryVoice = "previous_episode_summary_voice"
        case previousEpisodeSummary = "previous_episode_summary"
        case introVoice = "intro_voice"
        case outroVoice = "outro_voice"
        case introText = "intro_text"
        case outroText = "outro_text"
        case podcastDescription = "podcast_summary"
        case coverArtPrompt = "cover_art_prompt"
        case facebookPost = "facebook_post"
        case tumblrPost = "tumblr_post"
        case instagramPost = "instagram_post"
        case pinterestPost = "pinterest_post"
        case redditPost = "reddit_post"
        case xPost = "x_post"
    }
}

private struct NativeStyleGuideResponse: Decodable {
    let styleNotes: String
    let approvedWords: [String]

    enum CodingKeys: String, CodingKey {
        case styleNotes = "style_notes"
        case approvedWords = "approved_words"
    }
}

private struct NativeCharacterStyleResponse: Decodable {
    let characterName: String
    let styleNotes: String
    let visualDescription: String
    let approvedWords: [String]
    let projectConsistencyNotes: [String]

    enum CodingKeys: String, CodingKey {
        case characterName = "character_name"
        case styleNotes = "style_notes"
        case visualDescription = "visual_description"
        case approvedWords = "approved_words"
        case projectConsistencyNotes = "project_consistency_notes"
    }
}

private struct NativeContinuityMemoryResponse: Decodable {
    let summary: String
}

private struct NativeSceneBreakResponse: Decodable {
    let scenes: [Scene]

    struct Scene: Decodable {
        let title: String
        let openingQuote: String

        enum CodingKeys: String, CodingKey {
            case title
            case openingQuote = "opening_quote"
        }
    }
}

private struct NativeAssistantReviewResponse: Decodable {
    let issues: [Issue]

    struct Issue: Decodable {
        let sceneTitle: String?
        let category: String
        let quote: String
        let problem: String
        let recommendation: String
        let replacement: String?

        enum CodingKeys: String, CodingKey {
            case sceneTitle = "scene_title"
            case category
            case quote
            case problem
            case recommendation
            case replacement
        }
    }
}

enum NativeFindScope: String, CaseIterable, Identifiable {
    case currentSelection
    case selectedScenes
    case selectedChapters
    case visibleScope
    case entireProject

    var id: String { rawValue }

    var label: String {
        switch self {
        case .currentSelection: return "Selection"
        case .selectedScenes: return "Scenes"
        case .selectedChapters: return "Chapters"
        case .visibleScope: return "Visible"
        case .entireProject: return "Project"
        }
    }
}

enum NativeFindMode: String, CaseIterable, Identifiable {
    case contains
    case wholeWord
    case startsWith
    case endsWith

    var id: String { rawValue }

    var label: String {
        switch self {
        case .contains: return "Contains"
        case .wholeWord: return "Whole Word"
        case .startsWith: return "Starts With"
        case .endsWith: return "Ends With"
        }
    }
}

struct NativeFindMatch: Identifiable, Equatable {
    let id = UUID()
    let sceneID: UUID
    let sceneTitle: String
    let range: NSRange
    let snippet: String
}

struct NativeFindSelectionContext {
    let sceneID: UUID
    let sceneTitle: String
    let text: String
    let selectedRange: NSRange
}

private struct OpenAIResponsesRequest: Encodable {
    let model: String
    let input: String
    let store: Bool
}

private struct OpenAIResponsesResponse: Decodable {
    let output: [OutputItem]

    struct OutputItem: Decodable {
        let type: String
        let content: [ContentItem]?
    }

    struct ContentItem: Decodable {
        let type: String
        let text: String?
    }

    var outputText: String {
        output
            .flatMap { $0.content ?? [] }
            .filter { $0.type == "output_text" }
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private let openAIResponsesURL = URL(string: "https://api.openai.com/v1/responses")!
private let openAIRequestTimeout: TimeInterval = 180
private let openAIRequestRetryCount = 1
private let openAIRoutineModel = "gpt-5-mini"
private let openAIDeepReviewModel = "gpt-5.4"
private let openAIPodcastRecapModel = openAIDeepReviewModel

private func assistantModelDisplayName(for model: String) -> String {
    switch model {
    case openAIDeepReviewModel:
        return "GPT-5.4"
    case openAIRoutineModel:
        return "GPT-5 mini"
    default:
        return model
    }
}

private func performOpenAIResponsesRequest(
    apiKey: String,
    requestBody: OpenAIResponsesRequest
) async throws -> OpenAIResponsesResponse {
    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    var attempt = 0

    while true {
        do {
            var request = URLRequest(url: openAIResponsesURL, timeoutInterval: openAIRequestTimeout)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NativeOpenAIRequestError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw NativeOpenAIRequestError.apiError(message: String(data: data, encoding: .utf8) ?? "Unknown API error")
            }
            return try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        } catch {
            if shouldRetryOpenAIRequest(error), attempt < openAIRequestRetryCount {
                attempt += 1
                continue
            }
            throw error
        }
    }
}

private func shouldRetryOpenAIRequest(_ error: Error) -> Bool {
    guard let urlError = error as? URLError else { return false }
    switch urlError.code {
    case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
        return true
    default:
        return false
    }
}

private enum NativeOpenAIRequestError: Error {
    case invalidResponse
    case apiError(message: String)
}

@MainActor
final class NativeAssistantStore: ObservableObject {
    @Published private(set) var messages: [NativeAssistantMessage] = [
        NativeAssistantMessage(
            role: .status,
            text: "Assistant is ready. Ask about the current scene, selected text, or the full visible editing scope."
        )
    ]
    @Published var draft = ""
    @Published private(set) var isSending = false
    @Published private(set) var lastError: String?
    @Published private(set) var reviewIssues: [NativeAssistantReviewIssue] = []
    @Published var activeReviewIssueID: UUID?
    @Published private(set) var pendingStyleGuideSuggestion: NativeStyleGuideSuggestion?
    @Published private(set) var pendingCharacterStyleSuggestion: NativeCharacterStyleSuggestion?
    @Published private(set) var pendingContinuityMemorySuggestion: NativeContinuityMemorySuggestion?
    @Published private(set) var pendingSceneBreakSuggestion: NativeSceneBreakSuggestion?
    @Published private(set) var lastUsedModel = openAIRoutineModel

    func send(apiKey: String, context: NativeAssistantContext) {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedDraft.isEmpty else { return }
        guard !trimmedKey.isEmpty else {
            lastError = "Add an OpenAI API key to use the assistant."
            return
        }
        guard !context.scopeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            lastError = "Open a scene or chapter before asking the assistant."
            return
        }

        let prompt = trimmedDraft
        draft = ""
        lastError = nil
        isSending = true
        lastUsedModel = openAIRoutineModel
        messages.append(NativeAssistantMessage(role: .user, text: prompt))

        let transcript = messages.suffix(8).map { message in
            let prefix: String
            switch message.role {
            case .user:
                prefix = "User"
            case .assistant:
                prefix = "Assistant"
            case .status:
                prefix = "System"
            }
            return "\(prefix): \(message.text)"
        }.joined(separator: "\n\n")

        let requestBody = OpenAIResponsesRequest(
            model: openAIRoutineModel,
            input: buildInput(prompt: prompt, context: context, transcript: transcript),
            store: false
        )

        Task {
            defer { Task { @MainActor in self.isSending = false } }

            do {
                let decoded = try await performOpenAIResponsesRequest(apiKey: trimmedKey, requestBody: requestBody)
                let outputText = decoded.outputText
                let finalText = outputText.isEmpty ? "No text was returned." : outputText

                await MainActor.run {
                    self.messages.append(NativeAssistantMessage(role: .assistant, text: finalText))
                }
            } catch {
                await MainActor.run {
                    self.lastError = Self.describe(error)
                }
            }
        }
    }

    func fillPrompt(_ prompt: String) {
        draft = prompt
    }

    func reviewCurrentScope(apiKey: String, context: NativeAssistantContext, scenes: [NativeScene]) {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            lastError = "Add an OpenAI API key to use the assistant."
            return
        }
        guard !scenes.isEmpty else {
            lastError = "Open a scene or chapter before reviewing it."
            return
        }

        lastError = nil
        isSending = true
        lastUsedModel = openAIDeepReviewModel
        addStatus("Reviewing current scope...")

        let requestBody = OpenAIResponsesRequest(
            model: openAIDeepReviewModel,
            input: buildReviewInput(context: context),
            store: false
        )

        Task {
            defer { Task { @MainActor in self.isSending = false } }

            do {
                let decoded = try await performOpenAIResponsesRequest(apiKey: trimmedKey, requestBody: requestBody)
                let outputText = decoded.outputText
                let reviewResponse = try Self.decodeReviewResponse(from: outputText)
                let issues = Self.matchReviewIssues(reviewResponse.issues, scenes: scenes)

                await MainActor.run {
                    self.reviewIssues = issues
                    self.activeReviewIssueID = issues.first?.id
                    if issues.isEmpty {
                        self.messages.append(NativeAssistantMessage(role: .assistant, text: "No concrete scene issues were identified in the current scope."))
                    }
                }
            } catch {
                await MainActor.run {
                    self.lastError = Self.describe(error)
                }
            }
        }
    }

    func generateStyleGuideSuggestion(apiKey: String, context: NativeAssistantContext) {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            lastError = "Add an OpenAI API key to use the assistant."
            return
        }
        let sourceText = context.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? context.scopeText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        guard let sourceText else {
            lastError = "Select text or open a scene before building a style guide."
            return
        }

        lastError = nil
        isSending = true
        lastUsedModel = openAIRoutineModel
        addStatus("Building style guide suggestions...")

        let requestBody = OpenAIResponsesRequest(
            model: openAIRoutineModel,
            input: buildStyleGuideInput(context: context, sourceText: sourceText),
            store: false
        )

        Task {
            defer { Task { @MainActor in self.isSending = false } }

            do {
                let decoded = try await performOpenAIResponsesRequest(apiKey: trimmedKey, requestBody: requestBody)
                let outputText = decoded.outputText
                let suggestion = try Self.decodeStyleGuideResponse(from: outputText)

                await MainActor.run {
                    self.pendingStyleGuideSuggestion = suggestion
                    self.messages.append(NativeAssistantMessage(role: .assistant, text: Self.styleGuideSummaryText(for: suggestion)))
                }
            } catch {
                await MainActor.run {
                    self.lastError = Self.describe(error)
                }
            }
        }
    }

    func generateCharacterStyleSuggestion(apiKey: String, context: NativeAssistantContext) {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            lastError = "Add an OpenAI API key to use the assistant."
            return
        }
        let sourceText = context.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? context.scopeText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        guard let sourceText else {
            lastError = "Select text or open a scene before building character voice rules."
            return
        }

        lastError = nil
        isSending = true
        lastUsedModel = openAIDeepReviewModel
        addStatus("Building character voice suggestions...")

        let requestBody = OpenAIResponsesRequest(
            model: openAIDeepReviewModel,
            input: buildCharacterStyleInput(context: context, sourceText: sourceText),
            store: false
        )

        Task {
            defer { Task { @MainActor in self.isSending = false } }

            do {
                let decoded = try await performOpenAIResponsesRequest(apiKey: trimmedKey, requestBody: requestBody)
                let outputText = decoded.outputText
                let suggestion = try Self.decodeCharacterStyleResponse(from: outputText)

                await MainActor.run {
                    self.pendingCharacterStyleSuggestion = suggestion
                    self.messages.append(NativeAssistantMessage(role: .assistant, text: Self.characterStyleSummaryText(for: suggestion)))
                }
            } catch {
                await MainActor.run {
                    self.lastError = Self.describe(error)
                }
            }
        }
    }

    func generateContinuityMemorySuggestion(apiKey: String, context: NativeAssistantContext) {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            lastError = "Add an OpenAI API key to use the assistant."
            return
        }
        let sourceText = context.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? context.scopeText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        guard let sourceText else {
            lastError = "Select text or open a scene before updating continuity memory."
            return
        }

        lastError = nil
        isSending = true
        lastUsedModel = openAIRoutineModel
        addStatus("Updating project memory...")

        let requestBody = OpenAIResponsesRequest(
            model: openAIRoutineModel,
            input: buildContinuityMemoryInput(context: context, sourceText: sourceText),
            store: false
        )

        Task {
            defer { Task { @MainActor in self.isSending = false } }

            do {
                let decoded = try await performOpenAIResponsesRequest(apiKey: trimmedKey, requestBody: requestBody)
                let outputText = decoded.outputText
                let suggestion = try Self.decodeContinuityMemoryResponse(from: outputText)

                await MainActor.run {
                    self.pendingContinuityMemorySuggestion = suggestion
                    self.messages.append(NativeAssistantMessage(role: .assistant, text: Self.continuityMemorySummaryText(for: suggestion)))
                }
            } catch {
                await MainActor.run {
                    self.lastError = Self.describe(error)
                }
            }
        }
    }

    func generateSceneBreakSuggestion(apiKey: String, context: NativeAssistantContext, chapterTitle: String, chapterText: String) {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            lastError = "Add an OpenAI API key to use the assistant."
            return
        }
        let normalizedChapterText = chapterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChapterText.isEmpty else {
            lastError = "Open a chapter with scene text before proposing scene breaks."
            return
        }

        lastError = nil
        isSending = true
        lastUsedModel = openAIDeepReviewModel
        addStatus("Proposing scene breaks...")

        let requestBody = OpenAIResponsesRequest(
            model: openAIDeepReviewModel,
            input: buildSceneBreakInput(context: context, chapterTitle: chapterTitle, chapterText: normalizedChapterText),
            store: false
        )

        Task {
            defer { Task { @MainActor in self.isSending = false } }

            do {
                let decoded = try await performOpenAIResponsesRequest(apiKey: trimmedKey, requestBody: requestBody)
                let outputText = decoded.outputText
                let suggestion = try Self.decodeSceneBreakResponse(from: outputText, chapterTitle: chapterTitle)

                await MainActor.run {
                    self.pendingSceneBreakSuggestion = suggestion
                    self.messages.append(NativeAssistantMessage(role: .assistant, text: Self.sceneBreakSummaryText(for: suggestion)))
                }
            } catch {
                await MainActor.run {
                    self.lastError = Self.describe(error)
                }
            }
        }
    }

    func clearConversation() {
        messages = [
            NativeAssistantMessage(
                role: .status,
                text: "Assistant is ready. Ask about the current scene, selected text, or the full visible editing scope."
            )
        ]
        lastError = nil
        draft = ""
        reviewIssues = []
        activeReviewIssueID = nil
        pendingStyleGuideSuggestion = nil
        pendingCharacterStyleSuggestion = nil
        pendingContinuityMemorySuggestion = nil
        pendingSceneBreakSuggestion = nil
    }

    func addStatus(_ text: String) {
        messages.append(NativeAssistantMessage(role: .status, text: text))
    }

    func dismissReviewIssue(_ issueID: UUID) {
        reviewIssues.removeAll { $0.id == issueID }
        if activeReviewIssueID == issueID {
            activeReviewIssueID = reviewIssues.first?.id
        }
    }

    func clearReviewIssues() {
        reviewIssues = []
        activeReviewIssueID = nil
    }

    func clearPendingStyleGuideSuggestion() {
        pendingStyleGuideSuggestion = nil
    }

    func clearPendingCharacterStyleSuggestion() {
        pendingCharacterStyleSuggestion = nil
    }

    func clearPendingContinuityMemorySuggestion() {
        pendingContinuityMemorySuggestion = nil
    }

    func clearPendingSceneBreakSuggestion() {
        pendingSceneBreakSuggestion = nil
    }

    func setReviewIssues(_ issues: [NativeAssistantReviewIssue]) {
        reviewIssues = issues
        if let activeReviewIssueID, issues.contains(where: { $0.id == activeReviewIssueID }) {
            return
        }
        self.activeReviewIssueID = issues.first?.id
    }

    func applyReviewIssue(_ issueID: UUID) -> NativeAssistantReviewIssue? {
        guard let issue = reviewIssues.first(where: { $0.id == issueID }) else { return nil }
        let replacementLength = issue.replacement?.utf16.count ?? 0
        reviewIssues = adjustedReviewIssues(
            from: reviewIssues,
            afterReplacingIn: issue.sceneID,
            replacedRange: issue.range,
            replacementLength: replacementLength,
            removing: issueID
        )
        if activeReviewIssueID == issueID {
            activeReviewIssueID = reviewIssues.first?.id
        }
        return issue
    }

    private func buildInput(prompt: String, context: NativeAssistantContext, transcript: String) -> String {
        let selectedSection: String
        if let selectedText = context.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines), !selectedText.isEmpty {
            selectedSection = """
            Selected text:
            \(selectedText)
            """
        } else {
            selectedSection = "Selected text: None"
        }

        let styleSection: String
        if context.projectStyleNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           context.approvedWords.isEmpty {
            styleSection = "Project style guide: None"
        } else {
            let approvedWordsSection = context.approvedWords.isEmpty
                ? "Approved dialect/style words: None"
                : "Approved dialect/style words: \(context.approvedWords.joined(separator: ", "))"
            styleSection = """
            Project style guide:
            \(context.projectStyleNotes.nilIfEmpty ?? "None")

            \(approvedWordsSection)
            """
        }

        let directionSection = projectDirectionSection(for: context)
        let continuitySection = """
        Project continuity memory:
        \(context.continuityMemory.nilIfEmpty ?? "None")
        """
        let characterStylesSection = formattedCharacterStylesSection(
            from: context.relevantCharacterStyles,
            fallback: context.allCharacterStyles
        )

        return """
        You are a developmental and line editor helping with a novel in a native macOS writing app.
        Give actionable, manuscript-specific help. Prefer concise, practical feedback over general advice.
        If asked to revise text, preserve the author's intent and voice unless asked otherwise.
        Respect the project's approved dialect, slang, and character voice rules. Do not "correct" intentional voice.

        Current editing scope: \(context.scopeTitle)

        \(directionSection)

        \(continuitySection)

        \(styleSection)

        \(characterStylesSection)

        Visible manuscript context:
        \(context.scopeText)

        \(selectedSection)

        Recent conversation:
        \(transcript)

        User request:
        \(prompt)
        """
    }

    private func buildReviewInput(context: NativeAssistantContext) -> String {
        let approvedWordsSection = context.approvedWords.isEmpty
            ? "None"
            : context.approvedWords.joined(separator: ", ")
        let directionSection = projectDirectionSection(for: context)
        let continuitySection = """
        Project continuity memory:
        \(context.continuityMemory.nilIfEmpty ?? "None")
        """
        let characterStylesSection = formattedCharacterStylesSection(
            from: context.relevantCharacterStyles,
            fallback: context.allCharacterStyles
        )

        return """
        You are reviewing a novel scene in a native macOS writing app.
        Find concrete scene-level or line-level issues that should be edited.
        Respect intentional dialect, slang, and character voice. Do not flag approved voice choices as mistakes.

        Return JSON only. No markdown. No explanation outside JSON.
        Use this schema exactly:
        {
          "issues": [
            {
              "scene_title": "exact scene title if known",
              "category": "pacing|repetition|dialogue|clarity|continuity|prose",
              "quote": "exact contiguous quote from the manuscript",
              "problem": "short explanation of what is wrong",
              "recommendation": "specific fix recommendation",
              "replacement": "optional improved replacement text for the quoted passage"
            }
          ]
        }

        Rules:
        - Quote exact manuscript text, not paraphrases.
        - Keep issues specific and actionable.
        - Prefer no more than 8 issues.
        - If there are no issues, return {"issues":[]}.
        - Do not flag text only because it is informal, dialectal, or nonstandard if it matches the project style guide or approved words.
        - When a quoted passage has a clean local fix, provide a replacement by default instead of only diagnostic advice.
        - Prefer replacements for line-level dialogue problems, awkward tags, punctuation/grammar issues, clumsy short prose, and localized repetition where a tighter rewrite is practical.
        - Prefer replacements for formatting cleanup, stray spaces, missing quotation marks, standardizing line breaks, accidental special characters, and obvious casing/emphasis fixes.
        - Leave "replacement" null mainly for broader structural issues, scene-level pacing observations, or cases where a safe local rewrite would need too much surrounding context.
        - When you provide a replacement, choose one best replacement only. Do not provide multiple rewrite options, numbered alternatives, or menu-style choices.
        - Treat the replacement as the assistant's preferred fix for direct approve/apply use in the editor.
        - Keep "problem" and "recommendation" concise when a replacement is present. The replacement should do most of the work.
        - For obvious consistency fixes, capitalization fixes, punctuation fixes, and short local wording fixes, prefer a direct replacement rather than commentary alone.
        - If the issue is that the manuscript uses visible or invisible nonstandard line-break characters, return the normalized replacement text with standard line breaks rather than only naming the problem.
        - If the issue is abrupt ALL-CAPS-style emphasis or melodramatic punctuation in an otherwise local passage, provide one voice-consistent replacement unless the fix truly depends on wider scene intent.
        - Only provide a "replacement" when it is a materially improved rewrite, not a minor paraphrase of the original.
        - If the best help is diagnostic rather than a meaningful rewrite, leave "replacement" null.

        Current scope title: \(context.scopeTitle)

        \(directionSection)

        \(continuitySection)

        Project style guide:
        \(context.projectStyleNotes.nilIfEmpty ?? "None")

        Approved dialect/style words:
        \(approvedWordsSection)

        \(characterStylesSection)

        Manuscript text:
        \(context.scopeText)
        """
    }

    private func buildStyleGuideInput(context: NativeAssistantContext, sourceText: String) -> String {
        let approvedWordsSection = context.approvedWords.isEmpty
            ? "None"
            : context.approvedWords.joined(separator: ", ")
        let directionSection = projectDirectionSection(for: context)
        let characterStylesSection = formattedCharacterStylesSection(
            from: context.allCharacterStyles,
            fallback: []
        )

        return """
        You are building a project style guide for a novel writing app.
        Analyze the provided manuscript text and infer intentional voice, dialect, slang, spelling variants, and character-specific language patterns that should be preserved instead of corrected.

        Return JSON only. No markdown. No explanation outside JSON.
        Use this schema exactly:
        {
          "style_notes": "short practical style guide notes the assistant should follow",
          "approved_words": ["word or phrase", "word or phrase"]
        }

        Rules:
        - Focus on preserving intentional voice, dialect, slang, punctuation habits, and repeated language patterns.
        - Consider the project's declared genre, story promise, pacing expectations, and avoid notes when drafting guidance.
        - Only include approved words that clearly appear intentional in the source text.
        - Keep style notes concise and useful for future review/rewrite passes.
        - If there is not enough signal, return empty values.

        \(directionSection)

        Existing project style guide:
        \(context.projectStyleNotes.nilIfEmpty ?? "None")

        Existing approved words:
        \(approvedWordsSection)

        \(characterStylesSection)

        Source text:
        \(sourceText)
        """
    }

    private func buildCharacterStyleInput(context: NativeAssistantContext, sourceText: String) -> String {
        let approvedWordsSection = context.approvedWords.isEmpty
            ? "None"
            : context.approvedWords.joined(separator: ", ")
        let directionSection = projectDirectionSection(for: context)
        let characterStylesSection = formattedCharacterStylesSection(
            from: context.allCharacterStyles,
            fallback: []
        )

        return """
        You are building a character-specific voice guide for a novel writing app.
        Analyze the provided manuscript text and infer the most likely single character voice represented in that text.

        Return JSON only. No markdown. No explanation outside JSON.
        Use this schema exactly:
        {
          "character_name": "character name or Unnamed Speaker",
          "style_notes": "a complete standardized character voice sheet in the required format below",
          "visual_description": "a complete canonical physical description sheet in the required format below",
          "approved_words": ["word or phrase", "word or phrase"],
          "project_consistency_notes": ["novel-wide consistency note", "novel-wide consistency note"]
        }

        Rules:
        - Focus on one character only.
        - Prefer an existing character name when the source text clearly matches one of the current character voice rules.
        - If the name is not explicit, infer the most likely speaker label conservatively.
        - Capture only durable voice traits that should remain true for this character across the whole novel.
        - Good examples for style_notes: rhythm, slang, dropped endings, punctuation habits, profanity, diction, procedural habits, emotional cadence.
        - Do not include chapter-specific fixes, line edits, one-off examples, or comments about individual sentences.
        - Put novel-wide consistency items like time-format rules, radio formatting rules, or manuscript-wide style consistency issues into project_consistency_notes instead of style_notes.
        - Do not include scene-specific or chapter-specific notes in project_consistency_notes either.
        - Only include approved words or phrases that clearly appear intentional and should be preserved literally.
        - Good examples for approved_words: dialect spellings, recurring slang, in-world terms, named institutions, radio shorthand, catchphrases, repeated quoted phrasing that belongs to this voice.
        - Do not include generic filler words or ordinary common words such as "Okay", "Yes", "No", or everyday plain-English words unless they are part of a distinctive repeated phrase that matters.
        - Prefer a short, high-confidence approved_words list over a long noisy one.
        - style_notes must always follow this exact section structure, using plain text headings and flat bullets:
          CharacterName - voice summary for the character sheet

          Core: ...

          POV / tense
          - POV: ...
          - Tense: ...

          Tone
          - ...

          Sentence rhythm & vocabulary
          - ...

          Narrative habits
          - ...

          Dialogue tendencies
          - ...

          Approved words / recurring phrases
          - ...

          Consistency risks
          - ...

          Preserve in rewrites
          - ...

          Do / Don't - practical rules when writing CharacterName
          - Do ...
          - Don't ...

          Quick voice samples (use these as templates)
          - Calm, factual: "..."
          - Angry/defensive: "..."
          - Vulnerable/soft: "..."

          Use this sheet to check: ...
        - In the `POV / tense` section, explicitly state the most likely POV and tense from the source text, or say `Unclear` if the signal is weak.
        - In `Approved words / recurring phrases`, include characteristic terms, repeated constructions, signature phrasing, or say `- None established yet.` if none are clearly supported.
        - In `Consistency risks`, identify the most likely ways future drafting or rewriting could drift away from this voice.
        - In `Preserve in rewrites`, explicitly state the voice traits editing passes must preserve.
        - Make the sheet practical, complete, and writer-facing rather than academic.
        - Keep it compact but complete enough to guide future drafting and assistant rewrites on its own.
        - Use the resolved character name in the opening heading and the `Do / Don't` heading.
        - visual_description must always follow this exact section structure, using plain text headings and flat bullets:
          CharacterName - physical description (for the character sheet)

          Core visual identity
          - ...

          Face
          - ...

          Build
          - ...

          Clothing / gear
          - ...

          Movement / bearing
          - ...

          Distinguishing marks
          - ...

          Sensory impression
          - ...

          Canonical details to keep consistent
          - ...
        - visual_description should default to canonical-sheet mode, not brainstorming mode.
        - Avoid advisory language such as `consider`, `I recommend`, `pick`, `you could`, or `what needs to be decided`.
        - Resolve details declaratively from the source text when there is enough signal; if a detail is genuinely unclear, say `Unspecified in current text` instead of turning the sheet into a brainstorm.
        - Keep the physical description practical, visual, and continuity-friendly so it can be reused in later scenes and image/cover-art prompts.
        - Do not include POV-writing samples inside visual_description.
        - project_consistency_notes should be short, durable, and only include notes that belong in the project-wide style guide.
        - If there is not enough signal for a named character, return "Unnamed Speaker".

        \(directionSection)

        Existing project style guide:
        \(context.projectStyleNotes.nilIfEmpty ?? "None")

        Existing project approved words:
        \(approvedWordsSection)

        \(characterStylesSection)

        Source text:
        \(sourceText)
        """
    }

    private func buildContinuityMemoryInput(context: NativeAssistantContext, sourceText: String) -> String {
        let characterStylesSection = formattedCharacterStylesSection(
            from: context.allCharacterStyles,
            fallback: []
        )

        return """
        You are updating a novel's project-level continuity memory for a writing app.
        Extract durable facts, relationships, locations, ongoing threats, important objects, world rules, and continuity details that future scene reviews should remember.

        Return JSON only. No markdown. No explanation outside JSON.
        Use this schema exactly:
        {
          "summary": "short continuity summary written as compact bullet-style sentences separated by newlines"
        }

        Rules:
        - Keep only durable story context that will still matter in later chapters.
        - Prefer facts that reduce future continuity errors or missing context.
        - Do not summarize prose style or scene-by-scene action unless it creates lasting context.
        - Preserve important location, system, creature, relationship, and world-state facts.
        - Merge with the existing continuity memory instead of overwriting useful earlier facts.
        - Keep the result concise and cumulative.

        \(projectDirectionSection(for: context))

        Existing continuity memory:
        \(context.continuityMemory.nilIfEmpty ?? "None")

        Existing project style guide:
        \(context.projectStyleNotes.nilIfEmpty ?? "None")

        \(characterStylesSection)

        Source text:
        \(sourceText)
        """
    }

    private func buildSceneBreakInput(context: NativeAssistantContext, chapterTitle: String, chapterText: String) -> String {
        let directionSection = projectDirectionSection(for: context)
        let continuitySection = """
        Project continuity memory:
        \(context.continuityMemory.nilIfEmpty ?? "None")
        """
        let characterStylesSection = formattedCharacterStylesSection(
            from: context.relevantCharacterStyles,
            fallback: context.allCharacterStyles
        )

        return """
        You are helping split a chapter into scene boundaries for a novel writing app.
        Read the chapter and propose where scenes should start based on meaningful shifts in time, place, point of view, objective, or dramatic beat.

        Return JSON only. No markdown. No explanation outside JSON.
        Use this schema exactly:
        {
          "scenes": [
            {
              "title": "Scene 1",
              "opening_quote": "exact opening quote from the manuscript where this scene begins"
            }
          ]
        }

        Rules:
        - Use exact contiguous text from the manuscript for every "opening_quote".
        - The first scene's opening_quote must come from the opening of the chapter text.
        - Keep the number of scenes practical. Prefer strong boundaries over over-splitting.
        - If the chapter should stay one scene, return a single scene.
        - Do not invent text.
        - Preserve established voice, genre expectations, and continuity.

        Current chapter:
        \(chapterTitle)

        \(directionSection)

        \(continuitySection)

        Project style guide:
        \(context.projectStyleNotes.nilIfEmpty ?? "None")

        \(characterStylesSection)

        Chapter text:
        \(chapterText)
        """
    }

    private func formattedCharacterStylesSection(
        from characterStyles: [NativeCharacterStyleGuide],
        fallback allCharacterStyles: [NativeCharacterStyleGuide]
    ) -> String {
        let primaryStyles = characterStyles.isEmpty ? allCharacterStyles : characterStyles
        guard !primaryStyles.isEmpty else {
            return "Character voice rules: None"
        }

        let header = characterStyles.isEmpty
            ? "Character voice rules (all known characters):"
            : "Character voice rules most relevant to this scene/selection:"

        let entries = primaryStyles.map { character in
            let notes = character.styleNotes.nilIfEmpty ?? "None"
            let approvedWords = character.approvedWords.isEmpty ? "None" : character.approvedWords.joined(separator: ", ")
            return """
            - \(character.name.nilIfEmpty ?? "Unnamed Character")
              Voice notes: \(notes)
              Approved words: \(approvedWords)
            """
        }
        .joined(separator: "\n")

        return """
        \(header)
        \(entries)
        """
    }

    private func projectDirectionSection(for context: NativeAssistantContext) -> String {
        let genre = context.genre.nilIfEmpty ?? "None"
        let subgenre = context.subgenre.nilIfEmpty ?? "None"
        let storyPromise = context.storyPromise.nilIfEmpty ?? "None"
        let pacingNotes = context.pacingNotes.nilIfEmpty ?? "None"
        let avoidNotes = context.avoidNotes.nilIfEmpty ?? "None"

        return """
        Project direction:
        Narrative person: \(context.narrativePerson.nilIfEmpty ?? "None")
        Narrative tense: \(context.narrativeTense.nilIfEmpty ?? "None")
        Genre: \(genre)
        Subgenre / Blend: \(subgenre)
        Core story promise: \(storyPromise)
        Pacing / arc notes: \(pacingNotes)
        Avoid / flag: \(avoidNotes)
        """
    }

    private static func decodeReviewResponse(from text: String) throws -> NativeAssistantReviewResponse {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw NativeAssistantError.apiError(message: "The assistant returned invalid review text.")
        }
        return try JSONDecoder().decode(NativeAssistantReviewResponse.self, from: data)
    }

    private static func decodeStyleGuideResponse(from text: String) throws -> NativeStyleGuideSuggestion {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw NativeAssistantError.apiError(message: "The assistant returned invalid style guide text.")
        }
        let response = try JSONDecoder().decode(NativeStyleGuideResponse.self, from: data)
        return NativeStyleGuideSuggestion(
            styleNotes: response.styleNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            approvedWords: response.approvedWords
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private static func decodeCharacterStyleResponse(from text: String) throws -> NativeCharacterStyleSuggestion {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw NativeAssistantError.apiError(message: "The assistant returned invalid character style text.")
        }
        let response = try JSONDecoder().decode(NativeCharacterStyleResponse.self, from: data)
        return NativeCharacterStyleSuggestion(
            characterName: response.characterName.trimmingCharacters(in: .whitespacesAndNewlines),
            styleNotes: response.styleNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            visualDescription: response.visualDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            approvedWords: response.approvedWords
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter(Self.isUsefulApprovedCharacterTerm),
            projectConsistencyNotes: response.projectConsistencyNotes
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private static func isUsefulApprovedCharacterTerm(_ term: String) -> Bool {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let normalized = trimmed
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        guard !normalized.isEmpty else { return false }

        let blockedSingles: Set<String> = [
            "okay", "ok", "yes", "no", "hey", "hi", "hello",
            "dispatch", "copy", "roger", "right", "fine", "sure",
            "paramedic", "ambulance"
        ]

        if blockedSingles.contains(normalized) {
            return false
        }

        if trimmed.components(separatedBy: .whitespacesAndNewlines).count == 1,
           !trimmed.contains("'"),
           !trimmed.contains("-"),
           !trimmed.contains("."),
           normalized.rangeOfCharacter(from: .decimalDigits) == nil,
           normalized == normalized.lowercased() {
            return false
        }

        if normalized.count <= 2 && !trimmed.contains("'") {
            return false
        }

        return true
    }

    private static func decodeContinuityMemoryResponse(from text: String) throws -> NativeContinuityMemorySuggestion {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw NativeAssistantError.apiError(message: "The assistant returned invalid continuity memory text.")
        }
        let response = try JSONDecoder().decode(NativeContinuityMemoryResponse.self, from: data)
        return NativeContinuityMemorySuggestion(
            summary: response.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func decodeSceneBreakResponse(from text: String, chapterTitle: String) throws -> NativeSceneBreakSuggestion {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw NativeAssistantError.apiError(message: "The assistant returned invalid scene break text.")
        }
        let response = try JSONDecoder().decode(NativeSceneBreakResponse.self, from: data)
        let scenes = response.scenes.enumerated().compactMap { index, scene -> NativeSceneBreakSuggestion.Scene? in
            let title = scene.title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Scene \(index + 1)"
            let openingQuote = scene.openingQuote.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !openingQuote.isEmpty else { return nil }
            return NativeSceneBreakSuggestion.Scene(title: title, openingQuote: openingQuote)
        }
        if scenes.isEmpty {
            throw NativeAssistantError.apiError(message: "The assistant did not return usable scene break points.")
        }
        return NativeSceneBreakSuggestion(chapterTitle: chapterTitle, scenes: scenes)
    }

    private static func matchReviewIssues(_ payloads: [NativeAssistantReviewResponse.Issue], scenes: [NativeScene]) -> [NativeAssistantReviewIssue] {
        payloads.compactMap { payload in
            let candidateScenes: [NativeScene]
            if let sceneTitle = payload.sceneTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !sceneTitle.isEmpty {
                let titleMatches = scenes.filter { $0.title == sceneTitle }
                candidateScenes = titleMatches.isEmpty ? scenes : titleMatches
            } else {
                candidateScenes = scenes
            }

            for scene in candidateScenes {
                let nsBody = scene.body as NSString
                let range = nsBody.range(of: payload.quote)
                guard range.location != NSNotFound, range.length > 0 else { continue }
                let normalizedReplacement = meaningfulReplacement(from: payload.replacement, comparedTo: payload.quote)
                return NativeAssistantReviewIssue(
                    id: UUID(),
                    sceneID: scene.id,
                    sceneTitle: scene.title,
                    category: payload.category.capitalized,
                    quote: payload.quote,
                    problem: payload.problem,
                    recommendation: payload.recommendation,
                    replacement: normalizedReplacement,
                    range: range,
                    isStale: false
                )
            }
            return nil
        }
    }

    private static func meaningfulReplacement(from replacement: String?, comparedTo original: String) -> String? {
        guard let replacement else { return nil }
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReplacement.isEmpty else { return "" }

        let normalizedOriginal = normalizeComparisonText(original)
        let normalizedReplacement = normalizeComparisonText(trimmedReplacement)

        if normalizedOriginal == normalizedReplacement {
            return nil
        }

        let originalWords = Set(normalizedOriginal.split(separator: " ").map(String.init))
        let replacementWords = Set(normalizedReplacement.split(separator: " ").map(String.init))
        let sharedWords = originalWords.intersection(replacementWords).count
        let largerWordCount = max(originalWords.count, replacementWords.count)
        let wordOverlap = largerWordCount == 0 ? 0 : Double(sharedWords) / Double(largerWordCount)
        let lengthDelta = abs(normalizedOriginal.count - normalizedReplacement.count)

        if wordOverlap > 0.88 && lengthDelta < 18 {
            return nil
        }

        return trimmedReplacement
    }

    private static func normalizeComparisonText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func reviewSummaryText(for issues: [NativeAssistantReviewIssue]) -> String {
        let header = "Review found \(issues.count) issue" + (issues.count == 1 ? "" : "s") + "."
        let body = issues.enumerated().map { index, issue in
            "\(index + 1). [\(issue.category)] \(issue.problem)"
        }.joined(separator: "\n")
        return "\(header)\n\n\(body)"
    }

    private static func styleGuideSummaryText(for suggestion: NativeStyleGuideSuggestion) -> String {
        let notes = suggestion.styleNotes.nilIfEmpty ?? "No new style notes suggested."
        let words = suggestion.approvedWords.isEmpty
            ? "No approved words suggested."
            : "Approved words: " + suggestion.approvedWords.joined(separator: ", ")
        return """
        Style guide draft:

        \(notes)

        \(words)
        """
    }

    private static func characterStyleSummaryText(for suggestion: NativeCharacterStyleSuggestion) -> String {
        let name = suggestion.characterName.nilIfEmpty ?? "Unnamed Speaker"
        let notes = suggestion.styleNotes.nilIfEmpty ?? "No new character voice notes suggested."
        let visualDescription = suggestion.visualDescription.nilIfEmpty ?? "No physical description sheet suggested."
        let words = suggestion.approvedWords.isEmpty
            ? "No approved words suggested."
            : "Approved words: " + suggestion.approvedWords.joined(separator: ", ")
        let consistencyNotes = suggestion.projectConsistencyNotes.isEmpty
            ? nil
            : "Project-wide consistency notes:\n" + suggestion.projectConsistencyNotes.map { "- \($0)" }.joined(separator: "\n")
        return """
        Character voice draft for \(name):

        \(notes)

        Physical description draft:

        \(visualDescription)

        \(words)

        \(consistencyNotes ?? "")
        """
    }

    private static func continuityMemorySummaryText(for suggestion: NativeContinuityMemorySuggestion) -> String {
        """
        Continuity memory draft:

        \(suggestion.summary.nilIfEmpty ?? "No continuity updates suggested.")
        """
    }

    private static func sceneBreakSummaryText(for suggestion: NativeSceneBreakSuggestion) -> String {
        let lines = suggestion.scenes.enumerated().map { index, scene in
            "\(index + 1). \(scene.title) -> \"\(scene.openingQuote)\""
        }
        .joined(separator: "\n")

        return """
        Proposed scene breaks for \(suggestion.chapterTitle):

        \(lines)
        """
    }

    private static func describe(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return "The assistant request timed out. This usually means the review was heavy or the connection was slow. Try again, or review a smaller scope."
            case .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return "The assistant couldn’t finish because the network connection dropped. Please try again."
            default:
                break
            }
        }
        if let requestError = error as? NativeOpenAIRequestError {
            switch requestError {
            case .invalidResponse:
                return "The assistant returned an invalid response."
            case .apiError(let message):
                return message
            }
        }
        if let assistantError = error as? NativeAssistantError {
            switch assistantError {
            case .invalidResponse:
                return "The assistant returned an invalid response."
            case .apiError(let message):
                return message
            }
        }
        return error.localizedDescription
    }

    private enum NativeAssistantError: Error {
        case invalidResponse
        case apiError(message: String)
    }
}

@MainActor
final class NativePodcastPrepStore: ObservableObject {
    @Published var isGenerating = false
    @Published var generatingSection: NativePodcastPrepSection?
    @Published var lastError: String?

    func generateEpisodePrep(
        apiKey: String,
        project: NativeProject,
        chapter: NativeChapter,
        scenes: [NativeScene],
        previousEpisodeChapter: NativeChapter?,
        previousEpisodeScenes: [NativeScene],
        existingPrep: NativeChapterPodcastPrep
    ) async -> NativeChapterPodcastPrep? {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            lastError = "Add an OpenAI API key to generate podcast prep."
            return nil
        }

        let chapterText = scenes.map { scene in
            """
            [\(scene.title)]
            \(scene.body)
            """
        }.joined(separator: "\n\n")

        guard chapterText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty != nil else {
            lastError = "Open a chapter with scene text before generating podcast prep."
            return nil
        }

        lastError = nil
        isGenerating = true
        defer { isGenerating = false }

        do {
            let hasPreviousEpisode = previousEpisodeChapter != nil &&
                previousEpisodeScenes.contains { !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let model = hasPreviousEpisode ? openAIPodcastRecapModel : openAIRoutineModel
            let decoded = try await performOpenAIResponsesRequest(
                apiKey: trimmedKey,
                requestBody: OpenAIResponsesRequest(
                    model: model,
                    input: buildPrompt(
                        project: project,
                        chapter: chapter,
                        scenes: scenes,
                        previousEpisodeChapter: previousEpisodeChapter,
                        previousEpisodeScenes: previousEpisodeScenes,
                        existingPrep: existingPrep
                    ),
                    store: false
                )
            )
            let responseText = decoded.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let responseData = responseText.data(using: .utf8) else {
                throw NativePodcastPrepError.apiError(message: "The assistant returned invalid podcast prep text.")
            }
            let payload = try JSONDecoder().decode(NativePodcastPrepResponse.self, from: responseData)

            return NativeChapterPodcastPrep(
                episodeTitle: payload.episodeTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                previousEpisodeSummaryVoice: payload.previousEpisodeSummaryVoice.trimmingCharacters(in: .whitespacesAndNewlines),
                previousEpisodeSummary: payload.previousEpisodeSummary.trimmingCharacters(in: .whitespacesAndNewlines),
                introVoice: payload.introVoice.trimmingCharacters(in: .whitespacesAndNewlines),
                outroVoice: payload.outroVoice.trimmingCharacters(in: .whitespacesAndNewlines),
                introText: payload.introText.trimmingCharacters(in: .whitespacesAndNewlines),
                outroText: payload.outroText.trimmingCharacters(in: .whitespacesAndNewlines),
                podcastDescription: payload.podcastDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                coverArtPrompt: payload.coverArtPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
                facebookPost: payload.facebookPost.trimmingCharacters(in: .whitespacesAndNewlines),
                tumblrPost: payload.tumblrPost.trimmingCharacters(in: .whitespacesAndNewlines),
                instagramPost: payload.instagramPost.trimmingCharacters(in: .whitespacesAndNewlines),
                pinterestPost: payload.pinterestPost.trimmingCharacters(in: .whitespacesAndNewlines),
                redditPost: payload.redditPost.trimmingCharacters(in: .whitespacesAndNewlines),
                xPost: payload.xPost.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            lastError = describe(error)
            return nil
        }
    }

    func generateSection(
        apiKey: String,
        project: NativeProject,
        chapter: NativeChapter,
        scenes: [NativeScene],
        previousEpisodeChapter: NativeChapter?,
        previousEpisodeScenes: [NativeScene],
        existingPrep: NativeChapterPodcastPrep,
        section: NativePodcastPrepSection
    ) async -> NativeChapterPodcastPrep? {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            lastError = "Add an OpenAI API key to generate podcast prep."
            return nil
        }

        let chapterText = scenes.map { scene in
            """
            [\(scene.title)]
            \(scene.body)
            """
        }.joined(separator: "\n\n")

        guard chapterText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty != nil else {
            lastError = "Open a chapter with scene text before generating podcast prep."
            return nil
        }

        lastError = nil
        generatingSection = section
        defer { generatingSection = nil }

        do {
            let model = section == .previousEpisodeSummary ? openAIPodcastRecapModel : openAIRoutineModel
            let decoded = try await performOpenAIResponsesRequest(
                apiKey: trimmedKey,
                requestBody: OpenAIResponsesRequest(
                    model: model,
                    input: buildSectionPrompt(
                        project: project,
                        chapter: chapter,
                        scenes: scenes,
                        previousEpisodeChapter: previousEpisodeChapter,
                        previousEpisodeScenes: previousEpisodeScenes,
                        existingPrep: existingPrep,
                        section: section
                    ),
                    store: false
                )
            )
            let responseText = decoded.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let responseData = responseText.data(using: .utf8) else {
                throw NativePodcastPrepError.apiError(message: "The assistant returned invalid section text.")
            }
            let payload = try JSONDecoder().decode(NativePodcastPrepSectionResponse.self, from: responseData)
            return applySectionPayload(payload, to: existingPrep, section: section)
        } catch {
            lastError = describe(error)
            return nil
        }
    }

    private func buildPrompt(
        project: NativeProject,
        chapter: NativeChapter,
        scenes: [NativeScene],
        previousEpisodeChapter: NativeChapter?,
        previousEpisodeScenes: [NativeScene],
        existingPrep: NativeChapterPodcastPrep
    ) -> String {
        let chapterNumber = chapter.order + 1
        let episodeLabel = project.isPodcastProject ? "Episode" : "Chapter"
        let characterNames = project.characterStyles.map(\.name).joined(separator: ", ").nilIfEmpty ?? "None"
        let podcastTitle = project.podcastSetup.podcastTitle.nilIfEmpty ?? project.title
        let hostName = project.podcastSetup.hostDisplayName.nilIfEmpty ?? "Mike Carmel"
        let currentEpisodeTitle = existingPrep.episodeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectivePreviousEpisodeSummaryVoice = existingPrep.previousEpisodeSummaryVoice.nilIfEmpty
        let sceneText = scenes.map { scene in
            """
            [\(scene.title)]
            \(scene.body)
            """
        }.joined(separator: "\n\n")
        let previousEpisodeText = previousEpisodeScenes.map { scene in
            """
            [\(scene.title)]
            \(scene.body)
            """
        }.joined(separator: "\n\n")

        let linksSection = [
            ("Website", project.podcastSetup.websiteURL),
            ("Apple Podcasts", project.podcastSetup.applePodcastURL),
            ("Spotify", project.podcastSetup.spotifyURL),
            ("YouTube", project.podcastSetup.youtubeURL),
            ("Newsletter", project.podcastSetup.newsletterURL)
        ]
        .compactMap { label, value in
            value.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty.map { "\(label): \($0)" }
        }
        .joined(separator: "\n")

        return """
        You are preparing weekly podcast publishing materials for a fiction project.
        Create polished, ready-to-post content based on the current chapter/episode.

        Return JSON only. No markdown. No explanation outside JSON.
        Use this schema exactly:
        {
          "episode_title": "suitable episode title",
          "previous_episode_summary_voice": "character voice for the previous-episode recap, or empty string when no recap is needed",
          "previous_episode_summary": "spoiler-safe recap of the previous episode, or empty string when no recap is needed",
          "intro_voice": "speaker name",
          "outro_voice": "speaker name",
          "intro_text": "podcast intro script",
          "outro_text": "podcast outro script",
          "podcast_summary": "podcast description for posting",
          "cover_art_prompt": "single image generation prompt for cover art",
          "facebook_post": "facebook post",
          "tumblr_post": "tumblr post",
          "instagram_post": "instagram post",
          "pinterest_post": "pinterest post",
          "reddit_post": "reddit post",
          "x_post": "x post"
        }

        Project title: \(project.title)
        Podcast title: \(podcastTitle)
        Format: \(episodeLabel)
        \(episodeLabel) number: \(chapterNumber)
        \(episodeLabel) title: \(existingPrep.episodeTitle.nilIfEmpty ?? displayedChapterTitle(chapter.title, for: project))
        Narrative person: \(project.narrativePerson.nilIfEmpty ?? "None")
        Narrative tense: \(project.narrativeTense.nilIfEmpty ?? "None")
        Genre: \(project.genre.nilIfEmpty ?? "None")
        Subgenre: \(project.subgenre.nilIfEmpty ?? "None")
        Story promise: \(project.storyPromise.nilIfEmpty ?? "None")
        Pacing notes: \(project.pacingNotes.nilIfEmpty ?? "None")
        Continuity memory:
        \(project.continuityMemory.nilIfEmpty ?? "None")

        Character voices available:
        \(characterNames)

        Character visual descriptions:
        \(buildCharacterVisualDescriptions(project.characterStyles))

        Preferred host voice:
        \(hostName)

        Podcast links and calls to action:
        \(linksSection.nilIfEmpty ?? "No links supplied")

        Extra call to action:
        \(project.podcastSetup.callToAction.nilIfEmpty ?? "Invite listeners to rate, review, and share the show.")

        Existing preferred intro voice:
        \(existingPrep.introVoice.nilIfEmpty ?? hostName)

        Existing preferred outro voice:
        \(existingPrep.outroVoice.nilIfEmpty ?? hostName)

        Current episode title:
        \(currentEpisodeTitle.nilIfEmpty ?? "")

        Existing previous-episode recap voice:
        \(effectivePreviousEpisodeSummaryVoice ?? "None")

        Existing previous-episode recap:
        \(existingPrep.previousEpisodeSummary.nilIfEmpty ?? "None")

        Existing episode title:
        \(existingPrep.episodeTitle.nilIfEmpty ?? "None")

        Previous episode available:
        \(previousEpisodeChapter == nil || previousEpisodeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No" : "Yes")

        Previous episode title:
        \(previousEpisodeChapter.map { displayedChapterTitle($0.title, for: project) } ?? "None")

        Requirements:
        - If Current episode title is already filled in, treat it as a user-approved locked title. Return that exact same value as episode_title and use it everywhere in this response.
        - Only propose a new episode title when Current episode title is empty. In that case, return a real title as episode_title.
        - Do not fall back to generic labels like "\(episodeLabel) \(chapterNumber)", "Chapter \(chapterNumber)", "\(episodeLabel) Three", or any other numbering-only title.
        - The proposed title should feel like an actual publishable episode name: concise, evocative, and grounded in the strongest non-spoilery image, object, place, or tension in the episode.
        - If a previous episode exists, first infer the major POV or voice in that previous episode, then choose an opposite established character voice for a brief recap and return that voice as previous_episode_summary_voice.
        - If previous_episode_summary_voice is already supplied and not empty, keep using that chosen voice unless it is clearly impossible.
        - Write previous_episode_summary as a real previously-on recap of the previous episode in that selected opposite POV.
        - The recap may mention the meaningful events, emotional turn, and resulting situation of the previous episode, because listeners are expected to have already heard it.
        - Aim for roughly 60 to 100 words unless the previous episode was especially slight.
        - Keep it concise enough to sit near the start of a podcast intro, but substantial enough to reorient a listener returning a week later.
        - Keep the recap grounded in concrete on-page events, places, actions, and immediate emotional consequences.
        - Prefer specific nouns and actions over thematic or promotional phrasing.
        - Do not turn the recap into trailer copy, poetic commentary, relationship commentary, or a thematic tagline.
        - Do not invent relational framing like "stolen comfort," "growing bond," "they press onward," "no longer alone," "deeper unrest," or similar editorial phrasing unless the supplied text says that directly.
        - End on a concrete unresolved situation or present circumstance, not a dramatic slogan.
        - If there is no previous episode, return empty strings for previous_episode_summary_voice and previous_episode_summary.
        - Use that exact returned episode_title consistently anywhere the title is spoken or referenced in the intro, outro, summary, and social copy.
        - Intro should sound like a podcast intro, mention the podcast title and the \(episodeLabel.lowercased()) number/title, and avoid spoilers.
        - Default intro pattern should be close to: host greeting, show title, \(episodeLabel.lowercased()) number, episode title, one atmospheric setup line at most, then begin.
        - Do not preview multiple upcoming events or foreshadow specific developments unless they are already standard in the existing draft.
        - Outro should reflect the episode lightly, include the season/\(episodeLabel.lowercased()) number/title cleanly, and include a natural call to rate, review, follow, or share.
        - When mentioning listening platforms in the outro, prefer generic phrasing like Apple, Spotify, or wherever listeners get podcasts; do not read out long raw URLs inside the spoken outro.
        - Episode summary should read like compelling teaser copy for a listing or show notes, not a recap.
        - Keep the podcast description spoiler-light: do not reveal second-half developments, late-scene discoveries, ending-state consequences, dream/vision content, or major internal revelations unless the user already supplied them in an existing locked draft.
        - Focus the podcast description on setup, atmosphere, location, tension, and one or two early-episode hooks.
        - It must stay strictly grounded in explicit episode facts and should not invent motives, mystery framing, or descriptive twists that are not clearly present.
        - Cover art prompt should describe one vivid, high-impact visual moment from this \(episodeLabel.lowercased()) suitable for a cinematic single image.
        - Before finalizing the cover art prompt, re-check that all described details are actually supported by the episode text or the supplied character visual descriptions.
        - Social posts should be platform-appropriate, concise where needed, and avoid major spoilers.
        - Use the supplied links and CTA naturally when relevant.
        - Respect character voice notes when choosing or writing in a character voice.

        Previous episode text:
        \(previousEpisodeText.nilIfEmpty ?? "None")

        Episode text:
        \(sceneText)
        """
    }

    private func buildCharacterVisualDescriptions(_ characterStyles: [NativeCharacterStyleGuide]) -> String {
        let descriptions = characterStyles.compactMap { character -> String? in
            let description = character.visualDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { return nil }
            return "\(character.name): \(description)"
        }
        return descriptions.isEmpty ? "None" : descriptions.joined(separator: "\n")
    }

    private func buildSectionPrompt(
        project: NativeProject,
        chapter: NativeChapter,
        scenes: [NativeScene],
        previousEpisodeChapter: NativeChapter?,
        previousEpisodeScenes: [NativeScene],
        existingPrep: NativeChapterPodcastPrep,
        section: NativePodcastPrepSection
    ) -> String {
        let chapterNumber = chapter.order + 1
        let episodeLabel = project.isPodcastProject ? "Episode" : "Chapter"
        let characterNames = project.characterStyles.map(\.name).joined(separator: ", ").nilIfEmpty ?? "None"
        let podcastTitle = project.podcastSetup.podcastTitle.nilIfEmpty ?? project.title
        let hostName = project.podcastSetup.hostDisplayName.nilIfEmpty ?? "Mike Carmel"
        let effectiveEpisodeTitle = existingPrep.episodeTitle.nilIfEmpty ?? displayedChapterTitle(chapter.title, for: project)
        let effectivePreviousEpisodeSummaryVoice = existingPrep.previousEpisodeSummaryVoice.nilIfEmpty
        let sceneText = scenes.map { scene in
            """
            [\(scene.title)]
            \(scene.body)
            """
        }.joined(separator: "\n\n")
        let previousEpisodeText = previousEpisodeScenes.map { scene in
            """
            [\(scene.title)]
            \(scene.body)
            """
        }.joined(separator: "\n\n")
        let linksSection = [
            ("Website", project.podcastSetup.websiteURL),
            ("Apple Podcasts", project.podcastSetup.applePodcastURL),
            ("Spotify", project.podcastSetup.spotifyURL),
            ("YouTube", project.podcastSetup.youtubeURL),
            ("Newsletter", project.podcastSetup.newsletterURL)
        ]
        .compactMap { label, value in
            value.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty.map { "\(label): \($0)" }
        }
        .joined(separator: "\n")

        let existingSectionText: String = {
            switch section {
            case .previousEpisodeSummary: return existingPrep.previousEpisodeSummary
            case .intro: return existingPrep.introText
            case .outro: return existingPrep.outroText
            case .podcastDescription: return existingPrep.podcastDescription
            case .coverArtPrompt: return existingPrep.coverArtPrompt
            case .facebook: return existingPrep.facebookPost
            case .tumblr: return existingPrep.tumblrPost
            case .instagram: return existingPrep.instagramPost
            case .pinterest: return existingPrep.pinterestPost
            case .reddit: return existingPrep.redditPost
            case .x: return existingPrep.xPost
            }
        }()

        let schema: String = {
            switch section {
            case .previousEpisodeSummary:
                return """
                {
                  "previous_episode_summary_voice": "character voice for the recap, or empty string when no recap is needed",
                  "text": "previous episode recap"
                }
                """
            case .intro:
                return """
                {
                  "intro_voice": "speaker name",
                  "text": "intro script"
                }
                """
            case .outro:
                return """
                {
                  "outro_voice": "speaker name",
                  "text": "outro script"
                }
                """
            default:
                return """
                {
                  "text": "section content"
                }
                """
            }
        }()

        return """
        You are preparing one piece of weekly podcast publishing material for a fiction project.
        Return JSON only. No markdown. No explanation outside JSON.
        Use this schema exactly:
        \(schema)

        Section to generate: \(section.title)
        Project title: \(project.title)
        Podcast title: \(podcastTitle)
        Format: \(episodeLabel)
        \(episodeLabel) number: \(chapterNumber)
        \(episodeLabel) title: \(effectiveEpisodeTitle)
        Previous episode available: \(previousEpisodeChapter == nil || previousEpisodeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No" : "Yes")
        Previous episode title: \(previousEpisodeChapter.map { displayedChapterTitle($0.title, for: project) } ?? "None")
        Narrative person: \(project.narrativePerson.nilIfEmpty ?? "None")
        Narrative tense: \(project.narrativeTense.nilIfEmpty ?? "None")
        Genre: \(project.genre.nilIfEmpty ?? "None")
        Subgenre: \(project.subgenre.nilIfEmpty ?? "None")
        Story promise: \(project.storyPromise.nilIfEmpty ?? "None")
        Pacing notes: \(project.pacingNotes.nilIfEmpty ?? "None")
        Continuity memory:
        \(project.continuityMemory.nilIfEmpty ?? "None")

        Character voices available:
        \(characterNames)

        Preferred host voice:
        \(hostName)

        Podcast links and calls to action:
        \(linksSection.nilIfEmpty ?? "No links supplied")

        Extra call to action:
        \(project.podcastSetup.callToAction.nilIfEmpty ?? "Invite listeners to rate, review, and share the show.")

        Existing preferred intro voice:
        \(existingPrep.introVoice.nilIfEmpty ?? hostName)

        Existing preferred outro voice:
        \(existingPrep.outroVoice.nilIfEmpty ?? hostName)

        Existing previous-episode recap voice:
        \(effectivePreviousEpisodeSummaryVoice ?? "None")

        Existing \(section.title) draft:
        \(existingSectionText.nilIfEmpty ?? "None")

        Generation requirements:
        - \(section.generationInstruction)
        - Respect character voice notes when choosing or writing in a character voice.
        - Use the current episode title exactly if the section needs to reference the title.
        - Avoid major spoilers unless light mention is inherent to an outro.
        - Keep factual details grounded in the episode text. Do not invent descriptors or motivations just to make the copy more dramatic.
        - If the current draft already works, return a tighter stronger version rather than a completely different tone.
        - For the previous-episode recap specifically: infer the dominant POV in the previous episode, then write from the opposite POV unless a recap voice is already selected, in which case use the selected voice.
        - The previous-episode recap is allowed to summarize the prior episode’s important events; it should not behave like spoiler-safe promo copy.
        - Target roughly 60 to 100 words unless the previous episode was especially slight.
        - Keep the recap grounded in concrete on-page events, places, actions, and immediate emotional consequences.
        - Prefer specific nouns and actions over thematic or promotional phrasing.
        - Do not use trailer-style or romance-coded phrasing like "stolen comfort," "growing bond," "they press onward," "no longer alone," or other interpretive taglines unless the text states that directly.
        - End on a concrete unresolved situation or present circumstance, not a dramatic slogan.
        - If there is no previous episode, return an empty text field for the previous-episode recap and an empty previous_episode_summary_voice.

        Previous episode text:
        \(previousEpisodeText.nilIfEmpty ?? "None")

        Episode text:
        \(sceneText)
        """
    }

    private func applySectionPayload(
        _ payload: NativePodcastPrepSectionResponse,
        to existingPrep: NativeChapterPodcastPrep,
        section: NativePodcastPrepSection
    ) -> NativeChapterPodcastPrep {
        var updated = existingPrep
        let text = payload.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch section {
        case .previousEpisodeSummary:
            updated.previousEpisodeSummaryVoice = payload.previousEpisodeSummaryVoice?.trimmingCharacters(in: .whitespacesAndNewlines) ?? updated.previousEpisodeSummaryVoice
            updated.previousEpisodeSummary = text
        case .intro:
            updated.introVoice = payload.introVoice?.trimmingCharacters(in: .whitespacesAndNewlines) ?? updated.introVoice
            updated.introText = text
        case .outro:
            updated.outroVoice = payload.outroVoice?.trimmingCharacters(in: .whitespacesAndNewlines) ?? updated.outroVoice
            updated.outroText = text
        case .podcastDescription:
            updated.podcastDescription = text
        case .coverArtPrompt:
            updated.coverArtPrompt = text
        case .facebook:
            updated.facebookPost = text
        case .tumblr:
            updated.tumblrPost = text
        case .instagram:
            updated.instagramPost = text
        case .pinterest:
            updated.pinterestPost = text
        case .reddit:
            updated.redditPost = text
        case .x:
            updated.xPost = text
        }
        return updated
    }

    private func describe(_ error: Error) -> String {
        if let prepError = error as? NativePodcastPrepError {
            switch prepError {
            case .invalidResponse:
                return "The assistant returned an invalid podcast prep response."
            case .apiError(let message):
                return message
            }
        }
        return error.localizedDescription
    }

    private enum NativePodcastPrepError: Error {
        case invalidResponse
        case apiError(message: String)
    }
}

@MainActor
final class NativeFindReplaceStore: ObservableObject {
    @Published var isPresented = false
    @Published var query = ""
    @Published var replacement = ""
    @Published private(set) var queryFocusToken = 0
    @Published var scope: NativeFindScope = .visibleScope
    @Published var mode: NativeFindMode = .contains
    @Published var isMatchCaseEnabled = false
    @Published private(set) var matches: [NativeFindMatch] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var totalReplaced = 0
    @Published private(set) var status: String?
    private var hasActivatedCurrentMatch = false
    private(set) var isAwaitingSceneFocus = false

    var totalFound: Int { matches.count }
    var currentMatchNumber: Int { matches.isEmpty ? 0 : currentIndex + 1 }
    var currentMatch: NativeFindMatch? {
        guard matches.indices.contains(currentIndex) else { return nil }
        return matches[currentIndex]
    }

    func open(initialQuery: String?) {
        if let initialQuery, query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query = initialQuery
        }
        isPresented = true
        status = nil
        queryFocusToken += 1
    }

    func close() {
        isPresented = false
        status = nil
        isAwaitingSceneFocus = false
        NativeTextFormattingController.clearFindHighlights()
    }

    func refresh(
        model: NativeAppModel,
        projectID: UUID,
        visibleScenes: [NativeScene],
        selectionContext: NativeFindSelectionContext?
    ) {
        let decodedQuery = Self.decodedFindReplaceText(query)
        guard !decodedQuery.isEmpty else {
            matches = []
            currentIndex = 0
            status = nil
            hasActivatedCurrentMatch = false
            isAwaitingSceneFocus = false
            NativeTextFormattingController.clearFindHighlights()
            return
        }

        let previousMatch = currentMatch
        let nextMatches: [NativeFindMatch]

        switch scope {
        case .currentSelection:
            guard let selectionContext,
                  selectionContext.selectedRange.location != NSNotFound,
                  selectionContext.selectedRange.length > 0
            else {
                matches = []
                currentIndex = 0
                status = "Select text in the editor to search within the selection."
                hasActivatedCurrentMatch = false
                isAwaitingSceneFocus = false
                return
            }
            nextMatches = Self.matches(
                for: decodedQuery,
                mode: mode,
                isMatchCaseEnabled: isMatchCaseEnabled,
                in: selectionContext.text,
                sceneID: selectionContext.sceneID,
                sceneTitle: selectionContext.sceneTitle,
                limitingTo: selectionContext.selectedRange
            )
        case .selectedScenes:
            let targetScenes = model.selectedSceneIDs.compactMap { sceneID in
                model.scenes.first(where: { $0.id == sceneID && $0.projectID == projectID })
            }
            guard !targetScenes.isEmpty else {
                matches = []
                currentIndex = 0
                status = "Select one or more scenes in the binder to search within scenes."
                hasActivatedCurrentMatch = false
                isAwaitingSceneFocus = false
                return
            }
            nextMatches = targetScenes.flatMap { scene in
                Self.matches(
                    for: decodedQuery,
                    mode: mode,
                    isMatchCaseEnabled: isMatchCaseEnabled,
                    in: scene.body,
                    sceneID: scene.id,
                    sceneTitle: scene.title,
                    limitingTo: nil
                )
            }
        case .selectedChapters:
            let targetScenes = model.selectedChapterIDs
                .filter { chapterID in
                    model.chapters.contains(where: { $0.id == chapterID && $0.projectID == projectID })
                }
                .flatMap { chapterID in
                    model.scenesInChapter(chapterID)
                }
            guard !targetScenes.isEmpty else {
                matches = []
                currentIndex = 0
                status = "Select one or more chapters in the binder to search within chapters."
                hasActivatedCurrentMatch = false
                isAwaitingSceneFocus = false
                return
            }
            nextMatches = targetScenes.flatMap { scene in
                Self.matches(
                    for: decodedQuery,
                    mode: mode,
                    isMatchCaseEnabled: isMatchCaseEnabled,
                    in: scene.body,
                    sceneID: scene.id,
                    sceneTitle: scene.title,
                    limitingTo: nil
                )
            }
        case .visibleScope:
            nextMatches = visibleScenes.flatMap { scene in
                Self.matches(
                    for: decodedQuery,
                    mode: mode,
                    isMatchCaseEnabled: isMatchCaseEnabled,
                    in: scene.body,
                    sceneID: scene.id,
                    sceneTitle: scene.title,
                    limitingTo: nil
                )
            }
        case .entireProject:
            let projectScenes = model.orderedScenesForProject(projectID)
            nextMatches = projectScenes.flatMap { scene in
                Self.matches(
                    for: decodedQuery,
                    mode: mode,
                    isMatchCaseEnabled: isMatchCaseEnabled,
                    in: scene.body,
                    sceneID: scene.id,
                    sceneTitle: scene.title,
                    limitingTo: nil
                )
            }
        }

        matches = nextMatches
        if let previousMatch, let newIndex = nextMatches.firstIndex(where: { $0.sceneID == previousMatch.sceneID && $0.range.location == previousMatch.range.location && $0.range.length == previousMatch.range.length }) {
            currentIndex = newIndex
        } else {
            currentIndex = 0
        }
        hasActivatedCurrentMatch = false
        isAwaitingSceneFocus = false
        status = nextMatches.isEmpty ? "No matches found." : nil
        syncEditorHighlights()
    }

    func goToNext() {
        guard !matches.isEmpty else { return }
        guard !isAwaitingSceneFocus else { return }
        if !hasActivatedCurrentMatch {
            hasActivatedCurrentMatch = true
            status = nil
            syncEditorHighlights()
            return
        }
        currentIndex = (currentIndex + 1) % matches.count
        status = nil
        syncEditorHighlights()
    }

    func goToPrevious() {
        guard !matches.isEmpty else { return }
        guard !isAwaitingSceneFocus else { return }
        if !hasActivatedCurrentMatch {
            currentIndex = max(0, matches.count - 1)
            hasActivatedCurrentMatch = true
            status = nil
            syncEditorHighlights()
            return
        }
        currentIndex = (currentIndex - 1 + matches.count) % matches.count
        status = nil
        syncEditorHighlights()
    }

    func replaceCurrent(using replacement: String) -> NativeFindMatch? {
        guard let match = currentMatch else {
            status = "No active match to replace."
            return nil
        }
        let decodedReplacement = Self.decodedFindReplaceText(replacement)
        guard NativeTextFormattingController.replaceText(in: match.sceneID, range: match.range, with: decodedReplacement) else {
            status = "Open the matching scene in the editor before replacing this match."
            return nil
        }
        totalReplaced += 1
        status = "Replaced 1 match."
        return match
    }

    func replaceCurrentAndMoveNext(using replacement: String) -> Bool {
        guard replaceCurrent(using: replacement) != nil else { return false }
        goToNext()
        return true
    }

    func replaceAllVisible(using replacement: String) -> [NativeFindMatch] {
        guard !matches.isEmpty else {
            status = "No matches to replace."
            return []
        }
        let decodedReplacement = Self.decodedFindReplaceText(replacement)

        let sceneIDs = Set(matches.map(\.sceneID))
        let unavailableSceneIDs = sceneIDs.filter { !NativeTextFormattingController.hasLiveTextView(for: $0) }
        guard unavailableSceneIDs.isEmpty else {
            status = "Open the matching scenes in the editor before using Replace All."
            return []
        }

        var replacedMatches: [NativeFindMatch] = []
        let groupedMatches = Dictionary(grouping: matches, by: \.sceneID)
        let sceneOrder = matches.map(\.sceneID).reduce(into: [UUID]()) { partialResult, sceneID in
            if !partialResult.contains(sceneID) {
                partialResult.append(sceneID)
            }
        }

        for sceneID in sceneOrder {
            let sceneMatches = (groupedMatches[sceneID] ?? []).sorted { $0.range.location > $1.range.location }
            for match in sceneMatches {
                if NativeTextFormattingController.replaceText(in: match.sceneID, range: match.range, with: decodedReplacement) {
                    replacedMatches.append(match)
                }
            }
        }

        totalReplaced += replacedMatches.count
        status = replacedMatches.isEmpty ? "Nothing was replaced." : "Replaced \(replacedMatches.count) matches."
        return replacedMatches
    }

    func focusCurrentMatch(model: NativeAppModel) {
        guard let match = currentMatch else { return }
        hasActivatedCurrentMatch = true
        if NativeTextFormattingController.focus(sceneID: match.sceneID, range: match.range) {
            isAwaitingSceneFocus = false
            status = nil
            syncEditorHighlights()
            return
        }
        isAwaitingSceneFocus = true
        model.selectScene(match.sceneID, modifiers: [])
        NativeTextFormattingController.queuePendingFocus(sceneID: match.sceneID, range: match.range)
        status = "Opening \(match.sceneTitle)..."
        syncEditorHighlights()
    }

    func resumePendingFocus(model: NativeAppModel) {
        guard isAwaitingSceneFocus else { return }
        guard let match = currentMatch else {
            isAwaitingSceneFocus = false
            return
        }
        if NativeTextFormattingController.focus(sceneID: match.sceneID, range: match.range) {
            isAwaitingSceneFocus = false
            status = nil
            syncEditorHighlights()
        }
    }

    func setStatus(_ message: String?) {
        status = message
    }

    private func syncEditorHighlights() {
        NativeTextFormattingController.showFindHighlights(
            matches: matches,
            activeMatch: hasActivatedCurrentMatch ? currentMatch : nil
        )
    }

    private static func matches(
        for query: String,
        mode: NativeFindMode,
        isMatchCaseEnabled: Bool,
        in text: String,
        sceneID: UUID,
        sceneTitle: String,
        limitingTo limitingRange: NSRange?
    ) -> [NativeFindMatch] {
        let nsText = text as NSString
        let searchRange = limitingRange ?? NSRange(location: 0, length: nsText.length)
        guard searchRange.location != NSNotFound, searchRange.length > 0 || limitingRange == nil else { return [] }

        var discoveredMatches: [NativeFindMatch] = []
        var nextLocation = searchRange.location
        let searchEnd = NSMaxRange(searchRange)

        while nextLocation <= searchEnd {
            let remainingLength = searchEnd - nextLocation
            guard remainingLength >= 0 else { break }
            let foundRange = nsText.range(
                of: query,
                options: stringCompareOptions(isMatchCaseEnabled: isMatchCaseEnabled),
                range: NSRange(location: nextLocation, length: remainingLength)
            )
            guard foundRange.location != NSNotFound, foundRange.length > 0 else { break }
            guard isMatchValid(foundRange, in: nsText, mode: mode) else {
                let nextSearchLocation = foundRange.location + max(foundRange.length, 1)
                if nextSearchLocation > searchEnd { break }
                nextLocation = nextSearchLocation
                continue
            }
            discoveredMatches.append(
                NativeFindMatch(
                    sceneID: sceneID,
                    sceneTitle: sceneTitle,
                    range: foundRange,
                    snippet: snippet(for: foundRange, in: nsText)
                )
            )
            let nextSearchLocation = foundRange.location + max(foundRange.length, 1)
            if nextSearchLocation > searchEnd { break }
            nextLocation = nextSearchLocation
        }

        return discoveredMatches
    }

    private static func isMatchValid(_ range: NSRange, in text: NSString, mode: NativeFindMode) -> Bool {
        switch mode {
        case .contains:
            return true
        case .wholeWord:
            return isWholeWord(range, in: text)
        case .startsWith:
            return isWordStart(range.location, in: text)
        case .endsWith:
            return isWordEnd(NSMaxRange(range), in: text)
        }
    }

    private static func isWholeWord(_ range: NSRange, in text: NSString) -> Bool {
        isWordStart(range.location, in: text) && isWordEnd(NSMaxRange(range), in: text)
    }

    private static func isWordStart(_ location: Int, in text: NSString) -> Bool {
        guard location > 0 else { return true }
        return !isWordCharacter(text.character(at: location - 1))
    }

    private static func isWordEnd(_ location: Int, in text: NSString) -> Bool {
        guard location < text.length else { return true }
        return !isWordCharacter(text.character(at: location))
    }

    private static func isWordCharacter(_ character: unichar) -> Bool {
        guard let scalar = UnicodeScalar(Int(character)) else { return false }
        return CharacterSet.alphanumerics.contains(scalar) || scalar == "_"
    }

    private static func snippet(for range: NSRange, in text: NSString) -> String {
        let prefixLength = min(24, range.location)
        let suffixStart = NSMaxRange(range)
        let suffixLength = min(36, max(0, text.length - suffixStart))
        let snippetRange = NSRange(location: range.location - prefixLength, length: prefixLength + range.length + suffixLength)
        let rawSnippet = text.substring(with: snippetRange).replacingOccurrences(of: "\n", with: " ")
        return rawSnippet.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stringCompareOptions(isMatchCaseEnabled: Bool) -> NSString.CompareOptions {
        var options: NSString.CompareOptions = [.diacriticInsensitive]
        if !isMatchCaseEnabled {
            options.insert(.caseInsensitive)
        }
        return options
    }

    private static func decodedFindReplaceText(_ raw: String) -> String {
        guard raw.contains("\\") || raw.contains("^") else { return raw }

        var result = ""
        var iterator = raw.makeIterator()

        while let character = iterator.next() {
            if character == "^" {
                guard let marker = iterator.next() else {
                    result.append("^")
                    break
                }

                switch marker {
                case "p", "P":
                    result.append("\n")
                case "t", "T":
                    result.append("\t")
                default:
                    result.append("^")
                    result.append(marker)
                }
                continue
            }

            guard character == "\\" else {
                result.append(character)
                continue
            }

            guard let escaped = iterator.next() else {
                result.append("\\")
                break
            }

            switch escaped {
            case "n":
                result.append("\n")
            case "r":
                result.append("\r")
            case "t":
                result.append("\t")
            case "\\":
                result.append("\\")
            default:
                result.append("\\")
                result.append(escaped)
            }
        }

        return result
    }
}

@MainActor
final class NativeAPIKeyStore: ObservableObject {
    @Published var apiKey = ""
    @Published var rememberOnThisMac = true {
        didSet {
            UserDefaults.standard.set(rememberOnThisMac, forKey: rememberPreferenceKey)
            guard oldValue != rememberOnThisMac else { return }
            if rememberOnThisMac {
                persistIfNeeded()
            } else {
                deleteStoredKey()
            }
        }
    }

    private let service = "NovelWriterNative"
    private let account = "OpenAIAPIKey"
    private let rememberPreferenceKey = "assistantRememberAPIKey"
    private let storedAPIKeyDefaultsKey = "assistantRememberedAPIKey"
    private var lastPersistedAPIKey = ""
    private static var cachedAPIKey: String?
    private static var hasLoadedCachedAPIKey = false

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: rememberPreferenceKey) == nil {
            defaults.set(true, forKey: rememberPreferenceKey)
        }
        rememberOnThisMac = defaults.bool(forKey: rememberPreferenceKey)

        if rememberOnThisMac {
            if Self.hasLoadedCachedAPIKey {
                apiKey = Self.cachedAPIKey ?? ""
            } else {
                let storedKeyFromDefaults = defaults.string(forKey: storedAPIKeyDefaultsKey)
                let storedKey = storedKeyFromDefaults ?? read() ?? ""
                if storedKeyFromDefaults == nil, !storedKey.isEmpty {
                    defaults.set(storedKey, forKey: storedAPIKeyDefaultsKey)
                }
                Self.cachedAPIKey = storedKey
                Self.hasLoadedCachedAPIKey = true
                apiKey = storedKey
            }
            lastPersistedAPIKey = apiKey
        } else {
            apiKey = ""
        }
    }

    func persistIfNeeded() {
        guard rememberOnThisMac else { return }
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedKey != lastPersistedAPIKey else { return }
        if trimmedKey.isEmpty {
            deleteStoredKey()
            return
        }

        UserDefaults.standard.set(trimmedKey, forKey: storedAPIKeyDefaultsKey)

        let data = Data(trimmedKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let update: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            let attributes: [String: Any] = query.merging(update) { _, new in new }
            SecItemAdd(attributes as CFDictionary, nil)
        }

        lastPersistedAPIKey = trimmedKey
        Self.cachedAPIKey = trimmedKey
        Self.hasLoadedCachedAPIKey = true
    }

    private func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteStoredKey() {
        UserDefaults.standard.removeObject(forKey: storedAPIKeyDefaultsKey)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        lastPersistedAPIKey = ""
        Self.cachedAPIKey = nil
        Self.hasLoadedCachedAPIKey = true
    }
}

struct NativeAppSnapshot: Codable {
    var revision: Int
    var projects: [NativeProject]
    var chapters: [NativeChapter]
    var scenes: [NativeScene]
    var trashedProjects: [NativeTrashedProject]
    var trashedChapters: [NativeTrashedChapter]
    var trashedScenes: [NativeTrashedScene]
    var activeProjectID: UUID?
    var selectedChapterID: UUID?
    var selectedSceneID: UUID?
    var selectedChapterIDs: [UUID]
    var selectedSceneIDs: [UUID]
    var selectionAnchor: BinderSelectionKey?
    var editorFontSize: NativeEditorFontSize
    var editorLineSpacing: NativeEditorLineSpacing
    var editorZoom: NativeEditorZoom
    var showInvisibleCharacters: Bool
    var binderColumnWidth: CGFloat
    var lastEditedLocationBySceneID: [UUID: Int]

    enum CodingKeys: String, CodingKey {
        case revision
        case projects
        case chapters
        case scenes
        case trashedProjects
        case trashedChapters
        case trashedScenes
        case activeProjectID
        case selectedChapterID
        case selectedSceneID
        case selectedChapterIDs
        case selectedSceneIDs
        case selectionAnchor
        case editorFontSize
        case editorLineSpacing
        case editorZoom
        case showInvisibleCharacters
        case binderColumnWidth
        case lastEditedLocationBySceneID
    }

    init(
        revision: Int,
        projects: [NativeProject],
        chapters: [NativeChapter],
        scenes: [NativeScene],
        trashedProjects: [NativeTrashedProject],
        trashedChapters: [NativeTrashedChapter],
        trashedScenes: [NativeTrashedScene],
        activeProjectID: UUID?,
        selectedChapterID: UUID?,
        selectedSceneID: UUID?,
        selectedChapterIDs: [UUID],
        selectedSceneIDs: [UUID],
        selectionAnchor: BinderSelectionKey?,
        editorFontSize: NativeEditorFontSize,
        editorLineSpacing: NativeEditorLineSpacing,
        editorZoom: NativeEditorZoom,
        showInvisibleCharacters: Bool,
        binderColumnWidth: CGFloat,
        lastEditedLocationBySceneID: [UUID: Int]
    ) {
        self.revision = revision
        self.projects = projects
        self.chapters = chapters
        self.scenes = scenes
        self.trashedProjects = trashedProjects
        self.trashedChapters = trashedChapters
        self.trashedScenes = trashedScenes
        self.activeProjectID = activeProjectID
        self.selectedChapterID = selectedChapterID
        self.selectedSceneID = selectedSceneID
        self.selectedChapterIDs = selectedChapterIDs
        self.selectedSceneIDs = selectedSceneIDs
        self.selectionAnchor = selectionAnchor
        self.editorFontSize = editorFontSize
        self.editorLineSpacing = editorLineSpacing
        self.editorZoom = editorZoom
        self.showInvisibleCharacters = showInvisibleCharacters
        self.binderColumnWidth = binderColumnWidth
        self.lastEditedLocationBySceneID = lastEditedLocationBySceneID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
        projects = try container.decode([NativeProject].self, forKey: .projects)
        chapters = try container.decode([NativeChapter].self, forKey: .chapters)
        scenes = try container.decode([NativeScene].self, forKey: .scenes)
        trashedProjects = try container.decodeIfPresent([NativeTrashedProject].self, forKey: .trashedProjects) ?? []
        trashedChapters = try container.decodeIfPresent([NativeTrashedChapter].self, forKey: .trashedChapters) ?? []
        trashedScenes = try container.decodeIfPresent([NativeTrashedScene].self, forKey: .trashedScenes) ?? []
        activeProjectID = try container.decodeIfPresent(UUID.self, forKey: .activeProjectID)
        selectedChapterID = try container.decodeIfPresent(UUID.self, forKey: .selectedChapterID)
        selectedSceneID = try container.decodeIfPresent(UUID.self, forKey: .selectedSceneID)
        selectedChapterIDs = try container.decodeIfPresent([UUID].self, forKey: .selectedChapterIDs) ?? []
        selectedSceneIDs = try container.decodeIfPresent([UUID].self, forKey: .selectedSceneIDs) ?? []
        selectionAnchor = try container.decodeIfPresent(BinderSelectionKey.self, forKey: .selectionAnchor)
        editorFontSize = try container.decodeIfPresent(NativeEditorFontSize.self, forKey: .editorFontSize) ?? .medium
        editorLineSpacing = try container.decodeIfPresent(NativeEditorLineSpacing.self, forKey: .editorLineSpacing) ?? .oneAndHalf
        editorZoom = try container.decodeIfPresent(NativeEditorZoom.self, forKey: .editorZoom) ?? .x100
        showInvisibleCharacters = try container.decodeIfPresent(Bool.self, forKey: .showInvisibleCharacters) ?? false
        binderColumnWidth = try container.decodeIfPresent(CGFloat.self, forKey: .binderColumnWidth) ?? 290
        lastEditedLocationBySceneID = try container.decodeIfPresent([UUID: Int].self, forKey: .lastEditedLocationBySceneID) ?? [:]
    }
}

struct NativeAutomaticBackupInfo: Identifiable, Equatable {
    let id: URL
    let url: URL
    let exportedAt: Date
    let appVersion: String
    let modifiedAt: Date
}

struct NativeTrashedProject: Identifiable, Equatable, Codable {
    let id: UUID
    let project: NativeProject
    let chapters: [NativeChapter]
    let scenes: [NativeScene]
    let deletedAt: Date
}

struct NativeTrashedScene: Identifiable, Equatable, Codable {
    let id: UUID
    let scene: NativeScene
    let originalProjectID: UUID
    let originalChapterID: UUID
    let originalIndex: Int
    let chapterTitle: String?
    let deletedAt: Date
}

struct NativeTrashedChapter: Identifiable, Equatable, Codable {
    let id: UUID
    let chapter: NativeChapter
    let scenes: [NativeScene]
    let originalProjectID: UUID
    let originalIndex: Int
    let deletedAt: Date
}

@MainActor
final class NativeAppModel: ObservableObject {
    @Published var projects: [NativeProject]
    @Published var chapters: [NativeChapter]
    @Published var scenes: [NativeScene]
    @Published var trashedProjects: [NativeTrashedProject]
    @Published var trashedChapters: [NativeTrashedChapter]
    @Published var trashedScenes: [NativeTrashedScene]
    @Published var activeProjectID: UUID?
    @Published var selectedChapterID: UUID?
    @Published var selectedSceneID: UUID?
    @Published var selectedChapterIDs: [UUID]
    @Published var selectedSceneIDs: [UUID]
    @Published var selectionAnchor: BinderSelectionKey?
    @Published var pendingUndo: NativeUndoState?
    @Published var editorFontSize: NativeEditorFontSize
    @Published var editorLineSpacing: NativeEditorLineSpacing
    @Published var editorZoom: NativeEditorZoom
    @Published var showInvisibleCharacters: Bool
    @Published var binderColumnWidth: CGFloat
    var lastEditedLocationBySceneID: [UUID: Int]
    @Published private(set) var storageLocationDescription: String = ""
    @Published private(set) var storagePathDescription: String = ""
    @Published private(set) var storageLastSavedDescription: String = "Not saved yet"
    @Published private(set) var storageBackupDescription: String = ""
    @Published private(set) var storageErrorMessage: String?
    @Published private(set) var storageExternalChangeMessage: String?

    private var saveURL: URL
    private var storageFolderURL: URL
    private var undoClearWorkItem: DispatchWorkItem?
    private var textEditPersistWorkItem: DispatchWorkItem?
    private var lastKnownFileModificationDate: Date?
    private var isAccessingStorageSecurityScope = false
    private var loadedSnapshotRevision: Int = 0
    private var lastKnownDiskSnapshotRevision: Int = 0
    private static let storageBookmarkKey = "nativeStorageFolderBookmark"
    private static let snapshotFilename = "native-proof-of-concept.json"
    private static let automaticBackupsFolderName = "Automatic Backups"
    private static let automaticBackupInterval: TimeInterval = 10 * 60
    private static let automaticBackupRecentRetention: TimeInterval = 24 * 60 * 60
    private static let automaticBackupDailyRetentionDays = 30
    private static let coalescedTextEditPersistDelay: TimeInterval = 1.4

    init() {
        let resolvedFolderURL = Self.resolveStorageFolderURL()
        let resolvedSaveURL = resolvedFolderURL.appendingPathComponent(Self.snapshotFilename)
        let initialStorageAccessState = Self.startPersistentStorageAccessIfNeeded(for: resolvedFolderURL)
        self.storageFolderURL = resolvedFolderURL
        self.saveURL = resolvedSaveURL
        self.storageLocationDescription = Self.storageDescription(for: resolvedFolderURL)
        self.storagePathDescription = resolvedFolderURL.path
        self.storageBackupDescription = Self.backupDescription(for: resolvedFolderURL)
        self.isAccessingStorageSecurityScope = initialStorageAccessState

        if let snapshot = Self.loadSnapshot(from: resolvedSaveURL) {
            self.projects = []
            self.chapters = []
            self.scenes = []
            self.trashedProjects = []
            self.trashedChapters = []
            self.trashedScenes = []
            self.activeProjectID = nil
            self.selectedChapterID = nil
            self.selectedSceneID = nil
            self.selectedChapterIDs = []
            self.selectedSceneIDs = []
            self.selectionAnchor = nil
            self.editorFontSize = .medium
            self.editorLineSpacing = .oneAndHalf
            self.editorZoom = .x100
            self.showInvisibleCharacters = false
            self.binderColumnWidth = 290
            self.lastEditedLocationBySceneID = [:]
            apply(snapshot: snapshot)
            self.pendingUndo = nil
            refreshStorageStatus(detectExternalChanges: false)
            return
        }

        let project = NativeProject(id: UUID(), title: "The Test Novel", updatedAt: .now, styleNotes: "", approvedWords: [], genre: "", subgenre: "", storyPromise: "", pacingNotes: "", avoidNotes: "", continuityMemory: "", isPodcastProject: false, podcastSetup: NativePodcastSetup(), characterStyles: [], audioPronunciationReplacements: [])
        let chapterOne = NativeChapter(id: UUID(), projectID: project.id, title: "Chapter 1", order: 0)
        let chapterTwo = NativeChapter(id: UUID(), projectID: project.id, title: "Chapter 2", order: 1)
        let sceneOne = NativeScene(
            id: UUID(),
            projectID: project.id,
            chapterID: chapterOne.id,
            title: "Scene 1",
            order: 0,
            body: "This is the first scene. The native proof of concept should preserve the calm, focused writing feel of Novel Writer.",
            richTextRTF: nil
        )
        let sceneTwo = NativeScene(
            id: UUID(),
            projectID: project.id,
            chapterID: chapterTwo.id,
            title: "Scene 1",
            order: 0,
            body: "Selecting a chapter should open all of its scenes together. Selecting a scene should return to single-scene editing.",
            richTextRTF: nil
        )

        self.projects = [project]
        self.chapters = [chapterOne, chapterTwo]
        self.scenes = [sceneOne, sceneTwo]
        self.trashedProjects = []
        self.trashedChapters = []
        self.trashedScenes = []
        self.activeProjectID = nil
        self.selectedChapterID = nil
        self.selectedSceneID = nil
        self.selectedChapterIDs = []
        self.selectedSceneIDs = []
        self.selectionAnchor = nil
        self.pendingUndo = nil
        self.editorFontSize = .medium
        self.editorLineSpacing = .oneAndHalf
        self.editorZoom = .x100
        self.showInvisibleCharacters = false
        self.binderColumnWidth = 290
        self.lastEditedLocationBySceneID = [:]
        persist()
    }

    var activeProject: NativeProject? {
        guard let activeProjectID else { return nil }
        return projects.first(where: { $0.id == activeProjectID })
    }

    var isUsingCustomStorageLocation: Bool {
        storageFolderURL.standardizedFileURL != Self.defaultStorageFolderURL().standardizedFileURL
    }

    func chapters(for projectID: UUID) -> [NativeChapter] {
        chapters.filter { $0.projectID == projectID }.sorted { $0.order < $1.order }
    }

    func scenesInChapter(_ chapterID: UUID) -> [NativeScene] {
        scenes.filter { $0.chapterID == chapterID }.sorted { $0.order < $1.order }
    }

    func scenesInProject(_ projectID: UUID) -> [NativeScene] {
        scenes.filter { $0.projectID == projectID }
    }

    func orderedScenesForProject(_ projectID: UUID) -> [NativeScene] {
        chapters(for: projectID).flatMap { scenesInChapter($0.id) }
    }

    func chapterCount(for projectID: UUID) -> Int {
        chapters(for: projectID).count
    }

    func wordCount(for projectID: UUID) -> Int {
        scenesInProject(projectID).reduce(0) { partialResult, scene in
            partialResult + scene.body.split(whereSeparator: \.isWhitespace).count
        }
    }

    func backupData(for projectID: UUID) -> Data? {
        guard let project = projects.first(where: { $0.id == projectID }) else { return nil }
        let package = NativeProjectBackupPackage(
            exportedAt: Date(),
            appVersion: NativeBuildInfo.displayVersion,
            project: project,
            chapters: chapters(for: projectID),
            scenes: orderedScenesForProject(projectID)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(package)
    }

    func manuscriptExportText(for projectID: UUID, preset: NativeExportPreset = .standardManuscript) -> String? {
        guard let project = projects.first(where: { $0.id == projectID }) else { return nil }
        let projectChapters = chapters(for: projectID)
        var lines: [String] = [project.title, ""]

        for (chapterIndex, chapter) in projectChapters.enumerated() {
            let chapterHeading = exportChapterHeading(for: chapter, chapterIndex: chapterIndex, project: project)
            lines.append(chapterHeading)
            lines.append("")

            let chapterScenes = scenesInChapter(chapter.id)
            for (sceneIndex, scene) in chapterScenes.enumerated() {
                if shouldIncludeSceneHeading(in: chapterScenes, preset: preset) {
                    lines.append(scene.title)
                    lines.append("")
                }
                lines.append(scene.body.trimmingCharacters(in: .whitespacesAndNewlines))
                lines.append("")
                if chapterScenes.count > 1, sceneIndex < chapterScenes.count - 1 {
                    lines.append("* * *")
                    lines.append("")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    func binderExportScope(forChapterID chapterID: UUID) -> NativeBinderExportScope {
        if explicitSelectedBinderItemCount > 1, selectedChapterIDs.contains(chapterID) {
            return .selected
        }
        return .chapter(chapterID)
    }

    func binderExportScope(forSceneID sceneID: UUID) -> NativeBinderExportScope {
        if explicitSelectedBinderItemCount > 1, isSceneHighlighted(sceneID) {
            return .selected
        }
        return .scene(sceneID)
    }

    func binderExportText(for scope: NativeBinderExportScope, applyAudioPronunciations: Bool) -> (text: String, suggestedFilename: String)? {
        let resolved: (project: NativeProject, text: String, filenameStem: String)?
        switch scope {
        case let .chapter(chapterID):
            resolved = binderChapterExport(for: chapterID)
        case let .scene(sceneID):
            resolved = binderSceneExport(for: sceneID)
        case .selected:
            resolved = binderSelectedExport()
        }

        guard let resolved else { return nil }
        let text = applyAudioPronunciations
            ? applyAudioPronunciationReplacements(to: resolved.text, for: resolved.project)
            : resolved.text
        let suffix = applyAudioPronunciations ? "-audio" : ""
        return (text, "\(resolved.filenameStem)\(suffix).txt")
    }

    func manuscriptDOCXData(for projectID: UUID, preset: NativeExportPreset = .kdpPaperback) -> Data? {
        let attributed = manuscriptAttributedString(for: projectID, preset: preset)
        let range = NSRange(location: 0, length: attributed.length)
        return try? attributed.data(
            from: range,
            documentAttributes: documentAttributes(for: projectID, preset: preset)
        )
    }

    private var explicitSelectedBinderItemCount: Int {
        uniquePreservingOrder(selectedChapterIDs).count + uniquePreservingOrder(selectedSceneIDs).count
    }

    private func binderChapterExport(for chapterID: UUID) -> (project: NativeProject, text: String, filenameStem: String)? {
        guard let chapter = chapters.first(where: { $0.id == chapterID }),
              let project = projects.first(where: { $0.id == chapter.projectID }) else {
            return nil
        }

        let text = composeBinderExportText(
            project: project,
            sections: [
                (
                    chapter: chapter,
                    scenes: scenesInChapter(chapter.id),
                    includeSceneHeadings: shouldIncludeSceneHeading(in: scenesInChapter(chapter.id), preset: .standardManuscript)
                )
            ]
        )
        return (project, text, sanitizedExportFilename(project.title) + "-chapter-\(chapter.order + 1)")
    }

    private func binderSceneExport(for sceneID: UUID) -> (project: NativeProject, text: String, filenameStem: String)? {
        guard let scene = scenes.first(where: { $0.id == sceneID }),
              let chapter = chapters.first(where: { $0.id == scene.chapterID }),
              let project = projects.first(where: { $0.id == scene.projectID }) else {
            return nil
        }

        let text = composeBinderExportText(
            project: project,
            sections: [
                (
                    chapter: chapter,
                    scenes: [scene],
                    includeSceneHeadings: true
                )
            ]
        )
        return (project, text, sanitizedExportFilename(project.title) + "-chapter-\(chapter.order + 1)-scene-\(scene.order + 1)")
    }

    private func binderSelectedExport() -> (project: NativeProject, text: String, filenameStem: String)? {
        guard let activeProjectID,
              let project = projects.first(where: { $0.id == activeProjectID }) else {
            return nil
        }

        let selectedChapterSet = Set(selectedChapterIDs)
        let selectedSceneSet = Set(selectedSceneIDs)
        var sections: [(chapter: NativeChapter, scenes: [NativeScene], includeSceneHeadings: Bool)] = []

        for chapter in chapters(for: activeProjectID) {
            if selectedChapterSet.contains(chapter.id) {
                let chapterScenes = scenesInChapter(chapter.id)
                sections.append((
                    chapter: chapter,
                    scenes: chapterScenes,
                    includeSceneHeadings: shouldIncludeSceneHeading(in: chapterScenes, preset: .standardManuscript)
                ))
                continue
            }

            let chapterScenes = scenesInChapter(chapter.id).filter { selectedSceneSet.contains($0.id) }
            guard !chapterScenes.isEmpty else { continue }
            sections.append((
                chapter: chapter,
                scenes: chapterScenes,
                includeSceneHeadings: true
            ))
        }

        guard !sections.isEmpty else { return nil }
        let text = composeBinderExportText(project: project, sections: sections)
        return (project, text, sanitizedExportFilename(project.title) + "-selection")
    }

    private func composeBinderExportText(
        project: NativeProject,
        sections: [(chapter: NativeChapter, scenes: [NativeScene], includeSceneHeadings: Bool)]
    ) -> String {
        var lines: [String] = [project.title, ""]

        for (index, section) in sections.enumerated() {
            let chapterHeading = exportChapterHeading(
                for: section.chapter,
                chapterIndex: section.chapter.order,
                project: project
            )
            lines.append(chapterHeading)
            lines.append("")

            for (sceneIndex, scene) in section.scenes.enumerated() {
                if section.includeSceneHeadings {
                    lines.append(scene.title)
                    lines.append("")
                }
                lines.append(scene.body.trimmingCharacters(in: .whitespacesAndNewlines))
                lines.append("")
                if section.scenes.count > 1, sceneIndex < section.scenes.count - 1 {
                    lines.append("* * *")
                    lines.append("")
                }
            }

            if index < sections.count - 1 {
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func applyAudioPronunciationReplacements(to text: String, for project: NativeProject) -> String {
        let replacements = activeAudioPronunciationReplacements(for: project)
        guard !replacements.isEmpty else { return text }

        var updatedText = text
        for replacement in replacements {
            let escaped = NSRegularExpression.escapedPattern(for: replacement.writtenForm)
            let pattern = "\\b\(escaped)\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            updatedText = regex.stringByReplacingMatches(
                in: updatedText,
                options: [],
                range: NSRange(updatedText.startIndex..., in: updatedText),
                withTemplate: replacement.spokenForm
            )
        }
        return updatedText
    }

    private func activeAudioPronunciationReplacements(for project: NativeProject) -> [NativeAudioPronunciationReplacement] {
        project.audioPronunciationReplacements
            .filter { $0.isEnabled }
            .map { replacement in
                NativeAudioPronunciationReplacement(
                    id: replacement.id,
                    writtenForm: replacement.writtenForm.trimmingCharacters(in: .whitespacesAndNewlines),
                    spokenForm: replacement.spokenForm.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: replacement.notes,
                    isEnabled: replacement.isEnabled
                )
            }
            .filter { !$0.writtenForm.isEmpty && !$0.spokenForm.isEmpty }
            .sorted { lhs, rhs in lhs.writtenForm.count > rhs.writtenForm.count }
    }

    private func sanitizedExportFilename(_ title: String) -> String {
        let cleaned = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return cleaned.isEmpty ? "export" : cleaned
    }

    private func manuscriptAttributedString(for projectID: UUID, preset: NativeExportPreset) -> NSAttributedString {
        let document = NSMutableAttributedString()

        guard let project = projects.first(where: { $0.id == projectID }) else {
            return document
        }

        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center
        titleParagraph.paragraphSpacing = preset == .kdpPaperback ? 26 : 20

        document.append(
            NSAttributedString(
                string: project.title + "\n",
                attributes: [
                    .font: exportTitleFont(for: preset),
                    .foregroundColor: NativeTheme.ink1,
                    .paragraphStyle: titleParagraph
                ]
            )
        )

        document.append(NSAttributedString(string: "\n"))
        if preset == .kdpPaperback || preset == .kdpHardcover {
            document.append(pageBreakString())
        }

        for (chapterIndex, chapter) in chapters(for: projectID).enumerated() {
            let chapterParagraph = NSMutableParagraphStyle()
            chapterParagraph.alignment = .center
            chapterParagraph.paragraphSpacingBefore = preset == .kdpPaperback ? 24 : 18
            chapterParagraph.paragraphSpacing = preset == .kdpPaperback ? 18 : 12

            if chapterIndex > 0 {
                document.append(pageBreakString())
            }

            let chapterTitle = exportChapterHeading(for: chapter, chapterIndex: chapterIndex, project: project)
            document.append(
                NSAttributedString(
                    string: chapterTitle + "\n",
                    attributes: [
                        .font: exportChapterFont(for: preset),
                        .foregroundColor: NativeTheme.ink1,
                        .paragraphStyle: chapterParagraph
                    ]
                )
            )

            let chapterScenes = scenesInChapter(chapter.id)
            for (sceneIndex, scene) in chapterScenes.enumerated() {
                if shouldIncludeSceneHeading(in: chapterScenes, preset: preset) {
                    let sceneParagraph = NSMutableParagraphStyle()
                    sceneParagraph.paragraphSpacingBefore = 10
                    sceneParagraph.paragraphSpacing = 6
                    sceneParagraph.alignment = preset == .kdpHardcover ? .left : .left

                    let sceneHeadingText: String
                    sceneHeadingText = scene.title

                    document.append(
                        NSAttributedString(
                            string: sceneHeadingText + "\n",
                            attributes: [
                                .font: exportSceneHeadingFont(for: preset),
                                .foregroundColor: preset == .standardManuscript ? NativeTheme.accent : NativeTheme.ink2,
                                .paragraphStyle: sceneParagraph
                            ]
                        )
                    )
                }

                document.append(exportAttributedBody(for: scene, preset: preset))
                document.append(NSAttributedString(string: "\n"))

                if sceneIndex < chapterScenes.count - 1 {
                    document.append(NSAttributedString(string: "\n"))
                }
            }
        }

        return document
    }

    private func exportChapterHeading(for chapter: NativeChapter, chapterIndex: Int, project: NativeProject) -> String {
        "\(chapterKindName(for: project)) \(chapterIndex + 1): \(displayedChapterTitle(chapter.title, for: project))"
    }

    private func shouldIncludeSceneHeading(in chapterScenes: [NativeScene], preset: NativeExportPreset) -> Bool {
        switch preset {
        case .standardManuscript:
            return chapterScenes.count > 1
        case .kdpPaperback, .kdpHardcover:
            return chapterScenes.count > 1
        }
    }

    private func exportAttributedBody(for scene: NativeScene, preset: NativeExportPreset) -> NSAttributedString {
        let paragraph = exportBodyParagraphStyle(for: preset)
        let fallbackFont = exportBodyFont(for: preset)

        if let richTextRTF = scene.richTextRTF,
           let attributed = try? NSMutableAttributedString(
                data: richTextRTF,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
           ) {
            let fullRange = NSRange(location: 0, length: attributed.length)
            attributed.beginEditing()
            attributed.enumerateAttributes(in: fullRange) { attributes, range, _ in
                let currentFont = (attributes[.font] as? NSFont) ?? fallbackFont
                let normalizedFont = exportBodyFont(for: preset, from: currentFont)
                attributed.addAttributes([
                    .font: normalizedFont,
                    .foregroundColor: NativeTheme.ink1,
                    .paragraphStyle: paragraph
                ], range: range)
            }
            attributed.endEditing()
            if !attributed.string.hasSuffix("\n") {
                attributed.append(NSAttributedString(string: "\n"))
            }
            return attributed
        }

        return NSAttributedString(
            string: scene.body.trimmingCharacters(in: .whitespacesAndNewlines) + "\n",
            attributes: [
                .font: fallbackFont,
                .foregroundColor: NativeTheme.ink1,
                .paragraphStyle: paragraph
            ]
        )
    }

    private func exportTitleFont(for preset: NativeExportPreset) -> NSFont {
        switch preset {
        case .standardManuscript:
            return NSFont(name: "Iowan Old Style", size: 24) ?? .boldSystemFont(ofSize: 24)
        case .kdpPaperback:
            return NSFont(name: "Baskerville", size: 22) ?? .boldSystemFont(ofSize: 22)
        case .kdpHardcover:
            return NSFont(name: "Baskerville", size: 24) ?? .boldSystemFont(ofSize: 24)
        }
    }

    private func exportChapterFont(for preset: NativeExportPreset) -> NSFont {
        switch preset {
        case .standardManuscript:
            return NSFont(name: "Iowan Old Style", size: 18) ?? .boldSystemFont(ofSize: 18)
        case .kdpPaperback:
            return NSFont(name: "Baskerville-SemiBold", size: 18) ?? .boldSystemFont(ofSize: 18)
        case .kdpHardcover:
            return NSFont(name: "Baskerville-SemiBold", size: 20) ?? .boldSystemFont(ofSize: 20)
        }
    }

    private func exportSceneHeadingFont(for preset: NativeExportPreset) -> NSFont {
        switch preset {
        case .standardManuscript:
            return NSFont(name: "Avenir Next Demi Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        case .kdpPaperback:
            return NSFont(name: "Avenir Next Demi Bold", size: 11.5) ?? .boldSystemFont(ofSize: 11.5)
        case .kdpHardcover:
            return NSFont(name: "Avenir Next Demi Bold", size: 12.5) ?? .boldSystemFont(ofSize: 12.5)
        }
    }

    private func exportBodyFont(for preset: NativeExportPreset, from currentFont: NSFont? = nil) -> NSFont {
        let pointSize: CGFloat
        let fontName: String
        switch preset {
        case .standardManuscript:
            fontName = "Courier Prime"
            pointSize = 12
        case .kdpPaperback:
            fontName = "Times New Roman"
            pointSize = 12
        case .kdpHardcover:
            fontName = "Times New Roman"
            pointSize = 12.5
        }

        if let currentFont {
            let descriptor = currentFont.fontDescriptor.withFamily(fontName).withSize(pointSize)
            return NSFont(descriptor: descriptor, size: pointSize)
                ?? NSFont(name: fontName, size: pointSize)
                ?? .systemFont(ofSize: pointSize)
        }

        return NSFont(name: fontName, size: pointSize) ?? .systemFont(ofSize: pointSize)
    }

    private func exportBodyParagraphStyle(for preset: NativeExportPreset) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        switch preset {
        case .standardManuscript:
            paragraph.paragraphSpacing = 12
            paragraph.lineSpacing = 10
            paragraph.firstLineHeadIndent = 0
        case .kdpPaperback:
            paragraph.paragraphSpacing = 0
            paragraph.lineSpacing = 0
            paragraph.firstLineHeadIndent = 14.4
            paragraph.alignment = .justified
        case .kdpHardcover:
            paragraph.paragraphSpacing = 0
            paragraph.lineSpacing = 0
            paragraph.firstLineHeadIndent = 14.4
            paragraph.alignment = .justified
        }
        return paragraph
    }

    private func pageBreakString() -> NSAttributedString {
        NSAttributedString(string: "\u{000C}")
    }

    private func documentAttributes(for projectID: UUID, preset: NativeExportPreset) -> [NSAttributedString.DocumentAttributeKey: Any] {
        var attributes: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.officeOpenXML
        ]

        guard preset != .standardManuscript else { return attributes }

        let pageCount = estimatedKDPPageCount(for: projectID, preset: preset)
        let trimSize = NSSize(width: 6 * 72, height: 9 * 72)
        let gutter = kdpInsideMarginPoints(forEstimatedPageCount: pageCount)
        let topBottom: CGFloat = 72

        attributes[.paperSize] = trimSize
        attributes[.topMargin] = topBottom
        attributes[.bottomMargin] = topBottom
        attributes[.leftMargin] = gutter
        attributes[.rightMargin] = gutter
        return attributes
    }

    private func estimatedKDPPageCount(for projectID: UUID, preset: NativeExportPreset) -> Int {
        let words = max(1, wordCount(for: projectID))
        let wordsPerPage: Double = preset == .kdpHardcover ? 310 : 300
        return max(75, Int(ceil(Double(words) / wordsPerPage)))
    }

    private func kdpInsideMarginPoints(forEstimatedPageCount pageCount: Int) -> CGFloat {
        let inches: CGFloat
        switch pageCount {
        case 0..<151:
            inches = 0.375
        case 151..<301:
            inches = 0.5
        case 301..<501:
            inches = 0.625
        case 501..<701:
            inches = 0.75
        default:
            inches = 0.875
        }
        return inches * 72
    }

    func orderedBinderKeys(for projectID: UUID) -> [BinderSelectionKey] {
        chapters(for: projectID).flatMap { chapter in
            [BinderSelectionKey.chapter(chapter.id)] + scenesInChapter(chapter.id).map { BinderSelectionKey.scene($0.id) }
        }
    }

    func openProject(_ project: NativeProject) {
        activeProjectID = project.id
        if let chapter = chapters(for: project.id).first {
            selectChapter(chapter.id, modifiers: [])
        } else {
            selectedChapterID = nil
            selectedSceneID = nil
            selectedChapterIDs = []
            selectedSceneIDs = []
            selectionAnchor = nil
            persist()
        }
    }

    func returnToProjects() {
        activeProjectID = nil
        selectedChapterID = nil
        selectedSceneID = nil
        selectedChapterIDs = []
        selectedSceneIDs = []
        selectionAnchor = nil
        persist()
    }

    func createProject() {
        let projectNumber = projects.count + 1
        let project = NativeProject(id: UUID(), title: "New Novel \(projectNumber)", updatedAt: .now, styleNotes: "", approvedWords: [], genre: "", subgenre: "", storyPromise: "", pacingNotes: "", avoidNotes: "", continuityMemory: "", isPodcastProject: false, podcastSetup: NativePodcastSetup(), characterStyles: [], audioPronunciationReplacements: [])
        projects.append(project)
        let chapter = NativeChapter(id: UUID(), projectID: project.id, title: "Chapter 1", order: 0)
        let scene = NativeScene(id: UUID(), projectID: project.id, chapterID: chapter.id, title: "Scene 1", order: 0, body: "", richTextRTF: nil)
        chapters.append(chapter)
        scenes.append(scene)
        openProject(project)
        persist()
    }

    func importDOCXProject(from url: URL) throws {
        let imported = try Self.parseDOCXDocument(at: url)
        let projectTitle = imported.projectTitle?.nilIfEmpty ?? url.deletingPathExtension().lastPathComponent
        let project = NativeProject(
            id: UUID(),
            title: projectTitle,
            updatedAt: .now,
            styleNotes: "",
            approvedWords: [],
            genre: "",
            subgenre: "",
            storyPromise: "",
            pacingNotes: "",
            avoidNotes: "",
            continuityMemory: "",
            isPodcastProject: false,
            podcastSetup: NativePodcastSetup(),
            characterStyles: [],
            audioPronunciationReplacements: []
        )
        projects.append(project)

        let chapterDrafts = imported.chapters.isEmpty
            ? [NativeImportedChapterDraft(title: "Chapter 1", scenes: [NativeImportedSceneDraft(title: "Scene 1", body: "", richTextRTF: nil)])]
            : imported.chapters

        for (chapterIndex, chapterDraft) in chapterDrafts.enumerated() {
            let chapter = NativeChapter(
                id: UUID(),
                projectID: project.id,
                title: chapterDraft.title,
                order: chapterIndex
            )
            chapters.append(chapter)

            let sceneDrafts = chapterDraft.scenes.isEmpty
                ? [NativeImportedSceneDraft(title: "Scene 1", body: "", richTextRTF: nil)]
                : chapterDraft.scenes

            for (sceneIndex, sceneDraft) in sceneDrafts.enumerated() {
                scenes.append(
                    NativeScene(
                        id: UUID(),
                        projectID: project.id,
                        chapterID: chapter.id,
                        title: sceneDraft.title,
                        order: sceneIndex,
                        body: sceneDraft.body,
                        richTextRTF: sceneDraft.richTextRTF
                    )
                )
            }
        }

        openProject(project)
        persist()
    }

    func moveStorage(to folderURL: URL) {
        storageErrorMessage = nil
        storageExternalChangeMessage = nil
        deactivatePersistentStorageAccessIfNeeded()
        let normalizedFolderURL = folderURL.standardizedFileURL
        let newSaveURL = normalizedFolderURL.appendingPathComponent(Self.snapshotFilename)
        let snapshot = NativeAppSnapshot(
            revision: loadedSnapshotRevision,
            projects: projects,
            chapters: chapters,
            scenes: scenes,
            trashedProjects: trashedProjects,
            trashedChapters: trashedChapters,
            trashedScenes: trashedScenes,
            activeProjectID: activeProjectID,
            selectedChapterID: selectedChapterID,
            selectedSceneID: selectedSceneID,
            selectedChapterIDs: selectedChapterIDs,
            selectedSceneIDs: selectedSceneIDs,
            selectionAnchor: selectionAnchor,
            editorFontSize: editorFontSize,
            editorLineSpacing: editorLineSpacing,
            editorZoom: editorZoom,
            showInvisibleCharacters: showInvisibleCharacters,
            binderColumnWidth: binderColumnWidth,
            lastEditedLocationBySceneID: lastEditedLocationBySceneID
        )

        do {
            try Self.withSecurityScopedAccess(to: normalizedFolderURL) {
                try FileManager.default.createDirectory(at: normalizedFolderURL, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: newSaveURL, options: .atomic)
            }

            let bookmark = try normalizedFolderURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: Self.storageBookmarkKey)
            storageFolderURL = normalizedFolderURL
            saveURL = newSaveURL
            storageLocationDescription = Self.storageDescription(for: normalizedFolderURL)
            storagePathDescription = normalizedFolderURL.path
            storageBackupDescription = Self.backupDescription(for: normalizedFolderURL)
            activatePersistentStorageAccessIfNeeded()
            persist()
        } catch {
            storageErrorMessage = storageErrorMessage(for: error, prefix: "Couldn’t move project data there")
        }
    }

    func resetStorageToDefaultLocation() {
        deactivatePersistentStorageAccessIfNeeded()
        moveStorage(to: Self.defaultStorageFolderURL())
        if storageErrorMessage == nil {
            UserDefaults.standard.removeObject(forKey: Self.storageBookmarkKey)
            storageFolderURL = Self.defaultStorageFolderURL()
            saveURL = storageFolderURL.appendingPathComponent(Self.snapshotFilename)
            storageLocationDescription = Self.storageDescription(for: storageFolderURL)
            storagePathDescription = storageFolderURL.path
            storageBackupDescription = Self.backupDescription(for: storageFolderURL)
            activatePersistentStorageAccessIfNeeded()
            persist()
        }
    }

    func availableAutomaticBackups(for projectID: UUID) -> [NativeAutomaticBackupInfo] {
        let backupsFolderURL = automaticBackupsFolderURL(for: projectID)
        let fileManager = FileManager.default
        guard let backupURLs = try? fileManager.contentsOfDirectory(
            at: backupsFolderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return backupURLs
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url -> NativeAutomaticBackupInfo? in
                guard let package = Self.loadProjectBackupPackage(from: url),
                      let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                    return nil
                }

                return NativeAutomaticBackupInfo(
                    id: url,
                    url: url,
                    exportedAt: package.exportedAt,
                    appVersion: package.appVersion,
                    modifiedAt: modifiedAt
                )
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func restoreAutomaticBackup(for projectID: UUID, from url: URL) {
        storageErrorMessage = nil
        storageExternalChangeMessage = nil

        guard let package = Self.loadProjectBackupPackage(from: url) else {
            storageErrorMessage = "Couldn’t restore that backup snapshot."
            return
        }

        forceImmediateBackup(for: projectID, label: "pre-restore")
        replaceProject(package)
        pendingUndo = nil
        persist()
        refreshStorageStatus(detectExternalChanges: false)
    }

    func reloadFromDisk() {
        storageErrorMessage = nil
        storageExternalChangeMessage = nil
        guard let snapshot = Self.loadSnapshot(from: saveURL) else {
            storageErrorMessage = "Couldn’t reload project data from disk. If this Mac lost access to the shared folder, click Choose Folder again and reselect it."
            return
        }
        apply(snapshot: snapshot)
        pendingUndo = nil
        refreshStorageStatus(detectExternalChanges: false)
    }

    func refreshStorageStatus(detectExternalChanges: Bool = true) {
        storagePathDescription = storageFolderURL.path
        storageBackupDescription = Self.backupDescription(for: storageFolderURL)
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            storageLastSavedDescription = "Not saved yet"
            lastKnownFileModificationDate = nil
            lastKnownDiskSnapshotRevision = loadedSnapshotRevision
            storageExternalChangeMessage = nil
            return
        }

        if let diskSnapshot = Self.loadSnapshot(from: saveURL) {
            lastKnownDiskSnapshotRevision = diskSnapshot.revision
            if detectExternalChanges, diskSnapshot.revision > loadedSnapshotRevision {
                storageExternalChangeMessage = "A newer synced version exists on disk. Reload before making more edits so this window doesn’t overwrite newer work."
            } else if storageExternalChangeMessage == "Project file changed outside this window. Reload to pick up synced updates." ||
                        storageExternalChangeMessage == "A newer synced version exists on disk. Reload before making more edits so this window doesn’t overwrite newer work." {
                storageExternalChangeMessage = nil
            }
        }

        do {
            let values = try saveURL.resourceValues(forKeys: [.contentModificationDateKey])
            if let modifiedAt = values.contentModificationDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                if lastKnownDiskSnapshotRevision > 0 {
                    storageLastSavedDescription = "Last saved \(formatter.localizedString(for: modifiedAt, relativeTo: .now)) • r\(lastKnownDiskSnapshotRevision)"
                } else {
                    storageLastSavedDescription = "Last saved \(formatter.localizedString(for: modifiedAt, relativeTo: .now))"
                }

                if detectExternalChanges,
                   let lastKnownFileModificationDate,
                   storageExternalChangeMessage == nil,
                   modifiedAt.timeIntervalSince(lastKnownFileModificationDate) > 0.5 {
                    storageExternalChangeMessage = "Project file changed outside this window. Reload to pick up synced updates."
                }
                lastKnownFileModificationDate = modifiedAt
            }
        } catch {
            storageLastSavedDescription = "Save time unavailable"
        }
    }

    private func hasNewerDiskVersionThanMemory() -> Bool {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return false }
        guard let diskSnapshot = Self.loadSnapshot(from: saveURL) else { return false }
        lastKnownDiskSnapshotRevision = diskSnapshot.revision
        return diskSnapshot.revision > loadedSnapshotRevision
    }

    func deleteProject(_ projectID: UUID) {
        guard let project = projects.first(where: { $0.id == projectID }) else { return }
        forceImmediateBackup(for: projectID, label: "pre-delete")

        let projectChapters = chapters(for: projectID)
        let chapterOrders = Dictionary(uniqueKeysWithValues: projectChapters.map { ($0.id, $0.order) })
        let projectScenes = scenesInProject(projectID).sorted {
            let lhsChapterOrder = chapterOrders[$0.chapterID] ?? 0
            let rhsChapterOrder = chapterOrders[$1.chapterID] ?? 0
            if lhsChapterOrder == rhsChapterOrder {
                return $0.order < $1.order
            }
            return lhsChapterOrder < rhsChapterOrder
        }

        let trashedProject = NativeTrashedProject(
            id: UUID(),
            project: project,
            chapters: projectChapters,
            scenes: projectScenes,
            deletedAt: .now
        )

        trashedProjects.insert(trashedProject, at: 0)
        projects.removeAll { $0.id == projectID }
        chapters.removeAll { $0.projectID == projectID }
        scenes.removeAll { $0.projectID == projectID }

        if activeProjectID == projectID {
            activeProjectID = nil
            selectedChapterID = nil
            selectedSceneID = nil
            selectedChapterIDs = []
            selectedSceneIDs = []
            selectionAnchor = nil
        }

        registerUndo(message: "Project moved to Trash", payload: .project(trashedProject.id))
        persist()
    }

    func createChapter() {
        guard let project = activeProject else { return }
        let nextOrder = chapters(for: project.id).count
        let chapter = NativeChapter(
            id: UUID(),
            projectID: project.id,
            title: project.isPodcastProject ? "Episode \(nextOrder + 1)" : "Chapter \(nextOrder + 1)",
            order: nextOrder
        )
        let scene = NativeScene(id: UUID(), projectID: project.id, chapterID: chapter.id, title: "Scene 1", order: 0, body: "", richTextRTF: nil)
        chapters.append(chapter)
        scenes.append(scene)
        touchProject(project.id)
        selectChapter(chapter.id, modifiers: [])
        registerUndo(message: "Chapter created", payload: .createdChapter(chapter.id))
        persist()
    }

    func createScene() {
        guard let project = activeProject else { return }

        if let selectedSceneID,
           let currentScene = scenes.first(where: { $0.id == selectedSceneID }),
           let index = scenes.firstIndex(where: { $0.id == selectedSceneID }) {
            let targetChapterScenes = scenesInChapter(currentScene.chapterID)
            let nextOrder = targetChapterScenes.count
            let scene = NativeScene(
                id: UUID(),
                projectID: project.id,
                chapterID: currentScene.chapterID,
                title: "Scene \(nextOrder + 1)",
                order: nextOrder,
                body: "",
                richTextRTF: nil
            )
            scenes.insert(scene, at: index + 1)
            reindexScenes(in: currentScene.chapterID)
            touchProject(project.id)
            selectScene(scene.id, modifiers: [])
            registerUndo(message: "Scene created", payload: .createdScene(scene.id))
            persist()
            return
        }

        if let selectedChapterID {
            let nextOrder = scenesInChapter(selectedChapterID).count
            let scene = NativeScene(
                id: UUID(),
                projectID: project.id,
                chapterID: selectedChapterID,
                title: "Scene \(nextOrder + 1)",
                order: nextOrder,
                body: "",
                richTextRTF: nil
            )
            scenes.append(scene)
            touchProject(project.id)
            selectScene(scene.id, modifiers: [])
            registerUndo(message: "Scene created", payload: .createdScene(scene.id))
            persist()
        }
    }

    func replaceScenes(inChapter chapterID: UUID, with sceneDrafts: [(title: String, body: String)]) -> Bool {
        guard let chapter = chapters.first(where: { $0.id == chapterID }) else { return false }
        let normalizedDrafts = sceneDrafts.enumerated().map { index, draft in
            (
                title: sanitizedTitle(draft.title, fallback: "Scene \(index + 1)"),
                body: draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        .filter { !$0.body.isEmpty }

        guard !normalizedDrafts.isEmpty else { return false }

        scenes.removeAll { $0.chapterID == chapterID }
        for (index, draft) in normalizedDrafts.enumerated() {
            scenes.append(
                NativeScene(
                    id: UUID(),
                    projectID: chapter.projectID,
                    chapterID: chapterID,
                    title: draft.title,
                    order: index,
                    body: draft.body,
                    richTextRTF: nil
                )
            )
        }
        touchProject(chapter.projectID)
        selectChapter(chapterID, modifiers: [])
        persist()
        return true
    }

    @discardableResult
    func createAssistantScene(after sceneID: UUID, body: String) -> UUID? {
        guard let project = activeProject,
              let currentScene = scenes.first(where: { $0.id == sceneID }),
              let index = scenes.firstIndex(where: { $0.id == sceneID }) else { return nil }

        let nextOrder = scenesInChapter(currentScene.chapterID).count
        let scene = NativeScene(
            id: UUID(),
            projectID: project.id,
            chapterID: currentScene.chapterID,
            title: "Scene \(nextOrder + 1)",
            order: nextOrder,
            body: body,
            richTextRTF: nil
        )
        scenes.insert(scene, at: index + 1)
        reindexScenes(in: currentScene.chapterID)
        touchProject(project.id)
        selectScene(scene.id, modifiers: [])
        NativeTextFormattingController.queuePendingFocus(sceneID: scene.id, range: NSRange(location: 0, length: 0))
        persist()
        return scene.id
    }

    @discardableResult
    func createAssistantScene(in chapterID: UUID, body: String) -> UUID? {
        guard let project = activeProject,
              chapters.contains(where: { $0.id == chapterID && $0.projectID == project.id }) else { return nil }

        let nextOrder = scenesInChapter(chapterID).count
        let scene = NativeScene(
            id: UUID(),
            projectID: project.id,
            chapterID: chapterID,
            title: "Scene \(nextOrder + 1)",
            order: nextOrder,
            body: body,
            richTextRTF: nil
        )
        scenes.append(scene)
        touchProject(project.id)
        selectScene(scene.id, modifiers: [])
        NativeTextFormattingController.queuePendingFocus(sceneID: scene.id, range: NSRange(location: 0, length: 0))
        persist()
        return scene.id
    }

    func selectChapter(_ chapterID: UUID, modifiers: NSEvent.ModifierFlags) {
        let key = BinderSelectionKey.chapter(chapterID)
        if modifiers.contains(.shift) {
            applyRangeSelection(to: key)
            return
        }

        if modifiers.contains(.command) || modifiers.contains(.control) {
            toggleChapterSelection(chapterID)
            selectionAnchor = key
            refreshPrimarySelection()
            return
        }

        selectedChapterIDs = [chapterID]
        selectedSceneIDs = []
        selectionAnchor = key
        refreshPrimarySelection()
    }

    func selectScene(_ sceneID: UUID, modifiers: NSEvent.ModifierFlags) {
        let key = BinderSelectionKey.scene(sceneID)
        if modifiers.contains(.shift) {
            applyRangeSelection(to: key)
            return
        }

        if modifiers.contains(.command) || modifiers.contains(.control) {
            toggleSceneSelection(sceneID)
            selectionAnchor = key
            refreshPrimarySelection()
            return
        }

        selectedSceneIDs = [sceneID]
        selectedChapterIDs = []
        selectionAnchor = key
        refreshPrimarySelection()
    }

    func updateSceneBody(_ sceneID: UUID, body: String) {
        guard let index = scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        guard scenes[index].body != body else { return }
        scenes[index].body = body
        touchProject(scenes[index].projectID)
        scheduleCoalescedTextEditPersist()
    }

    func updateSceneBodies(_ updates: [(sceneID: UUID, body: String)]) {
        guard !updates.isEmpty else { return }
        var touchedProjectIDs = Set<UUID>()
        var changed = false

        for update in updates {
            guard let index = scenes.firstIndex(where: { $0.id == update.sceneID }) else { continue }
            if scenes[index].body != update.body {
                scenes[index].body = update.body
                scenes[index].richTextRTF = nil
                touchedProjectIDs.insert(scenes[index].projectID)
                changed = true
            }
        }

        guard changed else { return }
        for projectID in touchedProjectIDs {
            touchProject(projectID)
        }
        scheduleCoalescedTextEditPersist()
    }

    func updateSceneRichText(_ sceneID: UUID, richTextRTF: Data?) {
        guard let index = scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        guard scenes[index].richTextRTF != richTextRTF else { return }
        scenes[index].richTextRTF = richTextRTF
        touchProject(scenes[index].projectID)
        scheduleCoalescedTextEditPersist()
    }

    func updateSceneEditLocation(_ sceneID: UUID, location: Int) {
        let clampedLocation = max(0, min(location, scenes.first(where: { $0.id == sceneID })?.body.utf16.count ?? location))
        guard lastEditedLocationBySceneID[sceneID] != clampedLocation else { return }
        lastEditedLocationBySceneID[sceneID] = clampedLocation
    }

    func updateProjectTitle(_ projectID: UUID, title: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let trimmedTitle = sanitizedTitle(title, fallback: "Untitled Novel")
        guard projects[index].title != trimmedTitle else { return }
        projects[index].title = trimmedTitle
        touchProject(projectID)
        persist()
    }

    func updateProjectStyleNotes(_ projectID: UUID, notes: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        guard projects[index].styleNotes != notes else { return }
        projects[index].styleNotes = notes
        touchProject(projectID)
        persist()
    }

    func updateProjectApprovedWords(_ projectID: UUID, words: [String]) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let normalizedWords = words
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard projects[index].approvedWords != normalizedWords else { return }
        projects[index].approvedWords = normalizedWords
        touchProject(projectID)
        persist()
    }

    func updateProjectDirection(
        _ projectID: UUID,
        narrativePerson: String,
        narrativeTense: String,
        genre: String,
        subgenre: String,
        storyPromise: String,
        pacingNotes: String,
        avoidNotes: String
    ) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let normalizedNarrativePerson = narrativePerson.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNarrativeTense = narrativeTense.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedGenre = genre.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSubgenre = subgenre.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStoryPromise = storyPromise.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPacingNotes = pacingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAvoidNotes = avoidNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard projects[index].narrativePerson != normalizedNarrativePerson ||
                projects[index].narrativeTense != normalizedNarrativeTense ||
                projects[index].genre != normalizedGenre ||
                projects[index].subgenre != normalizedSubgenre ||
                projects[index].storyPromise != normalizedStoryPromise ||
                projects[index].pacingNotes != normalizedPacingNotes ||
                projects[index].avoidNotes != normalizedAvoidNotes else { return }
        projects[index].narrativePerson = normalizedNarrativePerson
        projects[index].narrativeTense = normalizedNarrativeTense
        projects[index].genre = normalizedGenre
        projects[index].subgenre = normalizedSubgenre
        projects[index].storyPromise = normalizedStoryPromise
        projects[index].pacingNotes = normalizedPacingNotes
        projects[index].avoidNotes = normalizedAvoidNotes
        touchProject(projectID)
        persist()
    }

    func updateProjectPodcastSettings(_ projectID: UUID, isPodcastProject: Bool, setup: NativePodcastSetup) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let normalizedSetup = NativePodcastSetup(
            podcastTitle: setup.podcastTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            hostDisplayName: setup.hostDisplayName.trimmingCharacters(in: .whitespacesAndNewlines),
            websiteURL: setup.websiteURL.trimmingCharacters(in: .whitespacesAndNewlines),
            applePodcastURL: setup.applePodcastURL.trimmingCharacters(in: .whitespacesAndNewlines),
            spotifyURL: setup.spotifyURL.trimmingCharacters(in: .whitespacesAndNewlines),
            youtubeURL: setup.youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines),
            newsletterURL: setup.newsletterURL.trimmingCharacters(in: .whitespacesAndNewlines),
            callToAction: setup.callToAction.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let modeChanged = projects[index].isPodcastProject != isPodcastProject
        guard modeChanged || projects[index].podcastSetup != normalizedSetup else { return }

        projects[index].isPodcastProject = isPodcastProject
        projects[index].podcastSetup = normalizedSetup

        if modeChanged {
            let originalPrefix = isPodcastProject ? "chapter " : "episode "
            let replacementPrefix = isPodcastProject ? "Episode " : "Chapter "
            for chapterIndex in chapters.indices where chapters[chapterIndex].projectID == projectID {
                let trimmedTitle = chapters[chapterIndex].title.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedTitle.lowercased().hasPrefix(originalPrefix) {
                    chapters[chapterIndex].title = replacementPrefix + trimmedTitle.dropFirst(originalPrefix.count)
                }
            }
        }

        touchProject(projectID)
        persist()
    }

    func updateProjectContinuityMemory(_ projectID: UUID, summary: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let normalizedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard projects[index].continuityMemory != normalizedSummary else { return }
        projects[index].continuityMemory = normalizedSummary
        touchProject(projectID)
        persist()
    }

    func updateProjectCharacterStyles(_ projectID: UUID, characterStyles: [NativeCharacterStyleGuide]) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let normalizedCharacterStyles = characterStyles.map { character in
            NativeCharacterStyleGuide(
                id: character.id,
                name: sanitizedTitle(character.name, fallback: "Unnamed Character"),
                styleNotes: character.styleNotes.trimmingCharacters(in: .whitespacesAndNewlines),
                visualDescription: character.visualDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                approvedWords: character.approvedWords
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        }
        guard projects[index].characterStyles != normalizedCharacterStyles else { return }
        projects[index].characterStyles = normalizedCharacterStyles
        touchProject(projectID)
        persist()
    }

    func updateProjectAudioPronunciationReplacements(_ projectID: UUID, replacements: [NativeAudioPronunciationReplacement]) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        let normalizedReplacements = replacements.compactMap { replacement -> NativeAudioPronunciationReplacement? in
            let writtenForm = replacement.writtenForm.trimmingCharacters(in: .whitespacesAndNewlines)
            let spokenForm = replacement.spokenForm.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = replacement.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !writtenForm.isEmpty || !spokenForm.isEmpty || !notes.isEmpty else { return nil }
            return NativeAudioPronunciationReplacement(
                id: replacement.id,
                writtenForm: writtenForm,
                spokenForm: spokenForm,
                notes: notes,
                isEnabled: replacement.isEnabled
            )
        }
        guard projects[index].audioPronunciationReplacements != normalizedReplacements else { return }
        projects[index].audioPronunciationReplacements = normalizedReplacements
        touchProject(projectID)
        persist()
    }

    func updateChapterPodcastPrep(_ chapterID: UUID, prep: NativeChapterPodcastPrep) {
        guard let index = chapters.firstIndex(where: { $0.id == chapterID }) else { return }
        guard chapters[index].podcastPrep != prep else { return }
        chapters[index].podcastPrep = prep
        touchProject(chapters[index].projectID)
        persist()
    }

    func updateChapterTitle(_ chapterID: UUID, title: String) {
        guard let index = chapters.firstIndex(where: { $0.id == chapterID }) else { return }
        let trimmedTitle = sanitizedTitle(title, fallback: "Untitled Chapter")
        guard chapters[index].title != trimmedTitle else { return }
        chapters[index].title = trimmedTitle
        touchProject(chapters[index].projectID)
        persist()
    }

    func updateSceneTitle(_ sceneID: UUID, title: String) {
        guard let index = scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        let trimmedTitle = sanitizedTitle(title, fallback: "Untitled Scene")
        guard scenes[index].title != trimmedTitle else { return }
        scenes[index].title = trimmedTitle
        touchProject(scenes[index].projectID)
        persist()
    }

    func setEditorFontSize(_ fontSize: NativeEditorFontSize) {
        guard editorFontSize != fontSize else { return }
        editorFontSize = fontSize
        persist()
    }

    func setEditorLineSpacing(_ lineSpacing: NativeEditorLineSpacing) {
        guard editorLineSpacing != lineSpacing else { return }
        editorLineSpacing = lineSpacing
        persist()
    }

    func setEditorZoom(_ zoom: NativeEditorZoom) {
        guard editorZoom != zoom else { return }
        editorZoom = zoom
        persist()
    }

    func setShowInvisibleCharacters(_ value: Bool) {
        guard showInvisibleCharacters != value else { return }
        showInvisibleCharacters = value
        persist()
    }

    func setBinderColumnWidth(_ width: CGFloat) {
        let clampedWidth = max(260, width)
        guard abs(binderColumnWidth - clampedWidth) > 0.5 else { return }
        binderColumnWidth = clampedWidth
        persist()
    }

    func flushSavepoint() {
        textEditPersistWorkItem?.cancel()
        textEditPersistWorkItem = nil
        persist()
        forceImmediateBackupsForChangedProjects()
    }

    func moveChapter(_ chapterID: UUID, before targetChapterID: UUID) {
        guard
            chapterID != targetChapterID,
            let draggedChapter = chapters.first(where: { $0.id == chapterID }),
            let targetChapter = chapters.first(where: { $0.id == targetChapterID }),
            draggedChapter.projectID == targetChapter.projectID
        else { return }

        var orderedChapters = chapters(for: draggedChapter.projectID)
        orderedChapters.removeAll { $0.id == chapterID }
        guard let targetIndex = orderedChapters.firstIndex(where: { $0.id == targetChapterID }) else { return }
        orderedChapters.insert(draggedChapter, at: targetIndex)

        for (offset, chapter) in orderedChapters.enumerated() {
            guard let index = chapters.firstIndex(where: { $0.id == chapter.id }) else { continue }
            chapters[index].order = offset
        }

        touchProject(draggedChapter.projectID)
        persist()
    }

    func moveScene(_ sceneID: UUID, before targetSceneID: UUID) {
        guard
            sceneID != targetSceneID,
            let draggedSceneIndex = scenes.firstIndex(where: { $0.id == sceneID }),
            let targetScene = scenes.first(where: { $0.id == targetSceneID })
        else { return }

        let sourceChapterID = scenes[draggedSceneIndex].chapterID
        let projectID = scenes[draggedSceneIndex].projectID

        scenes[draggedSceneIndex].chapterID = targetScene.chapterID

        var orderedTargetScenes = scenesInChapter(targetScene.chapterID).filter { $0.id != sceneID }
        guard let targetIndex = orderedTargetScenes.firstIndex(where: { $0.id == targetSceneID }) else { return }
        let draggedScene = scenes[draggedSceneIndex]
        orderedTargetScenes.insert(draggedScene, at: targetIndex)

        for (offset, scene) in orderedTargetScenes.enumerated() {
            guard let index = scenes.firstIndex(where: { $0.id == scene.id }) else { continue }
            scenes[index].chapterID = targetScene.chapterID
            scenes[index].order = offset
        }

        if sourceChapterID != targetScene.chapterID {
            reindexScenes(in: sourceChapterID)
        }

        touchProject(projectID)
        selectScene(sceneID, modifiers: [])
        persist()
    }

    func moveScene(_ sceneID: UUID, toChapter targetChapterID: UUID) {
        guard
            let draggedSceneIndex = scenes.firstIndex(where: { $0.id == sceneID }),
            chapters.contains(where: { $0.id == targetChapterID })
        else { return }

        let sourceChapterID = scenes[draggedSceneIndex].chapterID
        let projectID = scenes[draggedSceneIndex].projectID
        let targetOrder = scenesInChapter(targetChapterID).filter { $0.id != sceneID }.count

        scenes[draggedSceneIndex].chapterID = targetChapterID
        scenes[draggedSceneIndex].order = targetOrder

        if sourceChapterID != targetChapterID {
            reindexScenes(in: sourceChapterID)
        }
        reindexScenes(in: targetChapterID)

        touchProject(projectID)
        selectScene(sceneID, modifiers: [])
        persist()
    }

    func moveSelection(delta: Int, within projectID: UUID) {
        let orderedKeys = orderedBinderKeys(for: projectID)
        guard !orderedKeys.isEmpty else { return }

        let currentKey: BinderSelectionKey? = {
            if let selectedSceneID {
                return .scene(selectedSceneID)
            }
            if let selectedChapterID {
                return .chapter(selectedChapterID)
            }
            return orderedKeys.first
        }()

        guard let currentKey, let currentIndex = orderedKeys.firstIndex(of: currentKey) else {
            if case let .chapter(chapterID)? = orderedKeys.first {
                selectChapter(chapterID, modifiers: [])
            }
            return
        }

        let targetIndex = max(0, min(orderedKeys.count - 1, currentIndex + delta))
        let targetKey = orderedKeys[targetIndex]
        switch targetKey {
        case let .chapter(chapterID):
            selectChapter(chapterID, modifiers: [])
        case let .scene(sceneID):
            selectScene(sceneID, modifiers: [])
        }
    }

    func expandOrDescendSelection(in projectID: UUID) {
        if let selectedChapterID {
            guard let firstScene = scenesInChapter(selectedChapterID).first else { return }
            selectScene(firstScene.id, modifiers: [])
        }
    }

    func collapseSelection(in projectID: UUID) {
        if let selectedSceneID,
           let scene = scenes.first(where: { $0.id == selectedSceneID }) {
            selectChapter(scene.chapterID, modifiers: [])
        }
    }

    func openSelectedBinderItem() {
        refreshPrimarySelection()
    }

    func deleteSelectedItems() {
        if let selectedSceneID {
            deleteScene(selectedSceneID)
            return
        }
        if let selectedChapterID {
            deleteChapter(selectedChapterID)
        }
    }

    func deleteChapter(_ chapterID: UUID) {
        guard
            let chapterIndex = chapters.firstIndex(where: { $0.id == chapterID }),
            let chapter = chapters.first(where: { $0.id == chapterID })
        else { return }

        let chapterScenes = scenesInChapter(chapterID)
        let trashedChapter = NativeTrashedChapter(
            id: UUID(),
            chapter: chapter,
            scenes: chapterScenes,
            originalProjectID: chapter.projectID,
            originalIndex: chapter.order,
            deletedAt: .now
        )

        trashedChapters.insert(trashedChapter, at: 0)
        chapters.remove(at: chapterIndex)
        scenes.removeAll { $0.chapterID == chapterID }
        reindexChapters(in: chapter.projectID)
        clearSelectionIfNeeded(deletedChapterID: chapterID, deletedSceneIDs: chapterScenes.map(\.id))
        registerUndo(message: "Chapter moved to Trash", payload: .chapter(trashedChapter.id))
        touchProject(chapter.projectID)
        persist()
    }

    func deleteScene(_ sceneID: UUID) {
        guard
            let sceneIndex = scenes.firstIndex(where: { $0.id == sceneID }),
            let scene = scenes.first(where: { $0.id == sceneID })
        else { return }

        let chapterTitle = chapters.first(where: { $0.id == scene.chapterID })?.title
        let trashedScene = NativeTrashedScene(
            id: UUID(),
            scene: scene,
            originalProjectID: scene.projectID,
            originalChapterID: scene.chapterID,
            originalIndex: scene.order,
            chapterTitle: chapterTitle,
            deletedAt: .now
        )

        trashedScenes.insert(trashedScene, at: 0)
        scenes.remove(at: sceneIndex)
        reindexScenes(in: scene.chapterID)
        clearSelectionIfNeeded(deletedChapterID: nil, deletedSceneIDs: [sceneID])
        registerUndo(message: "Scene moved to Trash", payload: .scene(trashedScene.id))
        touchProject(scene.projectID)
        persist()
    }

    func restoreTrashedChapter(_ trashID: UUID) {
        guard let index = trashedChapters.firstIndex(where: { $0.id == trashID }) else { return }
        let trashed = trashedChapters.remove(at: index)
        let insertionIndex = min(trashed.originalIndex, chapters(for: trashed.originalProjectID).count)
        var restoredChapter = trashed.chapter
        restoredChapter.order = insertionIndex
        chapters.append(restoredChapter)
        reindexChapters(in: trashed.originalProjectID)

        let sortedScenes = trashed.scenes.sorted { $0.order < $1.order }
        for (offset, scene) in sortedScenes.enumerated() {
            var restoredScene = scene
            restoredScene.order = offset
            scenes.append(restoredScene)
        }

        touchProject(trashed.originalProjectID)
        selectChapter(restoredChapter.id, modifiers: [])
        clearPendingUndoIfMatching(.chapter(trashID))
        persist()
    }

    func restoreTrashedScene(_ trashID: UUID) {
        guard let index = trashedScenes.firstIndex(where: { $0.id == trashID }) else { return }
        let trashed = trashedScenes.remove(at: index)
        guard chapters.contains(where: { $0.id == trashed.originalChapterID }) else {
            trashedScenes.insert(trashed, at: index)
            return
        }

        let insertionOrder = min(trashed.originalIndex, scenesInChapter(trashed.originalChapterID).count)
        var restoredScene = trashed.scene
        restoredScene.order = insertionOrder
        scenes.append(restoredScene)
        reindexScenes(in: trashed.originalChapterID)
        touchProject(trashed.originalProjectID)
        selectScene(restoredScene.id, modifiers: [])
        clearPendingUndoIfMatching(.scene(trashID))
        persist()
    }

    func permanentlyDeleteTrashedChapter(_ trashID: UUID) {
        trashedChapters.removeAll { $0.id == trashID }
        clearPendingUndoIfMatching(.chapter(trashID))
        persist()
    }

    func permanentlyDeleteTrashedScene(_ trashID: UUID) {
        trashedScenes.removeAll { $0.id == trashID }
        clearPendingUndoIfMatching(.scene(trashID))
        persist()
    }

    func undoLastDelete() {
        guard let pendingUndo else { return }
        switch pendingUndo.payload {
        case let .project(trashID):
            restoreTrashedProject(trashID)
        case let .chapter(trashID):
            restoreTrashedChapter(trashID)
        case let .scene(trashID):
            restoreTrashedScene(trashID)
        case let .createdChapter(chapterID):
            undoCreatedChapter(chapterID)
        case let .createdScene(sceneID):
            undoCreatedScene(sceneID)
        }
    }

    private func undoCreatedChapter(_ chapterID: UUID) {
        guard let chapter = chapters.first(where: { $0.id == chapterID }) else {
            clearPendingUndoIfMatching(.createdChapter(chapterID))
            return
        }
        let projectID = chapter.projectID
        let removedSceneIDs = scenes.filter { $0.chapterID == chapterID }.map(\.id)
        chapters.removeAll { $0.id == chapterID }
        scenes.removeAll { $0.chapterID == chapterID }
        reindexChapters(in: projectID)
        clearSelectionIfNeeded(deletedChapterID: chapterID, deletedSceneIDs: removedSceneIDs)
        clearPendingUndoIfMatching(.createdChapter(chapterID))
        touchProject(projectID)
        persist()
    }

    private func undoCreatedScene(_ sceneID: UUID) {
        guard let scene = scenes.first(where: { $0.id == sceneID }) else {
            clearPendingUndoIfMatching(.createdScene(sceneID))
            return
        }
        let projectID = scene.projectID
        let chapterID = scene.chapterID
        scenes.removeAll { $0.id == sceneID }
        reindexScenes(in: chapterID)
        clearSelectionIfNeeded(deletedChapterID: nil, deletedSceneIDs: [sceneID])
        clearPendingUndoIfMatching(.createdScene(sceneID))
        touchProject(projectID)
        persist()
    }

    func restoreTrashedProject(_ trashID: UUID) {
        guard let index = trashedProjects.firstIndex(where: { $0.id == trashID }) else { return }
        let trashed = trashedProjects.remove(at: index)
        projects.append(trashed.project)
        chapters.append(contentsOf: trashed.chapters)
        scenes.append(contentsOf: trashed.scenes)
        clearPendingUndoIfMatching(.project(trashID))
        openProject(trashed.project)
        persist()
    }

    func permanentlyDeleteTrashedProject(_ trashID: UUID) {
        if let trashed = trashedProjects.first(where: { $0.id == trashID }) {
            deleteAutomaticBackups(for: trashed.project.id)
        }
        trashedProjects.removeAll { $0.id == trashID }
        clearPendingUndoIfMatching(.project(trashID))
        persist()
    }

    private func touchProject(_ projectID: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].updatedAt = .now
    }

    private func reindexScenes(in chapterID: UUID) {
        let orderedIDs = scenesInChapter(chapterID).map(\.id)
        for (offset, sceneID) in orderedIDs.enumerated() {
            guard let index = scenes.firstIndex(where: { $0.id == sceneID }) else { continue }
            scenes[index].order = offset
        }
    }

    private func reindexChapters(in projectID: UUID) {
        let orderedIDs = chapters(for: projectID).map(\.id)
        for (offset, chapterID) in orderedIDs.enumerated() {
            guard let index = chapters.firstIndex(where: { $0.id == chapterID }) else { continue }
            chapters[index].order = offset
        }
    }

    private func registerUndo(message: String, payload: NativeUndoPayload) {
        undoClearWorkItem?.cancel()
        pendingUndo = NativeUndoState(message: message, payload: payload)

        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingUndo = nil
        }
        undoClearWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func clearPendingUndoIfMatching(_ payload: NativeUndoPayload) {
        guard let pendingUndo, payloadMatches(pendingUndo.payload, payload) else { return }
        clearPendingUndo()
    }

    private func clearPendingUndo() {
        undoClearWorkItem?.cancel()
        undoClearWorkItem = nil
        pendingUndo = nil
    }

    private func payloadMatches(_ lhs: NativeUndoPayload, _ rhs: NativeUndoPayload) -> Bool {
        switch (lhs, rhs) {
        case let (.project(lhsID), .project(rhsID)):
            return lhsID == rhsID
        case let (.chapter(lhsID), .chapter(rhsID)):
            return lhsID == rhsID
        case let (.scene(lhsID), .scene(rhsID)):
            return lhsID == rhsID
        case let (.createdChapter(lhsID), .createdChapter(rhsID)):
            return lhsID == rhsID
        case let (.createdScene(lhsID), .createdScene(rhsID)):
            return lhsID == rhsID
        default:
            return false
        }
    }

    private func clearSelectionIfNeeded(deletedChapterID: UUID?, deletedSceneIDs: [UUID]) {
        if let deletedChapterID {
            selectedChapterIDs.removeAll { $0 == deletedChapterID }
            if selectedChapterID == deletedChapterID {
                selectedChapterID = nil
            }
        }

        let deletedSceneSet = Set(deletedSceneIDs)
        selectedSceneIDs.removeAll { deletedSceneSet.contains($0) }
        if let selectedSceneID, deletedSceneSet.contains(selectedSceneID) {
            self.selectedSceneID = nil
        }

        if let activeProjectID, let firstChapter = chapters(for: activeProjectID).first, selectedChapterIDs.isEmpty && selectedSceneIDs.isEmpty {
            selectChapter(firstChapter.id, modifiers: [])
            return
        }

        if activeProjectID != nil {
            refreshPrimarySelection()
        }
    }

    func displayScenes(for projectID: UUID) -> [NativeScene] {
        let chapterScenes = selectedChapterIDs.flatMap { scenesInChapter($0) }
        let directScenes = selectedSceneIDs.compactMap { sceneID in
            scenes.first(where: { $0.id == sceneID })
        }
        let combined = chapterScenes + directScenes
        var deduped: [UUID: NativeScene] = [:]
        for scene in combined {
            deduped[scene.id] = scene
        }

        return orderedBinderKeys(for: projectID).compactMap { key in
            guard case let .scene(sceneID) = key else { return nil }
            return deduped[sceneID]
        }
    }

    func isChapterHighlighted(_ chapterID: UUID) -> Bool {
        selectedChapterIDs.contains(chapterID)
    }

    func isSceneHighlighted(_ sceneID: UUID) -> Bool {
        selectedSceneIDs.contains(sceneID) || selectedChapterIDs.contains(where: { chapterID in
            scenesInChapter(chapterID).contains(where: { $0.id == sceneID })
        })
    }

    private func toggleChapterSelection(_ chapterID: UUID) {
        if let index = selectedChapterIDs.firstIndex(of: chapterID) {
            selectedChapterIDs.remove(at: index)
        } else {
            selectedChapterIDs.append(chapterID)
        }
    }

    private func toggleSceneSelection(_ sceneID: UUID) {
        if let index = selectedSceneIDs.firstIndex(of: sceneID) {
            selectedSceneIDs.remove(at: index)
        } else {
            selectedSceneIDs.append(sceneID)
        }
    }

    private func applyRangeSelection(to key: BinderSelectionKey) {
        guard let projectID = activeProjectID else { return }
        let orderedKeys = orderedBinderKeys(for: projectID)
        guard let targetIndex = orderedKeys.firstIndex(of: key) else { return }

        let anchorKey = selectionAnchor ?? key
        let anchorIndex = orderedKeys.firstIndex(of: anchorKey) ?? targetIndex
        let lowerBound = min(anchorIndex, targetIndex)
        let upperBound = max(anchorIndex, targetIndex)
        let range = orderedKeys[lowerBound ... upperBound]

        selectedChapterIDs = []
        selectedSceneIDs = []
        for entry in range {
            switch entry {
            case let .chapter(chapterID):
                selectedChapterIDs.append(chapterID)
            case let .scene(sceneID):
                selectedSceneIDs.append(sceneID)
            }
        }

        selectionAnchor = anchorKey
        refreshPrimarySelection()
    }

    private func refreshPrimarySelection() {
        selectedChapterIDs = uniquePreservingOrder(selectedChapterIDs)
        selectedSceneIDs = uniquePreservingOrder(selectedSceneIDs)

        selectedChapterID = selectedChapterIDs.count == 1 && selectedSceneIDs.isEmpty ? selectedChapterIDs.first : nil
        selectedSceneID = selectedSceneIDs.count == 1 && selectedChapterIDs.isEmpty ? selectedSceneIDs.first : nil
        persist()
    }

    private func uniquePreservingOrder(_ values: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return values.filter { seen.insert($0).inserted }
    }

    private func sanitizedTitle(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func scheduleCoalescedTextEditPersist() {
        textEditPersistWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.persist()
        }
        textEditPersistWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.coalescedTextEditPersistDelay, execute: workItem)
    }

    private func persist() {
        textEditPersistWorkItem?.cancel()
        textEditPersistWorkItem = nil
        if hasNewerDiskVersionThanMemory() {
            storageExternalChangeMessage = "A newer synced version exists on disk. Reload before making more edits so this window doesn’t overwrite newer work."
            refreshStorageStatus()
            return
        }

        let snapshot = NativeAppSnapshot(
            revision: loadedSnapshotRevision + 1,
            projects: projects,
            chapters: chapters,
            scenes: scenes,
            trashedProjects: trashedProjects,
            trashedChapters: trashedChapters,
            trashedScenes: trashedScenes,
            activeProjectID: activeProjectID,
            selectedChapterID: selectedChapterID,
            selectedSceneID: selectedSceneID,
            selectedChapterIDs: selectedChapterIDs,
            selectedSceneIDs: selectedSceneIDs,
            selectionAnchor: selectionAnchor,
            editorFontSize: editorFontSize,
            editorLineSpacing: editorLineSpacing,
            editorZoom: editorZoom,
            showInvisibleCharacters: showInvisibleCharacters,
            binderColumnWidth: binderColumnWidth,
            lastEditedLocationBySceneID: lastEditedLocationBySceneID
        )

        do {
            let directory = saveURL.deletingLastPathComponent()
            let data = try JSONEncoder().encode(snapshot)
            try Self.withSecurityScopedAccess(to: directory) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try data.write(to: saveURL, options: .atomic)
                try writeAutomaticBackupsIfNeeded()
            }
            storageErrorMessage = nil
            storageExternalChangeMessage = nil
            loadedSnapshotRevision = snapshot.revision
            lastKnownDiskSnapshotRevision = snapshot.revision
            refreshStorageStatus(detectExternalChanges: false)
        } catch {
            NSLog("Failed to persist native proof of concept state: %@", error.localizedDescription)
            storageErrorMessage = storageErrorMessage(for: error, prefix: "Couldn’t save project data")
        }
    }

    private func storageErrorMessage(for error: Error, prefix: String) -> String {
        if let accessError = error as? NativeStorageAccessError,
           let description = accessError.errorDescription {
            return "\(prefix): \(description)"
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileWriteNoPermissionError {
            return "\(prefix): This Mac no longer has write access to the chosen folder. Click Choose Folder again and reselect the shared iCloud folder."
        }

        return "\(prefix): \(error.localizedDescription)"
    }

    private func activatePersistentStorageAccessIfNeeded() {
        guard storageFolderURL.standardizedFileURL != Self.defaultStorageFolderURL().standardizedFileURL else {
            isAccessingStorageSecurityScope = false
            return
        }

        if !isAccessingStorageSecurityScope {
            isAccessingStorageSecurityScope = storageFolderURL.startAccessingSecurityScopedResource()
        }
    }

    private func deactivatePersistentStorageAccessIfNeeded() {
        guard isAccessingStorageSecurityScope else { return }
        storageFolderURL.stopAccessingSecurityScopedResource()
        isAccessingStorageSecurityScope = false
    }

    private func writeAutomaticBackupsIfNeeded() throws {
        let fileManager = FileManager.default
        let rootURL = storageFolderURL.appendingPathComponent(Self.automaticBackupsFolderName, isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

        for project in projects {
            try writeAutomaticBackupIfNeeded(for: project, force: false, label: nil)
        }
    }

    private func writeAutomaticBackupIfNeeded(for project: NativeProject, force: Bool, label: String?) throws {
        let fileManager = FileManager.default
        let backupsFolderURL = automaticBackupsFolderURL(for: project.id)
        try fileManager.createDirectory(at: backupsFolderURL, withIntermediateDirectories: true)

        let latestBackupDate = latestAutomaticBackupDate(in: backupsFolderURL)
        if !force {
            if let latestBackupDate,
               Date().timeIntervalSince(latestBackupDate) < Self.automaticBackupInterval {
                return
            }

            if let latestBackupDate,
               project.updatedAt <= latestBackupDate {
                return
            }
        }

        guard let data = backupData(for: project.id) else { return }
        let backupURL = backupsFolderURL.appendingPathComponent(Self.automaticBackupFilename(for: project, label: label))
        try data.write(to: backupURL, options: .atomic)
        try pruneAutomaticBackups(in: backupsFolderURL, keepingNewest: backupURL)
    }

    private func forceImmediateBackupsForChangedProjects() {
        let changedProjects = projects.filter { project in
            guard let latestBackupDate = latestAutomaticBackupDate(in: automaticBackupsFolderURL(for: project.id)) else {
                return true
            }
            return project.updatedAt > latestBackupDate
        }
        guard !changedProjects.isEmpty else { return }

        do {
            try Self.withSecurityScopedAccess(to: storageFolderURL) {
                for project in changedProjects {
                    try writeAutomaticBackupIfNeeded(for: project, force: true, label: "savepoint")
                }
            }
        } catch {
            storageErrorMessage = storageErrorMessage(for: error, prefix: "Couldn’t create automatic backup")
        }
    }

    private func forceImmediateBackup(for projectID: UUID, label: String) {
        guard let project = projects.first(where: { $0.id == projectID }) else { return }
        do {
            try Self.withSecurityScopedAccess(to: storageFolderURL) {
                try writeAutomaticBackupIfNeeded(for: project, force: true, label: label)
            }
        } catch {
            storageErrorMessage = storageErrorMessage(for: error, prefix: "Couldn’t create safety backup")
        }
    }

    private func latestAutomaticBackupDate(in folderURL: URL) -> Date? {
        let fileManager = FileManager.default
        guard let backupURLs = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return backupURLs
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            .max()
    }

    private func pruneAutomaticBackups(in folderURL: URL, keepingNewest newestURL: URL) throws {
        struct BackupEntry {
            let url: URL
            let modifiedAt: Date
        }

        let fileManager = FileManager.default
        let now = Date()
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -Self.automaticBackupDailyRetentionDays, to: now) ?? now

        let backupEntries = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .compactMap { url -> BackupEntry? in
            guard let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                return nil
            }
            return BackupEntry(url: url, modifiedAt: modifiedAt)
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }

        var keptURLs = Set<URL>([newestURL])
        var keptDailyBuckets = Set<Date>()

        for entry in backupEntries {
            if keptURLs.contains(entry.url) {
                continue
            }

            let age = now.timeIntervalSince(entry.modifiedAt)
            if age <= Self.automaticBackupRecentRetention {
                keptURLs.insert(entry.url)
                continue
            }

            if entry.modifiedAt >= cutoff {
                let dayBucket = calendar.startOfDay(for: entry.modifiedAt)
                if keptDailyBuckets.insert(dayBucket).inserted {
                    keptURLs.insert(entry.url)
                    continue
                }
            }

            try? fileManager.removeItem(at: entry.url)
        }
    }

    private func automaticBackupsFolderURL(for projectID: UUID) -> URL {
        storageFolderURL
            .appendingPathComponent(Self.automaticBackupsFolderName, isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
    }

    private func replaceProject(_ package: NativeProjectBackupPackage) {
        let projectID = package.project.id
        projects.removeAll { $0.id == projectID }
        chapters.removeAll { $0.projectID == projectID }
        scenes.removeAll { $0.projectID == projectID }

        projects.append(package.project)
        chapters.append(contentsOf: package.chapters)
        scenes.append(contentsOf: package.scenes)
        openProject(package.project)
    }

    private func deleteAutomaticBackups(for projectID: UUID) {
        let backupsFolderURL = automaticBackupsFolderURL(for: projectID)
        try? FileManager.default.removeItem(at: backupsFolderURL)
    }

    private static func loadProjectBackupPackage(from url: URL) -> NativeProjectBackupPackage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(NativeProjectBackupPackage.self, from: data)
    }

    private static func automaticBackupFilename(for project: NativeProject, label: String?) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let slug = project.title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(6)
            .joined(separator: "-")
        let safeSlug = slug.isEmpty ? "project" : slug
        let labelSuffix = label?.nilIfEmpty.map { "-\($0)" } ?? ""
        return "\(safeSlug)-\(formatter.string(from: Date()))\(labelSuffix).json"
    }

    private static func backupDescription(for folderURL: URL) -> String {
        let backupsPath = folderURL
            .appendingPathComponent(Self.automaticBackupsFolderName, isDirectory: true)
            .path
        return "Automatic backups every 10 minutes to \(backupsPath)"
    }

    private func apply(snapshot: NativeAppSnapshot) {
        loadedSnapshotRevision = snapshot.revision
        lastKnownDiskSnapshotRevision = snapshot.revision
        projects = snapshot.projects
        chapters = snapshot.chapters
        scenes = snapshot.scenes
        trashedProjects = snapshot.trashedProjects
        trashedChapters = snapshot.trashedChapters
        trashedScenes = snapshot.trashedScenes
        activeProjectID = snapshot.activeProjectID
        selectedChapterID = snapshot.selectedChapterID
        selectedSceneID = snapshot.selectedSceneID
        selectedChapterIDs = snapshot.selectedChapterIDs
        selectedSceneIDs = snapshot.selectedSceneIDs
        selectionAnchor = snapshot.selectionAnchor
        editorFontSize = snapshot.editorFontSize
        editorLineSpacing = snapshot.editorLineSpacing
        editorZoom = snapshot.editorZoom
        showInvisibleCharacters = snapshot.showInvisibleCharacters
        binderColumnWidth = snapshot.binderColumnWidth
        lastEditedLocationBySceneID = snapshot.lastEditedLocationBySceneID
    }

    private static func loadSnapshot(from url: URL) -> NativeAppSnapshot? {
        do {
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try withSecurityScopedAccess(to: url.deletingLastPathComponent()) {
                try Data(contentsOf: url)
            }
            return try JSONDecoder().decode(NativeAppSnapshot.self, from: data)
        } catch {
            NSLog("Failed to load native proof of concept state: %@", error.localizedDescription)
            return nil
        }
    }

    private static func fileModificationDate(for url: URL) -> Date? {
        do {
            let directory = url.deletingLastPathComponent()
            return try withSecurityScopedAccess(to: directory) {
                try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            }
        } catch {
            return nil
        }
    }

    private static func parseDOCXDocument(at url: URL) throws -> (projectTitle: String?, chapters: [NativeImportedChapterDraft]) {
        let data = try withSecurityScopedAccess(to: url) {
            try Data(contentsOf: url)
        }

        let attributed = try readWordAttributedString(from: url, data: data)

        let paragraphs = splitAttributedParagraphs(from: attributed)
        let projectTitle = firstMeaningfulParagraph(in: paragraphs)

        let chapterSections = detectChapterSections(in: paragraphs)
        let chapters = chapterSections.enumerated().map { index, section in
            let sceneParagraphGroups = splitSceneParagraphs(section.paragraphs)
            let scenes = sceneParagraphGroups.enumerated().compactMap { sceneIndex, group -> NativeImportedSceneDraft? in
                let sceneAttributed = normalizedImportedSceneAttributedString(from: attributedString(from: group))
                let sceneText = sceneAttributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sceneText.isEmpty else { return nil }
                let title = "Scene \(sceneIndex + 1)"
                let rtfData = try? sceneAttributed.data(
                    from: NSRange(location: 0, length: sceneAttributed.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                )
                return NativeImportedSceneDraft(title: title, body: sceneText, richTextRTF: rtfData)
            }

            return NativeImportedChapterDraft(
                title: section.title?.nilIfEmpty ?? "Chapter \(index + 1)",
                scenes: scenes.isEmpty ? [NativeImportedSceneDraft(title: "Scene 1", body: "", richTextRTF: nil)] : scenes
            )
        }

        return (projectTitle, chapters)
    }

    private static func readWordAttributedString(from url: URL, data: Data) throws -> NSAttributedString {
        var failures: [String] = []

        do {
            return try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
                documentAttributes: nil
            )
        } catch {
            failures.append("Office Open XML reader failed.")
        }

        do {
            return try NSAttributedString(
                data: data,
                options: [:],
                documentAttributes: nil
            )
        } catch {
            failures.append("Automatic document reader failed.")
        }

        do {
            return try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.docFormat],
                documentAttributes: nil
            )
        } catch {
            failures.append("Legacy Word reader failed.")
        }

        do {
            return try readWordAttributedStringUsingTextUtil(at: url)
        } catch {
            let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            failures.append(detail.isEmpty ? "textutil fallback failed." : detail)
        }

        throw NativeDocumentImportError.unreadableWordDocument(details: failures.joined(separator: " "))
    }

    private static func normalizedImportedSceneAttributedString(from attributed: NSAttributedString) -> NSAttributedString {
        let normalized = NSMutableAttributedString(attributedString: attributed)
        let baseFont = NSFont(name: "Palatino Linotype", size: NativeEditorFontSize.medium.pointSize)
            ?? NSFont(name: "Iowan Old Style", size: NativeEditorFontSize.medium.pointSize)
            ?? NSFont.systemFont(ofSize: NativeEditorFontSize.medium.pointSize)
        let range = NSRange(location: 0, length: normalized.length)

        normalized.beginEditing()
        normalized.enumerateAttributes(in: range) { attributes, range, _ in
            let paragraphStyle = ((attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = NativeEditorLineSpacing.oneAndHalf.spacing

            var newAttributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: NativeTheme.ink1,
                .paragraphStyle: paragraphStyle
            ]

            if let underline = attributes[.underlineStyle] {
                newAttributes[.underlineStyle] = underline
            }

            normalized.setAttributes(newAttributes, range: range)
        }
        normalized.endEditing()
        return normalized
    }

    private static func readWordAttributedStringUsingTextUtil(at url: URL) throws -> NSAttributedString {
        let rtfData = try runTextUtil(at: url, format: "rtf")
        if !rtfData.isEmpty,
           let attributed = try? NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
           ) {
            return attributed
        }

        let textData = try runTextUtil(at: url, format: "txt")
        guard let string = String(data: textData, encoding: .utf8)?
            .trimmingCharacters(in: .newlines),
              !string.isEmpty else {
            throw NativeDocumentImportError.unreadableWordDocument(details: "macOS textutil could not extract readable text from this file.")
        }

        return NSAttributedString(string: string)
    }

    private static func runTextUtil(at url: URL, format: String) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        process.arguments = ["-convert", format, "-stdout", url.path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try withSecurityScopedAccess(to: url) {
            try process.run()
            process.waitUntilExit()
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NativeDocumentImportError.unreadableWordDocument(
                details: message?.nilIfEmpty ?? "macOS textutil returned status \(process.terminationStatus)."
            )
        }

        return outputData
    }

    private static func splitAttributedParagraphs(from attributed: NSAttributedString) -> [NSAttributedString] {
        let fullNSString = attributed.string as NSString
        var paragraphs: [NSAttributedString] = []
        var location = 0

        while location < fullNSString.length {
            let range = fullNSString.paragraphRange(for: NSRange(location: location, length: 0))
            paragraphs.append(attributed.attributedSubstring(from: range))
            location = NSMaxRange(range)
        }

        if paragraphs.isEmpty, attributed.length > 0 {
            paragraphs = [attributed]
        }

        return paragraphs
    }

    private static func firstMeaningfulParagraph(in paragraphs: [NSAttributedString]) -> String? {
        paragraphs
            .map { $0.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty && !looksLikeChapterHeading($0) })
    }

    private static func detectChapterSections(in paragraphs: [NSAttributedString]) -> [(title: String?, paragraphs: [NSAttributedString])] {
        var sections: [(title: String?, paragraphs: [NSAttributedString])] = []
        var currentTitle: String?
        var currentParagraphs: [NSAttributedString] = []

        for paragraph in paragraphs {
            let text = paragraph.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                currentParagraphs.append(paragraph)
                continue
            }

            if looksLikeChapterHeading(text) {
                if !currentParagraphs.isEmpty || currentTitle != nil {
                    sections.append((title: currentTitle, paragraphs: currentParagraphs))
                }
                currentTitle = normalizedImportedHeading(text)
                currentParagraphs = []
            } else {
                currentParagraphs.append(paragraph)
            }
        }

        if !currentParagraphs.isEmpty || currentTitle != nil {
            sections.append((title: currentTitle, paragraphs: currentParagraphs))
        }

        if sections.isEmpty {
            return [(title: "Chapter 1", paragraphs: paragraphs)]
        }

        return sections.enumerated().map { index, section in
            let fallbackTitle = "Chapter \(index + 1)"
            return (title: section.title?.nilIfEmpty ?? fallbackTitle, paragraphs: section.paragraphs)
        }
    }

    private static func splitSceneParagraphs(_ paragraphs: [NSAttributedString]) -> [[NSAttributedString]] {
        let explicitSections = splitOnExplicitSceneBreaks(paragraphs)
        return explicitSections.flatMap { chunkParagraphsByWordCount($0) }
    }

    private static func splitOnExplicitSceneBreaks(_ paragraphs: [NSAttributedString]) -> [[NSAttributedString]] {
        var groups: [[NSAttributedString]] = []
        var current: [NSAttributedString] = []

        for paragraph in paragraphs {
            let trimmed = paragraph.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if isExplicitSceneBreak(trimmed) {
                if !current.isEmpty {
                    groups.append(current)
                    current = []
                }
                continue
            }
            current.append(paragraph)
        }

        if !current.isEmpty {
            groups.append(current)
        }

        return groups.isEmpty ? [paragraphs] : groups
    }

    private static func chunkParagraphsByWordCount(_ paragraphs: [NSAttributedString]) -> [[NSAttributedString]] {
        let targetWords = 1200
        let minimumWords = 500

        var groups: [[NSAttributedString]] = []
        var current: [NSAttributedString] = []
        var currentWords = 0

        for paragraph in paragraphs {
            let text = paragraph.string.trimmingCharacters(in: .whitespacesAndNewlines)
            let wordCount = text.split(whereSeparator: \.isWhitespace).count
            current.append(paragraph)
            currentWords += wordCount

            if currentWords >= targetWords, currentWords >= minimumWords {
                groups.append(current)
                current = []
                currentWords = 0
            }
        }

        if !current.isEmpty {
            if let last = groups.last, currentWords < minimumWords {
                groups[groups.count - 1] = last + current
            } else {
                groups.append(current)
            }
        }

        return groups.isEmpty ? [paragraphs] : groups
    }

    private static func attributedString(from paragraphs: [NSAttributedString]) -> NSAttributedString {
        let combined = NSMutableAttributedString()
        for paragraph in paragraphs {
            combined.append(paragraph)
            if !paragraph.string.hasSuffix("\n") {
                combined.append(NSAttributedString(string: "\n"))
            }
        }
        return combined
    }

    private static func looksLikeChapterHeading(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let patterns = [
            #"^(chapter|episode|prologue|epilogue)\b.*$"#,
            #"^(part)\b.*$"#,
            #"^(act)\b.*$"#,
            #"^(book)\b.*$"#
        ]

        return patterns.contains { pattern in
            trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func normalizedImportedHeading(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func isExplicitSceneBreak(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let markers = ["***", "* * *", "#", "###", "---", "—", "~~~"]
        if markers.contains(trimmed) {
            return true
        }
        return trimmed.range(of: #"^scene\s+\w+"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func defaultStorageFolderURL() -> URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupportURL.appendingPathComponent("NovelWriterNative", isDirectory: true)
    }

    private static func resolveStorageFolderURL() -> URL {
        guard
            let bookmarkData = UserDefaults.standard.data(forKey: storageBookmarkKey)
        else {
            return defaultStorageFolderURL()
        }

        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                let refreshedBookmark = try resolvedURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                UserDefaults.standard.set(refreshedBookmark, forKey: storageBookmarkKey)
            }
            return resolvedURL
        } catch {
            UserDefaults.standard.removeObject(forKey: storageBookmarkKey)
            return defaultStorageFolderURL()
        }
    }

    private static func storageDescription(for folderURL: URL) -> String {
        if folderURL.standardizedFileURL == defaultStorageFolderURL().standardizedFileURL {
            return "On This Mac"
        }

        let path = folderURL.path
        if path.range(of: "/Library/Mobile Documents/") != nil {
            return "iCloud Drive"
        }

        return folderURL.lastPathComponent.nilIfEmpty ?? folderURL.path
    }

    private static func startPersistentStorageAccessIfNeeded(for folderURL: URL) -> Bool {
        guard folderURL.standardizedFileURL != defaultStorageFolderURL().standardizedFileURL else {
            return false
        }
        return folderURL.startAccessingSecurityScopedResource()
    }

    @discardableResult
    private static func withSecurityScopedAccess<T>(to url: URL, perform work: () throws -> T) throws -> T {
        let needsScopedAccess = url.standardizedFileURL != defaultStorageFolderURL().standardizedFileURL
        let didStartAccessing = needsScopedAccess ? url.startAccessingSecurityScopedResource() : false
        if needsScopedAccess && !didStartAccessing {
            throw NativeStorageAccessError.securityScopeUnavailable(url)
        }
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try work()
    }
}

struct ContentView: View {
    @ObservedObject var model: NativeAppModel

    var body: some View {
        Group {
            if let project = model.activeProject {
                WorkspaceShellView(model: model, project: project)
            } else {
                ProjectLibraryView(model: model)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            model.flushSavepoint()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            model.flushSavepoint()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in
            model.flushSavepoint()
        }
    }
}

struct ProjectLibraryView: View {
    @ObservedObject var model: NativeAppModel
    @State private var importStatusMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 264, maximum: 264), spacing: 28)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Novel Writer Native")
                        .font(NativeTheme.displayFont(size: 34, weight: .bold))
                        .foregroundStyle(NativeTheme.ink1Color)
                    Text("Mac-first proof of concept")
                        .font(NativeTheme.interfaceFont(size: 14))
                        .foregroundStyle(NativeTheme.mutedColor)
                    Text(NativeBuildInfo.displayVersion)
                        .font(NativeTheme.interfaceFont(size: 11, weight: .semibold))
                        .foregroundStyle(NativeTheme.accentColor)
                }
                Spacer()
                Button("Import DOCX") {
                    importDOCX()
                }
                .buttonStyle(NativeSecondaryButtonStyle())

                Button("New Project") {
                    model.createProject()
                }
                .buttonStyle(NativeProminentButtonStyle())
            }

            HStack(spacing: 10) {
                Label("Storage: \(model.storageLocationDescription)", systemImage: model.isUsingCustomStorageLocation ? "icloud" : "internaldrive")
                    .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                    .foregroundStyle(model.isUsingCustomStorageLocation ? NativeTheme.accentColor : NativeTheme.mutedColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(NativeTheme.panelSoftColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button("Choose Folder") {
                    chooseStorageFolder()
                }
                .buttonStyle(.borderless)

                Button("Reload From Disk") {
                    model.reloadFromDisk()
                }
                .buttonStyle(.borderless)

                if model.isUsingCustomStorageLocation {
                    Button("Use Local Storage") {
                        model.resetStorageToDefaultLocation()
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(model.storagePathDescription)
                    .font(NativeTheme.interfaceFont(size: 11))
                    .foregroundStyle(NativeTheme.mutedColor)
                    .textSelection(.enabled)
                    .lineLimit(2)
                Text(model.storageBackupDescription)
                    .font(NativeTheme.interfaceFont(size: 11))
                    .foregroundStyle(NativeTheme.mutedColor)
                    .textSelection(.enabled)
                    .lineLimit(2)
                Text(model.storageLastSavedDescription)
                    .font(NativeTheme.interfaceFont(size: 11, weight: .semibold))
                    .foregroundStyle(NativeTheme.mutedColor)
            }

            if let storageErrorMessage = model.storageErrorMessage {
                Text(storageErrorMessage)
                    .font(NativeTheme.interfaceFont(size: 12))
                    .foregroundStyle(Color(nsColor: NativeTheme.accentStrong))
            }

            if let storageExternalChangeMessage = model.storageExternalChangeMessage {
                Text(storageExternalChangeMessage)
                    .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                    .foregroundStyle(NativeTheme.accentColor)
            }

            if let importStatusMessage {
                Text(importStatusMessage)
                    .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                    .foregroundStyle(NativeTheme.accentColor)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
                        ForEach(model.projects) { project in
                            ActiveProjectCardView(model: model, project: project)
                        }
                    }

                    if !model.trashedProjects.isEmpty {
                        DeletedProjectsSectionView(model: model)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(28)
        .background(NativeTheme.paper1Color)
        .onAppear {
            model.refreshStorageStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshStorageStatus()
        }
    }

    private func chooseStorageFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        panel.message = "Choose a folder for Novel Writer Native project data. An iCloud Drive folder works well for using the app on both Macs."
        if panel.runModal() == .OK, let folderURL = panel.url {
            model.moveStorage(to: folderURL)
        }
    }

    private func importDOCX() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let docxType = UTType(filenameExtension: "docx") {
            panel.allowedContentTypes = [docxType]
        }
        panel.prompt = "Import"
        panel.message = "Choose a Word document to import into a new Novel Writer project."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try model.importDOCXProject(from: url)
            setImportStatus("DOCX imported as a new project.")
        } catch {
            setImportStatus("Couldn't import DOCX: \(error.localizedDescription)")
        }
    }

    private func setImportStatus(_ message: String) {
        importStatusMessage = message
        let delayNanoseconds: UInt64 = message.hasPrefix("Couldn't import") ? 8_000_000_000 : 3_000_000_000
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            if importStatusMessage == message {
                importStatusMessage = nil
            }
        }
    }
}

struct AutomaticBackupsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    @State private var backupEntries: [NativeAutomaticBackupInfo] = []
    @State private var selectedBackupID: URL?
    @State private var isShowingRestoreConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Restore Automatic Backup")
                .font(NativeTheme.displayFont(size: 22, weight: .bold))
                .foregroundStyle(NativeTheme.ink1Color)

            Text("Choose a saved snapshot to restore only this project without rolling back the rest of the library.")
                .font(NativeTheme.interfaceFont(size: 13))
                .foregroundStyle(NativeTheme.mutedColor)

            if backupEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No automatic backups found yet.")
                        .font(NativeTheme.interfaceFont(size: 13, weight: .semibold))
                        .foregroundStyle(NativeTheme.ink1Color)
                    Text("Keep writing for a bit longer and the app will create rolling snapshots in the Automatic Backups folder.")
                        .font(NativeTheme.interfaceFont(size: 12))
                        .foregroundStyle(NativeTheme.mutedColor)
                    Text("Project: \(project.title)")
                        .font(NativeTheme.interfaceFont(size: 12))
                        .foregroundStyle(NativeTheme.mutedColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(16)
                .background(NativeTheme.panelSoftColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                List(selection: $selectedBackupID) {
                    ForEach(backupEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.exportedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(NativeTheme.interfaceFont(size: 13, weight: .semibold))
                                .foregroundStyle(NativeTheme.ink1Color)
                            Text("Backup file saved \(entry.modifiedAt.formatted(date: .omitted, time: .shortened)) • App \(entry.appVersion)")
                                .font(NativeTheme.interfaceFont(size: 12))
                                .foregroundStyle(NativeTheme.mutedColor)
                            Text(entry.url.lastPathComponent)
                                .font(NativeTheme.interfaceFont(size: 11))
                                .foregroundStyle(NativeTheme.mutedColor)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                        .tag(entry.id)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(NativeTheme.panelSoftColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack {
                Button("Refresh") {
                    reloadEntries()
                }
                .buttonStyle(NativeSecondaryButtonStyle())

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(NativeSecondaryButtonStyle())

                Button("Restore Selected") {
                    isShowingRestoreConfirmation = true
                }
                .buttonStyle(NativeProminentButtonStyle())
                .disabled(selectedBackup == nil)
            }
        }
        .padding(24)
        .frame(minWidth: 680, minHeight: 460)
        .background(NativeTheme.paper1Color)
        .onAppear {
            reloadEntries()
        }
        .alert("Restore this project backup?", isPresented: $isShowingRestoreConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                restoreSelectedBackup()
            }
        } message: {
            Text("\"\(project.title)\" will be replaced with the selected backup. The app will create one more safety snapshot of the current project first.")
        }
    }

    private var selectedBackup: NativeAutomaticBackupInfo? {
        backupEntries.first(where: { $0.id == selectedBackupID })
    }

    private func reloadEntries() {
        backupEntries = model.availableAutomaticBackups(for: project.id)
        if selectedBackupID == nil || !backupEntries.contains(where: { $0.id == selectedBackupID }) {
            selectedBackupID = backupEntries.first?.id
        }
    }

    private func restoreSelectedBackup() {
        guard let selectedBackup else { return }
        model.restoreAutomaticBackup(for: project.id, from: selectedBackup.url)
        dismiss()
    }
}

struct ActiveProjectCardView: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingRestoreBackups = false
    @State private var exportStatusMessage: String?

    var body: some View {
        Button {
            model.openProject(project)
        } label: {
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                EditableProjectTitleField(model: model, project: project)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 62, alignment: .center)
                VStack(spacing: 6) {
                    Text("\(model.chapterCount(for: project.id)) chapters")
                    Text("\(model.wordCount(for: project.id)) words")
                    Text("Updated \(project.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.caption)
                .foregroundStyle(NativeTheme.mutedColor)
                Spacer(minLength: 0)
            }
            .frame(width: 232, height: 232)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(NativeTheme.projectCardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(NativeTheme.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Export Backup…") {
                exportBackup()
            }

            Button("Restore Backup…") {
                isShowingRestoreBackups = true
            }

            Divider()

            Button("Export Standard Manuscript…") {
                exportPreset(.standardManuscript)
            }

            Button("Export KDP Paperback DOCX…") {
                exportPreset(.kdpPaperback)
            }

            Button("Export KDP Hardcover DOCX…") {
                exportPreset(.kdpHardcover)
            }

            Divider()

            Button("Delete Project", role: .destructive) {
                isShowingDeleteConfirmation = true
            }
        }
        .overlay(alignment: .bottom) {
            if let exportStatusMessage {
                Text(exportStatusMessage)
                    .font(NativeTheme.interfaceFont(size: 11, weight: .semibold))
                    .foregroundStyle(NativeTheme.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(NativeTheme.paper1Color.opacity(0.96))
                    .clipShape(Capsule())
                    .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $isShowingRestoreBackups) {
            AutomaticBackupsSheet(model: model, project: project)
        }
        .alert("Move project to Trash?", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                model.deleteProject(project.id)
            }
        } message: {
            Text("\"\(project.title)\" will move to Deleted Projects and can still be restored.")
        }
    }

    private func exportBackup() {
        guard let data = model.backupData(for: project.id) else {
            setExportStatus("Couldn't create backup.")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Project Backup"
        panel.message = "Save a full Novel Writer backup for this project."
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = sanitizedFilename(project.title) + ".novelwriter.json"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url, options: .atomic)
            setExportStatus("Backup exported.")
        } catch {
            setExportStatus("Couldn't export backup.")
        }
    }

    private func exportPreset(_ preset: NativeExportPreset) {
        switch preset.outputFormat {
        case .plainText:
            exportPlainTextPreset(preset)
        case .docx:
            exportDOCXPreset(preset)
        }
    }

    private func exportPlainTextPreset(_ preset: NativeExportPreset) {
        guard let text = model.manuscriptExportText(for: project.id, preset: preset), !text.isEmpty else {
            setExportStatus("Nothing to export yet.")
            return
        }

        let panel = NSSavePanel()
        panel.title = preset.panelTitle
        panel.message = preset.panelMessage
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = sanitizedFilename(project.title) + "-" + preset.filenameSuffix + ".txt"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            setExportStatus("\(preset.label) exported.")
        } catch {
            setExportStatus("Couldn't export \(preset.label.lowercased()).")
        }
    }

    private func exportDOCXPreset(_ preset: NativeExportPreset) {
        guard let data = model.manuscriptDOCXData(for: project.id, preset: preset), !data.isEmpty else {
            setExportStatus("Couldn't create \(preset.label.lowercased()) export.")
            return
        }

        let panel = NSSavePanel()
        panel.title = preset.panelTitle
        panel.message = preset.panelMessage
        if let docxType = UTType(filenameExtension: "docx") {
            panel.allowedContentTypes = [docxType]
        }
        panel.nameFieldStringValue = sanitizedFilename(project.title) + "-" + preset.filenameSuffix + ".docx"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url, options: .atomic)
            setExportStatus("\(preset.label) exported.")
        } catch {
            setExportStatus("Couldn't export \(preset.label.lowercased()).")
        }
    }

    private func sanitizedFilename(_ title: String) -> String {
        let cleaned = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return cleaned.isEmpty ? "Novel Writer Project" : cleaned
    }

    private func setExportStatus(_ message: String) {
        exportStatusMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if exportStatusMessage == message {
                exportStatusMessage = nil
            }
        }
    }
}

struct DeletedProjectsSectionView: View {
    @ObservedObject var model: NativeAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deleted Projects")
                .font(.headline)
                .foregroundStyle(NativeTheme.mutedColor)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(model.trashedProjects) { item in
                    DeletedProjectRowView(model: model, item: item)
                }
            }
        }
    }
}

struct DeletedProjectRowView: View {
    @ObservedObject var model: NativeAppModel
    let item: NativeTrashedProject
    @State private var isShowingPermanentDeleteConfirmation = false

    private var wordCount: Int {
        item.scenes.reduce(0) { partialResult, scene in
            partialResult + scene.body.split(whereSeparator: \.isWhitespace).count
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.project.title)
                .font(.subheadline.weight(.semibold))
            HStack {
                Text("\(item.chapters.count) chapters")
                Text("•")
                Text("\(wordCount) words")
                Spacer()
                Button("Restore") {
                    model.restoreTrashedProject(item.id)
                }
                .buttonStyle(.borderless)
                Button("Delete Forever", role: .destructive) {
                    isShowingPermanentDeleteConfirmation = true
                }
                .buttonStyle(.borderless)
            }
            .font(.caption)
            .foregroundStyle(NativeTheme.mutedColor)
        }
        .padding(12)
        .background(NativeTheme.panelSoftColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .alert("Delete project forever?", isPresented: $isShowingPermanentDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) {
                model.permanentlyDeleteTrashedProject(item.id)
            }
        } message: {
            Text("\"\(item.project.title)\" will be removed permanently from Deleted Projects.")
        }
    }
}

struct WorkspaceShellView: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    @StateObject private var findReplaceStore = NativeFindReplaceStore()
    @State private var isShowingStyleGuide = false

    var body: some View {
        VStack(spacing: 0) {
            if let storageExternalChangeMessage = model.storageExternalChangeMessage {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(NativeTheme.accentColor)
                    Text(storageExternalChangeMessage)
                        .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                        .foregroundStyle(NativeTheme.ink1Color)
                    Spacer()
                    Button("Reload From Disk") {
                        model.reloadFromDisk()
                    }
                    .buttonStyle(NativeSecondaryButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(NativeTheme.paper2Color)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(NativeTheme.dividerColor)
                        .frame(height: 1)
                }
            }

            HStack(spacing: 14) {
                Button("Projects") {
                    model.returnToProjects()
                }
                .buttonStyle(.borderless)

                VStack(alignment: .leading, spacing: 2) {
                    EditableProjectHeaderField(model: model, project: project)
                    Text("Local-first proof of concept")
                        .font(NativeTheme.interfaceFont(size: 12))
                        .foregroundStyle(NativeTheme.mutedColor)
                }

                Spacer()

                Button("Style Guide") {
                    isShowingStyleGuide = true
                }
                Button("New Chapter") {
                    model.createChapter()
                }
                Button("New Scene") {
                    model.createScene()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(NativeTheme.paper2Color)

            if let pendingUndo = model.pendingUndo {
                NativeUndoBannerView(model: model, message: pendingUndo.message)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(NativeTheme.paper3Color)
            }

            NativeWorkspaceSplitView(
                binderWidth: Binding(
                    get: { model.binderColumnWidth },
                    set: { model.setBinderColumnWidth($0) }
                ),
                binder: {
                    BinderColumnView(model: model, project: project, findReplaceStore: findReplaceStore)
                },
                editor: {
                    EditorColumnView(model: model, project: project, findReplaceStore: findReplaceStore)
                }
            )
        }
        .background(NativeTheme.paper3Color)
        .onAppear {
            NativeTextFormattingController.setPerformFindNextHandler {
                findReplaceStore.goToNext()
                findReplaceStore.focusCurrentMatch(model: model)
            }
            refreshFindResults()
        }
        .onDisappear {
            NativeTextFormattingController.setPerformFindNextHandler(nil)
        }
        .onChange(of: findReplaceStore.query) { _, _ in
            refreshFindResults()
        }
        .onChange(of: findReplaceStore.scope) { _, _ in
            refreshFindResults()
        }
        .onChange(of: findReplaceStore.mode) { _, _ in
            refreshFindResults()
        }
        .onChange(of: findReplaceStore.isMatchCaseEnabled) { _, _ in
            refreshFindResults()
        }
        .onChange(of: model.scenes.map(\.body)) { _, _ in
            refreshFindResults()
        }
        .onChange(of: model.selectedSceneIDs) { _, _ in
            refreshFindResults()
        }
        .onChange(of: model.selectedChapterIDs) { _, _ in
            refreshFindResults()
        }
        .sheet(isPresented: $isShowingStyleGuide) {
            NativeProjectStyleGuideSheet(model: model, project: project)
        }
        .onAppear {
            model.refreshStorageStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshStorageStatus()
        }
    }

    private func refreshFindResults() {
        findReplaceStore.refresh(
            model: model,
            projectID: project.id,
            visibleScenes: model.displayScenes(for: project.id),
            selectionContext: NativeTextFormattingController.currentFindSelectionContext()
        )
    }
}

struct NativeProjectStyleGuideSheet: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    @Environment(\.dismiss) private var dismiss
    private let narrativePersonOptions = ["", "First Person", "Second Person", "Third Person"]
    private let narrativeTenseOptions = ["", "Present Tense", "Past Tense"]
    @State private var narrativePerson: String
    @State private var narrativeTense: String
    @State private var genre: String
    @State private var subgenre: String
    @State private var storyPromise: String
    @State private var pacingNotes: String
    @State private var avoidNotes: String
    @State private var continuityMemory: String
    @State private var isPodcastProject: Bool
    @State private var podcastTitle: String
    @State private var hostDisplayName: String
    @State private var websiteURL: String
    @State private var applePodcastURL: String
    @State private var spotifyURL: String
    @State private var youtubeURL: String
    @State private var newsletterURL: String
    @State private var podcastCallToAction: String
    @State private var styleNotes: String
    @State private var approvedWordsText: String
    @State private var characterStyles: [NativeCharacterStyleGuide]
    @State private var audioPronunciationReplacements: [NativeAudioPronunciationReplacement]

    private var bodyFontSize: CGFloat { model.editorFontSize.pointSize }
    private var labelFontSize: CGFloat { max(12, model.editorFontSize.pointSize - 2) }
    private var helpFontSize: CGFloat { max(11, model.editorFontSize.pointSize - 3) }

    init(model: NativeAppModel, project: NativeProject) {
        self.model = model
        self.project = project
        _narrativePerson = State(initialValue: project.narrativePerson)
        _narrativeTense = State(initialValue: project.narrativeTense)
        _genre = State(initialValue: project.genre)
        _subgenre = State(initialValue: project.subgenre)
        _storyPromise = State(initialValue: project.storyPromise)
        _pacingNotes = State(initialValue: project.pacingNotes)
        _avoidNotes = State(initialValue: project.avoidNotes)
        _continuityMemory = State(initialValue: project.continuityMemory)
        _isPodcastProject = State(initialValue: project.isPodcastProject)
        _podcastTitle = State(initialValue: project.podcastSetup.podcastTitle)
        _hostDisplayName = State(initialValue: project.podcastSetup.hostDisplayName)
        _websiteURL = State(initialValue: project.podcastSetup.websiteURL)
        _applePodcastURL = State(initialValue: project.podcastSetup.applePodcastURL)
        _spotifyURL = State(initialValue: project.podcastSetup.spotifyURL)
        _youtubeURL = State(initialValue: project.podcastSetup.youtubeURL)
        _newsletterURL = State(initialValue: project.podcastSetup.newsletterURL)
        _podcastCallToAction = State(initialValue: project.podcastSetup.callToAction)
        _styleNotes = State(initialValue: project.styleNotes)
        _approvedWordsText = State(initialValue: project.approvedWords.joined(separator: "\n"))
        _characterStyles = State(initialValue: project.characterStyles)
        _audioPronunciationReplacements = State(initialValue: project.audioPronunciationReplacements)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Project Style Guide")
                        .font(NativeTheme.displayFont(size: 24, weight: .semibold))
                        .foregroundStyle(NativeTheme.ink1Color)
                    Text(project.title)
                        .font(NativeTheme.interfaceFont(size: 13, weight: .semibold))
                        .foregroundStyle(NativeTheme.accentColor)
                }
                Spacer()
                Button("Done") {
                    saveAndDismiss()
                }
                .buttonStyle(NativeProminentButtonStyle())
            }

            Text("Use this to define intentional voice, dialect, character slang, punctuation preferences, and anything the assistant should preserve instead of “correcting.” Project rules apply novel-wide, and character rules let you preserve specific voices.")
                .font(NativeTheme.interfaceFont(size: bodyFontSize))
                .foregroundStyle(NativeTheme.mutedColor)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Project Direction")
                            .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                            .foregroundStyle(NativeTheme.ink1Color)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Narrative Person")
                                    .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                    .foregroundStyle(NativeTheme.ink1Color)
                                Picker("Narrative Person", selection: $narrativePerson) {
                                    Text("Unspecified").tag("")
                                    ForEach(narrativePersonOptions.filter { !$0.isEmpty }, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Narrative Tense")
                                    .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                    .foregroundStyle(NativeTheme.ink1Color)
                                Picker("Narrative Tense", selection: $narrativeTense) {
                                    Text("Unspecified").tag("")
                                    ForEach(narrativeTenseOptions.filter { !$0.isEmpty }, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Genre")
                                    .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                    .foregroundStyle(NativeTheme.ink1Color)
                                TextField("Thriller, Romance, Mystery...", text: $genre)
                                    .font(NativeTheme.interfaceFont(size: bodyFontSize))
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Subgenre / Blend")
                                    .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                    .foregroundStyle(NativeTheme.ink1Color)
                                TextField("Psychological thriller, romantic suspense...", text: $subgenre)
                                    .font(NativeTheme.interfaceFont(size: bodyFontSize))
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        NativeStyleGuideLabeledEditor(
                            title: "Core Story Promise",
                            helpText: "What should readers consistently feel this novel is delivering?",
                            text: $storyPromise,
                            minHeight: 90,
                            fontSize: bodyFontSize,
                            labelFontSize: labelFontSize,
                            helpFontSize: helpFontSize
                        )

                        NativeStyleGuideLabeledEditor(
                            title: "Pacing / Arc Notes",
                            helpText: "How should scenes and chapters generally behave for this book?",
                            text: $pacingNotes,
                            minHeight: 100,
                            fontSize: bodyFontSize,
                            labelFontSize: labelFontSize,
                            helpFontSize: helpFontSize
                        )

                        NativeStyleGuideLabeledEditor(
                            title: "Avoid / Flag",
                            helpText: "What should the assistant warn about, like sagging tension, repetitive introspection, or lost momentum?",
                            text: $avoidNotes,
                            minHeight: 90,
                            fontSize: bodyFontSize,
                            labelFontSize: labelFontSize,
                            helpFontSize: helpFontSize
                        )

                        NativeStyleGuideLabeledEditor(
                            title: "Continuity Memory",
                            helpText: "Durable facts the assistant should remember across chapters: locations, relationships, world rules, ongoing threats, and important established details.",
                            text: $continuityMemory,
                            minHeight: 140,
                            fontSize: bodyFontSize,
                            labelFontSize: labelFontSize,
                            helpFontSize: helpFontSize
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("This project is a podcast / episodic audio release", isOn: $isPodcastProject)
                                .toggleStyle(.switch)

                            if isPodcastProject {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Podcast Title")
                                            .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                            .foregroundStyle(NativeTheme.ink1Color)
                                        TextField("Podcast title", text: $podcastTitle)
                                            .font(NativeTheme.interfaceFont(size: bodyFontSize))
                                            .textFieldStyle(.roundedBorder)
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Host / Default Voice")
                                            .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                            .foregroundStyle(NativeTheme.ink1Color)
                                        TextField("Mike Carmel", text: $hostDisplayName)
                                            .font(NativeTheme.interfaceFont(size: bodyFontSize))
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }

                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Website URL")
                                            .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                            .foregroundStyle(NativeTheme.ink1Color)
                                        TextField("https://...", text: $websiteURL)
                                            .font(NativeTheme.interfaceFont(size: bodyFontSize))
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Apple Podcasts URL")
                                            .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                            .foregroundStyle(NativeTheme.ink1Color)
                                        TextField("https://...", text: $applePodcastURL)
                                            .font(NativeTheme.interfaceFont(size: bodyFontSize))
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }

                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Spotify URL")
                                            .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                            .foregroundStyle(NativeTheme.ink1Color)
                                        TextField("https://...", text: $spotifyURL)
                                            .font(NativeTheme.interfaceFont(size: bodyFontSize))
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("YouTube URL")
                                            .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                            .foregroundStyle(NativeTheme.ink1Color)
                                        TextField("https://...", text: $youtubeURL)
                                            .font(NativeTheme.interfaceFont(size: bodyFontSize))
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Newsletter / Follow URL")
                                        .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                        .foregroundStyle(NativeTheme.ink1Color)
                                    TextField("https://...", text: $newsletterURL)
                                        .font(NativeTheme.interfaceFont(size: bodyFontSize))
                                        .textFieldStyle(.roundedBorder)
                                }

                                NativeStyleGuideLabeledEditor(
                                    title: "Podcast Call To Action",
                                    helpText: "Used in episode outros and social posts.",
                                    text: $podcastCallToAction,
                                    minHeight: 90,
                                    fontSize: bodyFontSize,
                                    labelFontSize: labelFontSize,
                                    helpFontSize: helpFontSize
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Voice Rules / Notes")
                            .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                            .foregroundStyle(NativeTheme.ink1Color)
                        NativeStyleGuideLabeledEditor(
                            title: nil,
                            helpText: nil,
                            text: $styleNotes,
                            minHeight: 180,
                            fontSize: bodyFontSize,
                            labelFontSize: labelFontSize,
                            helpFontSize: helpFontSize
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Approved Words")
                            .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                            .foregroundStyle(NativeTheme.ink1Color)
                        Text("One word or phrase per line. These are treated as intentional dialect/style for this project.")
                            .font(NativeTheme.interfaceFont(size: helpFontSize))
                            .foregroundStyle(NativeTheme.mutedColor)
                        NativeStyleGuideLabeledEditor(
                            title: nil,
                            helpText: nil,
                            text: $approvedWordsText,
                            minHeight: 140,
                            fontSize: bodyFontSize,
                            labelFontSize: labelFontSize,
                            helpFontSize: helpFontSize
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Character Voice Rules")
                                    .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                    .foregroundStyle(NativeTheme.ink1Color)
                                Text("Assign voice notes and approved words to specific characters.")
                                    .font(NativeTheme.interfaceFont(size: helpFontSize))
                                    .foregroundStyle(NativeTheme.mutedColor)
                            }
                            Spacer()
                            Button("Add Character") {
                                addCharacterStyle()
                            }
                        }

                        if characterStyles.isEmpty {
                            Text("No character-specific voice rules yet.")
                                .font(NativeTheme.interfaceFont(size: helpFontSize))
                                .foregroundStyle(NativeTheme.mutedColor)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(NativeTheme.panelSoftColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            ForEach($characterStyles) { $characterStyle in
                                NativeCharacterStyleCard(
                                    characterStyle: $characterStyle,
                                    bodyFontSize: bodyFontSize,
                                    labelFontSize: labelFontSize,
                                    helpFontSize: helpFontSize,
                                    removeAction: {
                                        removeCharacterStyle(characterStyle.id)
                                    }
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Audio Pronunciations")
                                    .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                                    .foregroundStyle(NativeTheme.ink1Color)
                                Text("Keep manuscript spelling intact, but replace names or terms with TTS-friendly phonetics when copying episode prep for audio production.")
                                    .font(NativeTheme.interfaceFont(size: helpFontSize))
                                    .foregroundStyle(NativeTheme.mutedColor)
                            }
                            Spacer()
                            Button("Add Replacement") {
                                addAudioPronunciationReplacement()
                            }
                        }

                        if audioPronunciationReplacements.isEmpty {
                            Text("No audio pronunciation replacements yet.")
                                .font(NativeTheme.interfaceFont(size: helpFontSize))
                                .foregroundStyle(NativeTheme.mutedColor)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(NativeTheme.panelSoftColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            ForEach($audioPronunciationReplacements) { $replacement in
                                NativeAudioPronunciationReplacementCard(
                                    replacement: $replacement,
                                    bodyFontSize: bodyFontSize,
                                    labelFontSize: labelFontSize,
                                    helpFontSize: helpFontSize,
                                    removeAction: {
                                        removeAudioPronunciationReplacement(replacement.id)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 700)
        .background(NativeTheme.paper2Color)
        .onDisappear {
            saveStyleGuide()
        }
    }

    private func saveAndDismiss() {
        saveStyleGuide()
        dismiss()
    }

    private func saveStyleGuide() {
        model.updateProjectDirection(
            project.id,
            narrativePerson: narrativePerson,
            narrativeTense: narrativeTense,
            genre: genre,
            subgenre: subgenre,
            storyPromise: storyPromise,
            pacingNotes: pacingNotes,
            avoidNotes: avoidNotes
        )
        model.updateProjectPodcastSettings(
            project.id,
            isPodcastProject: isPodcastProject,
            setup: NativePodcastSetup(
                podcastTitle: podcastTitle,
                hostDisplayName: hostDisplayName,
                websiteURL: websiteURL,
                applePodcastURL: applePodcastURL,
                spotifyURL: spotifyURL,
                youtubeURL: youtubeURL,
                newsletterURL: newsletterURL,
                callToAction: podcastCallToAction
            )
        )
        model.updateProjectContinuityMemory(project.id, summary: continuityMemory)
        model.updateProjectStyleNotes(project.id, notes: styleNotes)
        model.updateProjectApprovedWords(project.id, words: approvedWordsText.components(separatedBy: .newlines))
        model.updateProjectCharacterStyles(project.id, characterStyles: characterStyles)
        model.updateProjectAudioPronunciationReplacements(project.id, replacements: audioPronunciationReplacements)
    }

    private func addCharacterStyle() {
        characterStyles.append(
            NativeCharacterStyleGuide(
                id: UUID(),
                name: "New Character",
                styleNotes: "",
                visualDescription: "",
                approvedWords: []
            )
        )
    }

    private func removeCharacterStyle(_ characterID: UUID) {
        characterStyles.removeAll { $0.id == characterID }
    }

    private func addAudioPronunciationReplacement() {
        audioPronunciationReplacements.append(
            NativeAudioPronunciationReplacement(
                id: UUID(),
                writtenForm: "",
                spokenForm: "",
                notes: "",
                isEnabled: true
            )
        )
    }

    private func removeAudioPronunciationReplacement(_ replacementID: UUID) {
        audioPronunciationReplacements.removeAll { $0.id == replacementID }
    }
}

struct NativeStyleGuideLabeledEditor: View {
    let title: String?
    let helpText: String?
    @Binding var text: String
    let minHeight: CGFloat
    var fontSize: CGFloat = 13
    var labelFontSize: CGFloat = 12
    var helpFontSize: CGFloat = 11

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                    .foregroundStyle(NativeTheme.ink1Color)
            }
            if let helpText {
                Text(helpText)
                    .font(NativeTheme.interfaceFont(size: helpFontSize))
                    .foregroundStyle(NativeTheme.mutedColor)
            }
            NativeScrollingPlainTextEditor(
                text: $text,
                minHeight: minHeight,
                fontSize: fontSize
            )
            .frame(minHeight: minHeight)
        }
    }
}

struct NativeScrollingPlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    let minHeight: CGFloat
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NativeScrollingEditorTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont(name: "Avenir Next", size: fontSize) ?? .systemFont(ofSize: fontSize)
        textView.textColor = NativeTheme.ink1
        textView.insertionPointColor = NativeTheme.accent
        textView.textContainerInset = NSSize(width: 0, height: 6)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 12
        scrollView.layer?.backgroundColor = NativeTheme.panel.cgColor
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.borderColor = NativeTheme.border.cgColor
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NativeScrollingEditorTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        let font = NSFont(name: "Avenir Next", size: fontSize) ?? .systemFont(ofSize: fontSize)
        if textView.font != font {
            textView.font = font
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            textView.scrollRangeToVisible(textView.selectedRange())
        }
    }
}

final class NativeScrollingEditorTextView: NSTextView {
    override func didChangeText() {
        super.didChangeText()
        scrollRangeToVisible(selectedRange())
    }
}

struct NativeCharacterStyleCard: View {
    @Binding var characterStyle: NativeCharacterStyleGuide
    let bodyFontSize: CGFloat
    let labelFontSize: CGFloat
    let helpFontSize: CGFloat
    let removeAction: () -> Void

    private var approvedWordsText: Binding<String> {
        Binding(
            get: { characterStyle.approvedWords.joined(separator: "\n") },
            set: { newValue in
                characterStyle.approvedWords = newValue
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Character Name", text: $characterStyle.name)
                    .textFieldStyle(.roundedBorder)
                    .font(NativeTheme.interfaceFont(size: bodyFontSize, weight: .semibold))
                Spacer()
                Button("Remove", role: .destructive, action: removeAction)
                    .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Voice Notes")
                    .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                    .foregroundStyle(NativeTheme.ink1Color)
                NativeScrollingPlainTextEditor(
                    text: $characterStyle.styleNotes,
                    minHeight: 110,
                    fontSize: bodyFontSize
                )
                .frame(minHeight: 110)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Visual Description")
                    .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                    .foregroundStyle(NativeTheme.ink1Color)
                Text("Used for cover-art and image prompt generation.")
                    .font(NativeTheme.interfaceFont(size: helpFontSize))
                    .foregroundStyle(NativeTheme.mutedColor)
                NativeScrollingPlainTextEditor(
                    text: $characterStyle.visualDescription,
                    minHeight: 90,
                    fontSize: bodyFontSize
                )
                .frame(minHeight: 90)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Approved Words")
                    .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                    .foregroundStyle(NativeTheme.ink1Color)
                Text("One word or phrase per line for this character only.")
                    .font(NativeTheme.interfaceFont(size: helpFontSize))
                    .foregroundStyle(NativeTheme.mutedColor)
                NativeScrollingPlainTextEditor(
                    text: approvedWordsText,
                    minHeight: 90,
                    fontSize: bodyFontSize
                )
                .frame(minHeight: 90)
            }
        }
        .padding(14)
        .background(NativeTheme.panelSoftColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NativeTheme.borderColor.opacity(0.7), lineWidth: 1)
        )
    }
}

struct NativeAudioPronunciationReplacementCard: View {
    @Binding var replacement: NativeAudioPronunciationReplacement
    let bodyFontSize: CGFloat
    let labelFontSize: CGFloat
    let helpFontSize: CGFloat
    let removeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Toggle(isOn: $replacement.isEnabled) {
                    Text("Enable Replacement")
                        .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                        .foregroundStyle(NativeTheme.ink1Color)
                }
                .toggleStyle(.switch)
                Spacer()
                Button("Remove", role: .destructive, action: removeAction)
                    .buttonStyle(.borderless)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Written Form")
                        .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                        .foregroundStyle(NativeTheme.ink1Color)
                    TextField("Sharael", text: $replacement.writtenForm)
                        .font(NativeTheme.interfaceFont(size: bodyFontSize))
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Spoken / TTS Form")
                        .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                        .foregroundStyle(NativeTheme.ink1Color)
                    TextField("Shuhrel", text: $replacement.spokenForm)
                        .font(NativeTheme.interfaceFont(size: bodyFontSize))
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                    .foregroundStyle(NativeTheme.ink1Color)
                Text("Optional reminder for you, such as accent or emphasis guidance.")
                    .font(NativeTheme.interfaceFont(size: helpFontSize))
                    .foregroundStyle(NativeTheme.mutedColor)
                TextField("Soft first syllable", text: $replacement.notes)
                    .font(NativeTheme.interfaceFont(size: bodyFontSize))
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(14)
        .background(NativeTheme.panelSoftColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NativeTheme.borderColor.opacity(0.7), lineWidth: 1)
        )
    }
}

struct NativeWorkspaceSplitView<Binder: View, Editor: View>: View {
    @Binding var binderWidth: CGFloat
    let binder: Binder
    let centerDrawer: AnyView?
    let editor: Editor
    @State private var liveBinderWidth: CGFloat?
    @State private var isHoveringDivider = false

    init(
        binderWidth: Binding<CGFloat>,
        @ViewBuilder binder: () -> Binder,
        centerDrawer: AnyView? = nil,
        @ViewBuilder editor: () -> Editor
    ) {
        _binderWidth = binderWidth
        self.binder = binder()
        self.centerDrawer = centerDrawer
        self.editor = editor()
    }

    var body: some View {
        GeometryReader { proxy in
            let displayedBinderWidth = clampedBinderWidth(for: proxy.size.width)
            let containerFrame = proxy.frame(in: .global)

            HStack(spacing: 0) {
                binder
                    .frame(width: displayedBinderWidth)
                    .frame(maxHeight: .infinity)

                Rectangle()
                    .fill(isHoveringDivider || liveBinderWidth != nil ? NativeTheme.accentSoftColor.opacity(0.8) : NativeTheme.dividerColor)
                    .frame(width: dividerHitWidth)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(isHoveringDivider || liveBinderWidth != nil ? NativeTheme.accentColor : NativeTheme.accentSoftColor)
                            .frame(width: 4, height: 52)
                    )
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHoveringDivider = hovering
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .onChanged { value in
                                let nextWidth = value.location.x - containerFrame.minX - (dividerHitWidth / 2)
                                liveBinderWidth = clamp(nextWidth, totalWidth: proxy.size.width)
                            }
                            .onEnded { _ in
                                if let liveBinderWidth {
                                    binderWidth = clamp(liveBinderWidth, totalWidth: proxy.size.width)
                                }
                                liveBinderWidth = nil
                            }
                    )

                if let centerDrawer {
                    centerDrawer
                }

                editor
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onChange(of: binderWidth) { _, newValue in
                guard liveBinderWidth == nil else { return }
                liveBinderWidth = clamp(newValue, totalWidth: proxy.size.width)
            }
        }
    }

    private func clampedBinderWidth(for totalWidth: CGFloat) -> CGFloat {
        clamp(liveBinderWidth ?? binderWidth, totalWidth: totalWidth)
    }

    private func clamp(_ proposedWidth: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let maxWidth = max(minBinderWidth, totalWidth - dividerHitWidth - minEditorWidth)
        return min(max(proposedWidth, minBinderWidth), maxWidth)
    }

    private var minBinderWidth: CGFloat { 260 }
    private var minEditorWidth: CGFloat { 320 }
    private var dividerHitWidth: CGFloat { 14 }
}

struct NativeUndoBannerView: View {
    @ObservedObject var model: NativeAppModel
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward")
                .foregroundStyle(NativeTheme.accentColor)
            Text(message)
                .font(NativeTheme.interfaceFont(size: 14, weight: .medium))
                .foregroundStyle(NativeTheme.ink1Color)
            Spacer()
            Button("Undo") {
                model.undoLastDelete()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(NativeTheme.panelSoftColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NativeTheme.borderColor, lineWidth: 1)
        )
    }
}

struct BinderColumnView: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    @ObservedObject var findReplaceStore: NativeFindReplaceStore
    @State private var isTrashExpanded = false
    @State private var draggedChapterID: UUID?
    @State private var draggedSceneID: UUID?
    @State private var activeDropTarget: BinderDropTarget?
    @FocusState private var isBinderFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.chapters(for: project.id)) { chapter in
                        BinderChapterRowView(
                            model: model,
                            project: project,
                            chapter: chapter,
                            isSelected: model.isChapterHighlighted(chapter.id),
                            draggedChapterID: $draggedChapterID,
                            draggedSceneID: $draggedSceneID,
                            activeDropTarget: $activeDropTarget
                        )
                        ForEach(model.scenesInChapter(chapter.id)) { scene in
                            BinderSceneRowView(
                                model: model,
                                scene: scene,
                                isSelected: model.isSceneHighlighted(scene.id),
                                draggedSceneID: $draggedSceneID,
                                activeDropTarget: $activeDropTarget
                            )
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 0) {
                TrashSectionView(model: model, project: project, isExpanded: $isTrashExpanded)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                NativeBinderFooterFindReplaceView(
                    model: model,
                    project: project,
                    store: findReplaceStore
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 10)

                NativeStatusFooterBar {
                    Text("Project Words: \(model.wordCount(for: project.id))")
                        .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                        .foregroundStyle(NativeTheme.mutedColor)
                    Spacer()
                }
            }
        }
        .background(NativeTheme.panelColor)
        .contentShape(Rectangle())
        .focusable()
        .focused($isBinderFocused)
        .focusEffectDisabled()
        .onAppear {
            isBinderFocused = true
        }
        .onTapGesture {
            isBinderFocused = true
        }
        .onAppear {
            findReplaceStore.refresh(
                model: model,
                projectID: project.id,
                visibleScenes: model.displayScenes(for: project.id),
                selectionContext: NativeTextFormattingController.currentFindSelectionContext()
            )
        }
        .onMoveCommand { direction in
            switch direction {
            case .up:
                model.moveSelection(delta: -1, within: project.id)
            case .down:
                model.moveSelection(delta: 1, within: project.id)
            case .right:
                model.expandOrDescendSelection(in: project.id)
            case .left:
                model.collapseSelection(in: project.id)
            @unknown default:
                break
            }
        }
        .onExitCommand {
            model.returnToProjects()
        }
        .background(
            Button("") {
                let initialQuery = NativeTextFormattingController.currentSelectedText()
                findReplaceStore.open(initialQuery: initialQuery)
                findReplaceStore.refresh(
                    model: model,
                    projectID: project.id,
                    visibleScenes: model.displayScenes(for: project.id),
                    selectionContext: NativeTextFormattingController.currentFindSelectionContext()
                )
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0.001)
        )
        .onDeleteCommand {
            model.deleteSelectedItems()
        }
        .onKeyPress(.return) {
            model.openSelectedBinderItem()
            return .handled
        }
    }
}

struct BinderChapterRowView: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    let chapter: NativeChapter
    let isSelected: Bool
    @Binding var draggedChapterID: UUID?
    @Binding var draggedSceneID: UUID?
    @Binding var activeDropTarget: BinderDropTarget?
    @State private var isHovered = false
    @State private var isDropTargeted = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        HStack {
            Image(systemName: "books.vertical")
            EditableChapterTitleField(model: model, project: project, chapter: chapter)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(rowBackgroundColor)
        )
        .overlay(alignment: .top) {
            if isDropTargeted || activeDropTarget == .chapter(chapter.id) {
                Rectangle()
                    .fill(NativeTheme.accentColor)
                    .frame(height: 3)
                    .clipShape(Capsule())
                    .padding(.horizontal, 6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectChapter(chapter.id, modifiers: currentModifierFlags())
        }
        .onHover { hovered in
            isHovered = hovered
        }
        .onDrag {
            draggedChapterID = chapter.id
            draggedSceneID = nil
            activeDropTarget = nil
            return NSItemProvider(object: NSString(string: "chapter:\(chapter.id.uuidString)"))
        } preview: {
            BinderDragPreview(icon: "books.vertical", title: chapter.title)
        }
        .onDrop(of: [UTType.text], isTargeted: $isDropTargeted) { providers in
            defer {
                draggedChapterID = nil
                draggedSceneID = nil
                activeDropTarget = nil
                isDropTargeted = false
            }

            if let draggedChapterID {
                model.moveChapter(draggedChapterID, before: chapter.id)
                return true
            }
            if let draggedSceneID {
                model.moveScene(draggedSceneID, toChapter: chapter.id)
                return true
            }
            return false
        }
        .onChange(of: isDropTargeted) { _, targeted in
            activeDropTarget = targeted ? .chapter(chapter.id) : (activeDropTarget == .chapter(chapter.id) ? nil : activeDropTarget)
        }
        .contextMenu {
            Button("Export \(exportScope.label)…") {
                exportBinderScope(applyAudioPronunciations: false)
            }

            Button("Export \(exportScope.label) Using Audio Pronunciations…") {
                exportBinderScope(applyAudioPronunciations: true)
            }

            Divider()

            Button("Delete Chapter", role: .destructive) {
                isShowingDeleteConfirmation = true
            }
        }
        .alert("Move chapter to Trash?", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                model.deleteChapter(chapter.id)
            }
        } message: {
            Text("\"\(chapter.title)\" and its scenes will move to Trash and can still be restored.")
        }
    }

    private var rowBackgroundColor: Color {
        if isSelected {
            return NativeTheme.selectionColor
        }
        if isDropTargeted {
            return NativeTheme.accentSoftColor.opacity(0.55)
        }
        if isHovered {
            return NativeTheme.panelSoftColor
        }
        return NativeTheme.panelColor.opacity(0.001)
    }

    private var exportScope: NativeBinderExportScope {
        model.binderExportScope(forChapterID: chapter.id)
    }

    private func exportBinderScope(applyAudioPronunciations: Bool) {
        guard let export = model.binderExportText(for: exportScope, applyAudioPronunciations: applyAudioPronunciations) else { return }

        let panel = NSSavePanel()
        panel.title = "Export \(exportScope.label)"
        panel.message = applyAudioPronunciations
            ? "Export this \(exportScope.label.lowercased()) as plain text using the project's audio pronunciation replacements."
            : "Export this \(exportScope.label.lowercased()) as plain text."
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = export.suggestedFilename

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? export.text.write(to: url, atomically: true, encoding: .utf8)
    }
}

struct BinderSceneRowView: View {
    @ObservedObject var model: NativeAppModel
    let scene: NativeScene
    let isSelected: Bool
    @Binding var draggedSceneID: UUID?
    @Binding var activeDropTarget: BinderDropTarget?
    @State private var isHovered = false
    @State private var isDropTargeted = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        HStack {
            Image(systemName: "doc.text")
            EditableSceneTitleField(model: model, scene: scene)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .padding(.leading, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(rowBackgroundColor)
        )
        .overlay(alignment: .top) {
            if isDropTargeted || activeDropTarget == .scene(scene.id) {
                Rectangle()
                    .fill(NativeTheme.accentColor)
                    .frame(height: 3)
                    .clipShape(Capsule())
                    .padding(.horizontal, 6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectScene(scene.id, modifiers: currentModifierFlags())
        }
        .onHover { hovered in
            isHovered = hovered
        }
        .onDrag {
            draggedSceneID = scene.id
            activeDropTarget = nil
            return NSItemProvider(object: NSString(string: "scene:\(scene.id.uuidString)"))
        } preview: {
            BinderDragPreview(icon: "doc.text", title: scene.title)
        }
        .onDrop(of: [UTType.text], isTargeted: $isDropTargeted) { providers in
            defer {
                draggedSceneID = nil
                activeDropTarget = nil
                isDropTargeted = false
            }

            guard let draggedSceneID else { return false }
            model.moveScene(draggedSceneID, before: scene.id)
            return true
        }
        .onChange(of: isDropTargeted) { _, targeted in
            activeDropTarget = targeted ? .scene(scene.id) : (activeDropTarget == .scene(scene.id) ? nil : activeDropTarget)
        }
        .contextMenu {
            Button("Export \(exportScope.label)…") {
                exportBinderScope(applyAudioPronunciations: false)
            }

            Button("Export \(exportScope.label) Using Audio Pronunciations…") {
                exportBinderScope(applyAudioPronunciations: true)
            }

            Divider()

            Button("Delete Scene", role: .destructive) {
                isShowingDeleteConfirmation = true
            }
        }
        .alert("Move scene to Trash?", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                model.deleteScene(scene.id)
            }
        } message: {
            Text("\"\(scene.title)\" will move to Trash and can still be restored.")
        }
    }

    private var rowBackgroundColor: Color {
        if isSelected {
            return NativeTheme.selectionColor
        }
        if isDropTargeted {
            return NativeTheme.accentSoftColor.opacity(0.6)
        }
        if isHovered {
            return NativeTheme.panelSoftColor
        }
        return NativeTheme.panelColor.opacity(0.001)
    }

    private var exportScope: NativeBinderExportScope {
        model.binderExportScope(forSceneID: scene.id)
    }

    private func exportBinderScope(applyAudioPronunciations: Bool) {
        guard let export = model.binderExportText(for: exportScope, applyAudioPronunciations: applyAudioPronunciations) else { return }

        let panel = NSSavePanel()
        panel.title = "Export \(exportScope.label)"
        panel.message = applyAudioPronunciations
            ? "Export this \(exportScope.label.lowercased()) as plain text using the project's audio pronunciation replacements."
            : "Export this \(exportScope.label.lowercased()) as plain text."
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = export.suggestedFilename

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? export.text.write(to: url, atomically: true, encoding: .utf8)
    }
}

struct EditorColumnView: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    @ObservedObject var findReplaceStore: NativeFindReplaceStore
    @StateObject private var formattingState = NativeFormattingToolbarState.shared
    @StateObject private var assistantStore = NativeAssistantStore()
    @StateObject private var podcastPrepStore = NativePodcastPrepStore()
    @StateObject private var apiKeyStore = NativeAPIKeyStore()
    @AppStorage("assistantSidebarVisible") private var isAssistantSidebarVisible = true
    @AppStorage("assistantSidebarWidth") private var assistantSidebarWidth = 360.0
    @AppStorage("assistantTextSize") private var assistantTextSizeRaw = NativeAssistantTextSize.medium.rawValue
    @AppStorage("podcastPrepDrawerVisible") private var isPodcastPrepDrawerVisible = false
    @AppStorage("podcastPrepDrawerWidth") private var podcastPrepDrawerWidth = 380.0
    @State private var liveAssistantWidth: CGFloat?
    @State private var livePodcastDrawerWidth: CGFloat?
    @State private var isHoveringPodcastDrawerResizeHandle = false

    private var effectiveEditorFontSize: CGFloat {
        model.editorFontSize.pointSize * model.editorZoom.scale
    }

    private var effectiveEditorLineSpacing: CGFloat {
        model.editorLineSpacing.spacing * model.editorZoom.scale
    }

    private func previousPodcastEpisode(for chapter: NativeChapter) -> NativeChapter? {
        let orderedChapters = model.chapters(for: project.id)
        guard let currentIndex = orderedChapters.firstIndex(where: { $0.id == chapter.id }),
              currentIndex > 0 else {
            return nil
        }
        return orderedChapters[currentIndex - 1]
    }

    var body: some View {
        HStack(spacing: 0) {
            if project.isPodcastProject, let currentChapter {
                if isPodcastPrepDrawerVisible {
                    let previousEpisodeChapter = previousPodcastEpisode(for: currentChapter)
                    ZStack(alignment: .trailing) {
                        NativePodcastPrepDrawerView(
                            store: podcastPrepStore,
                            apiKey: apiKeyStore.apiKey,
                            project: project,
                            chapter: currentChapter,
                            scenes: model.scenesInChapter(currentChapter.id),
                            previousEpisodeChapter: previousEpisodeChapter,
                            previousEpisodeScenes: previousEpisodeChapter.map { model.scenesInChapter($0.id) } ?? [],
                            editorFontSize: model.editorFontSize,
                            savePrep: { prep in
                                model.updateChapterPodcastPrep(currentChapter.id, prep: prep)
                            }
                        )
                        .frame(width: displayedPodcastDrawerWidth)
                        .frame(maxHeight: .infinity)

                        NativeAssistantDrawerHandle(
                            direction: .left,
                            attachmentEdge: .left,
                            fullHeight: true,
                            helpText: "Close Episode Prep"
                        ) {
                            isPodcastPrepDrawerVisible = false
                        }
                    }

                    podcastDrawerResizeHandle
                } else {
                    NativeAssistantDrawerHandle(
                        direction: .right,
                        attachmentEdge: .right,
                        fullHeight: true,
                        helpText: "Show Episode Prep"
                    ) {
                        isPodcastPrepDrawerVisible = true
                    }
                }
            }

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text(project.title)
                            .font(NativeTheme.displayFont(size: 26, weight: .semibold))
                            .foregroundStyle(NativeTheme.ink1Color)
                        Spacer()
                        Button("Find") {
                            findReplaceStore.open(initialQuery: NativeTextFormattingController.currentSelectedText())
                            findReplaceStore.refresh(
                                model: model,
                                projectID: project.id,
                                visibleScenes: displayScenes,
                                selectionContext: NativeTextFormattingController.currentFindSelectionContext()
                            )
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)

                    HStack(spacing: 10) {
                        historyToolbarGroup
                        styleToolbarGroup
                        sizeSpacingAndZoomToolbarGroup
                        colorToolbarGroup
                        alignmentToolbarGroup
                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(NativeTheme.panelSoftColor)
                }
                .background(NativeTheme.panelColor)

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if let selectedScene = currentScene {
                                SingleSceneEditorView(model: model, scene: selectedScene)
                                    .id(selectedScene.id)
                            } else if !displayScenes.isEmpty {
                                CompositeChapterEditorView(
                                    model: model,
                                    project: project,
                                    chapter: currentChapter,
                                    projectID: project.id,
                                    isPodcastDrawerVisible: isPodcastPrepDrawerVisible,
                                    togglePodcastDrawer: {
                                        guard project.isPodcastProject, currentChapter != nil else { return }
                                        isPodcastPrepDrawerVisible.toggle()
                                    }
                                )
                            } else {
                                NativeEditorEmptyStateView()
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: 1560, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    NativeStatusFooterBar {
                        Text(editorWordCountLabel)
                            .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                            .foregroundStyle(NativeTheme.mutedColor)

                        if let selectionWordCount, selectionWordCount > 0 {
                            Divider()
                                .frame(height: 12)
                            Text("Selected Words: \(selectionWordCount)")
                                .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                                .foregroundStyle(NativeTheme.accentColor)
                        }

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isAssistantSidebarVisible {
                assistantSidebarResizeHandle

                ZStack(alignment: .leading) {
                    NativeAssistantSidebarView(
                        store: assistantStore,
                        apiKeyStore: apiKeyStore,
                        context: assistantContext,
                        textSize: assistantTextSize,
                        reviewScenes: displayScenes,
                        currentChapterTitle: currentChapter.map { displayedChapterTitle($0.title, for: project) },
                        currentChapterText: currentChapterSceneBreakText,
                        canCreateSceneFromReply: currentScene != nil || currentChapter != nil,
                        createSceneFromReply: { replyText in
                            createAssistantScene(from: replyText)
                        },
                        addStyleGuideSuggestion: { suggestion in
                            mergeStyleGuideSuggestion(suggestion)
                        },
                        addCharacterStyleSuggestion: { suggestion in
                            mergeCharacterStyleSuggestion(suggestion)
                        },
                        addContinuityMemorySuggestion: { suggestion in
                            mergeContinuityMemorySuggestion(suggestion)
                        },
                        applySceneBreakSuggestion: { suggestion in
                            applySceneBreakSuggestion(suggestion)
                        },
                        jumpToReviewIssue: { issue in
                            NativeTextFormattingController.activateReviewIssue(issue)
                        },
                        applyReviewIssue: { issue in
                            NativeTextFormattingController.applyReviewIssue(issue)
                        },
                        clearReviewIssues: {
                            NativeTextFormattingController.clearReviewIssues()
                        }
                    )
                    .frame(width: displayedAssistantSidebarWidth)
                    .frame(maxHeight: .infinity)

                    NativeAssistantDrawerHandle(direction: .right) {
                        isAssistantSidebarVisible = false
                    }
                }
            } else {
                NativeAssistantDrawerHandle(direction: .left) {
                    isAssistantSidebarVisible = true
                }
            }
        }
        .background(NativeTheme.paper3Color)
        .onAppear {
            requestEditorFocusForCurrentSelection()
            NativeTextFormattingController.setSceneNavigationOrder(displayScenes.map(\.id))
        }
        .onChange(of: model.selectedSceneID) { _, _ in
            requestEditorFocusForCurrentSelection()
        }
        .onChange(of: displayScenes.map(\.id)) { _, _ in
            NativeTextFormattingController.setSceneNavigationOrder(displayScenes.map(\.id))
            findReplaceStore.refresh(
                model: model,
                projectID: project.id,
                visibleScenes: displayScenes,
                selectionContext: NativeTextFormattingController.currentFindSelectionContext()
            )
            requestEditorFocusForCurrentSelection()
            findReplaceStore.resumePendingFocus(model: model)
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativeAssistantActiveReviewIssueChanged)) { notification in
            assistantStore.activeReviewIssueID = notification.object as? UUID
        }
        .onReceive(NotificationCenter.default.publisher(for: .nativeAssistantReviewIssuesChanged)) { notification in
            if let issues = notification.object as? [NativeAssistantReviewIssue] {
                assistantStore.setReviewIssues(issues)
            }
        }
        .onChange(of: assistantStore.reviewIssues) { _, issues in
            if issues.isEmpty {
                NativeTextFormattingController.clearReviewIssues()
            } else {
                NativeTextFormattingController.showReviewIssues(issues)
            }
        }
    }

    private var currentScene: NativeScene? {
        guard displayScenes.count == 1 else { return nil }
        return displayScenes.first
    }

    private var currentChapter: NativeChapter? {
        guard let selectedChapterID = model.selectedChapterID else { return nil }
        return model.chapters.first(where: { $0.id == selectedChapterID })
    }

    private var displayScenes: [NativeScene] {
        model.displayScenes(for: project.id)
    }

    private var displayedPodcastDrawerWidth: CGFloat {
        CGFloat(livePodcastDrawerWidth ?? podcastPrepDrawerWidth)
    }

    private var assistantContext: NativeAssistantContext {
        let scopeTitle: String
        let scopeLabel: String
        if let scene = currentScene {
            scopeTitle = "Scene: \(scene.title)"
            scopeLabel = "Current Scene"
        } else if let chapter = currentChapter {
            scopeTitle = "\(chapterKindName(for: project)): \(displayedChapterTitle(chapter.title, for: project))"
            scopeLabel = project.isPodcastProject ? "Current Episode" : "Current Chapter"
        } else if !displayScenes.isEmpty {
            scopeTitle = "Combined Selection"
            scopeLabel = "Visible Composite"
        } else {
            scopeTitle = "No selection"
            scopeLabel = "No Editor Scope"
        }

        let scopeText = displayScenes
            .map { scene in
                """
                [\(scene.title)]
                \(scene.body)
                """
            }
            .joined(separator: "\n\n")

        let selectedText = NativeTextFormattingController.currentSelectedText()
        let liveSelectedText = NativeTextFormattingController.currentLiveSelectedText()
        let selectedWordCount = liveSelectedText?
            .split(whereSeparator: \.isWhitespace)
            .count ?? 0
        let characterSignalText = [
            liveSelectedText?.nilIfEmpty,
            selectedText?.nilIfEmpty,
            scopeText.nilIfEmpty
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
        let relevantCharacterStyles = relevantCharacterStyles(for: characterSignalText)

        return NativeAssistantContext(
            scopeTitle: scopeTitle,
            scopeLabel: scopeLabel,
            scopeText: scopeText,
            scopeWordCount: displayScenes.reduce(0) { partialResult, scene in
                partialResult + scene.body.split(whereSeparator: \.isWhitespace).count
            },
            sceneCount: displayScenes.count,
            selectedText: selectedText,
            hasLiveSelection: liveSelectedText != nil,
            selectedWordCount: selectedWordCount,
            projectStyleNotes: project.styleNotes,
            approvedWords: project.approvedWords,
            narrativePerson: project.narrativePerson,
            narrativeTense: project.narrativeTense,
            genre: project.genre,
            subgenre: project.subgenre,
            storyPromise: project.storyPromise,
            pacingNotes: project.pacingNotes,
            avoidNotes: project.avoidNotes,
            continuityMemory: project.continuityMemory,
            relevantCharacterStyles: relevantCharacterStyles,
            allCharacterStyles: project.characterStyles
        )
    }

    private var assistantTextSize: NativeAssistantTextSize {
        NativeAssistantTextSize(rawValue: assistantTextSizeRaw) ?? .medium
    }

    private var currentChapterSceneBreakText: String? {
        guard let chapter = currentChapter else { return nil }
        let text = model.scenesInChapter(chapter.id)
            .map(\.body)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.nilIfEmpty
    }

    private var displayedAssistantSidebarWidth: CGFloat {
        CGFloat(liveAssistantWidth ?? assistantSidebarWidth)
    }

    private func applySceneBreakSuggestion(_ suggestion: NativeSceneBreakSuggestion) -> Bool {
        guard let chapter = currentChapter,
              let chapterText = currentChapterSceneBreakText,
              let drafts = resolvedSceneBreakDrafts(from: suggestion, chapterText: chapterText) else {
            return false
        }
        return model.replaceScenes(inChapter: chapter.id, with: drafts)
    }

    private func resolvedSceneBreakDrafts(from suggestion: NativeSceneBreakSuggestion, chapterText: String) -> [(title: String, body: String)]? {
        let nsText = chapterText as NSString
        let scenes = suggestion.scenes
        guard !scenes.isEmpty else { return nil }

        var boundaries: [(location: Int, title: String)] = []
        var searchLocation = 0

        for (index, scene) in scenes.enumerated() {
            let openingQuote = scene.openingQuote.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !openingQuote.isEmpty else { return nil }

            let searchRange = NSRange(location: searchLocation, length: max(0, nsText.length - searchLocation))
            let foundRange = nsText.range(of: openingQuote, options: [], range: searchRange)
            guard foundRange.location != NSNotFound else { return nil }

            if index == 0 {
                boundaries.append((0, scene.title))
            } else {
                boundaries.append((foundRange.location, scene.title))
            }
            searchLocation = foundRange.location + max(foundRange.length, 1)
        }

        let orderedBoundaries = boundaries.sorted { $0.location < $1.location }
        var drafts: [(title: String, body: String)] = []

        for (index, boundary) in orderedBoundaries.enumerated() {
            let start = boundary.location
            let end = index + 1 < orderedBoundaries.count ? orderedBoundaries[index + 1].location : nsText.length
            guard end > start else { continue }
            let body = nsText.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            drafts.append((boundary.title, body))
        }

        return drafts.isEmpty ? nil : drafts
    }

    private var podcastDrawerResizeHandle: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 14)
            .background(
                ZStack {
                    NativeTheme.panelColor

                    Rectangle()
                        .fill(isHoveringPodcastDrawerResizeHandle ? NativeTheme.accentSoftColor.opacity(0.5) : NativeTheme.borderColor.opacity(0.65))
                        .frame(width: 1)

                    VStack(spacing: 5) {
                        Circle()
                        Circle()
                        Circle()
                    }
                    .foregroundStyle(isHoveringPodcastDrawerResizeHandle ? NativeTheme.accentColor : NativeTheme.mutedColor.opacity(0.7))
                    .frame(width: 3)
                }
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHoveringPodcastDrawerResizeHandle = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        livePodcastDrawerWidth = clampedPodcastDrawerWidth(podcastPrepDrawerWidth + value.translation.width)
                    }
                    .onEnded { value in
                        podcastPrepDrawerWidth = Double(clampedPodcastDrawerWidth(podcastPrepDrawerWidth + value.translation.width))
                        livePodcastDrawerWidth = nil
                    }
            )
    }

    private var assistantSidebarResizeHandle: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 10)
            .background(
                Rectangle()
                    .fill(NativeTheme.borderColor)
                    .frame(width: 1)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        liveAssistantWidth = clampedAssistantWidth(assistantSidebarWidth - value.translation.width)
                    }
                    .onEnded { value in
                        assistantSidebarWidth = Double(clampedAssistantWidth(assistantSidebarWidth - value.translation.width))
                        liveAssistantWidth = nil
                    }
            )
    }

    private func clampedAssistantWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, 300), 680)
    }

    private func clampedPodcastDrawerWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, 320), 720)
    }

    private func relevantCharacterStyles(for text: String) -> [NativeCharacterStyleGuide] {
        let normalizedText = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !normalizedText.isEmpty else { return [] }

        return project.characterStyles.filter { character in
            let normalizedName = character.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if !normalizedName.isEmpty, normalizedText.contains(normalizedName) {
                return true
            }

            return character.approvedWords.contains { word in
                let normalizedWord = word
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                return !normalizedWord.isEmpty && normalizedText.contains(normalizedWord)
            }
        }
    }

    private func mergeStyleGuideSuggestion(_ suggestion: NativeStyleGuideSuggestion) {
        let mergedNotes = [project.styleNotes.nilIfEmpty, suggestion.styleNotes.nilIfEmpty]
            .compactMap { $0 }
            .joined(separator: "\n\n")
        let mergedWords = Array(Set(project.approvedWords + suggestion.approvedWords)).sorted()
        model.updateProjectStyleNotes(project.id, notes: mergedNotes)
        model.updateProjectApprovedWords(project.id, words: mergedWords)
    }

    private func mergeCharacterStyleSuggestion(_ suggestion: NativeCharacterStyleSuggestion) {
        let suggestedName = suggestion.characterName.nilIfEmpty ?? "Unnamed Speaker"
        let normalizedName = suggestedName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var characterStyles = project.characterStyles

        if let index = characterStyles.firstIndex(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName }) {
            let existing = characterStyles[index]
            let mergedNotes = [existing.styleNotes.nilIfEmpty, suggestion.styleNotes.nilIfEmpty]
                .compactMap { $0 }
                .joined(separator: "\n\n")
            let mergedVisualDescription = suggestion.visualDescription.nilIfEmpty ?? existing.visualDescription
            let mergedWords = Array(Set(existing.approvedWords + suggestion.approvedWords)).sorted()
            characterStyles[index] = NativeCharacterStyleGuide(
                id: existing.id,
                name: existing.name,
                styleNotes: mergedNotes,
                visualDescription: mergedVisualDescription,
                approvedWords: mergedWords
            )
        } else {
            characterStyles.append(
                NativeCharacterStyleGuide(
                    id: UUID(),
                    name: suggestedName,
                    styleNotes: suggestion.styleNotes,
                    visualDescription: suggestion.visualDescription,
                    approvedWords: suggestion.approvedWords
                )
            )
        }

        model.updateProjectCharacterStyles(project.id, characterStyles: characterStyles)

        if !suggestion.projectConsistencyNotes.isEmpty {
            let mergedProjectNotes = mergedProjectStyleNotes(
                existing: project.styleNotes,
                additionalConsistencyNotes: suggestion.projectConsistencyNotes
            )
            model.updateProjectStyleNotes(project.id, notes: mergedProjectNotes)
        }
    }

    private func mergedProjectStyleNotes(existing: String, additionalConsistencyNotes: [String]) -> String {
        let currentLines = existing
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        var mergedLines: [String] = []

        for line in currentLines + additionalConsistencyNotes {
            let normalized = line.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            mergedLines.append(line)
        }

        return mergedLines.joined(separator: "\n")
    }

    private func mergeContinuityMemorySuggestion(_ suggestion: NativeContinuityMemorySuggestion) {
        let mergedLines = [project.continuityMemory.nilIfEmpty, suggestion.summary.nilIfEmpty]
            .compactMap { $0 }
            .flatMap { text in
                text.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }

        var seen = Set<String>()
        let dedupedLines = mergedLines.filter { line in
            let key = line.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return seen.insert(key).inserted
        }

        let merged = dedupedLines.joined(separator: "\n")
        model.updateProjectContinuityMemory(project.id, summary: merged)
    }

    private var historyToolbarGroup: some View {
        Group {
            NativeEditorToolbarButton(
                title: "Undo",
                icon: "arrow.uturn.backward",
                isEnabled: formattingState.canUndo
            ) {
                NativeTextFormattingController.undo()
            }

            NativeEditorToolbarButton(
                title: "Redo",
                icon: "arrow.uturn.forward",
                isEnabled: formattingState.canRedo
            ) {
                NativeTextFormattingController.redo()
            }
        }
    }

    private var styleToolbarGroup: some View {
        Group {
            NativeEditorToolbarButton(
                title: "Bold",
                icon: "bold",
                isActive: formattingState.isBoldActive,
                isEnabled: formattingState.canFormat
            ) {
                NativeTextFormattingController.toggleBold()
            }

            NativeEditorToolbarButton(
                title: "Italic",
                icon: "italic",
                isActive: formattingState.isItalicActive,
                isEnabled: formattingState.canFormat
            ) {
                NativeTextFormattingController.toggleItalic()
            }

            NativeEditorToolbarButton(
                title: "Underline",
                icon: "underline",
                isActive: formattingState.isUnderlineActive,
                isEnabled: formattingState.canFormat
            ) {
                NativeTextFormattingController.toggleUnderline()
            }

            NativeEditorToolbarButton(
                title: "Bullet List",
                icon: "list.bullet",
                isActive: formattingState.isBulletListActive,
                isEnabled: formattingState.canFormat
            ) {
                NativeTextFormattingController.toggleBulletList()
            }
        }
    }

    private var sizeSpacingAndZoomToolbarGroup: some View {
        Group {
            NativeEditorMenu(
                title: "Size",
                icon: "textformat.size",
                selectionLabel: model.editorFontSize.label
            ) {
                ForEach(NativeEditorFontSize.allCases, id: \.self) { option in
                    Button(option.label) {
                        model.setEditorFontSize(option)
                    }
                }
            }

            NativeEditorMenu(
                title: "Spacing",
                icon: "line.3.horizontal.decrease.circle",
                selectionLabel: model.editorLineSpacing.label
            ) {
                ForEach(NativeEditorLineSpacing.allCases, id: \.self) { option in
                    Button(option.label) {
                        model.setEditorLineSpacing(option)
                    }
                }
            }

            NativeEditorMenu(
                title: "Zoom",
                icon: "plus.magnifyingglass",
                selectionLabel: model.editorZoom.label
            ) {
                ForEach(NativeEditorZoom.allCases, id: \.self) { option in
                    Button(option.label) {
                        model.setEditorZoom(option)
                    }
                }
            }

            NativeEditorToolbarButton(
                title: "Reveal Invisibles",
                icon: "paragraphsign",
                isActive: model.showInvisibleCharacters,
                isEnabled: true
            ) {
                model.setShowInvisibleCharacters(!model.showInvisibleCharacters)
            }
        }
    }

    private var colorToolbarGroup: some View {
        NativeEditorMenu(
            title: "Color",
            icon: "paintpalette",
            selectionLabel: formattingState.textColorLabel
        ) {
            ForEach(NativeEditorTextColor.allCases, id: \.self) { option in
                Button(option.label) {
                    NativeTextFormattingController.setTextColor(option.color)
                }
            }
        }
    }

    private var alignmentToolbarGroup: some View {
        Group {
            NativeEditorToolbarButton(
                title: "Align Left",
                icon: "text.alignleft",
                isActive: formattingState.alignment == .left,
                isEnabled: formattingState.canFormat
            ) {
                NativeTextFormattingController.setAlignment(.left)
            }

            NativeEditorToolbarButton(
                title: "Align Center",
                icon: "text.aligncenter",
                isActive: formattingState.alignment == .center,
                isEnabled: formattingState.canFormat
            ) {
                NativeTextFormattingController.setAlignment(.center)
            }

            NativeEditorToolbarButton(
                title: "Align Right",
                icon: "text.alignright",
                isActive: formattingState.alignment == .right,
                isEnabled: formattingState.canFormat
            ) {
                NativeTextFormattingController.setAlignment(.right)
            }

            NativeEditorToolbarButton(
                title: "Justify",
                icon: "text.justify",
                isActive: formattingState.alignment == .justified,
                isEnabled: formattingState.canFormat
            ) {
                NativeTextFormattingController.setAlignment(.justified)
            }
        }
    }

    private var selectionWordCount: Int? {
        guard formattingState.selectedWordCount > 0 else { return nil }
        return formattingState.selectedWordCount
    }

    private var editorWordCountLabel: String {
        if displayScenes.count == 1, let scene = displayScenes.first {
            return "Words: \(scene.body.split(whereSeparator: \.isWhitespace).count)"
        }
        if !displayScenes.isEmpty {
            let wordCount = displayScenes.reduce(0) { partialResult, scene in
                partialResult + scene.body.split(whereSeparator: \.isWhitespace).count
            }
            return "Words: \(wordCount)"
        }
        return "Words: 0"
    }

    private func createAssistantScene(from replyText: String) -> Bool {
        let trimmedReply = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReply.isEmpty else { return false }

        if let currentScene {
            return model.createAssistantScene(after: currentScene.id, body: trimmedReply) != nil
        }

        if let currentChapter {
            return model.createAssistantScene(in: currentChapter.id, body: trimmedReply) != nil
        }

        return false
    }

    private func requestEditorFocusForCurrentSelection() {
        guard model.selectedChapterIDs.isEmpty,
              model.selectedSceneIDs.count == 1,
              let sceneID = model.selectedSceneID else { return }
        let anchorLocation = model.lastEditedLocationBySceneID[sceneID] ?? 0
        NativeTextFormattingController.focusOrQueue(
            sceneID: sceneID,
            range: NSRange(location: anchorLocation, length: 0)
        )
    }
}

struct NativeAssistantDrawerHandle: View {
    enum Direction {
        case left
        case right

        var systemImage: String {
            switch self {
            case .left: return "chevron.left"
            case .right: return "chevron.right"
            }
        }
    }

    enum AttachmentEdge {
        case left
        case right
    }

    let direction: Direction
    var attachmentEdge: AttachmentEdge? = nil
    var fullHeight = false
    var helpText = "Toggle Drawer"
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: direction.systemImage)
                .font(NativeTheme.interfaceFont(size: 15, weight: .bold))
                .foregroundStyle(isHovering ? Color(nsColor: NativeTheme.primaryButtonText) : NativeTheme.ink3Color)
                .frame(width: fullHeight ? 28 : 24, height: fullHeight ? nil : 68)
                .frame(maxHeight: fullHeight ? .infinity : nil)
                .background(isHovering ? NativeTheme.accentColor : NativeTheme.panelSoftColor, in: handleShape)
                .overlay(
                    handleShape
                        .stroke(isHovering ? NativeTheme.accentSoftColor : NativeTheme.borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .frame(maxHeight: fullHeight ? .infinity : nil)
        .onHover { hovering in
            isHovering = hovering
        }
        .help(helpText)
    }

    private var handleShape: NativeDrawerHandleShape {
        NativeDrawerHandleShape(attachmentEdge: attachmentEdge)
    }
}

struct NativeDrawerHandleShape: Shape {
    let attachmentEdge: NativeAssistantDrawerHandle.AttachmentEdge?

    func path(in rect: CGRect) -> Path {
        switch attachmentEdge {
        case .left:
            return UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 0,
                    bottomLeading: 0,
                    bottomTrailing: 12,
                    topTrailing: 12
                ),
                style: .continuous
            )
            .path(in: rect)
        case .right:
            return UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 12,
                    bottomLeading: 12,
                    bottomTrailing: 0,
                    topTrailing: 0
                ),
                style: .continuous
            )
            .path(in: rect)
        case .none:
            return RoundedRectangle(cornerRadius: 12, style: .continuous)
                .path(in: rect)
        }
    }
}

struct NativeStatusFooterBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(NativeTheme.paper2Color)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NativeTheme.borderColor)
                .frame(height: 1)
        }
    }
}

struct NativeBinderFooterFindReplaceView: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    @ObservedObject var store: NativeFindReplaceStore
    @State private var isMarkerHelpPresented = false
    @State private var findFieldHeight: CGFloat = 42
    @State private var replaceFieldHeight: CGFloat = 42

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.isPresented {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        Text("Find / Replace")
                            .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                            .foregroundStyle(NativeTheme.mutedColor)
                        Button {
                            isMarkerHelpPresented.toggle()
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                                .foregroundStyle(NativeTheme.mutedColor)
                        }
                        .buttonStyle(.plain)
                        .help("Show search markers")
                        .popover(isPresented: $isMarkerHelpPresented, arrowEdge: .top) {
                            NativeFindReplaceMarkerHelpView()
                        }
                        Spacer()
                        Button("Close") {
                            store.close()
                        }
                        .buttonStyle(.borderless)
                    }

                    NativeGrowingPlainTextInput(
                        text: $store.query,
                        measuredHeight: $findFieldHeight,
                        placeholder: "Find",
                        showInvisibleCharacters: model.showInvisibleCharacters,
                        focusRequestToken: store.queryFocusToken
                    )
                    .frame(height: findFieldHeight)

                    NativeGrowingPlainTextInput(
                        text: $store.replacement,
                        measuredHeight: $replaceFieldHeight,
                        placeholder: "Replace",
                        showInvisibleCharacters: model.showInvisibleCharacters
                    )
                    .frame(height: replaceFieldHeight)

                    HStack(spacing: 12) {
                        Picker("Scope", selection: $store.scope) {
                            ForEach(NativeFindScope.allCases) { scope in
                                Text(scope.label).tag(scope)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Mode", selection: $store.mode) {
                            ForEach(NativeFindMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Toggle("Match Case", isOn: $store.isMatchCaseEnabled)
                        .toggleStyle(.checkbox)
                        .font(.caption)

                    HStack(spacing: 10) {
                        Button("Prev") {
                            store.goToPrevious()
                            store.focusCurrentMatch(model: model)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(store.totalFound == 0)

                        Button("Next") {
                            store.goToNext()
                            store.focusCurrentMatch(model: model)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(store.totalFound == 0)
                    }

                    HStack(spacing: 10) {
                        Button("Replace") {
                            if store.replaceCurrent(using: store.replacement) != nil {
                                store.refresh(
                                    model: model,
                                    projectID: project.id,
                                    visibleScenes: model.displayScenes(for: project.id),
                                    selectionContext: NativeTextFormattingController.currentFindSelectionContext()
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(store.currentMatch == nil)

                        Button("Replace + Next") {
                            if store.replaceCurrentAndMoveNext(using: store.replacement) {
                                store.refresh(
                                    model: model,
                                    projectID: project.id,
                                    visibleScenes: model.displayScenes(for: project.id),
                                    selectionContext: NativeTextFormattingController.currentFindSelectionContext()
                                )
                                store.focusCurrentMatch(model: model)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(store.currentMatch == nil)

                        Button("Replace All") {
                            let replacedMatches = store.replaceAllVisible(using: store.replacement)
                            guard !replacedMatches.isEmpty else { return }
                            store.refresh(
                                model: model,
                                projectID: project.id,
                                visibleScenes: model.displayScenes(for: project.id),
                                selectionContext: NativeTextFormattingController.currentFindSelectionContext()
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(store.totalFound == 0)
                    }

                    HStack(spacing: 8) {
                        Text("Found: \(store.totalFound)")
                        Text("|")
                        Text("Current: \(store.currentMatchNumber)")
                        Text("|")
                        Text("Replaced: \(store.totalReplaced)")
                        Spacer()
                    }
                    .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                    .foregroundStyle(NativeTheme.mutedColor)

                    if let status = store.status {
                        Text(status)
                            .font(NativeTheme.interfaceFont(size: 12))
                            .foregroundStyle(NativeTheme.mutedColor)
                            .lineLimit(2)
                    }
                }
                .padding(12)
                .background(NativeTheme.panelSoftColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Button {
                    store.open(initialQuery: NativeTextFormattingController.currentSelectedText())
                    store.refresh(
                        model: model,
                        projectID: project.id,
                        visibleScenes: model.displayScenes(for: project.id),
                        selectionContext: NativeTextFormattingController.currentFindSelectionContext()
                    )
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                        Text("Find / Replace")
                            .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                            .foregroundStyle(NativeTheme.mutedColor)
                        Spacer()
                        Text("Cmd+F")
                            .font(NativeTheme.interfaceFont(size: 12))
                            .foregroundStyle(NativeTheme.mutedColor)
                        Image(systemName: "chevron.up")
                            .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                            .foregroundStyle(NativeTheme.mutedColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(NativeTheme.panelSoftColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NativeGrowingPlainTextInput: NSViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat
    let placeholder: String
    let showInvisibleCharacters: Bool
    var focusRequestToken: Int = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, measuredHeight: $measuredHeight, placeholder: placeholder)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NativeInvisibleAwareInputTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont(name: "Avenir Next", size: 15) ?? .systemFont(ofSize: 15)
        textView.textColor = NativeTheme.ink1
        textView.insertionPointColor = NativeTheme.accent
        textView.placeholder = placeholder
        textView.showInvisibleCharacters = showInvisibleCharacters
        textView.textContainerInset = NSSize(width: 0, height: 6)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 8
        scrollView.layer?.backgroundColor = NativeTheme.paper1.withAlphaComponent(0.96).cgColor
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.borderColor = NativeTheme.border.withAlphaComponent(0.9).cgColor

        context.coordinator.recalculateHeight(for: textView, scrollView: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NativeInvisibleAwareInputTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.showInvisibleCharacters = showInvisibleCharacters
        if context.coordinator.lastFocusRequestToken != focusRequestToken {
            context.coordinator.lastFocusRequestToken = focusRequestToken
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                let endLocation = textView.string.utf16.count
                textView.setSelectedRange(NSRange(location: endLocation, length: 0))
            }
        }
        context.coordinator.recalculateHeight(for: textView, scrollView: scrollView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var measuredHeight: CGFloat
        let placeholder: String
        private let minHeight: CGFloat = 42
        private let maxHeight: CGFloat = 140
        var lastFocusRequestToken: Int = 0

        init(text: Binding<String>, measuredHeight: Binding<CGFloat>, placeholder: String) {
            _text = text
            _measuredHeight = measuredHeight
            self.placeholder = placeholder
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let scrollView = textView.enclosingScrollView else { return }
            text = textView.string
            recalculateHeight(for: textView, scrollView: scrollView)
        }

        func recalculateHeight(for textView: NSTextView, scrollView: NSScrollView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let contentHeight = ceil(usedRect.height + (textView.textContainerInset.height * 2) + 12)
            let clampedHeight = min(max(minHeight, contentHeight), maxHeight)
            scrollView.hasVerticalScroller = contentHeight > maxHeight
            if abs(measuredHeight - clampedHeight) > 1 {
                DispatchQueue.main.async {
                    self.measuredHeight = clampedHeight
                }
            }
        }
    }
}

final class NativeInvisibleAwareInputTextView: NSTextView {
    var placeholder = ""
    var showInvisibleCharacters = false {
        didSet {
            guard oldValue != showInvisibleCharacters else { return }
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawPlaceholderIfNeeded()
        drawInvisibleCharacters(in: dirtyRect)
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            insertNewline(nil)
            return
        }
        super.keyDown(with: event)
    }

    private func drawPlaceholderIfNeeded() {
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 15),
            .foregroundColor: NativeTheme.muted.withAlphaComponent(0.9)
        ]
        let point = CGPoint(x: textContainerInset.width + 2, y: textContainerInset.height + 1)
        (placeholder as NSString).draw(at: point, withAttributes: attributes)
    }

    private func drawInvisibleCharacters(in dirtyRect: NSRect) {
        guard showInvisibleCharacters else { return }
        guard let layoutManager, let textContainer else { return }

        let textNSString = string as NSString
        guard textNSString.length > 0 else { return }

        layoutManager.ensureLayout(for: textContainer)
        let markerFont = NSFont.systemFont(ofSize: max(10, (font?.pointSize ?? 15) * 0.62), weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: markerFont,
            .foregroundColor: NativeTheme.accent.withAlphaComponent(0.88)
        ]

        for index in 0..<textNSString.length {
            let character = textNSString.character(at: index)
            let symbol: String

            switch character {
            case 32:
                symbol = "·"
            case 9:
                symbol = "⇥"
            case 10, 13:
                symbol = "¶"
            default:
                continue
            }

            guard let markerPoint = markerPoint(forCharacterAt: index, symbol: symbol, attributes: attributes) else {
                continue
            }

            let markerSize = (symbol as NSString).size(withAttributes: attributes)
            let markerRect = NSRect(origin: markerPoint, size: markerSize)
            guard markerRect.intersects(dirtyRect.insetBy(dx: -20, dy: -20)) else { continue }
            (symbol as NSString).draw(at: markerPoint, withAttributes: attributes)
        }
    }

    private func markerPoint(
        forCharacterAt characterIndex: Int,
        symbol: String,
        attributes: [NSAttributedString.Key: Any]
    ) -> CGPoint? {
        guard let layoutManager, let textContainer else { return nil }

        let stringLength = string.utf16.count
        guard stringLength > 0, characterIndex >= 0, characterIndex < stringLength else { return nil }

        let markerSize = (symbol as NSString).size(withAttributes: attributes)
        let textOrigin = textContainerOrigin

        if let scalar = UnicodeScalar(Int((string as NSString).character(at: characterIndex))),
           CharacterSet.newlines.contains(scalar) {
            var precedingNewlineCount = 0
            var anchorIndex = characterIndex - 1
            while anchorIndex >= 0,
                  let precedingScalar = UnicodeScalar(Int((string as NSString).character(at: anchorIndex))),
                  CharacterSet.newlines.contains(precedingScalar) {
                precedingNewlineCount += 1
                anchorIndex -= 1
            }

            let resolvedAnchorIndex = max(0, min(anchorIndex, stringLength - 1))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: resolvedAnchorIndex)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let usedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let x = textOrigin.x + (characterIndex == 0 || precedingNewlineCount > 0 ? lineRect.minX + 2 : max(lineRect.minX + 2, usedRect.maxX + 2))
            let y = textOrigin.y + lineRect.midY - (markerSize.height / 2) + (CGFloat(precedingNewlineCount) * lineRect.height)
            return CGPoint(x: x, y: y)
        }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: characterIndex, length: 1), actualCharacterRange: nil)
        var glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        if glyphRect.isEmpty {
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
            glyphRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        }

        let x = textOrigin.x + glyphRect.midX - (markerSize.width / 2)
        let y = textOrigin.y + glyphRect.midY - (markerSize.height / 2)
        return CGPoint(x: x, y: y)
    }
}

struct NativeFindReplaceMarkerHelpView: View {
    private let rows: [(String, String)] = [
        ("^p", "Paragraph break / new line"),
        ("\\n", "Paragraph break / new line"),
        ("^p^p", "Double paragraph break"),
        ("^t", "Tab"),
        ("\\t", "Tab"),
        ("\\\\", "Backslash"),
        ("--", "Two hyphens"),
        ("—", "Em dash"),
        ("  ", "Two spaces"),
        ("Punctuation", "Characters like ! @ # $ % ^ & * ( ) { } [ ] - = are searched literally")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find / Replace Markers")
                .font(NativeTheme.interfaceFont(size: 13, weight: .semibold))
                .foregroundStyle(NativeTheme.ink1Color)

            ForEach(rows, id: \.0) { row in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(row.0)
                        .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                        .foregroundStyle(NativeTheme.accentColor)
                        .frame(width: 72, alignment: .leading)
                    Text(row.1)
                        .font(NativeTheme.interfaceFont(size: 12))
                        .foregroundStyle(NativeTheme.mutedColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Examples: find ^p^p and replace with ^p to turn double paragraph breaks into single ones, or find -- and replace with — to clean up em dashes.")
                .font(NativeTheme.interfaceFont(size: 11))
                .foregroundStyle(NativeTheme.mutedColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 330, alignment: .leading)
        .background(NativeTheme.panelSoftColor)
    }
}

struct SingleSceneEditorView: View {
    @ObservedObject var model: NativeAppModel
    let scene: NativeScene

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                EditableSceneHeaderField(model: model, scene: scene)
                Text("Single-scene editor")
                    .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                    .foregroundStyle(NativeTheme.mutedColor)
            }
            .padding(.horizontal, 6)

            NativeEditorCard {
                EditableSceneBodyView(
                    model: model,
                    sceneID: scene.id,
                    fontSize: model.editorFontSize.pointSize * model.editorZoom.scale,
                    lineSpacing: model.editorLineSpacing.spacing * model.editorZoom.scale,
                    showInvisibleCharacters: model.showInvisibleCharacters,
                    minimumHeight: 260
                )
            }
        }
    }
}

struct CompositeChapterEditorView: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    let chapter: NativeChapter?
    let projectID: UUID
    let isPodcastDrawerVisible: Bool
    let togglePodcastDrawer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let chapter {
                HStack(alignment: .center, spacing: 12) {
                    EditableChapterHeaderField(model: model, project: project, chapter: chapter)
                    if project.isPodcastProject {
                        Button(action: togglePodcastDrawer) {
                            HStack(spacing: 6) {
                                Image(systemName: "mic.fill")
                                Image(systemName: isPodcastDrawerVisible ? "chevron.right" : "chevron.left")
                                    .font(NativeTheme.interfaceFont(size: 11, weight: .bold))
                            }
                            .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                            .foregroundStyle(NativeTheme.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(NativeTheme.panelSoftColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help(isPodcastDrawerVisible ? "Hide episode prep drawer" : "Show episode prep drawer")
                    }
                    Spacer()
                }
            } else {
                Text("Combined Selection")
                    .font(NativeTheme.displayFont(size: 26, weight: .semibold))
                    .foregroundStyle(NativeTheme.ink1Color)
            }
            Text(project.isPodcastProject ? "Composite episode view" : "Composite chapter view")
                .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                .foregroundStyle(NativeTheme.mutedColor)

            if chapter == nil, model.displayScenes(for: projectID).count > 1 {
                MultiSelectionContinuousEditorView(
                    model: model,
                    project: project,
                    scenes: model.displayScenes(for: projectID)
                )
            } else {
                NativeEditorCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(model.displayScenes(for: projectID).enumerated()), id: \.element.id) { index, scene in
                            VStack(alignment: .leading, spacing: 14) {
                                Text(compositeSceneLabel(for: scene))
                                    .font(NativeTheme.displayFont(size: 19, weight: .semibold))
                                    .foregroundStyle(NativeTheme.accentColor)
                                EditableSceneBodyView(
                                    model: model,
                                    sceneID: scene.id,
                                    fontSize: model.editorFontSize.pointSize * model.editorZoom.scale,
                                    lineSpacing: model.editorLineSpacing.spacing * model.editorZoom.scale,
                                    showInvisibleCharacters: model.showInvisibleCharacters,
                                    minimumHeight: 72
                                )
                            }
                            .padding(.vertical, 8)

                            if index < model.displayScenes(for: projectID).count - 1 {
                                Divider()
                                    .overlay(NativeTheme.borderColor)
                                    .padding(.vertical, 14)
                            }
                        }
                    }
                }
            }
        }
    }

    private func compositeSceneLabel(for scene: NativeScene) -> String {
        let chapterTitle = model.chapters.first(where: { $0.id == scene.chapterID })?.title ?? "Unknown Chapter"
        return "\(displayedChapterTitle(chapterTitle, for: project)) / \(scene.title)"
    }
}

struct NativeEditorEmptyStateView: View {
    var body: some View {
        NativeEditorCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nothing selected yet")
                    .font(NativeTheme.displayFont(size: 22, weight: .semibold))
                    .foregroundStyle(NativeTheme.ink1Color)
                Text("Choose a chapter to open its scenes in composite view, or choose a single scene to focus on one writing block.")
                    .foregroundStyle(NativeTheme.mutedColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
        }
    }
}

struct MultiSelectionContinuousEditorView: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    let scenes: [NativeScene]
    @State private var contentHeight: CGFloat = 280

    var body: some View {
        NativeEditorCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Continuous Multi-Scene Editor")
                        .font(NativeTheme.displayFont(size: 20, weight: .semibold))
                        .foregroundStyle(NativeTheme.accentColor)
                    Text("Selected scenes edit as one flowing block here. Scene labels stay outside the text so selection and cursor movement can pass straight through.")
                        .font(NativeTheme.interfaceFont(size: 12))
                        .foregroundStyle(NativeTheme.mutedColor)
                        .fixedSize(horizontal: false, vertical: true)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(scenes) { scene in
                                Text(sceneChipLabel(for: scene))
                                    .font(NativeTheme.interfaceFont(size: 11, weight: .semibold))
                                    .foregroundStyle(NativeTheme.ink1Color)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(NativeTheme.panelSoftColor)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                ContinuousSelectionTextEditor(
                    scenes: scenes,
                    fontSize: model.editorFontSize.pointSize * model.editorZoom.scale,
                    lineSpacing: model.editorLineSpacing.spacing * model.editorZoom.scale,
                    showInvisibleCharacters: model.showInvisibleCharacters,
                    measuredHeight: $contentHeight,
                    onSceneBodiesChanged: { updates in
                        model.updateSceneBodies(updates)
                    }
                )
                .frame(minHeight: max(220, contentHeight))
            }
            .padding(.vertical, 8)
        }
    }

    private func sceneChipLabel(for scene: NativeScene) -> String {
        let chapterTitle = model.chapters.first(where: { $0.id == scene.chapterID })?.title ?? "Chapter"
        return "\(displayedChapterTitle(chapterTitle, for: project)) / \(scene.title)"
    }
}

struct NativeAssistantSidebarView: View {
    @ObservedObject var store: NativeAssistantStore
    @ObservedObject var apiKeyStore: NativeAPIKeyStore
    let context: NativeAssistantContext
    let textSize: NativeAssistantTextSize
    let reviewScenes: [NativeScene]
    let currentChapterTitle: String?
    let currentChapterText: String?
    let canCreateSceneFromReply: Bool
    let createSceneFromReply: (String) -> Bool
    let addStyleGuideSuggestion: (NativeStyleGuideSuggestion) -> Void
    let addCharacterStyleSuggestion: (NativeCharacterStyleSuggestion) -> Void
    let addContinuityMemorySuggestion: (NativeContinuityMemorySuggestion) -> Void
    let applySceneBreakSuggestion: (NativeSceneBreakSuggestion) -> Bool
    let jumpToReviewIssue: (NativeAssistantReviewIssue) -> Void
    let applyReviewIssue: (NativeAssistantReviewIssue) -> Bool
    let clearReviewIssues: () -> Void
    @StateObject private var formattingState = NativeFormattingToolbarState.shared
    @State private var shouldShowJumpToBottom = false
    @State private var isShowingAPIKeyField = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Assistant")
                        .font(NativeTheme.displayFont(size: 20 * textSize.scale, weight: .semibold))
                        .foregroundStyle(NativeTheme.ink1Color)
                    Spacer()
                    Button("Clear") {
                        store.clearConversation()
                        clearReviewIssues()
                    }
                    .buttonStyle(.borderless)
                }

                assistantContextSummary

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.easeOut(duration: 0.16)) {
                                isShowingAPIKeyField.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isShowingAPIKeyField ? "key.fill" : "key")
                                Text(isShowingAPIKeyField ? "Hide API Key" : "API Key")
                            }
                            .font(NativeTheme.interfaceFont(size: 12, weight: .medium))
                            .foregroundStyle(NativeTheme.ink1Color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(NativeTheme.panelSoftColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Toggle("Remember on this Mac", isOn: $apiKeyStore.rememberOnThisMac)
                            .toggleStyle(.checkbox)
                            .font(textSize.font(size: 12))
                            .foregroundStyle(NativeTheme.mutedColor)

                        Spacer()
                    }

                    if isShowingAPIKeyField {
                        SecureField("OpenAI API Key", text: $apiKeyStore.apiKey)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                apiKeyStore.persistIfNeeded()
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                quickActions
            }
            .padding(16)
            .background(NativeTheme.panelColor)

            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if !store.reviewIssues.isEmpty {
                                NativeAssistantReviewPanel(
                                    context: context,
                                    textSize: textSize,
                                    issues: store.reviewIssues,
                                    activeIssueID: store.activeReviewIssueID,
                                    selectIssue: { issue in
                                        store.activeReviewIssueID = issue.id
                                        jumpToReviewIssue(issue)
                                    },
                                    applyIssue: { issue in
                                        if applyReviewIssue(issue) {
                                            _ = store.applyReviewIssue(issue.id)
                                            if store.reviewIssues.isEmpty {
                                                clearReviewIssues()
                                            }
                                        } else {
                                            store.addStatus("Couldn’t apply that suggested change automatically.")
                                        }
                                    },
                                    dismissIssue: { issue in
                                        store.dismissReviewIssue(issue.id)
                                        if store.reviewIssues.isEmpty {
                                            clearReviewIssues()
                                        }
                                    },
                                    approveAllSafe: approveAllSafeIssues,
                                    clearIssues: {
                                        store.clearReviewIssues()
                                        clearReviewIssues()
                                    }
                                )
                            }

                            ForEach(store.messages) { message in
                                NativeAssistantMessageBubble(
                                    textSize: textSize,
                                    message: message,
                                    canReplaceSelection: formattingState.canFormat && formattingState.hasExpandedSelection,
                                    canInsertIntoEditor: formattingState.canFormat,
                                    canCreateScene: canCreateSceneFromReply,
                                    replaceSelection: {
                                        applyAssistantReply(message.text, mode: .replaceSelection)
                                    },
                                    insertBelow: {
                                        applyAssistantReply(message.text, mode: .insertBelow)
                                    },
                                    appendToEnd: {
                                        applyAssistantReply(message.text, mode: .appendToEnd)
                                    },
                                    createNewScene: {
                                        applyAssistantReply(message.text, mode: .newScene)
                                    },
                                    copyReply: {
                                        if NativeTextFormattingController.copyToPasteboard(message.text) {
                                            store.addStatus("Assistant reply copied.")
                                        } else {
                                            store.addStatus("Couldn't copy the assistant reply.")
                                        }
                                    }
                                )
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("assistant-bottom")
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onAppear {
                        shouldShowJumpToBottom = store.messages.count > 1
                        scrollAssistantToBottom(using: proxy, animated: false)
                    }
                    .onChange(of: store.messages) { _, _ in
                        shouldShowJumpToBottom = store.messages.count > 1
                        scrollAssistantToBottom(using: proxy, animated: true)
                    }
                    .onChange(of: store.activeReviewIssueID) { _, activeIssueID in
                        guard let activeIssueID else { return }
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo(activeIssueID, anchor: .center)
                        }
                    }
                    .onChange(of: store.isSending) { _, isSending in
                        if isSending {
                            scrollAssistantToBottom(using: proxy, animated: true)
                        }
                    }

                    if shouldShowJumpToBottom {
                        Button {
                            scrollAssistantToBottom(using: proxy, animated: true)
                        } label: {
                            Image(systemName: "arrow.down")
                                .font(NativeTheme.interfaceFont(size: 14, weight: .bold))
                                .foregroundStyle(Color(nsColor: NativeTheme.primaryButtonText))
                                .frame(width: 34, height: 34)
                                .background(NativeTheme.accentColor)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(NativeTheme.accentSoftColor.opacity(0.5), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 14)
                        .padding(.bottom, 12)
                        .help("Jump to latest reply")
                    }
                }
            }

            if !store.reviewIssues.isEmpty {
                assistantReviewActionBar
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(NativeTheme.paper2Color)
            }

            if let suggestion = store.pendingStyleGuideSuggestion {
                assistantStyleGuideActionBar(for: suggestion)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(NativeTheme.paper2Color)
            }

            if let suggestion = store.pendingCharacterStyleSuggestion {
                assistantCharacterStyleActionBar(for: suggestion)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(NativeTheme.paper2Color)
            }

            if let suggestion = store.pendingContinuityMemorySuggestion {
                assistantContinuityMemoryActionBar(for: suggestion)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(NativeTheme.paper2Color)
            }

            if let suggestion = store.pendingSceneBreakSuggestion {
                assistantSceneBreakActionBar(for: suggestion)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(NativeTheme.paper2Color)
            }

            if let lastError = store.lastError {
                Text(lastError)
                    .font(NativeTheme.interfaceFont(size: 12))
                    .foregroundStyle(Color(nsColor: NativeTheme.accentStrong))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Message")
                            .font(textSize.font(size: 11, weight: .semibold))
                            .foregroundStyle(NativeTheme.accentColor)
                        Spacer()
                        Text("Enter sends • Shift+Enter newline")
                            .font(textSize.font(size: 10))
                            .foregroundStyle(NativeTheme.mutedColor)
                            .lineLimit(1)
                    }

                    ZStack(alignment: .topLeading) {
                        AssistantPromptInput(text: $store.draft, textSize: textSize) {
                            apiKeyStore.persistIfNeeded()
                            store.send(apiKey: apiKeyStore.apiKey, context: context)
                        }
                        .frame(minHeight: 76, maxHeight: 102)

                        if store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Ask the assistant to review, rewrite, summarize, or help with the current scene.")
                                .font(textSize.font(size: 13))
                                .foregroundStyle(NativeTheme.mutedColor.opacity(0.9))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(12)
                .background(NativeTheme.panelColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(NativeTheme.accentColor.opacity(0.55), lineWidth: 1.5)
                )

                HStack(alignment: .center, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(assistantModelDisplayName(for: store.lastUsedModel))
                            .font(textSize.font(size: 11, weight: .semibold))
                            .foregroundStyle(store.lastUsedModel == openAIDeepReviewModel ? NativeTheme.accentColor : NativeTheme.mutedColor)
                        if store.isSending {
                            Text("in use")
                                .font(textSize.font(size: 10, weight: .semibold))
                                .foregroundStyle(Color(nsColor: NativeTheme.primaryButtonText))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(store.lastUsedModel == openAIDeepReviewModel ? NativeTheme.accentColor : NativeTheme.panelColor)
                                .clipShape(Capsule())
                        }
                        Picker("Assistant Text", selection: Binding(
                            get: { textSize },
                            set: { newValue in
                                UserDefaults.standard.set(newValue.rawValue, forKey: "assistantTextSize")
                            }
                        )) {
                            ForEach(NativeAssistantTextSize.allCases, id: \.rawValue) { size in
                                Text(size.label).tag(size)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    Spacer()

                    Button(store.isSending ? "Thinking..." : "Send") {
                        apiKeyStore.persistIfNeeded()
                        store.send(apiKey: apiKeyStore.apiKey, context: context)
                    }
                    .buttonStyle(NativeProminentButtonStyle())
                    .disabled(store.isSending)
                }
            }
            .padding(16)
            .background(NativeTheme.panelSoftColor)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(NativeTheme.borderColor.opacity(0.9))
                    .frame(height: 1)
            }
        }
        .background(NativeTheme.paper2Color)
    }

    private var activeReviewIssue: NativeAssistantReviewIssue? {
        guard let activeIssueID = store.activeReviewIssueID else { return store.reviewIssues.first }
        return store.reviewIssues.first(where: { $0.id == activeIssueID }) ?? store.reviewIssues.first
    }

    private var assistantReviewActionBar: some View {
        let activeIssue = activeReviewIssue
        let canJump = activeIssue != nil && !(activeIssue?.isStale ?? true)
        let canApply = activeIssue?.replacement != nil && !(activeIssue?.isStale ?? true)
        let canApproveAllSafe = store.reviewIssues.contains(where: { $0.replacement != nil && !$0.isStale })
        let applyTitle = activeIssue?.replacement == "" ? "Delete" : "Apply"

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Review Actions")
                    .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                    .foregroundStyle(NativeTheme.mutedColor)
                Spacer()
                if let activeIssue {
                    Text(activeIssue.sceneTitle)
                        .font(NativeTheme.interfaceFont(size: 11))
                        .foregroundStyle(NativeTheme.mutedColor)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                assistantActionBarButton("Jump", isEnabled: canJump) {
                    if let activeIssue {
                        store.activeReviewIssueID = activeIssue.id
                        jumpToReviewIssue(activeIssue)
                    }
                }
                assistantActionBarButton(applyTitle, isEnabled: canApply) {
                    guard let activeIssue else { return }
                    if applyReviewIssue(activeIssue) {
                        _ = store.applyReviewIssue(activeIssue.id)
                        if store.reviewIssues.isEmpty {
                            clearReviewIssues()
                        }
                    } else {
                        store.addStatus("Couldn’t apply that suggested change automatically.")
                    }
                }
                assistantActionBarButton("Decline", isEnabled: activeIssue != nil) {
                    guard let activeIssue else { return }
                    store.dismissReviewIssue(activeIssue.id)
                    if store.reviewIssues.isEmpty {
                        clearReviewIssues()
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                assistantActionBarButton("Approve All Safe", isEnabled: canApproveAllSafe, isProminent: canApproveAllSafe) {
                    approveAllSafeIssues()
                }
                assistantActionBarButton("Clear Review", isEnabled: true) {
                    store.clearReviewIssues()
                    clearReviewIssues()
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(NativeTheme.panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NativeTheme.borderColor, lineWidth: 1)
        )
    }

    private func assistantActionBarButton(_ title: String, isEnabled: Bool, isProminent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderless)
            .font(NativeTheme.interfaceFont(size: 12, weight: .medium))
            .foregroundStyle(
                isEnabled
                    ? (isProminent ? Color(nsColor: NativeTheme.primaryButtonText) : NativeTheme.ink1Color)
                    : NativeTheme.mutedColor.opacity(0.7)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isEnabled
                    ? (isProminent ? AnyShapeStyle(NativeTheme.accentColor) : AnyShapeStyle(NativeTheme.paper1Color))
                    : AnyShapeStyle(NativeTheme.panelSoftColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .disabled(!isEnabled)
    }

    private func approveAllSafeIssues() {
        var appliedCount = 0
        while let safeIssue = store.reviewIssues.first(where: { $0.replacement != nil && !$0.isStale }) {
            guard applyReviewIssue(safeIssue) else {
                store.addStatus("Couldn’t apply one of the queued suggestions automatically.")
                break
            }
            _ = store.applyReviewIssue(safeIssue.id)
            appliedCount += 1
        }
        if store.reviewIssues.isEmpty {
            clearReviewIssues()
        }
        if appliedCount > 0 {
            store.addStatus("Applied \(appliedCount) assistant suggestion" + (appliedCount == 1 ? "." : "s."))
        }
    }

    private func assistantStyleGuideActionBar(for suggestion: NativeStyleGuideSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Style Guide Draft")
                .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                .foregroundStyle(NativeTheme.mutedColor)

            HStack(spacing: 8) {
                assistantActionBarButton("Add to Style Guide", isEnabled: true, isProminent: true) {
                    addStyleGuideSuggestion(suggestion)
                    store.addStatus("Added the assistant’s style guide draft to this project.")
                    store.clearPendingStyleGuideSuggestion()
                }
                assistantActionBarButton("Dismiss", isEnabled: true) {
                    store.clearPendingStyleGuideSuggestion()
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(NativeTheme.panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NativeTheme.borderColor, lineWidth: 1)
        )
    }

    private func assistantCharacterStyleActionBar(for suggestion: NativeCharacterStyleSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Character Draft: \(suggestion.characterName.nilIfEmpty ?? "Unnamed Speaker")")
                .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                .foregroundStyle(NativeTheme.mutedColor)

            if !suggestion.projectConsistencyNotes.isEmpty {
                Text("Includes \(suggestion.projectConsistencyNotes.count) project-wide consistency note" + (suggestion.projectConsistencyNotes.count == 1 ? "" : "s") + " for the novel style guide.")
                    .font(textSize.font(size: 11, weight: .medium))
                    .foregroundStyle(NativeTheme.mutedColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                assistantActionBarButton("Add to Character Guide", isEnabled: true, isProminent: true) {
                    addCharacterStyleSuggestion(suggestion)
                    store.addStatus("Added the assistant’s character voice draft to this project.")
                    store.clearPendingCharacterStyleSuggestion()
                }
                assistantActionBarButton("Dismiss", isEnabled: true) {
                    store.clearPendingCharacterStyleSuggestion()
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(NativeTheme.panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NativeTheme.borderColor, lineWidth: 1)
        )
    }

    private func assistantContinuityMemoryActionBar(for suggestion: NativeContinuityMemorySuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Continuity Memory Draft")
                .font(textSize.font(size: 12, weight: .semibold))
                .foregroundStyle(NativeTheme.mutedColor)

            HStack(spacing: 8) {
                assistantActionBarButton("Add to Project Memory", isEnabled: true, isProminent: true) {
                    addContinuityMemorySuggestion(suggestion)
                    store.addStatus("Added the assistant’s continuity memory update to this project.")
                    store.clearPendingContinuityMemorySuggestion()
                }
                assistantActionBarButton("Dismiss", isEnabled: true) {
                    store.clearPendingContinuityMemorySuggestion()
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(NativeTheme.panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NativeTheme.borderColor, lineWidth: 1)
        )
    }

    private func assistantSceneBreakActionBar(for suggestion: NativeSceneBreakSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scene Break Draft: \(suggestion.chapterTitle)")
                .font(textSize.font(size: 12, weight: .semibold))
                .foregroundStyle(NativeTheme.mutedColor)

            HStack(spacing: 8) {
                assistantActionBarButton("Apply Scene Breaks", isEnabled: true, isProminent: true) {
                    if applySceneBreakSuggestion(suggestion) {
                        store.addStatus("Applied assistant scene breaks to \(suggestion.chapterTitle).")
                        store.clearPendingSceneBreakSuggestion()
                    } else {
                        store.addStatus("Couldn’t map those proposed scene breaks cleanly onto the chapter text.")
                    }
                }
                assistantActionBarButton("Dismiss", isEnabled: true) {
                    store.clearPendingSceneBreakSuggestion()
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(NativeTheme.panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NativeTheme.borderColor, lineWidth: 1)
        )
    }

    private func scrollAssistantToBottom(using proxy: ScrollViewProxy, animated: Bool) {
        let action = {
            proxy.scrollTo("assistant-bottom", anchor: .bottom)
            shouldShowJumpToBottom = false
        }
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                action()
            }
        } else {
            action()
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                .foregroundStyle(NativeTheme.mutedColor)

            HStack(spacing: 8) {
                quickActionButton("Comment") {
                    store.fillPrompt("Comment on the currently selected text. Flag pacing, repetition, clarity, and line-level improvements.")
                }
                quickActionButton("Rewrite") {
                    store.fillPrompt("Rewrite the selected text for clarity, flow, and stronger prose while preserving voice and intent.")
                }
                quickActionButton("Review Scene") {
                    apiKeyStore.persistIfNeeded()
                    store.reviewCurrentScope(apiKey: apiKeyStore.apiKey, context: context, scenes: reviewScenes)
                }
                assistantToolsMenu
                assistantDraftsMenu
                Spacer(minLength: 0)
            }
        }
    }

    private var assistantToolsMenu: some View {
        Menu {
            Button("Build Style Guide") {
                apiKeyStore.persistIfNeeded()
                store.generateStyleGuideSuggestion(apiKey: apiKeyStore.apiKey, context: context)
            }
            Button("Build Character") {
                apiKeyStore.persistIfNeeded()
                store.generateCharacterStyleSuggestion(apiKey: apiKeyStore.apiKey, context: context)
            }
            Button("Update Project Memory") {
                apiKeyStore.persistIfNeeded()
                store.generateContinuityMemorySuggestion(apiKey: apiKeyStore.apiKey, context: context)
            }
            if let currentChapterTitle, let currentChapterText {
                Button("Propose Scene Breaks") {
                    apiKeyStore.persistIfNeeded()
                    store.generateSceneBreakSuggestion(
                        apiKey: apiKeyStore.apiKey,
                        context: context,
                        chapterTitle: currentChapterTitle,
                        chapterText: currentChapterText
                    )
                }
            }
        } label: {
            assistantMenuLabel("Build")
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
    }

    private var assistantDraftsMenu: some View {
        Menu {
            Button("Summarize Scene") {
                store.fillPrompt("Summarize the current scene and list the main dramatic beats, purpose, and any pacing concerns.")
            }
            Button("Pacing Pass") {
                store.fillPrompt("Assess the current scope for pacing issues, repetitive beats, and scenes or paragraphs that could be tightened or cut.")
            }
        } label: {
            assistantMenuLabel("Draft")
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
    }

    private func assistantMenuLabel(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(NativeTheme.interfaceFont(size: 10, weight: .bold))
        }
        .font(NativeTheme.interfaceFont(size: 12, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(NativeTheme.panelSoftColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func quickActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderless)
            .font(NativeTheme.interfaceFont(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(NativeTheme.panelSoftColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var assistantContextSummary: some View {
        HStack(spacing: 6) {
            Text(context.scopeLabel)
                .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                .foregroundStyle(NativeTheme.accentColor)
                .lineLimit(1)
            Text("•")
                .foregroundStyle(NativeTheme.mutedColor)
            Text("\(context.sceneCount) scene" + (context.sceneCount == 1 ? "" : "s"))
                .font(NativeTheme.interfaceFont(size: 12))
                .foregroundStyle(NativeTheme.mutedColor)
                .lineLimit(1)
            Text("•")
                .foregroundStyle(NativeTheme.mutedColor)
            Text("\(context.scopeWordCount) words")
                .font(NativeTheme.interfaceFont(size: 12))
                .foregroundStyle(NativeTheme.mutedColor)
                .lineLimit(1)
            if context.selectedWordCount > 0 {
                Text("•")
                    .foregroundStyle(NativeTheme.mutedColor)
                Text("\(context.selectedWordCount) selected")
                    .font(NativeTheme.interfaceFont(size: 12))
                    .foregroundStyle(NativeTheme.mutedColor)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(NativeTheme.panelSoftColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func applyAssistantReply(_ text: String, mode: AssistantApplyMode) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            store.addStatus("The assistant reply was empty.")
            return
        }

        switch mode {
        case .replaceSelection:
            if NativeTextFormattingController.replaceSelection(with: trimmedText) {
                store.addStatus("Assistant reply replaced the selected text.")
            } else {
                store.addStatus("Select text in the editor first, then try Replace Selection.")
            }
        case .insertBelow:
            if NativeTextFormattingController.insertBelowSelection(trimmedText) {
                store.addStatus("Assistant reply inserted into the scene.")
            } else {
                store.addStatus("Open a scene in the editor first, then try Insert Below.")
            }
        case .appendToEnd:
            if NativeTextFormattingController.appendToSceneEnd(trimmedText) {
                store.addStatus("Assistant reply appended to the end of the scene.")
            } else {
                store.addStatus("Open a scene in the editor first, then try Append to End.")
            }
        case .newScene:
            if createSceneFromReply(trimmedText) {
                store.addStatus("Assistant reply created a new scene.")
            } else {
                store.addStatus("Open a single scene or chapter first, then try New Scene.")
            }
        }
        shouldShowJumpToBottom = true
    }

    private enum AssistantApplyMode {
        case replaceSelection
        case insertBelow
        case appendToEnd
        case newScene
    }
}

struct NativeAssistantMessageBubble: View {
    let textSize: NativeAssistantTextSize
    let message: NativeAssistantMessage
    let canReplaceSelection: Bool
    let canInsertIntoEditor: Bool
    let canCreateScene: Bool
    let replaceSelection: () -> Void
    let insertBelow: () -> Void
    let appendToEnd: () -> Void
    let createNewScene: () -> Void
    let copyReply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(roleLabel)
                .font(textSize.font(size: 12, weight: .semibold))
                .foregroundStyle(roleColor)
            Text(message.text)
                .font(textSize.font(size: 14))
                .foregroundStyle(NativeTheme.ink1Color)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        assistantActionButton("Replace Selection", isEnabled: canReplaceSelection, action: replaceSelection)
                        assistantActionButton("Insert Below", isEnabled: canInsertIntoEditor, action: insertBelow)
                        assistantActionButton("Append to End", isEnabled: canInsertIntoEditor, action: appendToEnd)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        assistantActionButton("New Scene", isEnabled: canCreateScene, action: createNewScene)
                        assistantActionButton("Copy Reply", isEnabled: true, action: copyReply)
                        Spacer(minLength: 0)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var roleLabel: String {
        switch message.role {
        case .user:
            return "You"
        case .assistant:
            return "Assistant"
        case .status:
            return "Status"
        }
    }

    private var roleColor: Color {
        switch message.role {
        case .user:
            return NativeTheme.accentColor
        case .assistant:
            return NativeTheme.mutedColor
        case .status:
            return NativeTheme.mutedColor
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return NativeTheme.selectionColor.opacity(0.8)
        case .assistant:
            return NativeTheme.panelSoftColor
        case .status:
            return NativeTheme.panelColor
        }
    }

    private func assistantActionButton(_ title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderless)
            .font(textSize.font(size: 12, weight: .medium))
            .foregroundStyle(isEnabled ? NativeTheme.ink1Color : NativeTheme.mutedColor.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isEnabled ? NativeTheme.panelSoftColor : NativeTheme.panelColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .disabled(!isEnabled)
    }
}

struct NativeAssistantReviewPanel: View {
    let context: NativeAssistantContext
    let textSize: NativeAssistantTextSize
    let issues: [NativeAssistantReviewIssue]
    let activeIssueID: UUID?
    let selectIssue: (NativeAssistantReviewIssue) -> Void
    let applyIssue: (NativeAssistantReviewIssue) -> Void
    let dismissIssue: (NativeAssistantReviewIssue) -> Void
    let approveAllSafe: () -> Void
    let clearIssues: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Scene Review")
                    .font(textSize.font(size: 13, weight: .semibold))
                    .foregroundStyle(NativeTheme.ink1Color)
                Spacer()
                Button("Clear Review", action: clearIssues)
                    .buttonStyle(.borderless)
            }

            HStack(spacing: 8) {
                reviewSummaryChip(
                    title: "Issues",
                    value: "\(issues.count)",
                    tint: NativeTheme.mutedColor
                )
                reviewSummaryChip(
                    title: "Ready",
                    value: "\(issues.filter { $0.replacement != nil && !$0.isStale }.count)",
                    tint: NativeTheme.accentColor
                )
                if issues.contains(where: \.isStale) {
                    reviewSummaryChip(
                        title: "Needs Review",
                        value: "\(issues.filter(\.isStale).count)",
                        tint: Color(nsColor: NativeTheme.accentStrong)
                    )
                }
                Spacer(minLength: 0)
            }

            ForEach(issues) { issue in
                NativeAssistantReviewIssueCard(
                    context: context,
                    textSize: textSize,
                    issue: issue,
                    isActive: activeIssueID == issue.id,
                    selectIssue: { selectIssue(issue) }
                )
                .id(issue.id)
            }
        }
        .padding(14)
        .background(NativeTheme.panelColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func reviewSummaryChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(textSize.font(size: 10, weight: .semibold))
                .foregroundStyle(NativeTheme.mutedColor)
            Text(value)
                .font(textSize.font(size: 12, weight: .semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(NativeTheme.panelSoftColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct NativeAssistantReviewIssueCard: View {
    let context: NativeAssistantContext
    let textSize: NativeAssistantTextSize
    let issue: NativeAssistantReviewIssue
    let isActive: Bool
    let selectIssue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let hasReplacement = issue.replacement != nil
            let isDeletionSuggestion = issue.replacement == ""

            HStack {
                issueTag(issue.category, tint: NativeTheme.accentColor)
                if hasReplacement {
                    issueTag("Suggestion Ready", tint: Color(nsColor: NativeTheme.accentStrong))
                }
                if issue.isStale {
                    issueTag("Needs Review", tint: Color(nsColor: NativeTheme.accentStrong))
                }
                Spacer()
                Text(issue.sceneTitle)
                    .font(textSize.font(size: 11))
                    .foregroundStyle(NativeTheme.mutedColor)
                    .lineLimit(1)
            }

            if !influenceLabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(influenceLabels) { label in
                            issueTag(label.title, tint: label.tint)
                        }
                    }
                }
            }

            if !hasReplacement {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quoted Passage")
                        .font(textSize.font(size: 10, weight: .semibold))
                        .foregroundStyle(NativeTheme.mutedColor)
                    Text(issue.quote)
                        .font(textSize.font(size: 13, weight: .medium))
                        .foregroundStyle(NativeTheme.ink1Color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NativeTheme.paper1Color.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if !hasReplacement {
                Text(issue.problem)
                    .font(textSize.font(size: 12))
                    .foregroundStyle(NativeTheme.ink2Color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if issue.isStale {
                Text("Needs Review: this passage changed and the exact quote no longer matches cleanly.")
                    .font(textSize.font(size: 11, weight: .semibold))
                    .foregroundStyle(Color(nsColor: NativeTheme.accentStrong))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(issue.recommendation)
                .font(textSize.font(size: 12))
                .foregroundStyle(hasReplacement ? NativeTheme.ink2Color : NativeTheme.mutedColor)
                .fixedSize(horizontal: false, vertical: true)

            if let replacement = issue.replacement {
                HStack(alignment: .top, spacing: 10) {
                    comparisonColumn(
                        title: "Current",
                        text: issue.quote,
                        tint: Color(nsColor: NativeTheme.accentStrong).opacity(0.9),
                        background: NativeTheme.selectionColor.opacity(0.5)
                    )
                    comparisonColumn(
                        title: isDeletionSuggestion ? "Delete" : "Suggested",
                        text: isDeletionSuggestion ? "Remove this passage." : replacement,
                        tint: NativeTheme.accentColor,
                        background: NativeTheme.panelColor
                    )
                }
            }
        }
        .padding(12)
        .background(isActive ? NativeTheme.selectionColor.opacity(0.92) : NativeTheme.panelSoftColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isActive ? NativeTheme.accentColor : NativeTheme.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            guard !issue.isStale else { return }
            selectIssue()
        }
    }

    private func issueTag(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(textSize.font(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(NativeTheme.paper1Color.opacity(0.95))
            .clipShape(Capsule())
    }

    private func comparisonColumn(title: String, text: String, tint: Color, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(textSize.font(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(textSize.font(size: 12))
                .foregroundStyle(NativeTheme.ink1Color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var influenceLabels: [NativeAssistantInfluenceLabel] {
        var labels: [NativeAssistantInfluenceLabel] = []
        let normalizedQuote = issue.quote.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        if let genre = context.genre.nilIfEmpty {
            labels.append(NativeAssistantInfluenceLabel(title: "Genre: \(genre)", tint: NativeTheme.accentColor))
        }

        if issue.category.lowercased() == "pacing",
           context.pacingNotes.nilIfEmpty != nil || context.storyPromise.nilIfEmpty != nil {
            labels.append(NativeAssistantInfluenceLabel(title: "Pacing / Arc", tint: Color(nsColor: NativeTheme.accentStrong)))
        }

        if context.avoidNotes.nilIfEmpty != nil {
            labels.append(NativeAssistantInfluenceLabel(title: "Avoid / Flag", tint: NativeTheme.mutedColor))
        }

        if context.projectStyleNotes.nilIfEmpty != nil || !context.approvedWords.isEmpty {
            labels.append(NativeAssistantInfluenceLabel(title: "Project Style", tint: NativeTheme.ink2Color))
        }

        if context.relevantCharacterStyles.contains(where: { character in
            let normalizedName = character.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if !normalizedName.isEmpty, normalizedQuote.contains(normalizedName) {
                return true
            }
            return character.approvedWords.contains { word in
                let normalizedWord = word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                return !normalizedWord.isEmpty && normalizedQuote.contains(normalizedWord)
            }
        }) || (issue.category.lowercased() == "dialogue" && !context.relevantCharacterStyles.isEmpty) {
            labels.append(NativeAssistantInfluenceLabel(title: "Character Voice", tint: Color(nsColor: NativeTheme.accentStrong)))
        }

        return labels
    }
}

struct NativePodcastPrepDrawerView: View {
    @ObservedObject var store: NativePodcastPrepStore
    let apiKey: String
    let project: NativeProject
    let chapter: NativeChapter
    let scenes: [NativeScene]
    let previousEpisodeChapter: NativeChapter?
    let previousEpisodeScenes: [NativeScene]
    let editorFontSize: NativeEditorFontSize
    let savePrep: (NativeChapterPodcastPrep) -> Void

    @State private var draftPrep: NativeChapterPodcastPrep
    @State private var copyFeedbackMessage: String?

    init(
        store: NativePodcastPrepStore,
        apiKey: String,
        project: NativeProject,
        chapter: NativeChapter,
        scenes: [NativeScene],
        previousEpisodeChapter: NativeChapter?,
        previousEpisodeScenes: [NativeScene],
        editorFontSize: NativeEditorFontSize,
        savePrep: @escaping (NativeChapterPodcastPrep) -> Void
    ) {
        self.store = store
        self.apiKey = apiKey
        self.project = project
        self.chapter = chapter
        self.scenes = scenes
        self.previousEpisodeChapter = previousEpisodeChapter
        self.previousEpisodeScenes = previousEpisodeScenes
        self.editorFontSize = editorFontSize
        self.savePrep = savePrep
        _draftPrep = State(initialValue: chapter.podcastPrep)
    }

    private var panelBodyFontSize: CGFloat { editorFontSize.pointSize }
    private var panelLabelFontSize: CGFloat { max(12, editorFontSize.pointSize - 2) }
    private var panelCaptionFontSize: CGFloat { max(11, editorFontSize.pointSize - 3) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Episode Prep")
                            .font(NativeTheme.displayFont(size: 20, weight: .semibold))
                            .foregroundStyle(NativeTheme.ink1Color)
                        Text(displayedChapterTitle(chapter.title, for: project))
                            .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                            .foregroundStyle(NativeTheme.accentColor)
                    }
                    Spacer()

                    HStack(spacing: 8) {
                        Button(store.isGenerating ? "Generating..." : "Generate Pack") {
                            Task {
                                if let generated = await store.generateEpisodePrep(
                                    apiKey: apiKey,
                                    project: project,
                                    chapter: chapter,
                                    scenes: scenes,
                                    previousEpisodeChapter: previousEpisodeChapter,
                                    previousEpisodeScenes: previousEpisodeScenes,
                                    existingPrep: draftPrep
                                ) {
                                    draftPrep = generated
                                    savePrep(generated)
                                }
                            }
                        }
                        .buttonStyle(NativeProminentButtonStyle())
                        .disabled(store.isGenerating || store.generatingSection != nil)

                        Menu {
                            Button("Generate Missing Only") {
                                Task {
                                    await generateMissingOnly()
                                }
                            }
                            .disabled(store.isGenerating || store.generatingSection != nil)

                            Divider()

                            Button("Copy Episode Pack") {
                                copyToPasteboard(composeEpisodePack())
                            }

                            Button("Copy Episode Pack for TTS") {
                                copyToPasteboard(composeEpisodePackForTTS())
                            }

                            Button("Export Pack") {
                                exportEpisodePack()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(NativeTheme.interfaceFont(size: 15, weight: .semibold))
                                .frame(width: 32, height: 32)
                        }
                        .menuStyle(.borderlessButton)
                        .help("Episode pack actions")

                        Button {
                            exportEpisodePackRTF()
                        } label: {
                            Image(systemName: "doc.richtext")
                                .font(NativeTheme.interfaceFont(size: 14, weight: .semibold))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(NativeSecondaryIconButtonStyle())
                        .help("Export episode pack as RTF")
                    }
                }

                Text("Generate intros, outros, episode copy, cover-art prompt, and social posts for this episode.")
                    .font(NativeTheme.interfaceFont(size: panelCaptionFontSize))
                    .foregroundStyle(NativeTheme.mutedColor)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Episode Title")
                        .font(NativeTheme.interfaceFont(size: panelLabelFontSize, weight: .semibold))
                        .foregroundStyle(NativeTheme.ink1Color)
                    TextField("Suggested episode title", text: $draftPrep.episodeTitle)
                        .font(NativeTheme.interfaceFont(size: panelBodyFontSize))
                        .textFieldStyle(.roundedBorder)
                }

                HStack(alignment: .top, spacing: 12) {
                    if hasPreviousEpisode {
                        NativePodcastVoiceMenuField(
                            title: "Recap Voice",
                            selection: $draftPrep.previousEpisodeSummaryVoice,
                            options: recapVoiceOptions,
                            placeholder: "Choose",
                            bodyFontSize: panelBodyFontSize,
                            labelFontSize: panelLabelFontSize
                        )
                    }
                    NativePodcastVoiceMenuField(
                        title: "Intro Voice",
                        selection: $draftPrep.introVoice,
                        options: suggestedVoices,
                        placeholder: "Choose",
                        bodyFontSize: panelBodyFontSize,
                        labelFontSize: panelLabelFontSize
                    )
                    NativePodcastVoiceMenuField(
                        title: "Outro Voice",
                        selection: $draftPrep.outroVoice,
                        options: suggestedVoices,
                        placeholder: "Choose",
                        bodyFontSize: panelBodyFontSize,
                        labelFontSize: panelLabelFontSize
                    )
                }

                if let copyFeedbackMessage {
                    Text(copyFeedbackMessage)
                        .font(NativeTheme.interfaceFont(size: panelCaptionFontSize, weight: .semibold))
                        .foregroundStyle(NativeTheme.accentColor)
                }
            }
            .padding(16)
            .background(NativeTheme.panelColor)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if hasPreviousEpisode {
                        NativePodcastPrepEditor(
                            title: "Previous Episode Summary",
                            text: $draftPrep.previousEpisodeSummary,
                            minHeight: 100,
                            fontSize: panelBodyFontSize,
                            labelFontSize: panelLabelFontSize,
                            isGenerating: store.generatingSection == .previousEpisodeSummary,
                            onCopy: { copyToPasteboard(draftPrep.previousEpisodeSummary) },
                            onRegenerate: { regenerate(.previousEpisodeSummary) }
                        )
                    }
                    NativePodcastPrepEditor(
                        title: "Intro",
                        text: $draftPrep.introText,
                        minHeight: 120,
                        fontSize: panelBodyFontSize,
                        labelFontSize: panelLabelFontSize,
                        isGenerating: store.generatingSection == .intro,
                        onCopy: { copyToPasteboard(draftPrep.introText) },
                        onRegenerate: { regenerate(.intro) }
                    )
                    NativePodcastPrepEditor(
                        title: "Outro",
                        text: $draftPrep.outroText,
                        minHeight: 120,
                        fontSize: panelBodyFontSize,
                        labelFontSize: panelLabelFontSize,
                        isGenerating: store.generatingSection == .outro,
                        onCopy: { copyToPasteboard(draftPrep.outroText) },
                        onRegenerate: { regenerate(.outro) }
                    )
                    NativePodcastPrepEditor(
                        title: "Podcast Description",
                        text: $draftPrep.podcastDescription,
                        minHeight: 120,
                        fontSize: panelBodyFontSize,
                        labelFontSize: panelLabelFontSize,
                        isGenerating: store.generatingSection == .podcastDescription,
                        onCopy: { copyToPasteboard(draftPrep.podcastDescription) },
                        onRegenerate: { regenerate(.podcastDescription) }
                    )
                    NativePodcastPrepEditor(
                        title: "Cover Art Prompt",
                        text: $draftPrep.coverArtPrompt,
                        minHeight: 140,
                        fontSize: panelBodyFontSize,
                        labelFontSize: panelLabelFontSize,
                        isGenerating: store.generatingSection == .coverArtPrompt,
                        onCopy: { copyToPasteboard(draftPrep.coverArtPrompt) },
                        onRegenerate: { regenerate(.coverArtPrompt) }
                    )
                    NativePodcastPrepEditor(
                        title: "Facebook",
                        text: $draftPrep.facebookPost,
                        minHeight: 110,
                        fontSize: panelBodyFontSize,
                        labelFontSize: panelLabelFontSize,
                        isGenerating: store.generatingSection == .facebook,
                        onCopy: { copyToPasteboard(draftPrep.facebookPost) },
                        onRegenerate: { regenerate(.facebook) }
                    )
                    NativePodcastPrepEditor(
                        title: "Tumblr",
                        text: $draftPrep.tumblrPost,
                        minHeight: 110,
                        fontSize: panelBodyFontSize,
                        labelFontSize: panelLabelFontSize,
                        isGenerating: store.generatingSection == .tumblr,
                        onCopy: { copyToPasteboard(draftPrep.tumblrPost) },
                        onRegenerate: { regenerate(.tumblr) }
                    )
                    NativePodcastPrepEditor(
                        title: "Instagram",
                        text: $draftPrep.instagramPost,
                        minHeight: 110,
                        fontSize: panelBodyFontSize,
                        labelFontSize: panelLabelFontSize,
                        isGenerating: store.generatingSection == .instagram,
                        onCopy: { copyToPasteboard(draftPrep.instagramPost) },
                        onRegenerate: { regenerate(.instagram) }
                    )
                    NativePodcastPrepEditor(
                        title: "Pinterest",
                        text: $draftPrep.pinterestPost,
                        minHeight: 110,
                        fontSize: panelBodyFontSize,
                        labelFontSize: panelLabelFontSize,
                        isGenerating: store.generatingSection == .pinterest,
                        onCopy: { copyToPasteboard(draftPrep.pinterestPost) },
                        onRegenerate: { regenerate(.pinterest) }
                    )
                    NativePodcastPrepEditor(
                        title: "Reddit",
                        text: $draftPrep.redditPost,
                        minHeight: 120,
                        fontSize: panelBodyFontSize,
                        labelFontSize: panelLabelFontSize,
                        isGenerating: store.generatingSection == .reddit,
                        onCopy: { copyToPasteboard(draftPrep.redditPost) },
                        onRegenerate: { regenerate(.reddit) }
                    )
                    NativePodcastPrepEditor(
                        title: "X",
                        text: $draftPrep.xPost,
                        minHeight: 100,
                        fontSize: panelBodyFontSize,
                        labelFontSize: panelLabelFontSize,
                        isGenerating: store.generatingSection == .x,
                        onCopy: { copyToPasteboard(draftPrep.xPost) },
                        onRegenerate: { regenerate(.x) }
                    )
                }
                .padding(16)
            }

            if let lastError = store.lastError {
                Text(lastError)
                    .font(NativeTheme.interfaceFont(size: panelCaptionFontSize))
                    .foregroundStyle(Color(nsColor: NativeTheme.accentStrong))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NativeTheme.paper2Color)
            }
        }
        .background(NativeTheme.paper2Color)
        .onAppear {
            applyDefaultVoicesIfNeeded()
        }
        .onChange(of: draftPrep) { _, newValue in
            savePrep(newValue)
        }
        .onChange(of: chapter.id) { _, _ in
            draftPrep = chapter.podcastPrep
            applyDefaultVoicesIfNeeded()
        }
        .onChange(of: chapter.podcastPrep) { _, newValue in
            draftPrep = newValue
            applyDefaultVoicesIfNeeded()
        }
    }

    private var suggestedVoices: [String] {
        var choices: [String] = []
        if let host = project.podcastSetup.hostDisplayName.nilIfEmpty {
            choices.append(host)
        }
        choices.append(contentsOf: project.characterStyles.map(\.name).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        if !choices.contains("Mike Carmel") {
            choices.append("Mike Carmel")
        }
        return Array(NSOrderedSet(array: choices)) as? [String] ?? choices
    }

    private var recapVoiceOptions: [String] {
        let choices = project.characterStyles
            .map(\.name)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return Array(NSOrderedSet(array: choices)) as? [String] ?? choices
    }

    private var hasPreviousEpisode: Bool {
        previousEpisodeChapter != nil && !previousEpisodeScenes.isEmpty
    }

    private func regenerate(_ section: NativePodcastPrepSection) {
        Task {
            if let generated = await store.generateSection(
                apiKey: apiKey,
                project: project,
                chapter: chapter,
                scenes: scenes,
                previousEpisodeChapter: previousEpisodeChapter,
                previousEpisodeScenes: previousEpisodeScenes,
                existingPrep: draftPrep,
                section: section
            ) {
                draftPrep = generated
                savePrep(generated)
            }
        }
    }

    private func generateMissingOnly() async {
        let sections = NativePodcastPrepSection.allCases.filter { shouldGenerateSection($0) && sectionIsEmpty($0) }
        guard !sections.isEmpty else {
            copyFeedbackMessage = "Nothing missing to generate."
            clearCopyFeedbackSoon(ifMatches: "Nothing missing to generate.")
            return
        }

        var workingPrep = draftPrep
        for section in sections {
            guard let generated = await store.generateSection(
                apiKey: apiKey,
                project: project,
                chapter: chapter,
                scenes: scenes,
                previousEpisodeChapter: previousEpisodeChapter,
                previousEpisodeScenes: previousEpisodeScenes,
                existingPrep: workingPrep,
                section: section
            ) else {
                break
            }
            workingPrep = generated
            draftPrep = generated
            savePrep(generated)
        }

        if store.lastError == nil {
            copyFeedbackMessage = "Generated missing sections."
            clearCopyFeedbackSoon(ifMatches: "Generated missing sections.")
        }
    }

    private func copyToPasteboard(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trimmed, forType: .string)
        copyFeedbackMessage = "Copied to clipboard."
        clearCopyFeedbackSoon(ifMatches: "Copied to clipboard.")
    }

    private func exportEpisodePack() {
        let content = composeEpisodePack().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            copyFeedbackMessage = "Nothing to export yet."
            clearCopyFeedbackSoon(ifMatches: "Nothing to export yet.")
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = exportFilename
        panel.allowedContentTypes = [.plainText]
        panel.prompt = "Export"
        panel.message = "Export this episode pack as a plain text file."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            copyFeedbackMessage = "Episode pack exported."
            clearCopyFeedbackSoon(ifMatches: "Episode pack exported.")
        } catch {
            copyFeedbackMessage = "Couldn't export episode pack."
            clearCopyFeedbackSoon(ifMatches: "Couldn't export episode pack.")
        }
    }

    private func exportEpisodePackRTF() {
        let content = composeEpisodePack().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            copyFeedbackMessage = "Nothing to export yet."
            clearCopyFeedbackSoon(ifMatches: "Nothing to export yet.")
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = exportRTFFilename
        panel.allowedContentTypes = [.rtf]
        panel.prompt = "Export"
        panel.message = "Export this episode pack as an RTF file."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Avenir Next", size: 14) ?? .systemFont(ofSize: 14),
            .foregroundColor: NSColor.textColor
        ]
        let attributed = NSAttributedString(string: content, attributes: attributes)

        do {
            let data = try attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            try data.write(to: url, options: .atomic)
            copyFeedbackMessage = "Episode pack exported as RTF."
            clearCopyFeedbackSoon(ifMatches: "Episode pack exported as RTF.")
        } catch {
            copyFeedbackMessage = "Couldn't export RTF."
            clearCopyFeedbackSoon(ifMatches: "Couldn't export RTF.")
        }
    }

    private var exportFilename: String {
        let episodeLabel = project.isPodcastProject ? "Episode" : "Chapter"
        let baseTitle = effectiveEpisodeTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(episodeLabel) \(chapter.order + 1) - \(baseTitle) Prep.txt"
    }

    private var exportRTFFilename: String {
        let episodeLabel = project.isPodcastProject ? "Episode" : "Chapter"
        let baseTitle = effectiveEpisodeTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(episodeLabel) \(chapter.order + 1) - \(baseTitle) Prep.rtf"
    }

    private func applyDefaultVoicesIfNeeded() {
        let defaultVoice = preferredDefaultVoice
        var updated = draftPrep
        var changed = false

        if updated.introVoice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.introVoice = defaultVoice
            changed = true
        }

        if updated.outroVoice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.outroVoice = defaultVoice
            changed = true
        }

        if !hasPreviousEpisode {
            if !updated.previousEpisodeSummaryVoice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.previousEpisodeSummaryVoice = ""
                changed = true
            }
            if !updated.previousEpisodeSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.previousEpisodeSummary = ""
                changed = true
            }
        }

        guard changed else { return }
        draftPrep = updated
        savePrep(updated)
    }

    private var preferredDefaultVoice: String {
        project.podcastSetup.hostDisplayName.nilIfEmpty
            ?? project.characterStyles.first?.name.nilIfEmpty
            ?? "Mike Carmel"
    }

    private func sectionIsEmpty(_ section: NativePodcastPrepSection) -> Bool {
        switch section {
        case .previousEpisodeSummary:
            return draftPrep.previousEpisodeSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .intro:
            return draftPrep.introText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .outro:
            return draftPrep.outroText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .podcastDescription:
            return draftPrep.podcastDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .coverArtPrompt:
            return draftPrep.coverArtPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .facebook:
            return draftPrep.facebookPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tumblr:
            return draftPrep.tumblrPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .instagram:
            return draftPrep.instagramPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .pinterest:
            return draftPrep.pinterestPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .reddit:
            return draftPrep.redditPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .x:
            return draftPrep.xPost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func shouldGenerateSection(_ section: NativePodcastPrepSection) -> Bool {
        switch section {
        case .previousEpisodeSummary:
            return hasPreviousEpisode
        default:
            return true
        }
    }

    private func clearCopyFeedbackSoon(ifMatches message: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if copyFeedbackMessage == message {
                copyFeedbackMessage = nil
            }
        }
    }

    private func composeEpisodePack() -> String {
        let episodeLabel = project.isPodcastProject ? "Episode" : "Chapter"
        let header = "\(episodeLabel) \(chapter.order + 1): \(effectiveEpisodeTitle)"
        let sections: [(String, String)] = [
            ("Episode Title", effectiveEpisodeTitle),
            ("Recap Voice", draftPrep.previousEpisodeSummaryVoice),
            ("Previous Episode Summary", draftPrep.previousEpisodeSummary),
            ("Intro Voice", draftPrep.introVoice),
            ("Intro", draftPrep.introText),
            ("Outro Voice", draftPrep.outroVoice),
            ("Outro", draftPrep.outroText),
            ("Podcast Description", draftPrep.podcastDescription),
            ("Cover Art Prompt", draftPrep.coverArtPrompt),
            ("Facebook", draftPrep.facebookPost),
            ("Tumblr", draftPrep.tumblrPost),
            ("Instagram", draftPrep.instagramPost),
            ("Pinterest", draftPrep.pinterestPost),
            ("Reddit", draftPrep.redditPost),
            ("X", draftPrep.xPost)
        ]
        let body = sections
            .compactMap { title, value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : "\(title)\n\(trimmed)"
            }
            .joined(separator: "\n\n")
        return ([header, body].filter { !$0.isEmpty }).joined(separator: "\n\n")
    }

    private func composeEpisodePackForTTS() -> String {
        applyAudioPronunciationReplacements(to: composeEpisodePack())
    }

    private func applyAudioPronunciationReplacements(to text: String) -> String {
        let replacements = activeAudioPronunciationReplacements
        guard !replacements.isEmpty else { return text }

        var updatedText = text
        for replacement in replacements {
            let escaped = NSRegularExpression.escapedPattern(for: replacement.writtenForm)
            let pattern = "\\b\(escaped)\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            updatedText = regex.stringByReplacingMatches(
                in: updatedText,
                options: [],
                range: NSRange(updatedText.startIndex..., in: updatedText),
                withTemplate: replacement.spokenForm
            )
        }
        return updatedText
    }

    private var activeAudioPronunciationReplacements: [NativeAudioPronunciationReplacement] {
        project.audioPronunciationReplacements
            .filter { $0.isEnabled }
            .map { replacement in
                NativeAudioPronunciationReplacement(
                    id: replacement.id,
                    writtenForm: replacement.writtenForm.trimmingCharacters(in: .whitespacesAndNewlines),
                    spokenForm: replacement.spokenForm.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: replacement.notes,
                    isEnabled: replacement.isEnabled
                )
            }
            .filter { !$0.writtenForm.isEmpty && !$0.spokenForm.isEmpty }
            .sorted { lhs, rhs in
                lhs.writtenForm.count > rhs.writtenForm.count
            }
    }

    private var effectiveEpisodeTitle: String {
        draftPrep.episodeTitle.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? displayedChapterTitle(chapter.title, for: project)
    }
}

struct NativePodcastVoiceMenuField: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    let placeholder: String
    let bodyFontSize: CGFloat
    let labelFontSize: CGFloat

    private var menuOptions: [String] {
        var values = options
        if let existing = selection.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
           !values.contains(existing) {
            values.insert(existing, at: 0)
        }
        return values
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                .foregroundStyle(NativeTheme.ink1Color)
            Menu {
                ForEach(menuOptions, id: \.self) { option in
                    Button(option) {
                        selection = option
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selection.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? placeholder)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                }
                .font(NativeTheme.interfaceFont(size: max(11, bodyFontSize - 1), weight: .semibold))
                .foregroundStyle(NativeTheme.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NativeTheme.panelSoftColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(NativeTheme.borderColor, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NativePodcastPrepEditor: View {
    let title: String
    @Binding var text: String
    var minHeight: CGFloat = 120
    var fontSize: CGFloat = 13
    var labelFontSize: CGFloat = 12
    var isGenerating: Bool = false
    var onCopy: (() -> Void)? = nil
    var onRegenerate: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(NativeTheme.interfaceFont(size: labelFontSize, weight: .semibold))
                    .foregroundStyle(NativeTheme.ink1Color)
                Spacer()
                if let onCopy {
                    Button("Copy", action: onCopy)
                        .buttonStyle(NativeSecondaryButtonStyle())
                }
                if let onRegenerate {
                    Button(isGenerating ? "Refreshing..." : "Refresh", action: onRegenerate)
                        .buttonStyle(NativeSecondaryButtonStyle())
                        .disabled(isGenerating)
                }
            }
            TextEditor(text: $text)
                .font(NativeTheme.interfaceFont(size: fontSize))
                .foregroundStyle(NativeTheme.ink1Color)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(10)
                .background(NativeTheme.paper1Color)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NativeTheme.borderColor, lineWidth: 1)
                )
        }
    }
}

struct AssistantPromptInput: NSViewRepresentable {
    @Binding var text: String
    let textSize: NativeAssistantTextSize
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = AssistantPromptTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont(name: "Avenir Next", size: 17 * textSize.scale) ?? .systemFont(ofSize: 17 * textSize.scale)
        textView.textColor = NativeTheme.ink1
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.onEnter = context.coordinator.handleEnter
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 12
        scrollView.layer?.backgroundColor = NativeTheme.paper1.withAlphaComponent(1.0).cgColor
        scrollView.layer?.borderWidth = 1.5
        scrollView.layer?.borderColor = NativeTheme.accent.withAlphaComponent(0.72).cgColor
        scrollView.layer?.shadowColor = NativeTheme.accentStrong.withAlphaComponent(0.16).cgColor
        scrollView.layer?.shadowOpacity = 1
        scrollView.layer?.shadowRadius = 10
        scrollView.layer?.shadowOffset = CGSize(width: 0, height: 3)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? AssistantPromptTextView else { return }
        textView.onEnter = context.coordinator.handleEnter
        if textView.string != text {
            textView.string = text
        }
        let targetFont = NSFont(name: "Avenir Next", size: 17 * textSize.scale) ?? .systemFont(ofSize: 17 * textSize.scale)
        if textView.font != targetFont {
            textView.font = targetFont
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        let onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }

        func handleEnter() {
            onSubmit()
        }
    }
}

final class AssistantPromptTextView: NSTextView {
    var onEnter: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 {
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift) {
                super.keyDown(with: event)
            } else {
                onEnter?()
            }
            return
        }
        super.keyDown(with: event)
    }
}

private func currentModifierFlags() -> NSEvent.ModifierFlags {
    NSApp.currentEvent?.modifierFlags ?? []
}

struct TrashSectionView: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Trash")
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(NativeTheme.interfaceFont(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NativeTheme.panelSoftColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if isExpanded {
                let chapterItems = model.trashedChapters.filter { $0.originalProjectID == project.id }
                let sceneItems = model.trashedScenes.filter { $0.originalProjectID == project.id }

                if chapterItems.isEmpty && sceneItems.isEmpty {
                    Text("Trash is empty.")
                        .font(NativeTheme.interfaceFont(size: 12))
                        .foregroundStyle(NativeTheme.mutedColor)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                } else {
                    ForEach(chapterItems) { item in
                        TrashChapterRowView(model: model, item: item)
                    }
                    ForEach(sceneItems) { item in
                        TrashSceneRowView(model: model, item: item)
                    }
                }
            }
        }
    }
}

struct TrashChapterRowView: View {
    @ObservedObject var model: NativeAppModel
    let item: NativeTrashedChapter
    @State private var isShowingPermanentDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(item.chapter.title.lowercased().hasPrefix("episode ") ? "Episode" : "Chapter"): \(item.chapter.title)")
                .font(.subheadline.weight(.semibold))
            HStack {
                Text("\(item.scenes.count) scenes")
                    .font(NativeTheme.interfaceFont(size: 12))
                    .foregroundStyle(NativeTheme.mutedColor)
                Spacer()
                Button("Restore") {
                    model.restoreTrashedChapter(item.id)
                }
                .buttonStyle(.borderless)
                Button("Delete Forever", role: .destructive) {
                    isShowingPermanentDeleteConfirmation = true
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .background(NativeTheme.panelSoftColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .alert("Delete chapter forever?", isPresented: $isShowingPermanentDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) {
                model.permanentlyDeleteTrashedChapter(item.id)
            }
        } message: {
            Text("\"\(item.chapter.title)\" will be removed permanently from Trash.")
        }
    }
}

struct TrashSceneRowView: View {
    @ObservedObject var model: NativeAppModel
    let item: NativeTrashedScene
    @State private var isShowingPermanentDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(item.chapterTitle ?? "Unknown Chapter") / \(item.scene.title)")
                .font(.subheadline.weight(.semibold))
            HStack {
                Text("\(item.scene.body.split(whereSeparator: \.isWhitespace).count) words")
                    .font(NativeTheme.interfaceFont(size: 12))
                    .foregroundStyle(NativeTheme.mutedColor)
                Spacer()
                Button("Restore") {
                    model.restoreTrashedScene(item.id)
                }
                .buttonStyle(.borderless)
                Button("Delete Forever", role: .destructive) {
                    isShowingPermanentDeleteConfirmation = true
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .background(NativeTheme.panelSoftColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .alert("Delete scene forever?", isPresented: $isShowingPermanentDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) {
                model.permanentlyDeleteTrashedScene(item.id)
            }
        } message: {
            Text("\"\(item.scene.title)\" will be removed permanently from Trash.")
        }
    }
}

struct EditableProjectTitleField: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject

    var body: some View {
        RenameableTitleText(
            text: project.title,
            placeholder: "Untitled Novel",
            font: NativeTheme.displayFont(size: 22, weight: .semibold),
            alignment: .center,
            commit: { model.updateProjectTitle(project.id, title: $0) }
        )
        .lineLimit(2)
        .multilineTextAlignment(.center)
    }
}

struct BinderDragPreview: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 220, alignment: .leading)
        .background(NativeTheme.paper2Color)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NativeTheme.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct NativeEditorMenu<Content: View>: View {
    let title: String
    let icon: String
    let selectionLabel: String
    @ViewBuilder let content: Content

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                Text(selectionLabel)
                    .foregroundStyle(NativeTheme.mutedColor)
            }
            .font(NativeTheme.interfaceFont(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(NativeTheme.panelSoftColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .menuStyle(.borderlessButton)
    }
}

struct NativeEditorToolbarButton: View {
    let title: String
    let icon: String
    var isActive: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        NativeToolbarActionButton(
            title: title,
            icon: icon,
            isActive: isActive,
            isEnabled: isEnabled,
            action: action
        )
            .frame(width: 30, height: 30)
            .help(title)
    }
}

struct NativeToolbarActionButton: NSViewRepresentable {
    let title: String
    let icon: String
    let isActive: Bool
    let isEnabled: Bool
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NativeMouseDownButton {
        let button = NativeMouseDownButton()
        button.actionHandler = context.coordinator.performAction
        button.toolTip = title
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryChange)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.wantsLayer = true
        button.image = NSImage(
            systemSymbolName: icon,
            accessibilityDescription: title
        )?.withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
        applyAppearance(to: button)
        return button
    }

    func updateNSView(_ nsView: NativeMouseDownButton, context: Context) {
        nsView.actionHandler = context.coordinator.performAction
        nsView.toolTip = title
        nsView.image = NSImage(
            systemSymbolName: icon,
            accessibilityDescription: title
        )?.withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
        applyAppearance(to: nsView)
    }

    private func applyAppearance(to button: NativeMouseDownButton) {
        button.isEnabled = isEnabled
        button.layer?.cornerRadius = 10
        if isActive {
            button.contentTintColor = NativeTheme.primaryButtonText
            button.layer?.backgroundColor = NativeTheme.accent.cgColor
        } else {
            button.contentTintColor = isEnabled ? NativeTheme.ink1 : NativeTheme.muted.withAlphaComponent(0.45)
            button.layer?.backgroundColor = (isEnabled ? NativeTheme.panelSoft : NativeTheme.panel).cgColor
        }
    }

    final class Coordinator: NSObject {
        let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}

final class NativeMouseDownButton: NSButton {
    var actionHandler: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isHighlighted = true
        actionHandler?()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.isHighlighted = false
        }
    }
}

@MainActor
final class NativeFormattingToolbarState: ObservableObject {
    enum AlignmentState {
        case left
        case center
        case right
        case justified
        case mixed
    }

    static let shared = NativeFormattingToolbarState()

    @Published private(set) var canFormat = false
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var hasExpandedSelection = false
    @Published private(set) var isBoldActive = false
    @Published private(set) var isItalicActive = false
    @Published private(set) var isUnderlineActive = false
    @Published private(set) var isBulletListActive = false
    @Published private(set) var selectedWordCount = 0
    @Published private(set) var alignment: AlignmentState = .left
    @Published private(set) var textColorLabel = NativeEditorTextColor.default.label

    private init() {}

    func update(from textView: NSTextView?) {
        guard let textView else {
            canFormat = false
            canUndo = false
            canRedo = false
            hasExpandedSelection = false
            isBoldActive = false
            isItalicActive = false
            isUnderlineActive = false
            isBulletListActive = false
            selectedWordCount = 0
            alignment = .left
            textColorLabel = NativeEditorTextColor.default.label
            return
        }

        canFormat = true
        canUndo = textView.undoManager?.canUndo ?? false
        canRedo = textView.undoManager?.canRedo ?? false
        hasExpandedSelection = textView.hasExpandedSelection
        isBoldActive = textView.selectionOrTypingHasTrait(.boldFontMask)
        isItalicActive = textView.selectionOrTypingHasTrait(.italicFontMask)
        isUnderlineActive = textView.selectionOrTypingHasUnderline
        isBulletListActive = textView.selectionUsesBulletList
        selectedWordCount = textView.selectedWordCount
        alignment = textView.selectionAlignmentState
        textColorLabel = textView.selectionTextColorLabel
    }
}

struct NativeEditorCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(22)
            .background(NativeTheme.panelColor)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(NativeTheme.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: NativeTheme.accentSoftColor.opacity(0.18), radius: 18, y: 8)
    }
}

struct EditableProjectHeaderField: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject

    var body: some View {
        RenameableTitleText(
            text: project.title,
            placeholder: "Untitled Novel",
            font: NativeTheme.displayFont(size: 28, weight: .bold),
            alignment: .leading,
            commit: { model.updateProjectTitle(project.id, title: $0) }
        )
        .frame(minWidth: 240, alignment: .leading)
    }
}

struct EditableChapterTitleField: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    let chapter: NativeChapter

    var body: some View {
        RenameableTitleText(
            text: displayedChapterTitle(chapter.title, for: project),
            placeholder: project.isPodcastProject ? "Untitled Episode" : "Untitled Chapter",
            font: NativeTheme.displayFont(size: 19, weight: .semibold),
            alignment: .leading,
            commit: { model.updateChapterTitle(chapter.id, title: $0) }
        )
    }
}

struct EditableSceneTitleField: View {
    @ObservedObject var model: NativeAppModel
    let scene: NativeScene

    var body: some View {
        RenameableTitleText(
            text: scene.title,
            placeholder: "Untitled Scene",
            font: NativeTheme.displayFont(size: 17, weight: .semibold),
            alignment: .leading,
            commit: { model.updateSceneTitle(scene.id, title: $0) }
        )
    }
}

struct EditableChapterHeaderField: View {
    @ObservedObject var model: NativeAppModel
    let project: NativeProject
    let chapter: NativeChapter

    var body: some View {
        RenameableTitleText(
            text: displayedChapterTitle(chapter.title, for: project),
            placeholder: project.isPodcastProject ? "Untitled Episode" : "Untitled Chapter",
            font: NativeTheme.displayFont(size: 26, weight: .semibold),
            alignment: .leading,
            commit: { model.updateChapterTitle(chapter.id, title: $0) }
        )
    }
}

struct EditableSceneHeaderField: View {
    @ObservedObject var model: NativeAppModel
    let scene: NativeScene
    var font: Font = NativeTheme.displayFont(size: 28, weight: .bold)

    var body: some View {
        RenameableTitleText(
            text: scene.title,
            placeholder: "Untitled Scene",
            font: font,
            alignment: .leading,
            commit: { model.updateSceneTitle(scene.id, title: $0) }
        )
    }
}

struct RenameableTitleText: View {
    let text: String
    let placeholder: String
    var font: Font = .body
    var alignment: TextAlignment = .leading
    let commit: (String) -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField(placeholder, text: $draft)
                    .textFieldStyle(.plain)
                    .font(font)
                    .foregroundStyle(NativeTheme.ink1Color)
                    .multilineTextAlignment(alignment)
                    .focused($isFocused)
                    .onAppear {
                        draft = text
                        isFocused = true
                    }
                    .onSubmit {
                        finishEditing()
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused {
                            finishEditing()
                        }
                    }
            } else {
                Text(text.isEmpty ? placeholder : text)
                    .font(font)
                    .multilineTextAlignment(alignment)
                    .foregroundStyle(NativeTheme.ink1Color)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        draft = text
                        isEditing = true
                    }
            }
        }
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .center:
            return .center
        case .trailing:
            return .trailing
        default:
            return .leading
        }
    }

    private func finishEditing() {
        isEditing = false
        commit(draft)
    }
}

struct EditableSceneBodyView: View {
    @ObservedObject var model: NativeAppModel
    let sceneID: UUID
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let showInvisibleCharacters: Bool
    let minimumHeight: CGFloat
    @State private var contentHeight: CGFloat = 320

    var body: some View {
        AutoSizingTextView(
            sceneID: sceneID,
            text: sceneBodyBinding,
            richTextRTF: sceneRTFBinding,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            showInvisibleCharacters: showInvisibleCharacters,
            measuredHeight: $contentHeight,
            initialSelectionLocation: model.lastEditedLocationBySceneID[sceneID],
            selectionAnchorChanged: { location in
                model.updateSceneEditLocation(sceneID, location: location)
            }
        )
        .id(sceneID)
        .frame(minHeight: max(minimumHeight, contentHeight))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private var sceneBodyBinding: Binding<String> {
        Binding(
            get: {
                model.scenes.first(where: { $0.id == sceneID })?.body ?? ""
            },
            set: { newValue in
                model.updateSceneBody(sceneID, body: newValue)
            }
        )
    }

    private var sceneRTFBinding: Binding<Data?> {
        Binding(
            get: {
                model.scenes.first(where: { $0.id == sceneID })?.richTextRTF
            },
            set: { newValue in
                model.updateSceneRichText(sceneID, richTextRTF: newValue)
            }
        )
    }
}

struct AutoSizingTextView: NSViewRepresentable {
    let sceneID: UUID
    @Binding var text: String
    @Binding var richTextRTF: Data?
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let showInvisibleCharacters: Bool
    @Binding var measuredHeight: CGFloat
    let initialSelectionLocation: Int?
    let selectionAnchorChanged: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            richTextRTF: $richTextRTF,
            measuredHeight: $measuredHeight,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            initialSelectionLocation: initialSelectionLocation,
            selectionAnchorChanged: selectionAnchorChanged
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NativeSceneTextView()
        textView.sceneID = sceneID
        textView.onBoundaryNavigate = { direction, sceneID in
            NativeTextFormattingController.navigateAcrossSceneBoundary(
                from: sceneID,
                direction: direction
            )
        }
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.usesFindBar = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isAutomaticTextReplacementEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.smartInsertDeleteEnabled = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.showInvisibleCharacters = showInvisibleCharacters

        let scrollView = PassiveEditorScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView

        context.coordinator.isProgrammaticUpdate = true
        if let richTextRTF, let attributed = try? NSAttributedString(
            data: richTextRTF,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            textView.textStorage?.setAttributedString(attributed)
            context.coordinator.lastAppliedRTF = richTextRTF
        } else {
            textView.string = text
        }
        applyAppearance(to: textView)
        context.coordinator.recordAppearance(fontSize: fontSize, lineSpacing: lineSpacing)
        if let initialSelectionLocation {
            let clampedLocation = min(max(0, initialSelectionLocation), textView.string.utf16.count)
            textView.setSelectedRange(NSRange(location: clampedLocation, length: 0))
        }
        context.coordinator.isProgrammaticUpdate = false
        textView.textStorage?.delegate = context.coordinator
        NativeTextFormattingController.register(textView, sceneID: sceneID)
        context.coordinator.recalculateHeight(for: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NativeSceneTextView else { return }
        textView.sceneID = sceneID
        let isActiveEditor = textView.window?.firstResponder === textView
        context.coordinator.isProgrammaticUpdate = true
        textView.showInvisibleCharacters = showInvisibleCharacters

        if !isActiveEditor {
            if let richTextRTF,
               context.coordinator.lastAppliedRTF != richTextRTF,
               let attributed = try? NSAttributedString(
                    data: richTextRTF,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
               ) {
                textView.textStorage?.setAttributedString(attributed)
                applyAppearance(to: textView)
                context.coordinator.lastAppliedRTF = richTextRTF
            } else if textView.string != text {
                textView.string = text
            }
        }

        if context.coordinator.needsAppearanceUpdate(fontSize: fontSize, lineSpacing: lineSpacing) {
            applyAppearance(to: textView)
            context.coordinator.recordAppearance(fontSize: fontSize, lineSpacing: lineSpacing)
        }
        NativeTextFormattingController.register(textView, sceneID: sceneID)
        context.coordinator.isProgrammaticUpdate = false
        context.coordinator.recalculateHeight(for: textView)
    }

    private func applyAppearance(to textView: NSTextView) {
        let baseFont = NSFont(name: "Palatino Linotype", size: fontSize)
            ?? NSFont(name: "Iowan Old Style", size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)
        textView.font = baseFont
        textView.textColor = NativeTheme.ink1
        textView.insertionPointColor = NativeTheme.accent

        let paragraphStyle = configuredParagraphStyle(
            from: textView.defaultParagraphStyle,
            lineSpacing: lineSpacing
        )

        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: baseFont,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NativeTheme.ink1
        ]

        let range = NSRange(location: 0, length: textView.string.utf16.count)
        textView.textStorage?.beginEditing()
        textView.textStorage?.enumerateAttributes(in: range) { attributes, range, _ in
            let currentFont = (attributes[.font] as? NSFont) ?? baseFont
            let convertedFont = resizedFont(currentFont, to: fontSize)
            let mergedParagraphStyle = configuredParagraphStyle(
                from: attributes[.paragraphStyle] as? NSParagraphStyle,
                lineSpacing: lineSpacing
            )
            let foregroundColor = (attributes[.foregroundColor] as? NSColor) ?? NativeTheme.ink1
            textView.textStorage?.addAttributes([
                .font: convertedFont,
                .paragraphStyle: mergedParagraphStyle,
                .foregroundColor: foregroundColor
            ], range: range)
        }
        textView.textStorage?.endEditing()
    }

    private func configuredParagraphStyle(from existingStyle: NSParagraphStyle?, lineSpacing: CGFloat) -> NSMutableParagraphStyle {
        let paragraphStyle = (existingStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        return paragraphStyle
    }

    private func resizedFont(_ font: NSFont, to pointSize: CGFloat) -> NSFont {
        let descriptor = font.fontDescriptor.withSize(pointSize)
        return NSFont(descriptor: descriptor, size: pointSize) ?? NSFont.systemFont(ofSize: pointSize)
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        @Binding var text: String
        @Binding var richTextRTF: Data?
        @Binding var measuredHeight: CGFloat
        let initialSelectionLocation: Int?
        let selectionAnchorChanged: (Int) -> Void
        var lastAppliedRTF: Data?
        var isProgrammaticUpdate = false
        private var pendingPlainTextSyncWorkItem: DispatchWorkItem?
        private var pendingRTFSyncWorkItem: DispatchWorkItem?
        private var pendingSelectionAnchorWorkItem: DispatchWorkItem?
        private var lastFontSize: CGFloat
        private var lastLineSpacing: CGFloat
        private static let plainTextSyncDelay: TimeInterval = 0.45
        private static let rtfSyncDelay: TimeInterval = 1.2
        private static let selectionAnchorDelay: TimeInterval = 0.9

        init(
            text: Binding<String>,
            richTextRTF: Binding<Data?>,
            measuredHeight: Binding<CGFloat>,
            fontSize: CGFloat,
            lineSpacing: CGFloat,
            initialSelectionLocation: Int?,
            selectionAnchorChanged: @escaping (Int) -> Void
        ) {
            _text = text
            _richTextRTF = richTextRTF
            _measuredHeight = measuredHeight
            lastFontSize = fontSize
            lastLineSpacing = lineSpacing
            self.initialSelectionLocation = initialSelectionLocation
            self.selectionAnchorChanged = selectionAnchorChanged
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isProgrammaticUpdate else { return }
            guard !NativeTextFormattingController.isPerformingProgrammaticEdit(on: textView) else { return }
            NativeTextFormattingController.register(textView)
            NativeTextFormattingController.registerSelection(textView.selectedRanges)
            schedulePlainTextSync(from: textView)
            scheduleRTFSync(from: textView)
            recalculateHeight(for: textView)
        }

        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard !isProgrammaticUpdate else { return }
            guard let textView = textStorage.layoutManagers.first?.firstTextView else { return }
            guard !NativeTextFormattingController.isPerformingProgrammaticEdit(on: textView) else { return }
            if editedMask.contains(.editedCharacters) {
                NativeTextFormattingController.handleManualReviewEdit(
                    in: textView,
                    editedRange: editedRange,
                    changeInLength: delta
                )
            }
            guard editedMask.contains(.editedAttributes) || editedMask.contains(.editedCharacters) else { return }
            NativeTextFormattingController.register(textView)
            NativeTextFormattingController.registerSelection(textView.selectedRanges)
            if editedMask.contains(.editedAttributes) {
                scheduleRTFSync(from: textView)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            NativeTextFormattingController.register(textView)
            NativeTextFormattingController.registerSelection(textView.selectedRanges)
            scheduleSelectionAnchorSync(location: textView.safeSelectedRange.location)
            if textView.window?.firstResponder === textView {
                textView.reveal(range: textView.safeSelectedRange)
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            flushPlainTextSync(from: textView)
            flushRTFSync(from: textView)
            flushSelectionAnchorSync(location: textView.safeSelectedRange.location)
        }

        func recalculateHeight(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let nextHeight = ceil(usedRect.height + (textView.textContainerInset.height * 2) + 12)
            if abs(measuredHeight - nextHeight) > 1 {
                DispatchQueue.main.async {
                    self.measuredHeight = nextHeight
                }
            }
        }

        private func schedulePlainTextSync(from textView: NSTextView) {
            pendingPlainTextSyncWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.flushPlainTextSync(from: textView)
            }
            pendingPlainTextSyncWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.plainTextSyncDelay, execute: workItem)
        }

        private func flushPlainTextSync(from textView: NSTextView) {
            pendingPlainTextSyncWorkItem?.cancel()
            pendingPlainTextSyncWorkItem = nil
            let nextText = textView.string
            if text != nextText {
                text = nextText
            }
        }

        private func scheduleRTFSync(from textView: NSTextView) {
            pendingRTFSyncWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak textView] in
                guard let self, let textView else { return }
                let nextRTF = textView.rtfData()
                if self.richTextRTF != nextRTF {
                    self.richTextRTF = nextRTF
                }
                self.lastAppliedRTF = nextRTF
            }
            pendingRTFSyncWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.rtfSyncDelay, execute: workItem)
        }

        private func flushRTFSync(from textView: NSTextView) {
            pendingRTFSyncWorkItem?.cancel()
            pendingRTFSyncWorkItem = nil
            let nextRTF = textView.rtfData()
            if richTextRTF != nextRTF {
                richTextRTF = nextRTF
            }
            lastAppliedRTF = nextRTF
        }

        private func scheduleSelectionAnchorSync(location: Int) {
            pendingSelectionAnchorWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.selectionAnchorChanged(location)
            }
            pendingSelectionAnchorWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.selectionAnchorDelay, execute: workItem)
        }

        private func flushSelectionAnchorSync(location: Int) {
            pendingSelectionAnchorWorkItem?.cancel()
            pendingSelectionAnchorWorkItem = nil
            selectionAnchorChanged(location)
        }

        func needsAppearanceUpdate(fontSize: CGFloat, lineSpacing: CGFloat) -> Bool {
            abs(lastFontSize - fontSize) > 0.5 || abs(lastLineSpacing - lineSpacing) > 0.5
        }

        func recordAppearance(fontSize: CGFloat, lineSpacing: CGFloat) {
            lastFontSize = fontSize
            lastLineSpacing = lineSpacing
        }
    }
}

struct ContinuousSelectionTextEditor: NSViewRepresentable {
    let scenes: [NativeScene]
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let showInvisibleCharacters: Bool
    @Binding var measuredHeight: CGFloat
    let onSceneBodiesChanged: ([(sceneID: UUID, body: String)]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            scenes: scenes,
            measuredHeight: $measuredHeight,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            onSceneBodiesChanged: onSceneBodiesChanged
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NativeSceneTextView()
        context.coordinator.textView = textView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isAutomaticTextReplacementEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.smartInsertDeleteEnabled = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.showInvisibleCharacters = showInvisibleCharacters

        let scrollView = PassiveEditorScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView

        context.coordinator.isProgrammaticUpdate = true
        context.coordinator.rebuildText(using: scenes, in: textView)
        applyAppearance(to: textView)
        context.coordinator.recordAppearance(fontSize: fontSize, lineSpacing: lineSpacing)
        context.coordinator.isProgrammaticUpdate = false
        textView.textStorage?.delegate = context.coordinator
        NativeTextFormattingController.register(textView)
        context.coordinator.recalculateHeight(for: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NativeSceneTextView else { return }
        context.coordinator.onSceneBodiesChanged = onSceneBodiesChanged
        textView.showInvisibleCharacters = showInvisibleCharacters
        if context.coordinator.needsRebuild(for: scenes) {
            context.coordinator.isProgrammaticUpdate = true
            context.coordinator.rebuildText(using: scenes, in: textView)
            applyAppearance(to: textView)
            context.coordinator.isProgrammaticUpdate = false
        }
        if context.coordinator.needsAppearanceUpdate(fontSize: fontSize, lineSpacing: lineSpacing) {
            applyAppearance(to: textView)
            context.coordinator.recordAppearance(fontSize: fontSize, lineSpacing: lineSpacing)
        }
        NativeTextFormattingController.register(textView)
        context.coordinator.recalculateHeight(for: textView)
    }

    private func applyAppearance(to textView: NSTextView) {
        let baseFont = NSFont(name: "Palatino Linotype", size: fontSize)
            ?? NSFont(name: "Iowan Old Style", size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)
        textView.font = baseFont
        textView.textColor = NativeTheme.ink1
        textView.insertionPointColor = NativeTheme.accent

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: baseFont,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NativeTheme.ink1
        ]

        let range = NSRange(location: 0, length: textView.string.utf16.count)
        textView.textStorage?.setAttributes([
            .font: baseFont,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NativeTheme.ink1
        ], range: range)
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        private static let separatorText = "\n\n"
        @Binding var measuredHeight: CGFloat
        var onSceneBodiesChanged: ([(sceneID: UUID, body: String)]) -> Void
        var isProgrammaticUpdate = false
        weak var textView: NativeSceneTextView?
        private var segmentDescriptors: [SegmentDescriptor] = []
        private var dividerRanges: [NSRange] = []
        private var lastSceneSignature: String = ""
        private var lastFontSize: CGFloat
        private var lastLineSpacing: CGFloat

        init(
            scenes: [NativeScene],
            measuredHeight: Binding<CGFloat>,
            fontSize: CGFloat,
            lineSpacing: CGFloat,
            onSceneBodiesChanged: @escaping ([(sceneID: UUID, body: String)]) -> Void
        ) {
            _measuredHeight = measuredHeight
            self.onSceneBodiesChanged = onSceneBodiesChanged
            self.lastFontSize = fontSize
            self.lastLineSpacing = lineSpacing
            super.init()
            self.lastSceneSignature = Self.signature(for: scenes)
        }

        func rebuildText(using scenes: [NativeScene], in textView: NSTextView) {
            segmentDescriptors = []
            dividerRanges = []
            let combined = NSMutableString()
            var cursor = 0
            for (index, scene) in scenes.enumerated() {
                let body = scene.body
                let bodyLength = (body as NSString).length
                segmentDescriptors.append(SegmentDescriptor(sceneID: scene.id, location: cursor, length: bodyLength))
                combined.append(body)
                cursor += bodyLength
                if index < scenes.count - 1 {
                    let dividerRange = NSRange(location: cursor, length: Self.separatorText.utf16.count)
                    dividerRanges.append(dividerRange)
                    combined.append(Self.separatorText)
                    cursor += dividerRange.length
                }
            }
            textView.string = combined as String
            refreshDividerRanges(in: textView as? NativeSceneTextView)
            lastSceneSignature = Self.signature(for: scenes)
        }

        func needsRebuild(for scenes: [NativeScene]) -> Bool {
            Self.signature(for: scenes) != lastSceneSignature
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isProgrammaticUpdate else { return }
            syncSceneBodies(from: textView.string as NSString)
            recalculateHeight(for: textView)
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard !isProgrammaticUpdate else { return true }
            if affectedCharRange.length > 0, affectedCharRange.intersectsAny(of: dividerRanges) {
                return false
            }
            return true
        }

        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            guard !isProgrammaticUpdate else { return }
            updateSegments(forEditedRange: editedRange, delta: delta)
        }

        func recalculateHeight(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let nextHeight = ceil(usedRect.height + (textView.textContainerInset.height * 2) + 12)
            if abs(measuredHeight - nextHeight) > 1 {
                DispatchQueue.main.async {
                    self.measuredHeight = nextHeight
                }
            }
        }

        func needsAppearanceUpdate(fontSize: CGFloat, lineSpacing: CGFloat) -> Bool {
            abs(lastFontSize - fontSize) > 0.5 || abs(lastLineSpacing - lineSpacing) > 0.5
        }

        func recordAppearance(fontSize: CGFloat, lineSpacing: CGFloat) {
            lastFontSize = fontSize
            lastLineSpacing = lineSpacing
        }

        private func syncSceneBodies(from fullText: NSString) {
            normalizeSegments(totalLength: fullText.length)
            let updates = segmentDescriptors.map { descriptor in
                let safeLocation = min(max(0, descriptor.location), fullText.length)
                let safeLength = min(max(0, descriptor.length), fullText.length - safeLocation)
                return (sceneID: descriptor.sceneID, body: fullText.substring(with: NSRange(location: safeLocation, length: safeLength)))
            }
            lastSceneSignature = Self.signature(for: updates)
            onSceneBodiesChanged(updates)
        }

        private func updateSegments(forEditedRange editedRange: NSRange, delta: Int) {
            guard !segmentDescriptors.isEmpty else { return }
            let replacedLength = editedRange.length - delta
            if replacedLength == 0, delta > 0 {
                applyInsertion(ofLength: delta, at: editedRange.location)
                return
            }
            let oldEditedRange = NSRange(location: editedRange.location, length: max(0, replacedLength))
            let oldEditedEnd = NSMaxRange(oldEditedRange)
            var firstOverlappingIndex: Int?

            for index in segmentDescriptors.indices {
                let segment = segmentDescriptors[index]
                let segmentStart = segment.location
                let segmentEnd = segment.location + segment.length

                if segmentEnd <= oldEditedRange.location {
                    continue
                } else if segmentStart >= oldEditedEnd {
                    segmentDescriptors[index].location += delta
                } else {
                    if firstOverlappingIndex == nil {
                        firstOverlappingIndex = index
                    }
                    let prefixLength = max(0, min(oldEditedRange.location, segmentEnd) - segmentStart)
                    let suffixLength = max(0, segmentEnd - max(oldEditedEnd, segmentStart))
                    let insertedLength = firstOverlappingIndex == index ? editedRange.length : 0
                    segmentDescriptors[index].length = max(0, prefixLength + insertedLength + suffixLength)
                    if segmentStart > oldEditedRange.location {
                        segmentDescriptors[index].location = editedRange.location
                    }
                }
            }

            recomputeLayout()
        }

        private func applyInsertion(ofLength insertedLength: Int, at location: Int) {
            guard insertedLength > 0 else { return }

            let ownerIndex = segmentDescriptors.firstIndex { descriptor in
                let start = descriptor.location
                let end = descriptor.location + descriptor.length
                return location >= start && location <= end
            } ?? max(0, segmentDescriptors.count - 1)

            for index in segmentDescriptors.indices {
                if index == ownerIndex {
                    segmentDescriptors[index].length += insertedLength
                }
            }

            recomputeLayout()
        }

        private func normalizeSegments(totalLength: Int) {
            guard !segmentDescriptors.isEmpty else { return }
            for index in segmentDescriptors.indices {
                segmentDescriptors[index].length = max(0, segmentDescriptors[index].length)
            }

            let expectedLength = segmentDescriptors.reduce(0) { $0 + $1.length } + separatorTotalLength
            let delta = totalLength - expectedLength
            if delta != 0, let lastIndex = segmentDescriptors.indices.last {
                segmentDescriptors[lastIndex].length = max(0, segmentDescriptors[lastIndex].length + delta)
            }

            recomputeLayout()
        }

        private func recomputeLayout() {
            dividerRanges = []
            var cursor = 0
            for index in segmentDescriptors.indices {
                segmentDescriptors[index].location = cursor
                cursor += segmentDescriptors[index].length
                if index < segmentDescriptors.count - 1 {
                    let dividerRange = NSRange(location: cursor, length: Self.separatorText.utf16.count)
                    dividerRanges.append(dividerRange)
                    cursor += dividerRange.length
                }
            }
            refreshDividerRanges()
        }

        private func refreshDividerRanges(in textView: NativeSceneTextView? = nil) {
            let targetTextView = textView ?? self.textView
            targetTextView?.dividerRanges = dividerRanges
            targetTextView?.needsDisplay = true
        }

        private var separatorTotalLength: Int {
            max(0, segmentDescriptors.count - 1) * Self.separatorText.utf16.count
        }

        private static func signature(for scenes: [NativeScene]) -> String {
            scenes.map { "\($0.id.uuidString):\($0.body)" }.joined(separator: "\u{1F}")
        }

        private static func signature(for updates: [(sceneID: UUID, body: String)]) -> String {
            updates.map { "\($0.sceneID.uuidString):\($0.body)" }.joined(separator: "\u{1F}")
        }

        private struct SegmentDescriptor {
            let sceneID: UUID
            var location: Int
            var length: Int
        }
    }
}

final class PassiveEditorScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

final class NativeSceneTextView: NSTextView {
    enum BoundaryDirection {
        case up
        case down
    }

    var sceneID: UUID?
    var onBoundaryNavigate: ((BoundaryDirection, UUID) -> Bool)?
    var reviewHighlights: [NativeAssistantReviewIssue] = []
    var activeReviewIssueID: UUID?
    var findHighlightRanges: [NSRange] = []
    var activeFindHighlightRange: NSRange?
    var dividerRanges: [NSRange] = []
    var showInvisibleCharacters = false {
        didSet {
            guard oldValue != showInvisibleCharacters else { return }
            needsDisplay = true
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "g",
           NativeTextFormattingController.performFindNext() {
            return
        }
        guard let sceneID,
              let direction = boundaryDirection(for: event),
              selectedRange().length == 0,
              shouldNavigateAcrossBoundary(direction),
              onBoundaryNavigate?(direction, sceneID) == true else {
            super.keyDown(with: event)
            revealAfterDocumentJumpIfNeeded(for: event)
            return
        }
    }

    override func moveToBeginningOfDocument(_ sender: Any?) {
        super.moveToBeginningOfDocument(sender)
        reveal(range: safeSelectedRange)
    }

    override func moveToEndOfDocument(_ sender: Any?) {
        super.moveToEndOfDocument(sender)
        reveal(range: safeSelectedRange)
    }

    override func deleteBackward(_ sender: Any?) {
        guard !shouldBlockBoundaryDeletion(backward: true) else { return }
        super.deleteBackward(sender)
    }

    override func deleteForward(_ sender: Any?) {
        guard !shouldBlockBoundaryDeletion(backward: false) else { return }
        super.deleteForward(sender)
    }

    override func paste(_ sender: Any?) {
        guard isEditable else {
            super.paste(sender)
            return
        }

        let pasteboard = NSPasteboard.general
        guard let pastedString = pasteboard.string(forType: .string), !pastedString.isEmpty else {
            super.paste(sender)
            return
        }

        let normalizedText = pastedString
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let replacementRange = selectedRange()

        if let delegate = delegate,
           delegate.responds(to: #selector(NSTextViewDelegate.textView(_:shouldChangeTextIn:replacementString:))),
           delegate.textView?(self, shouldChangeTextIn: replacementRange, replacementString: normalizedText) == false {
            return
        }

        let pasteAttributes = normalizedPasteAttributes()
        if let textStorage {
            textStorage.beginEditing()
            textStorage.replaceCharacters(
                in: replacementRange,
                with: NSAttributedString(string: normalizedText, attributes: pasteAttributes)
            )
            textStorage.endEditing()
            didChangeText()
        } else {
            insertText(NSAttributedString(string: normalizedText, attributes: pasteAttributes), replacementRange: replacementRange)
        }
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        drawSceneDividers(in: rect)
        drawFindHighlights(in: rect)
        drawReviewHighlights(in: rect)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawInvisibleCharacters(in: dirtyRect)
    }

    private func boundaryDirection(for event: NSEvent) -> BoundaryDirection? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.isEmpty else { return nil }
        switch event.keyCode {
        case 126:
            return .up
        case 125:
            return .down
        default:
            return nil
        }
    }

    private func shouldNavigateAcrossBoundary(_ direction: BoundaryDirection) -> Bool {
        switch direction {
        case .up:
            return caretIsOnFirstVisualLine
        case .down:
            return caretIsOnLastVisualLine
        }
    }

    private var caretIsOnFirstVisualLine: Bool {
        guard let layoutManager, let textContainer else { return false }
        let safeRange = safeSelectedRange
        let stringLength = string.utf16.count
        let characterLocation = min(max(0, safeRange.location), max(0, stringLength - 1))
        guard stringLength > 0 else { return true }
        layoutManager.ensureLayout(for: textContainer)
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterLocation)
        var effectiveRange = NSRange(location: 0, length: 0)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
        return lineRect.minY <= 1
    }

    private var caretIsOnLastVisualLine: Bool {
        guard let layoutManager, let textContainer else { return false }
        let stringLength = string.utf16.count
        guard stringLength > 0 else { return true }
        let safeRange = safeSelectedRange
        let characterLocation = min(max(0, safeRange.location), max(0, stringLength - 1))
        layoutManager.ensureLayout(for: textContainer)
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterLocation)
        var effectiveRange = NSRange(location: 0, length: 0)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
        let usedRect = layoutManager.usedRect(for: textContainer)
        return lineRect.maxY >= (usedRect.maxY - 1)
    }

    private func drawReviewHighlights(in dirtyRect: NSRect) {
        guard let layoutManager, let textContainer, !reviewHighlights.isEmpty else { return }
        layoutManager.ensureLayout(for: textContainer)
        for issue in reviewHighlights {
            let safeRange = rangeClampedToString(issue.range)
            guard safeRange.location != NSNotFound, safeRange.length > 0 else { continue }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: safeRange, actualCharacterRange: nil)
            guard !issue.isStale else { continue }
            let fillColor = issue.id == activeReviewIssueID
                ? NativeTheme.accent.withAlphaComponent(0.26)
                : NativeTheme.accentSoft.withAlphaComponent(0.33)
            let strokeColor = issue.id == activeReviewIssueID
                ? NativeTheme.accentStrong
                : NativeTheme.accent.withAlphaComponent(0.7)

            layoutManager.enumerateEnclosingRects(
                forGlyphRange: glyphRange,
                withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                in: textContainer
            ) { rect, _ in
                var drawRect = rect.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y)
                drawRect = drawRect.insetBy(dx: -2, dy: -1)
                guard drawRect.intersects(dirtyRect) else { return }
                let path = NSBezierPath(roundedRect: drawRect, xRadius: 4, yRadius: 4)
                fillColor.setFill()
                path.fill()
                strokeColor.setStroke()
                path.lineWidth = issue.id == self.activeReviewIssueID ? 1.2 : 0.8
                path.stroke()
            }
        }
    }

    private func drawInvisibleCharacters(in dirtyRect: NSRect) {
        guard showInvisibleCharacters else { return }
        guard let layoutManager, let textContainer else { return }

        let textNSString = string as NSString
        guard textNSString.length > 0 else { return }

        layoutManager.ensureLayout(for: textContainer)

        let markerColor = NativeTheme.muted.withAlphaComponent(0.72)
        let markerFont = NSFont.systemFont(ofSize: max(10, font?.pointSize ?? 12 * 0.62), weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: markerFont,
            .foregroundColor: markerColor
        ]

        for index in 0..<textNSString.length {
            let character = textNSString.character(at: index)
            let symbol: String

            switch character {
            case 32:
                symbol = "·"
            case 9:
                symbol = "⇥"
            case 10, 13:
                symbol = "¶"
            default:
                continue
            }

            guard let markerPoint = markerPoint(forCharacterAt: index, symbol: symbol, attributes: attributes) else {
                continue
            }

            let markerSize = (symbol as NSString).size(withAttributes: attributes)
            let markerRect = NSRect(origin: markerPoint, size: markerSize)
            guard markerRect.intersects(dirtyRect.insetBy(dx: -24, dy: -24)) else { continue }
            (symbol as NSString).draw(at: markerPoint, withAttributes: attributes)
        }
    }

    private func markerPoint(
        forCharacterAt characterIndex: Int,
        symbol: String,
        attributes: [NSAttributedString.Key: Any]
    ) -> CGPoint? {
        guard let layoutManager, let textContainer else { return nil }

        let stringLength = string.utf16.count
        guard stringLength > 0, characterIndex >= 0, characterIndex < stringLength else { return nil }

        let markerSize = (symbol as NSString).size(withAttributes: attributes)
        let textOrigin = textContainerOrigin

        if let scalar = UnicodeScalar(Int((string as NSString).character(at: characterIndex))),
           CharacterSet.newlines.contains(scalar) {
            let anchorIndex = max(0, min(characterIndex - 1, stringLength - 1))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: anchorIndex)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let usedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let x = textOrigin.x + max(lineRect.minX + 2, usedRect.maxX + 2)
            let y = textOrigin.y + lineRect.midY - (markerSize.height / 2)
            return CGPoint(x: x, y: y)
        }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: characterIndex, length: 1), actualCharacterRange: nil)
        var glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        if glyphRect.isEmpty {
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
            glyphRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        }

        let x = textOrigin.x + glyphRect.midX - (markerSize.width / 2)
        let y = textOrigin.y + glyphRect.midY - (markerSize.height / 2)
        return CGPoint(x: x, y: y)
    }

    private func drawFindHighlights(in dirtyRect: NSRect) {
        guard let layoutManager, let textContainer, !findHighlightRanges.isEmpty else { return }
        layoutManager.ensureLayout(for: textContainer)

        for range in findHighlightRanges {
            let safeRange = rangeClampedToString(range)
            guard safeRange.location != NSNotFound, safeRange.length > 0 else { continue }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: safeRange, actualCharacterRange: nil)
            let isActive = activeFindHighlightRange == safeRange
            let fillColor = isActive
                ? NativeTheme.accent.withAlphaComponent(0.24)
                : NativeTheme.selection.withAlphaComponent(0.26)
            let strokeColor = isActive
                ? NativeTheme.accentStrong
                : NativeTheme.accent.withAlphaComponent(0.55)

            layoutManager.enumerateEnclosingRects(
                forGlyphRange: glyphRange,
                withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                in: textContainer
            ) { rect, _ in
                var drawRect = rect.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y)
                drawRect = drawRect.insetBy(dx: -1, dy: 0)
                guard drawRect.intersects(dirtyRect) else { return }
                let path = NSBezierPath(roundedRect: drawRect, xRadius: 3, yRadius: 3)
                fillColor.setFill()
                path.fill()
                strokeColor.setStroke()
                path.lineWidth = isActive ? 1.2 : 0.7
                path.stroke()
            }
        }
    }

    private func drawSceneDividers(in dirtyRect: NSRect) {
        guard let layoutManager, let textContainer, !dividerRanges.isEmpty else { return }
        layoutManager.ensureLayout(for: textContainer)

        for dividerRange in dividerRanges {
            guard dividerRange.location < string.utf16.count else { continue }
            let anchorLocation = min(max(0, dividerRange.location + max(0, dividerRange.length - 1)), max(0, string.utf16.count - 1))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: anchorLocation)
            var effectiveRange = NSRange(location: 0, length: 0)
            var rect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
            rect.origin.x += textContainerOrigin.x
            rect.origin.y += textContainerOrigin.y
            let lineY = rect.midY
            guard dirtyRect.intersects(NSRect(x: 0, y: lineY - 8, width: bounds.width, height: 16)) else { continue }

            let path = NSBezierPath()
            path.move(to: NSPoint(x: textContainerOrigin.x + 8, y: lineY))
            path.line(to: NSPoint(x: bounds.width - textContainerOrigin.x - 8, y: lineY))
            path.lineWidth = 1
            let dashPattern: [CGFloat] = [6, 6]
            path.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
            NativeTheme.border.withAlphaComponent(0.85).setStroke()
            path.stroke()
        }
    }

    private func shouldBlockBoundaryDeletion(backward: Bool) -> Bool {
        let selection = selectedRange()
        if selection.location == NSNotFound {
            return false
        }

        if selection.length > 0 {
            return selection.intersectsAny(of: dividerRanges)
        }

        let protectedLocation = backward ? max(0, selection.location - 1) : selection.location
        return dividerRanges.contains { NSLocationInRange(protectedLocation, $0) }
    }

    private func revealAfterDocumentJumpIfNeeded(for event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers == .command else { return }
        guard event.keyCode == 126 || event.keyCode == 125 else { return }
        reveal(range: safeSelectedRange)
    }

    private func normalizedPasteAttributes() -> [NSAttributedString.Key: Any] {
        var attributes = typingAttributes
        if attributes[.font] == nil {
            attributes[.font] = font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }
        if attributes[.foregroundColor] == nil {
            attributes[.foregroundColor] = textColor ?? NativeTheme.ink1
        }
        if attributes[.paragraphStyle] == nil, let defaultParagraphStyle {
            attributes[.paragraphStyle] = defaultParagraphStyle
        }
        return attributes
    }
}

enum NativeTextFormattingController {
    private weak static var lastKnownTextView: NSTextView?
    private static var lastKnownSceneID: UUID?
    private static var lastKnownSelectedRanges: [NSValue] = []
    private static var lastKnownSelectedText: String?
    private static var programmaticallyEditingTextViews: Set<ObjectIdentifier> = []
    private static var textViewBySceneID: [UUID: WeakNativeTextViewBox] = [:]
    private static var sceneIDByTextViewIdentifier: [ObjectIdentifier: UUID] = [:]
    private static var pendingFocusRequest: (sceneID: UUID, range: NSRange)?
    private static var sceneNavigationOrder: [UUID] = []
    private static var reviewIssuesBySceneID: [UUID: [NativeAssistantReviewIssue]] = [:]
    private static var activeReviewIssueID: UUID?
    private static var lastReportedReviewIssueID: UUID?
    private static var findHighlightRangesBySceneID: [UUID: [NSRange]] = [:]
    private static var activeFindHighlightBySceneID: [UUID: NSRange] = [:]
    private static var performFindNextHandler: (() -> Void)?

    static func register(_ textView: NSTextView, sceneID: UUID? = nil) {
        lastKnownTextView = textView
        if let sceneID {
            textViewBySceneID[sceneID] = WeakNativeTextViewBox(textView)
            sceneIDByTextViewIdentifier[ObjectIdentifier(textView)] = sceneID
            lastKnownSceneID = sceneID
            applyFindHighlights(to: textView, sceneID: sceneID)
            applyReviewHighlights(to: textView, sceneID: sceneID)
            if let pendingFocusRequest, pendingFocusRequest.sceneID == sceneID {
                self.pendingFocusRequest = nil
                _ = focus(sceneID: sceneID, range: pendingFocusRequest.range)
            }
        } else if let mappedSceneID = sceneIDByTextViewIdentifier[ObjectIdentifier(textView)] {
            lastKnownSceneID = mappedSceneID
            applyFindHighlights(to: textView, sceneID: mappedSceneID)
            applyReviewHighlights(to: textView, sceneID: mappedSceneID)
        }
        pruneReleasedTextViews()
        NativeFormattingToolbarState.shared.update(from: textView)
    }

    static func isPerformingProgrammaticEdit(on textView: NSTextView) -> Bool {
        programmaticallyEditingTextViews.contains(ObjectIdentifier(textView))
    }

    static func registerSelection(_ selectedRanges: [NSValue]) {
        if containsExpandedSelection(selectedRanges) {
            lastKnownSelectedRanges = selectedRanges
            if let textView = lastKnownTextView {
                lastKnownSelectedText = textView.selectedText(from: selectedRanges)
            }
        }
        syncActiveReviewIssueFromSelection()
        NativeFormattingToolbarState.shared.update(from: lastKnownTextView)
    }

    static func toggleBold() {
        mutateActiveTextView { textView in
            toggleTrait(.boldFontMask, in: textView)
        }
    }

    static func toggleItalic() {
        mutateActiveTextView { textView in
            toggleTrait(.italicFontMask, in: textView)
        }
    }

    static func toggleUnderline() {
        mutateActiveTextView { textView in
            toggleUnderline(in: textView)
        }
    }

    static func toggleBulletList() {
        mutateActiveTextView(restoreCachedSelection: false) { textView in
            toggleBulletList(in: textView)
        }
    }

    static func undo() {
        mutateActiveTextView(restoreCachedSelection: false) { textView in
            guard textView.undoManager?.canUndo == true else { return }
            textView.undoManager?.undo()
            revealSelection(in: textView)
        }
    }

    static func redo() {
        mutateActiveTextView(restoreCachedSelection: false) { textView in
            guard textView.undoManager?.canRedo == true else { return }
            textView.undoManager?.redo()
            revealSelection(in: textView)
        }
    }

    static func setAlignment(_ alignment: NSTextAlignment) {
        mutateActiveTextView { textView in
            applyAlignment(alignment, in: textView)
        }
    }

    static func setTextColor(_ color: NSColor) {
        mutateActiveTextView { textView in
            applyTextColor(color, in: textView)
        }
    }

    static func currentSelectedText() -> String? {
        guard let textView = activeTextView() else { return lastKnownSelectedText }
        let selectedRange = textView.safeSelectedRange
        if selectedRange.location != NSNotFound, selectedRange.length > 0 {
            let selectedText = (textView.string as NSString).substring(with: selectedRange)
            lastKnownSelectedText = selectedText
            return selectedText
        }
        return lastKnownSelectedText
    }

    static func currentLiveSelectedText() -> String? {
        pruneReleasedTextViews()
        let editorTextView = editorContextTextView()
        let selectedRange = editorTextView?.safeSelectedRange ?? NSRange(location: NSNotFound, length: 0)
        guard selectedRange.location != NSNotFound, selectedRange.length > 0, let editorTextView else {
            return nil
        }
        return (editorTextView.string as NSString).substring(with: selectedRange)
    }

    static func currentFindSelectionContext() -> NativeFindSelectionContext? {
        guard let textView = activeTextView() else { return nil }
        let selectedRange = textView.safeSelectedRange
        guard selectedRange.location != NSNotFound, selectedRange.length > 0 else { return nil }
        guard let sceneID = sceneIDByTextViewIdentifier[ObjectIdentifier(textView)] ?? lastKnownSceneID else { return nil }
        let sceneTitle = "Scene"
        return NativeFindSelectionContext(
            sceneID: sceneID,
            sceneTitle: sceneTitle,
            text: textView.string,
            selectedRange: selectedRange
        )
    }

    static func hasLiveTextView(for sceneID: UUID) -> Bool {
        pruneReleasedTextViews()
        return textViewBySceneID[sceneID]?.textView != nil
    }

    static func setSceneNavigationOrder(_ sceneIDs: [UUID]) {
        sceneNavigationOrder = sceneIDs
    }

    static func queuePendingFocus(sceneID: UUID, range: NSRange) {
        pendingFocusRequest = (sceneID, range)
    }

    static func focusOrQueue(sceneID: UUID, range: NSRange) {
        if !focus(sceneID: sceneID, range: range) {
            queuePendingFocus(sceneID: sceneID, range: range)
        }
    }

    static func navigateAcrossSceneBoundary(from sceneID: UUID, direction: NativeSceneTextView.BoundaryDirection) -> Bool {
        guard let currentIndex = sceneNavigationOrder.firstIndex(of: sceneID) else { return false }
        let targetIndex: Int
        let targetRange: NSRange

        switch direction {
        case .up:
            guard currentIndex > 0 else { return false }
            targetIndex = currentIndex - 1
            targetRange = NSRange(location: Int.max - 1, length: 0)
        case .down:
            guard currentIndex < sceneNavigationOrder.count - 1 else { return false }
            targetIndex = currentIndex + 1
            targetRange = NSRange(location: 0, length: 0)
        }

        let targetSceneID = sceneNavigationOrder[targetIndex]
        focusOrQueue(sceneID: targetSceneID, range: targetRange)
        return true
    }

    static func showReviewIssues(_ issues: [NativeAssistantReviewIssue]) {
        reviewIssuesBySceneID = Dictionary(grouping: issues, by: \.sceneID)
        activeReviewIssueID = issues.first?.id
        refreshReviewHighlights()
        postActiveReviewIssueChanged()
    }

    static func clearReviewIssues() {
        reviewIssuesBySceneID = [:]
        activeReviewIssueID = nil
        lastReportedReviewIssueID = nil
        refreshReviewHighlights()
        postActiveReviewIssueChanged()
    }

    static func activateReviewIssue(_ issue: NativeAssistantReviewIssue) {
        activeReviewIssueID = issue.id
        refreshReviewHighlights()
        postActiveReviewIssueChanged()
        focusOrQueue(sceneID: issue.sceneID, range: issue.range)
    }

    static func applyReviewIssue(_ issue: NativeAssistantReviewIssue) -> Bool {
        guard let replacement = issue.replacement else { return false }
        guard replaceText(in: issue.sceneID, range: issue.range, with: replacement) else { return false }
        updateReviewIssuesAfterReplacement(
            sceneID: issue.sceneID,
            replacedRange: issue.range,
            replacementLength: (replacement as NSString).length,
            removedIssueID: issue.id
        )
        return true
    }

    static func handleManualReviewEdit(in textView: NSTextView, editedRange: NSRange, changeInLength delta: Int) {
        guard let sceneID = sceneIDByTextViewIdentifier[ObjectIdentifier(textView)] else { return }
        guard let sceneIssues = reviewIssuesBySceneID[sceneID], !sceneIssues.isEmpty else { return }

        let replacementLength = editedRange.length
        let originalLength = max(0, replacementLength - delta)
        let originalRange = NSRange(location: editedRange.location, length: originalLength)
        let updatedText = textView.string

        let updatedSceneIssues = updateReviewIssuesForManualEdit(
            issues: sceneIssues,
            originalEditedRange: originalRange,
            replacementLength: replacementLength,
            updatedText: updatedText
        )
        reviewIssuesBySceneID[sceneID] = updatedSceneIssues.isEmpty ? nil : updatedSceneIssues
        refreshReviewHighlights()
        postUpdatedReviewIssues()
    }

    static func showFindHighlights(matches: [NativeFindMatch], activeMatch: NativeFindMatch?) {
        findHighlightRangesBySceneID = Dictionary(grouping: matches, by: \.sceneID)
            .mapValues { $0.map(\.range) }
        if let activeMatch {
            activeFindHighlightBySceneID = [activeMatch.sceneID: activeMatch.range]
        } else {
            activeFindHighlightBySceneID = [:]
        }
        refreshFindHighlights()
    }

    static func clearFindHighlights() {
        findHighlightRangesBySceneID = [:]
        activeFindHighlightBySceneID = [:]
        refreshFindHighlights()
    }

    static func setPerformFindNextHandler(_ handler: (() -> Void)?) {
        performFindNextHandler = handler
    }

    @discardableResult
    static func performFindNext() -> Bool {
        guard let performFindNextHandler else { return false }
        performFindNextHandler()
        return true
    }

    @discardableResult
    static func focus(sceneID: UUID, range: NSRange) -> Bool {
        pruneReleasedTextViews()
        guard let textView = textViewBySceneID[sceneID]?.textView else { return false }
        let clampedRange = textView.rangeClampedToString(range)
        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(clampedRange)
        textView.scrollRangeToVisible(clampedRange)
        textView.reveal(range: clampedRange)
        if clampedRange.length > 0 {
            textView.showFindIndicator(for: clampedRange)
        }
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(clampedRange)
            textView.scrollRangeToVisible(clampedRange)
            textView.reveal(range: clampedRange)
        }
        register(textView, sceneID: sceneID)
        return true
    }

    @discardableResult
    static func replaceText(in sceneID: UUID, range: NSRange, with replacement: String) -> Bool {
        pruneReleasedTextViews()
        guard let textView = textViewBySceneID[sceneID]?.textView else { return false }
        let clampedRange = textView.rangeClampedToString(range)
        guard clampedRange.location != NSNotFound else { return false }
        textView.window?.makeFirstResponder(textView)
        textView.breakUndoCoalescing()
        guard textView.shouldChangeText(in: clampedRange, replacementString: replacement) else {
            return false
        }

        beginProgrammaticEdit(on: textView)
        textView.textStorage?.replaceCharacters(in: clampedRange, with: replacement)
        let nextLocation = min(clampedRange.location + (replacement as NSString).length, textView.string.utf16.count)
        textView.setSelectedRange(NSRange(location: nextLocation, length: 0))
        endProgrammaticEdit(on: textView)
        textView.didChangeText()
        textView.breakUndoCoalescing()
        textView.undoManager?.setActionName("Replace")
        register(textView, sceneID: sceneID)
        return true
    }

    static func replaceSelection(with replacement: String) -> Bool {
        guard let textView = activeTextView() else { return false }
        let selectedRange = textView.selectedRange()
        guard selectedRange.location != NSNotFound, selectedRange.length > 0 else { return false }

        textView.window?.makeFirstResponder(textView)
        textView.breakUndoCoalescing()
        guard let replacementAttributedText = assistantAttributedText(
            for: replacement,
            basedOn: textView,
            selectedRange: selectedRange
        ) else {
            return false
        }

        guard textView.shouldChangeText(in: selectedRange, replacementString: replacement) else {
            return false
        }

        beginProgrammaticEdit(on: textView)
        textView.textStorage?.replaceCharacters(in: selectedRange, with: replacementAttributedText)
        let nextLocation = min(selectedRange.location + replacementAttributedText.length, textView.string.utf16.count)
        textView.setSelectedRange(NSRange(location: nextLocation, length: 0))
        endProgrammaticEdit(on: textView)
        textView.didChangeText()
        textView.breakUndoCoalescing()
        textView.undoManager?.setActionName("Replace Selection")
        NativeFormattingToolbarState.shared.update(from: textView)
        return true
    }

    static func insertBelowSelection(_ insertedText: String) -> Bool {
        guard let textView = activeTextView() else { return false }
        let fullString = textView.string as NSString
        let selectedRange = textView.selectedRange()
        let anchorRange: NSRange

        if fullString.length == 0 {
            anchorRange = NSRange(location: 0, length: 0)
        } else if selectedRange.location != NSNotFound, selectedRange.length > 0 {
            anchorRange = fullString.paragraphRange(for: selectedRange)
        } else {
            let caretLocation = min(max(0, selectedRange.location), max(0, fullString.length - 1))
            anchorRange = fullString.paragraphRange(for: NSRange(location: caretLocation, length: 0))
        }

        let insertionLocation = min(NSMaxRange(anchorRange), fullString.length)
        let needsLeadingNewline = insertionLocation > 0
            && insertionLocation <= fullString.length
            && fullString.character(at: insertionLocation - 1) != 10
            && fullString.character(at: insertionLocation - 1) != 13
        let normalizedInsertedText = insertedText.trimmingCharacters(in: .newlines)
        let insertedBlock = (needsLeadingNewline ? "\n" : "") + normalizedInsertedText + "\n"

        guard let replacementAttributedText = assistantAttributedText(
            for: insertedBlock,
            basedOn: textView,
            selectedRange: NSRange(location: max(0, min(insertionLocation, max(0, fullString.length - 1))), length: 0)
        ) else {
            return false
        }

        let insertionRange = NSRange(location: insertionLocation, length: 0)
        textView.window?.makeFirstResponder(textView)
        textView.breakUndoCoalescing()
        guard textView.shouldChangeText(in: insertionRange, replacementString: insertedBlock) else {
            return false
        }

        beginProgrammaticEdit(on: textView)
        textView.textStorage?.replaceCharacters(in: insertionRange, with: replacementAttributedText)
        let nextLocation = min(insertionLocation + replacementAttributedText.length, textView.string.utf16.count)
        textView.setSelectedRange(NSRange(location: nextLocation, length: 0))
        endProgrammaticEdit(on: textView)
        textView.didChangeText()
        textView.breakUndoCoalescing()
        textView.undoManager?.setActionName("Insert Below")
        NativeFormattingToolbarState.shared.update(from: textView)
        return true
    }

    static func appendToSceneEnd(_ insertedText: String) -> Bool {
        guard let textView = activeTextView() else { return false }
        let fullString = textView.string as NSString
        let normalizedInsertedText = insertedText.trimmingCharacters(in: .newlines)
        guard !normalizedInsertedText.isEmpty else { return false }

        let insertionLocation = fullString.length
        let needsSeparator = insertionLocation > 0 && !textView.string.hasSuffix("\n")
        let leadingBreak = insertionLocation == 0 ? "" : (needsSeparator ? "\n\n" : "\n")
        let insertedBlock = leadingBreak + normalizedInsertedText

        guard let replacementAttributedText = assistantAttributedText(
            for: insertedBlock,
            basedOn: textView,
            selectedRange: NSRange(location: max(0, insertionLocation - 1), length: 0)
        ) else {
            return false
        }

        let insertionRange = NSRange(location: insertionLocation, length: 0)
        textView.window?.makeFirstResponder(textView)
        textView.breakUndoCoalescing()
        guard textView.shouldChangeText(in: insertionRange, replacementString: insertedBlock) else {
            return false
        }

        beginProgrammaticEdit(on: textView)
        textView.textStorage?.replaceCharacters(in: insertionRange, with: replacementAttributedText)
        let nextLocation = min(insertionLocation + replacementAttributedText.length, textView.string.utf16.count)
        textView.setSelectedRange(NSRange(location: nextLocation, length: 0))
        endProgrammaticEdit(on: textView)
        textView.didChangeText()
        textView.breakUndoCoalescing()
        textView.undoManager?.setActionName("Append to End")
        NativeFormattingToolbarState.shared.update(from: textView)
        return true
    }

    static func copyToPasteboard(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(trimmedText, forType: .string)
    }

    private static func mutateActiveTextView(
        restoreCachedSelection: Bool = true,
        _ action: (NSTextView) -> Void
    ) {
        guard let textView = activeTextView() else { return }
        textView.window?.makeFirstResponder(textView)
        if restoreCachedSelection,
           !containsExpandedSelection(textView.selectedRanges),
           containsExpandedSelection(lastKnownSelectedRanges) {
            textView.selectedRanges = lastKnownSelectedRanges
        }
        action(textView)
        NativeFormattingToolbarState.shared.update(from: textView)
    }

    private static func activeTextView() -> NSTextView? {
        if let editorTextView = editorContextTextView() {
            return editorTextView
        }
        return lastKnownTextView
    }

    private static func editorContextTextView() -> NSTextView? {
        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
           sceneIDByTextViewIdentifier[ObjectIdentifier(textView)] != nil {
            return textView
        }
        if let textView = NSApp.mainWindow?.firstResponder as? NSTextView,
           sceneIDByTextViewIdentifier[ObjectIdentifier(textView)] != nil {
            return textView
        }
        if let textView = lastKnownTextView,
           sceneIDByTextViewIdentifier[ObjectIdentifier(textView)] != nil {
            return textView
        }
        return nil
    }

    private static func revealSelection(in textView: NSTextView) {
        DispatchQueue.main.async {
            let range = textView.safeSelectedRange
            guard range.location != NSNotFound else { return }
            textView.window?.makeFirstResponder(textView)
            textView.scrollRangeToVisible(range)
            textView.reveal(range: range)
            if range.length > 0 {
                textView.showFindIndicator(for: range)
            }
            register(textView)
        }
    }

    private static func pruneReleasedTextViews() {
        textViewBySceneID = textViewBySceneID.filter { _, box in
            box.textView != nil
        }
        let liveIdentifiers = Set(textViewBySceneID.values.compactMap { $0.textView }.map(ObjectIdentifier.init))
        sceneIDByTextViewIdentifier = sceneIDByTextViewIdentifier.filter { liveIdentifiers.contains($0.key) }
    }

    private static func toggleUnderline(in textView: NSTextView) {
        let storage = textView.textStorage ?? NSTextStorage()
        let selectedRange = textView.selectedRange()
        let hasSelection = selectedRange.location != NSNotFound && selectedRange.length > 0

        if hasSelection {
            let currentValue = storage.attribute(.underlineStyle, at: selectedRange.location, effectiveRange: nil) as? Int ?? 0
            let nextValue = currentValue == 0 ? NSUnderlineStyle.single.rawValue : 0
            storage.beginEditing()
            storage.addAttribute(.underlineStyle, value: nextValue, range: selectedRange)
            storage.endEditing()
        } else {
            var typingAttributes = textView.typingAttributes
            let currentValue = typingAttributes[.underlineStyle] as? Int ?? 0
            typingAttributes[.underlineStyle] = currentValue == 0 ? NSUnderlineStyle.single.rawValue : 0
            textView.typingAttributes = typingAttributes
        }
        textView.textStorage?.edited(.editedAttributes, range: selectedRange, changeInLength: 0)
    }

    private static func toggleBulletList(in textView: NSTextView) {
        let fullString = textView.string as NSString
        let selectedRange = textView.selectedRange()
        guard fullString.length > 0 else { return }
        let originalSelectedRange = selectedRange

        let paragraphRange: NSRange
        if selectedRange.location != NSNotFound, selectedRange.length > 0 {
            paragraphRange = fullString.paragraphRange(for: selectedRange)
        } else {
            let caretLocation = clampedParagraphAnchorLocation(
                for: selectedRange.location,
                textLength: fullString.length
            )
            paragraphRange = fullString.paragraphRange(for: NSRange(location: caretLocation, length: 0))
        }

        let shouldRemoveList = textView.selectionUsesBulletList(in: paragraphRange)
        guard let textStorage = textView.textStorage else { return }
        let paragraphSubranges = paragraphRanges(in: paragraphRange, string: fullString)
        let replacementAttributedText = NSMutableAttributedString()
        for paragraphRange in paragraphSubranges {
            replacementAttributedText.append(
                transformedBulletParagraph(
                    from: textStorage.attributedSubstring(from: paragraphRange),
                    removingBullets: shouldRemoveList,
                    fallbackAttributes: textView.typingAttributes
                )
            )
        }
        let replacementLength = replacementAttributedText.length

        guard textView.shouldChangeText(in: paragraphRange, replacementString: replacementAttributedText.string) else {
            return
        }

        beginProgrammaticEdit(on: textView)
        textStorage.replaceCharacters(in: paragraphRange, with: replacementAttributedText)
        clearBulletArtifacts(
            in: textStorage,
            range: NSRange(location: paragraphRange.location, length: replacementLength)
        )

        let nextSelectionRange = updatedBulletSelectionRange(
            originalSelectedRange,
            paragraphRange: paragraphRange,
            removingBullets: shouldRemoveList,
            replacementLength: replacementLength,
            updatedTextLength: (textView.string as NSString).length
        )
        let selectionRefreshRange = NSRange(location: nextSelectionRange.location, length: 0)
        textView.setSelectedRange(selectionRefreshRange)
        textView.setSelectedRange(nextSelectionRange)
        if let textContainer = textView.textContainer, let layoutManager = textView.layoutManager {
            layoutManager.ensureLayout(for: textContainer)
            layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: paragraphRange.location, length: replacementLength))
        }
        textView.insertionPointColor = .clear
        textView.insertionPointColor = NativeTheme.accent
        textView.displayIfNeeded()
        textView.needsDisplay = true
        textView.scrollRangeToVisible(nextSelectionRange)
        endProgrammaticEdit(on: textView)
        textView.didChangeText()
    }

    private static func applyAlignment(_ alignment: NSTextAlignment, in textView: NSTextView) {
        let selectedRange = textView.selectedRange()
        let paragraphRange: NSRange

        if textView.string.isEmpty {
            var typingAttributes = textView.typingAttributes
            let paragraphStyle = ((typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
                ?? ((textView.defaultParagraphStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle())
            paragraphStyle.alignment = alignment
            typingAttributes[.paragraphStyle] = paragraphStyle
            textView.defaultParagraphStyle = paragraphStyle
            textView.typingAttributes = typingAttributes
            return
        } else if selectedRange.location != NSNotFound, selectedRange.length > 0 {
            paragraphRange = (textView.string as NSString).paragraphRange(for: selectedRange)
        } else {
            let caretRange = NSRange(location: max(0, selectedRange.location), length: 0)
            paragraphRange = (textView.string as NSString).paragraphRange(for: caretRange)
        }

        textView.setAlignment(alignment, range: paragraphRange)

        var typingAttributes = textView.typingAttributes
        let typingParagraphStyle = ((typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
            ?? ((textView.defaultParagraphStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle())
        typingParagraphStyle.alignment = alignment
        textView.defaultParagraphStyle = typingParagraphStyle
        typingAttributes[.paragraphStyle] = typingParagraphStyle
        textView.typingAttributes = typingAttributes
    }

    private static func applyTextColor(_ color: NSColor, in textView: NSTextView) {
        let selectedRange = textView.selectedRange()
        let hasSelection = selectedRange.location != NSNotFound && selectedRange.length > 0

        if hasSelection {
            textView.textStorage?.beginEditing()
            textView.textStorage?.addAttribute(.foregroundColor, value: color, range: selectedRange)
            textView.textStorage?.endEditing()
            textView.textStorage?.edited(.editedAttributes, range: selectedRange, changeInLength: 0)
        } else {
            var typingAttributes = textView.typingAttributes
            typingAttributes[.foregroundColor] = color
            textView.typingAttributes = typingAttributes
        }
    }

    private static func paragraphRanges(in range: NSRange, string: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var location = range.location
        let maxLocation = NSMaxRange(range)

        while location < maxLocation {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            ranges.append(paragraphRange)
            location = NSMaxRange(paragraphRange)
        }

        return ranges
    }

    private static func updatedBulletSelectionRange(
        _ selectedRange: NSRange,
        paragraphRange: NSRange,
        removingBullets: Bool,
        replacementLength: Int,
        updatedTextLength: Int
    ) -> NSRange {
        guard selectedRange.location != NSNotFound else {
            return selectedRange
        }

        if selectedRange.length == 0 {
            let originalOffset = max(0, selectedRange.location - paragraphRange.location)
            let adjustedOffset = max(0, originalOffset + (removingBullets ? -nativeBulletPrefix.count : nativeBulletPrefix.count))
            let newParagraphStart = min(paragraphRange.location, updatedTextLength)
            let proposedLocation = newParagraphStart + adjustedOffset
            return NSRange(
                location: min(max(0, proposedLocation), updatedTextLength),
                length: 0
            )
        }

        let newStart = min(paragraphRange.location, updatedTextLength)
        let maxLength = max(0, updatedTextLength - newStart)
        let clampedLength = min(replacementLength, maxLength)
        let paragraphSelectionLength = max(0, clampedLength - trailingNewlineTrimCount(
            for: paragraphRange,
            updatedTextLength: updatedTextLength
        ))
        return NSRange(location: newStart, length: paragraphSelectionLength)
    }

    private static func trailingNewlineTrimCount(for paragraphRange: NSRange, updatedTextLength: Int) -> Int {
        if paragraphRange.location + paragraphRange.length >= updatedTextLength {
            return 0
        }
        return 1
    }

    private static func bulletPrefixRange(in paragraphText: String) -> NSRange? {
        if paragraphText.hasPrefix(nativeBulletPrefix) {
            return NSRange(location: 0, length: nativeBulletPrefix.count)
        }
        return nil
    }

    private static func transformedBulletParagraph(
        from paragraph: NSAttributedString,
        removingBullets: Bool,
        fallbackAttributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let paragraphText = paragraph.string
        if removingBullets {
            if let bulletRange = bulletPrefixRange(in: paragraphText),
               NSMaxRange(bulletRange) <= paragraph.length {
                let updatedParagraph = NSMutableAttributedString(attributedString: paragraph)
                updatedParagraph.deleteCharacters(in: bulletRange)
                return updatedParagraph
            }
            return paragraph
        }

        if bulletPrefixRange(in: paragraphText) == nil {
            let updatedParagraph = NSMutableAttributedString()
            let leadingAttributes: [NSAttributedString.Key: Any]
            if paragraph.length > 0 {
                leadingAttributes = paragraph.attributes(at: 0, effectiveRange: nil)
            } else {
                leadingAttributes = fallbackAttributes
            }
            updatedParagraph.append(NSAttributedString(string: nativeBulletPrefix, attributes: leadingAttributes))
            updatedParagraph.append(paragraph)
            return updatedParagraph
        }
        return paragraph
    }

    private static func clearBulletArtifacts(in textStorage: NSTextStorage, range: NSRange) {
        guard range.length > 0 else { return }
        let nsString = textStorage.string as NSString
        let safeRange = NSRange(
            location: min(max(0, range.location), nsString.length),
            length: min(range.length, max(0, nsString.length - min(max(0, range.location), nsString.length)))
        )
        guard safeRange.length > 0 else { return }

        var location = safeRange.location
        let maxLocation = NSMaxRange(safeRange)
        while location < maxLocation {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: location, length: 0))
            let clampedParagraphRange = NSIntersectionRange(paragraphRange, safeRange)
            if clampedParagraphRange.length > 0 {
                let paragraphText = nsString.substring(with: clampedParagraphRange)
                if paragraphText.hasPrefix(nativeBulletPrefix) {
                    let prefixLength = min(nativeBulletPrefix.count, clampedParagraphRange.length)
                    textStorage.addAttribute(.underlineStyle, value: 0, range: NSRange(location: clampedParagraphRange.location, length: prefixLength))
                }

                let paragraphEnd = NSMaxRange(clampedParagraphRange)
                if paragraphEnd > clampedParagraphRange.location {
                    let trailingIndex = paragraphEnd - 1
                    let trailingCharacter = nsString.substring(with: NSRange(location: trailingIndex, length: 1))
                    if trailingCharacter == "\n" || trailingCharacter == "\r" {
                        textStorage.addAttribute(.underlineStyle, value: 0, range: NSRange(location: trailingIndex, length: 1))
                    }
                }
            }
            location = NSMaxRange(paragraphRange)
        }
    }

    private static func toggleTrait(_ trait: NSFontTraitMask, in textView: NSTextView) {
        let storage = textView.textStorage ?? NSTextStorage()
        let selectedRange = textView.selectedRange()
        let fontManager = NSFontManager.shared
        let hasSelection = selectedRange.location != NSNotFound && selectedRange.length > 0

        if hasSelection {
            let shouldRemoveTrait = selectionHasTrait(
                trait,
                in: storage,
                range: selectedRange,
                fallbackFont: textView.typingAttributes[.font] as? NSFont
            )
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: selectedRange) { value, range, _ in
                let currentFont = (value as? NSFont)
                    ?? (textView.typingAttributes[.font] as? NSFont)
                    ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                let convertedFont = updatedFont(
                    currentFont,
                    trait: trait,
                    fontManager: fontManager,
                    removeTrait: shouldRemoveTrait
                )
                storage.addAttribute(.font, value: convertedFont, range: range)
            }
            storage.endEditing()
        } else {
            var typingAttributes = textView.typingAttributes
            let currentFont = (typingAttributes[.font] as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let shouldRemoveTrait = fontManager.traits(of: currentFont).contains(trait)
            typingAttributes[.font] = updatedFont(
                currentFont,
                trait: trait,
                fontManager: fontManager,
                removeTrait: shouldRemoveTrait
            )
            textView.typingAttributes = typingAttributes
        }

        textView.textStorage?.edited(.editedAttributes, range: selectedRange, changeInLength: 0)
    }

    private static func selectionHasTrait(_ trait: NSFontTraitMask, in storage: NSTextStorage, range: NSRange, fallbackFont: NSFont?) -> Bool {
        var allFontsHaveTrait = true
        storage.enumerateAttribute(.font, in: range) { value, _, stop in
            let currentFont = (value as? NSFont)
                ?? fallbackFont
                ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            if !NSFontManager.shared.traits(of: currentFont).contains(trait) {
                allFontsHaveTrait = false
                stop.pointee = true
            }
        }
        return allFontsHaveTrait
    }

    private static func updatedFont(_ font: NSFont, trait: NSFontTraitMask, fontManager: NSFontManager, removeTrait: Bool) -> NSFont {
        if removeTrait {
            return fontManager.convert(font, toNotHaveTrait: trait)
        }
        return fontManager.convert(font, toHaveTrait: trait)
    }

    private static func assistantAttributedText(
        for text: String,
        basedOn textView: NSTextView,
        selectedRange: NSRange
    ) -> NSAttributedString? {
        let baseAttributes: [NSAttributedString.Key: Any]
        if let textStorage = textView.textStorage,
           textStorage.length > 0,
           selectedRange.location != NSNotFound {
            let attributeLocation = min(selectedRange.location, textStorage.length - 1)
            baseAttributes = textStorage.attributes(at: attributeLocation, effectiveRange: nil)
        } else {
            baseAttributes = textView.typingAttributes
        }

        return NSAttributedString(string: text, attributes: baseAttributes)
    }

    private static func containsExpandedSelection(_ selectedRanges: [NSValue]) -> Bool {
        selectedRanges.contains { value in
            let range = value.rangeValue
            return range.location != NSNotFound && range.length > 0
        }
    }

    private static func clampedParagraphAnchorLocation(for location: Int, textLength: Int) -> Int {
        guard textLength > 0 else { return 0 }
        return min(max(0, location), textLength - 1)
    }

    private static func beginProgrammaticEdit(on textView: NSTextView) {
        programmaticallyEditingTextViews.insert(ObjectIdentifier(textView))
    }

    private static func endProgrammaticEdit(on textView: NSTextView) {
        programmaticallyEditingTextViews.remove(ObjectIdentifier(textView))
    }

    private static func removeReviewIssue(_ issueID: UUID) {
        reviewIssuesBySceneID = reviewIssuesBySceneID.compactMapValues { issues in
            let remaining = issues.filter { $0.id != issueID }
            return remaining.isEmpty ? nil : remaining
        }
        if activeReviewIssueID == issueID {
            activeReviewIssueID = reviewIssuesBySceneID.values.flatMap { $0 }.first?.id
        }
        refreshReviewHighlights()
        postActiveReviewIssueChanged()
    }

    private static func updateReviewIssuesAfterReplacement(
        sceneID: UUID,
        replacedRange: NSRange,
        replacementLength: Int,
        removedIssueID: UUID
    ) {
        let flattenedIssues = reviewIssuesBySceneID.values.flatMap { $0 }
        let adjustedIssues = adjustedReviewIssues(
            from: flattenedIssues,
            afterReplacingIn: sceneID,
            replacedRange: replacedRange,
            replacementLength: replacementLength,
            removing: removedIssueID
        )
        reviewIssuesBySceneID = Dictionary(grouping: adjustedIssues, by: \.sceneID)
        if activeReviewIssueID == removedIssueID {
            activeReviewIssueID = adjustedIssues.first?.id
        }
        refreshReviewHighlights()
        postActiveReviewIssueChanged()
    }

    private static func refreshReviewHighlights() {
        pruneReleasedTextViews()
        for (sceneID, box) in textViewBySceneID {
            guard let textView = box.textView else { continue }
            applyReviewHighlights(to: textView, sceneID: sceneID)
        }
    }

    private static func refreshFindHighlights() {
        pruneReleasedTextViews()
        for (sceneID, box) in textViewBySceneID {
            guard let textView = box.textView else { continue }
            applyFindHighlights(to: textView, sceneID: sceneID)
        }
    }

    private static func applyFindHighlights(to textView: NSTextView, sceneID: UUID) {
        guard let sceneTextView = textView as? NativeSceneTextView else { return }
        sceneTextView.findHighlightRanges = findHighlightRangesBySceneID[sceneID] ?? []
        sceneTextView.activeFindHighlightRange = activeFindHighlightBySceneID[sceneID]
        sceneTextView.needsDisplay = true
    }

    private static func applyReviewHighlights(to textView: NSTextView, sceneID: UUID) {
        guard let sceneTextView = textView as? NativeSceneTextView else { return }
        sceneTextView.reviewHighlights = reviewIssuesBySceneID[sceneID] ?? []
        sceneTextView.activeReviewIssueID = activeReviewIssueID
        sceneTextView.needsDisplay = true
    }

    private static func syncActiveReviewIssueFromSelection() {
        guard let textView = editorContextTextView(),
              let sceneID = sceneIDByTextViewIdentifier[ObjectIdentifier(textView)] else { return }
        let range = textView.safeSelectedRange
        let location = range.location == NSNotFound ? nil : range.location
        let matchingIssue = reviewIssuesBySceneID[sceneID]?.first(where: { issue in
            guard !issue.isStale else { return false }
            guard let location else { return false }
            return NSLocationInRange(location, issue.range) || issue.range.location == location
        })
        let nextIssueID = matchingIssue?.id
        guard nextIssueID != lastReportedReviewIssueID else { return }
        lastReportedReviewIssueID = nextIssueID
        activeReviewIssueID = nextIssueID
        refreshReviewHighlights()
        postActiveReviewIssueChanged()
    }

    private static func postActiveReviewIssueChanged() {
        NotificationCenter.default.post(
            name: .nativeAssistantActiveReviewIssueChanged,
            object: activeReviewIssueID
        )
    }

    private static func postUpdatedReviewIssues() {
        let issues = reviewIssuesBySceneID.values
            .flatMap { $0 }
            .sorted { lhs, rhs in
                if lhs.sceneTitle == rhs.sceneTitle {
                    return lhs.range.location < rhs.range.location
                }
                return lhs.sceneTitle < rhs.sceneTitle
            }
        NotificationCenter.default.post(
            name: .nativeAssistantReviewIssuesChanged,
            object: issues
        )
    }

}

private final class WeakNativeTextViewBox {
    weak var textView: NSTextView?

    init(_ textView: NSTextView) {
        self.textView = textView
    }
}

private extension NSTextView {
    var safeSelectedRange: NSRange {
        clampedRange(selectedRange())
    }

    func rangeClampedToString(_ range: NSRange) -> NSRange {
        clampedRange(range)
    }

    func reveal(range: NSRange) {
        guard range.location != NSNotFound else { return }
        guard let layoutManager, let textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        rect = rect.insetBy(dx: -20, dy: -40)
        scrollToVisible(rect)
        scrollRangeToVisible(range)
        centerSelectionInVisibleArea(nil)
        revealThroughAncestorScrollViews(localRect: rect)
        DispatchQueue.main.async {
            self.scrollRangeToVisible(range)
            self.centerSelectionInVisibleArea(nil)
            self.revealThroughAncestorScrollViews(localRect: rect)
        }
    }

    private func revealThroughAncestorScrollViews(localRect: NSRect) {
        var currentView: NSView = self
        while let parent = currentView.superview {
            let rectInParent = parent.convert(localRect, from: self)
            parent.scrollToVisible(rectInParent.insetBy(dx: -20, dy: -80))
            currentView = parent
        }
    }

    func selectedText(from selectedRanges: [NSValue]) -> String? {
        let parts = selectedRanges.compactMap { value -> String? in
            let range = clampedRange(value.rangeValue)
            guard range.location != NSNotFound, range.length > 0 else { return nil }
            return (string as NSString).substring(with: range)
        }
        let combined = parts.joined(separator: "\n")
        return combined.isEmpty ? nil : combined
    }

    var hasExpandedSelection: Bool {
        let selectedRange = safeSelectedRange
        return selectedRange.location != NSNotFound && selectedRange.length > 0
    }

    var selectionTextColorLabel: String {
        NativeEditorTextColor.closestLabel(for: selectionOrTypingForegroundColor)
    }

    var selectedWordCount: Int {
        selectedRanges.compactMap { value in
            let range = clampedRange(value.rangeValue)
            guard range.location != NSNotFound, range.length > 0 else { return nil }
            let selectedText = (string as NSString).substring(with: range)
            return selectedText.split(whereSeparator: \.isWhitespace).count
        }
        .reduce(0, +)
    }

    var selectionUsesBulletList: Bool {
        let selectedRange = safeSelectedRange
        let fullString = string as NSString

        if fullString.length == 0 {
            let paragraphStyle = (typingAttributes[.paragraphStyle] as? NSParagraphStyle) ?? defaultParagraphStyle
            return !(paragraphStyle?.textLists.isEmpty ?? true)
        }

        let paragraphRange: NSRange
        if selectedRange.location != NSNotFound, selectedRange.length > 0 {
            paragraphRange = fullString.paragraphRange(for: selectedRange)
        } else {
            let caretLocation = min(max(0, selectedRange.location), max(0, fullString.length - 1))
            paragraphRange = fullString.paragraphRange(for: NSRange(location: caretLocation, length: 0))
        }

        return selectionUsesBulletList(in: paragraphRange)
    }

    func selectionUsesBulletList(in paragraphRange: NSRange) -> Bool {
        let fullString = string as NSString
        var allParagraphsUseList = true
        var location = paragraphRange.location
        let maxLocation = NSMaxRange(paragraphRange)

        while location < maxLocation {
            let nextParagraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            let paragraphText = fullString.substring(with: nextParagraphRange)
            if !paragraphText.hasPrefix(nativeBulletPrefix) {
                allParagraphsUseList = false
                break
            }
            location = NSMaxRange(nextParagraphRange)
        }

        return allParagraphsUseList
    }

    var selectionAlignmentState: NativeFormattingToolbarState.AlignmentState {
        let selectedRange = safeSelectedRange
        let paragraphRange = (string as NSString).paragraphRange(
            for: selectedRange.location == NSNotFound
                ? NSRange(location: 0, length: 0)
                : NSRange(location: selectedRange.location, length: max(selectedRange.length, 0))
        )

        guard let textStorage else {
            return alignmentState(for: defaultParagraphStyle?.alignment ?? .left)
        }

        var discoveredAlignment: NSTextAlignment?
        var isMixed = false

        textStorage.enumerateAttribute(.paragraphStyle, in: paragraphRange) { value, _, stop in
            let alignment = (value as? NSParagraphStyle)?.alignment ?? self.defaultParagraphStyle?.alignment ?? .left
            if let discoveredAlignment {
                if discoveredAlignment != alignment {
                    isMixed = true
                    stop.pointee = true
                }
            } else {
                discoveredAlignment = alignment
            }
        }

        if isMixed {
            return .mixed
        }

        return alignmentState(for: discoveredAlignment ?? defaultParagraphStyle?.alignment ?? .left)
    }

    func selectionOrTypingHasTrait(_ trait: NSFontTraitMask) -> Bool {
        let selectedRange = safeSelectedRange
        let fallbackFont = (typingAttributes[.font] as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)

        if selectedRange.location != NSNotFound, selectedRange.length > 0 {
            guard let textStorage else { return false }
            var allFontsHaveTrait = true
            textStorage.enumerateAttribute(.font, in: selectedRange) { value, _, stop in
                let currentFont = (value as? NSFont) ?? fallbackFont
                if !NSFontManager.shared.traits(of: currentFont).contains(trait) {
                    allFontsHaveTrait = false
                    stop.pointee = true
                }
            }
            return allFontsHaveTrait
        }

        return NSFontManager.shared.traits(of: fallbackFont).contains(trait)
    }

    var selectionOrTypingHasUnderline: Bool {
        let selectedRange = safeSelectedRange

        if selectedRange.location != NSNotFound, selectedRange.length > 0 {
            guard let textStorage else { return false }
            var allRangesUnderlined = true
            textStorage.enumerateAttribute(.underlineStyle, in: selectedRange) { value, _, stop in
                let underlineStyle = value as? Int ?? 0
                if underlineStyle == 0 {
                    allRangesUnderlined = false
                    stop.pointee = true
                }
            }
            return allRangesUnderlined
        }

        let underlineStyle = typingAttributes[.underlineStyle] as? Int ?? 0
        return underlineStyle != 0
    }

    private var selectionOrTypingForegroundColor: NSColor? {
        let selectedRange = safeSelectedRange
        if selectedRange.location != NSNotFound, selectedRange.length > 0 {
            guard let textStorage else { return typingAttributes[.foregroundColor] as? NSColor }

            let baseColor = (textStorage.attribute(.foregroundColor, at: selectedRange.location, effectiveRange: nil) as? NSColor)
                ?? (typingAttributes[.foregroundColor] as? NSColor)
                ?? NativeTheme.ink1
            var isMixed = false

            textStorage.enumerateAttribute(.foregroundColor, in: selectedRange) { value, _, stop in
                let candidate = (value as? NSColor) ?? NativeTheme.ink1
                if !candidate.isVisuallyEqual(to: baseColor) {
                    isMixed = true
                    stop.pointee = true
                }
            }

            return isMixed ? nil : baseColor
        }

        return (typingAttributes[.foregroundColor] as? NSColor) ?? NativeTheme.ink1
    }

    private func alignmentState(for alignment: NSTextAlignment) -> NativeFormattingToolbarState.AlignmentState {
        switch alignment {
        case .center:
            return .center
        case .right:
            return .right
        case .justified:
            return .justified
        default:
            return .left
        }
    }

    func rtfData() -> Data? {
        let fullRange = NSRange(location: 0, length: string.utf16.count)
        return try? attributedString().data(
            from: fullRange,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    private func clampedRange(_ range: NSRange) -> NSRange {
        let length = string.utf16.count
        guard range.location != NSNotFound else { return range }
        let clampedLocation = min(max(0, range.location), length)
        let maxLength = max(0, length - clampedLocation)
        let clampedLength = min(max(0, range.length), maxLength)
        return NSRange(location: clampedLocation, length: clampedLength)
    }
}

private extension NSRange {
    func intersectsAny(of ranges: [NSRange]) -> Bool {
        ranges.contains { NSIntersectionRange(self, $0).length > 0 }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension Notification.Name {
    static let nativeAssistantActiveReviewIssueChanged = Notification.Name("nativeAssistantActiveReviewIssueChanged")
    static let nativeAssistantReviewIssuesChanged = Notification.Name("nativeAssistantReviewIssuesChanged")
}

private extension NSColor {
    func isVisuallyEqual(to other: NSColor) -> Bool {
        guard
            let lhs = usingColorSpace(.deviceRGB),
            let rhs = other.usingColorSpace(.deviceRGB)
        else {
            return self == other
        }

        let tolerance: CGFloat = 0.02
        return abs(lhs.redComponent - rhs.redComponent) < tolerance
            && abs(lhs.greenComponent - rhs.greenComponent) < tolerance
            && abs(lhs.blueComponent - rhs.blueComponent) < tolerance
            && abs(lhs.alphaComponent - rhs.alphaComponent) < tolerance
    }
}
