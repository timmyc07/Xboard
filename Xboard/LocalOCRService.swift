import AppKit
import Vision

enum LocalOCRService {
    static func recognize(imageData: Data) -> String? {
        guard let image = NSImage(data: imageData)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "pt-PT"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let lines = request.results?.compactMap { observation in
            observation.topCandidates(1).first?.string
        } ?? []
        let text = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
