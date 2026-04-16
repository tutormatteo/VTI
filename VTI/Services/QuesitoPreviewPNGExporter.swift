import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

enum QuesitoPreviewPNGExporter {
    /// Rasterizza la prima pagina del PDF in PNG (sfondo bianco, scala per risoluzione).
    /// Usa solo `CGContext` + ImageIO: evita `NSImage.lockFocus()` che spesso non produce TIFF/PNG validi.
    static func pngData(from pdfURL: URL, scale: CGFloat = 3) throws -> Data {
        guard let document = PDFDocument(url: pdfURL), let page = document.page(at: 0) else {
            throw AppError.ioError("Impossibile leggere il PDF per l'esportazione.")
        }

        let mediaBox = page.bounds(for: .mediaBox)
        let pixelWidth = max(1, Int(ceil(mediaBox.width * scale)))
        let pixelHeight = max(1, Int(ceil(mediaBox.height * scale)))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw AppError.ioError("Impossibile creare il contesto bitmap.")
        }

        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        ctx.saveGState()
        // `PDFPage.draw` su macOS usa già coordinate tipo vista (Y verso il basso): non applicare
        // translate(0,h)+scale(·,-·) come per CGPDFPage grezzo, altrimenti l’PNG risulta capovolto.
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -mediaBox.origin.x, y: -mediaBox.origin.y)
        page.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()

        guard let cgImage = ctx.makeImage() else {
            throw AppError.ioError("Rendering della pagina PDF fallito.")
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw AppError.ioError("Impossibile creare il buffer PNG.")
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw AppError.ioError("Scrittura PNG fallita.")
        }

        guard data.length > 0 else {
            throw AppError.ioError("File PNG vuoto.")
        }

        return data as Data
    }
}
