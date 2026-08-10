import Foundation

enum WorkspacePrimaryCanvasFingerprint {
    static func make(canvasIDs: [String]) -> String {
        let sortedCanvasIDs = canvasIDs.sorted {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        }
        var payload = Data()
        var recordCount = UInt64(sortedCanvasIDs.count).bigEndian
        withUnsafeBytes(of: &recordCount) { recordCountBytes in
            payload.append(contentsOf: recordCountBytes)
        }

        for canvasID in sortedCanvasIDs {
            let canvasIDBytes = Array(canvasID.utf8)
            var byteCount = UInt64(canvasIDBytes.count).bigEndian
            withUnsafeBytes(of: &byteCount) { byteCountBytes in
                payload.append(contentsOf: byteCountBytes)
            }
            payload.append(contentsOf: canvasIDBytes)
        }

        return payload.base64EncodedString()
    }
}
