import AppKit
import XCTest
@testable import NotDefteriCekirdek
@testable import NotDefteriMac

final class TemaTestleri: XCTestCase {
    func testTemaDegisimiMarkdownuVeBicimleriKorur() {
        let eski = gTemaIndex
        defer { gTemaIndex = eski }
        let adaptor = MacBelgeAdaptoru()
        let belge = NSMutableAttributedString(attributedString:
            markdowndenAttributedStringUret("# Başlık\n**Kalın** ve *italik*\n`kod`\n"))
        let kaynak = markdownMetniUret(belge)
        for tema in [0, 1, 0, 1] {
            gTemaIndex = tema
            adaptor.gorunumuUygula(belge, aralik: NSRange(location: 0, length: belge.length))
            XCTAssertEqual(markdownMetniUret(belge), kaynak)
            XCTAssertEqual(belge.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, kMetinRenk)
        }
    }

    func testTemaYenilemeSecimiVeBelgeyiKorur() {
        _ = NSApplication.shared
        let eski = gTemaIndex
        defer { gTemaIndex = eski }
        let gorunum = NotMetinGorunumu(frame: .zero)
        gorunum.textStorage?.setAttributedString(MacBelgeAdaptoru.markdownuAc("**Kalın** metin"))
        gorunum.textStorage?.delegate = gorunum
        gorunum.setSelectedRange(NSRange(location: 0, length: 3))
        let kaynak = markdownMetniUret(gorunum.textStorage!)
        gTemaIndex = 1
        gorunum.belgeGorunumunuYenile()
        XCTAssertEqual(gorunum.selectedRange(), NSRange(location: 0, length: 3))
        XCTAssertEqual(markdownMetniUret(gorunum.textStorage!), kaynak)
        XCTAssertFalse(gorunum.yaziOlcegiUygulaniyor)
    }
}
