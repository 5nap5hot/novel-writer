import Foundation

enum WordCountService {
  static func countWords(in text: String) -> Int {
    text.split(whereSeparator: \.isWhitespace).count
  }

  static func countCharacters(in text: String) -> Int {
    text.count
  }
}

