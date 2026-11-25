import SwiftUI
import CoreImage.CIFilterBuiltins

public struct QRCodeView: View {
    public let urlString: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    public init(urlString: String) {
        self.urlString = urlString
    }

    public var body: some View {
        if let image = generateQRCode(from: urlString) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(Text("QR Loading…"))
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
