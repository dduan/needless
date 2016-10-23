import Foundation

struct FunctionHead {
  let original: String
  let line: Int
  let pos: Int
  var name: String
  var firstLabel: String?
  let firstParam: String
  let firstType: String

  init(_ original: String, _ line: Int, _ pos: Int, _ name: String,
    _ label: String?, _ param: String, _ type: String)
  {
    self.original = original
    self.line = line
    self.pos = pos
    self.name = name
    self.firstLabel = label == "_" ? nil : label
    self.firstParam = param
    self.firstType = type
  }

  init(_ other: FunctionHead) {
    self.original = other.original
    self.line = other.line
    self.pos = other.pos
    self.name = other.name
    self.firstLabel = other.firstLabel
    self.firstParam = other.firstParam
    self.firstType = other.firstType
  }
}

extension FunctionHead: CustomStringConvertible {
  var description: String {
    return "func \(name)(\(firstLabel ?? "_") \(firstParam): \(firstType)"
  }
}

extension String {
  subscript(_ range: NSRange) -> String {
    let s = self.unicodeScalars
    let start = s.index(s.startIndex, offsetBy: range.location)
    let end = s.index(s.startIndex, offsetBy: range.location + range.length)
    return String(s[start..<end])
  }

  func splitByCamelCase() -> [String] {
    var result = [String]()
    var word = [UnicodeScalar]()
    for c in self.unicodeScalars {
      if c >= "a" && c <= "z" {
        word.append(c)
      } else {
        result.append(String(String.UnicodeScalarView(word)))
        word = [c]
      }
    }
    result.append(String(String.UnicodeScalarView(word)))
    return result
  }
}

typealias Suggestion = (old: FunctionHead, new: FunctionHead, reason: String)
typealias Suggester = (FunctionHead) -> Suggestion?

func commonSuffix(_ a: [String], _ b: [String]) -> [String] {
  var commonParts = [String]()
  for (x, y) in zip(a.reversed(), b.reversed()) {
    if x.lowercased() == y.lowercased() {
      commonParts.append(x)
    }
  }
  return Array(commonParts.reversed())
}

func needlessWordsInFirstLabel(head: FunctionHead) -> Suggestion? {
  if let firstLabel = head.firstLabel,
    let last = firstLabel.splitByCamelCase().last,
    head.firstParam.lowercased().hasSuffix(last.lowercased()),
    head.firstType.lowercased().hasSuffix(last.lowercased()),
    head.name != head.firstParam
  {
    let labelParts = firstLabel.splitByCamelCase()
    let typeParts = head.firstType.splitByCamelCase()
    let commonParts = commonSuffix(labelParts, typeParts)
    let p = labelParts.count - commonParts.count
    let newLabel = labelParts.prefix(upTo: p).joined(separator: "")
    var new = FunctionHead(head)
    new.firstLabel = newLabel
    let text = "potential needless words in first parameter label"
    return (old: head, new: new, text)
  }
  return nil
}

let prepositions = Set([
"aboard", "about", "above", "across", "after", "against", "along", "amid",
"among", "anti", "around", "as", "at", "before", "behind", "below", "beneath",
"beside", "besides", "between", "beyond", "but", "by", "concerning",
"considering", "despite", "down", "during", "except", "excepting", "excluding",
"following", "for", "from", "in", "inside", "into", "like", "minus", "near",
"of", "off", "on", "onto", "opposite", "outside", "over", "past", "per", "plus",
"regarding", "round", "save", "since", "than", "through", "to", "toward",
"towards", "under", "underneath", "unlike", "until", "up", "upon", "versus",
"via", "with", "within", "without",
])

func needlessWordsInName(head: FunctionHead) -> Suggestion? {
  let typeParts = head.firstType.splitByCamelCase()
  let nameParts = head.name.splitByCamelCase()
  let commonParts = commonSuffix(typeParts, nameParts)
  if head.firstLabel == nil &&
    !commonParts.isEmpty &&
    head.name != head.firstParam &&
    nameParts.count > commonParts.count
  {
    let p = nameParts.count - commonParts.count - 1
    let preposition = nameParts[p].lowercased()
    if prepositions.contains(preposition) {
      var new = FunctionHead(head)
      new.name = nameParts.prefix(upTo: p).joined(separator: "")
      new.firstLabel = preposition.lowercased()
      return (old: head, new: new, "potential needless words in function name")
    }
  }
  return nil
}

func suggest(_ head: FunctionHead, rules: [Suggester]) -> [Suggestion] {
  return rules.flatMap { suggester in
    return suggester(head)
  }
}


let headString = "\\bfunc[ ]+(\\w+)\\(([a-z1-9A-Z_]+)?[ ]?(\\w+)[ ]*:[ ]*(\\w+)"
let pattern = try NSRegularExpression(pattern: headString, options: [])

func head(from line: String, lineNumber: Int) -> FunctionHead? {
  let range = NSMakeRange(0, line.unicodeScalars.count)
  if let match = pattern.firstMatch(in: line, range: range) {
    if match.numberOfRanges == 5 {
      for i in 0..<5 {
        if match.rangeAt(i).location == NSNotFound {
          return nil
        }
      }
      return FunctionHead(
        line,
        lineNumber,
        match.rangeAt(0).location,
        line[match.rangeAt(1)],
        line[match.rangeAt(2)],
        line[match.rangeAt(3)],
        line[match.rangeAt(4)]
      )
    }
  }
  return nil
}

let rules = [
  needlessWordsInFirstLabel,
  needlessWordsInName
]

typealias SuggestionFormatter = (Suggestion, String?) -> String

func dollarSeparatedFormatter(suggestion: Suggestion, path: String?) -> String {
  let (old, new, reason) = suggestion
  return "\(reason)$\(path ?? "")$\(old.line)$\(old.pos)$\(old)$\(new)"
}

func xcodeWarningFormatter(suggestion: Suggestion, path: String?) -> String {
  let (old, new, reason) = suggestion
  let parts = [
    path ?? "",
    "\(old.line+1)",
    "\(old.pos+1)",
    " warning",
    " \(reason) '\(old) …'; perhaps use '\(new) …' instead?"
  ]
  return parts.joined(separator: ":")
}

func readableFormatter(suggestion: Suggestion, path: String?) -> String {
  let (old, new, reason) = suggestion
  let parts = [
    "\(reason) \(path == nil ? "" : "in " + path! + " ")(line \(old.line))",
    "\(old.original)",
    "\(String(repeating: " ", count: old.pos))^",
    "possible alternative: \(new) …",
    "",
  ]
  return parts.joined(separator: "\n")
}

func processLine(path: String?, line: String, lineNumber: Int,
  formatter: @escaping SuggestionFormatter, diffMode: Bool)
{
  if diffMode && !line.hasPrefix("+") && !line.hasPrefix("!") &&
      !line.hasPrefix(">")
  {
    return
  }
  head(from: line, lineNumber: lineNumber)
    .flatMap { suggest($0, rules: rules) }
    .map { $0.flatMap { formatter($0, path) } }
    .map { $0.forEach { print($0) } }
}

let formatters: [String: SuggestionFormatter] = [
  "-Xcode": xcodeWarningFormatter,
  "-dollar": dollarSeparatedFormatter,
  "-readable": readableFormatter,
]

func main() {
  let options = CommandLine.arguments.filter { $0.hasPrefix("-") }
  if options.contains("-h") || options.contains("--help") {
    print([
      "Find needless words that merely repeats type information in your Swift function names.",
      "",
      "Useage: needless [options] file1 [file2 file3 ...]",
      "",
      "options:",
      "\t-readable print result in a human readable format",
      "\t-Xcode    print result in clang/swiftc style errors",
      "\t-dollar   print result in '$' separated fields, specifically:",
      "\t          [description]$[path]$[line number]$[column number]$[original name]$[suggested name]",
      "\t-diff     only check lines that's an addition in diff/patch formats",
      "\t-h --help print this message.",
    ].joined(separator: "\n"))
    return
  }

  let files = CommandLine.arguments.filter { !$0.hasPrefix("-") }

  let formatter: SuggestionFormatter = {
    let found = options.flatMap { formatters[$0] }
    return found.isEmpty ? readableFormatter : found[0]
  }()

  let diffMode = options.contains("-diff")

  var count = 0
  if files.count <= 1 {
    while let line = readLine() {
      processLine(path: nil, line: line, lineNumber: count,
        formatter: formatter, diffMode: diffMode)
      count += 1
    }
  } else {
    for path in files.suffix(from: 1) {
      do {
        for line in try String(contentsOfFile: path)
          .components(separatedBy: .newlines)
        {
          processLine(path: path, line: line, lineNumber: count,
            formatter: formatter, diffMode: diffMode)
          count += 1
        }
      } catch {
        print("Error opening file \(path)")
      }
    }
  }
}

main()
