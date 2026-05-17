import Foundation

extension Data {
    /// Append this data to the file at `path`, creating it if necessary.
    /// Used only for /tmp/notchy.log debug logging.
    func writeAppending(to path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            handle.seekToEndOfFile()
            try handle.write(contentsOf: self)
            try handle.close()
        } else {
            try write(to: URL(fileURLWithPath: path))
        }
    }
}
