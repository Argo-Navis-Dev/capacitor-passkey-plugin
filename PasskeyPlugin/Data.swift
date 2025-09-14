import Foundation

extension Data {
    init?(base64URLEncoded base64urlString: String) {
        var base64 = base64urlString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding to ensure length is multiple of 4
        while base64.count % 4 != 0 {
            base64 += "="
        }

        self.init(base64Encoded: base64)
    }
}
