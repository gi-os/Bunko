import Foundation

/// A small XML tree for the EPUB package files and OPDS feeds. Names are local (no namespace
/// prefix), so `dc:title` is found as `title`.
final class XNode {
    let name: String
    let attributes: [String: String]
    fileprivate(set) var children: [XNode] = []
    fileprivate(set) var text = ""

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    subscript(attribute: String) -> String? { attributes[attribute] }

    func first(_ name: String) -> XNode? { children.first { $0.name == name } }
    func all(_ name: String) -> [XNode] { children.filter { $0.name == name } }

    func descendants(_ name: String) -> [XNode] {
        children.flatMap { ($0.name == name ? [$0] : []) + $0.descendants(name) }
    }

    func firstDescendant(_ name: String) -> XNode? {
        for child in children {
            if child.name == name { return child }
            if let found = child.firstDescendant(name) { return found }
        }
        return nil
    }

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    static func parse(_ data: Data) -> XNode? {
        let builder = Builder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        parser.shouldResolveExternalEntities = false
        _ = parser.parse()
        return builder.root
    }

    static func localName(_ qualified: String) -> String {
        qualified.split(separator: ":").last.map(String.init) ?? qualified
    }

    private final class Builder: NSObject, XMLParserDelegate {
        var root: XNode?
        var stack: [XNode] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String] = [:]) {
            var attrs = attributes
            for (key, value) in attributes where key.contains(":") { attrs[XNode.localName(key)] = value }
            let node = XNode(name: XNode.localName(elementName), attributes: attrs)
            if let parent = stack.last { parent.children.append(node) } else { root = node }
            stack.append(node)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
            _ = stack.popLast()
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            stack.last?.text += string
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            stack.last?.text += String(decoding: CDATABlock, as: UTF8.self)
        }
    }
}
