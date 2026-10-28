import Compression
import Foundation

/// Reads files out of a ZIP (an EPUB is one): stored and deflated entries, which is all EPUBs use.
struct ZipArchive {
    enum Failure: Error, Equatable {
        case notZip
        case missing(String)
        case unsupported(method: Int)
        case corrupt
    }

    private struct Entry {
        let method: Int
        let compressedSize: Int
        let size: Int
        let headerOffset: Int
    }

    private let bytes: [UInt8]
    private let entries: [String: Entry]

    var paths: [String] { Array(entries.keys) }

    init(data: Data) throws {
        let bytes = [UInt8](data)
        self.bytes = bytes
        guard bytes.count >= 22 else { throw Failure.notZip }

        // The end-of-central-directory record is in the last 64 KB (it may carry a comment).
        var end = -1
        var p = bytes.count - 22
        let floor = max(0, bytes.count - 65_557)
        while p >= floor {
            if bytes[p] == 0x50, bytes[p + 1] == 0x4B, bytes[p + 2] == 0x05, bytes[p + 3] == 0x06 { end = p; break }
            p -= 1
        }
        guard end >= 0 else { throw Failure.notZip }

        func u16(_ o: Int) -> Int { Int(bytes[o]) | Int(bytes[o + 1]) << 8 }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }

        let count = u16(end + 10)
        var cursor = u32(end + 16)
        var entries: [String: Entry] = [:]
        for _ in 0..<count {
            guard cursor + 46 <= bytes.count, u32(cursor) == 0x0201_4B50 else { throw Failure.corrupt }
            let nameLength = u16(cursor + 28)
            let extraLength = u16(cursor + 30)
            let commentLength = u16(cursor + 32)
            guard cursor + 46 + nameLength <= bytes.count else { throw Failure.corrupt }
            let name = String(decoding: bytes[(cursor + 46)..<(cursor + 46 + nameLength)], as: UTF8.self)
            entries[name] = Entry(method: u16(cursor + 10), compressedSize: u32(cursor + 20),
                                  size: u32(cursor + 24), headerOffset: u32(cursor + 42))
            cursor += 46 + nameLength + extraLength + commentLength
        }
        self.entries = entries
    }

    func contains(_ path: String) -> Bool { entries[path] != nil }

    func data(_ path: String) throws -> Data {
        guard let entry = entries[path] else { throw Failure.missing(path) }
        let h = entry.headerOffset
        guard h + 30 <= bytes.count else { throw Failure.corrupt }
        let nameLength = Int(bytes[h + 26]) | Int(bytes[h + 27]) << 8
        let extraLength = Int(bytes[h + 28]) | Int(bytes[h + 29]) << 8
        let start = h + 30 + nameLength + extraLength
        guard start + entry.compressedSize <= bytes.count else { throw Failure.corrupt }
        let body = bytes[start..<(start + entry.compressedSize)]
        switch entry.method {
        case 0: return Data(body)
        case 8: return try Self.inflate(body, size: entry.size)
        default: throw Failure.unsupported(method: entry.method)
        }
    }

    /// Raw DEFLATE (no zlib header), which is what COMPRESSION_ZLIB decodes.
    private static func inflate(_ source: ArraySlice<UInt8>, size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        guard !source.isEmpty else { throw Failure.corrupt }
        var out = [UInt8](repeating: 0, count: size)
        let written = source.withUnsafeBufferPointer { src in
            out.withUnsafeMutableBufferPointer { dst in
                compression_decode_buffer(dst.baseAddress!, size, src.baseAddress!, src.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw Failure.corrupt }
        return Data(out)
    }
}
