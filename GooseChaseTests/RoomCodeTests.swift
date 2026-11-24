//
//  RoomCodeTests.swift  ·  GooseChaseTests
//  RoomCode (GooseChase/Shared/RaceMessages.swift): room-code generation and the
//  quarry://join?code=XXXX link format used by QR codes, the iPhone Camera app and Siri.
//

import Foundation
import Testing
@testable import GooseChase

@MainActor
@Suite("RoomCode")
struct RoomCodeTests {

    // MARK: make()

    @Test("make() returns 4 characters from the no-look-alike alphabet")
    func makeUsesAlphabet() {
        for _ in 0..<500 {
            let code = RoomCode.make()
            #expect(code.count == 4)
            #expect(code.allSatisfy { RoomCode.alphabet.contains($0) }, "unexpected character in \(code)")
        }
    }

    @Test("alphabet has no look-alikes (0/O, 1/I) and no lowercase")
    func alphabetHasNoLookAlikes() {
        for banned in ["0", "O", "1", "I"] {
            #expect(!RoomCode.alphabet.contains(Character(banned)))
        }
        #expect(RoomCode.alphabet.allSatisfy { !$0.isLowercase })
        #expect(Set(RoomCode.alphabet).count == RoomCode.alphabet.count, "alphabet has duplicates")
        #expect(RoomCode.alphabet.count == 32)
    }

    // MARK: joinURL(_:)

    @Test("joinURL builds quarry://join?code=XXXX")
    func joinURLFormat() {
        let url = RoomCode.joinURL("KQ7X")
        #expect(url.absoluteString == "quarry://join?code=KQ7X")
        #expect(url.scheme == "quarry")
        #expect(url.host == "join")
    }

    @Test("joinURL → code(from:) round-trips for generated codes")
    func joinURLRoundTrip() {
        for _ in 0..<100 {
            let code = RoomCode.make()
            #expect(RoomCode.code(from: RoomCode.joinURL(code)) == code)
        }
    }

    // MARK: code(from:)

    @Test("valid links return the code, uppercased", arguments: [
        ("quarry://join?code=KQ7X", "KQ7X"),
        ("quarry://join?code=kq7x", "KQ7X"),         // lowercase is uppercased
        ("quarry://join?code=Kq7X", "KQ7X"),         // mixed case
        ("quarry://join?foo=1&code=ab23", "AB23"),   // extra query items are ignored
        ("quarry://join?code=AAAA&code=BBBB", "AAAA") // first code wins
    ])
    func validLinks(link: String, expected: String) throws {
        let url = try #require(URL(string: link))
        #expect(RoomCode.code(from: url) == expected)
    }

    @Test("other schemes, hosts and missing codes return nil", arguments: [
        "https://join?code=KQ7X",               // wrong scheme
        "https://example.com/join?code=KQ7X",   // web link
        "quarry://camera",                      // the Live Activity link, not a join link
        "quarry://host?code=KQ7X",              // wrong host
        "quarry://join",                        // no query
        "quarry://join?room=KQ7X",              // wrong query name
        "file:///tmp/hunt.quarryhunt"           // AirDropped hunt file
    ])
    func invalidLinks(link: String) throws {
        let url = try #require(URL(string: link))
        #expect(RoomCode.code(from: url) == nil)
    }

    // MARK: Malformed codes are rejected

    @Test("empty code= is rejected")
    func emptyCodeIsRejected() throws {
        let url = try #require(URL(string: "quarry://join?code="))
        #expect(RoomCode.code(from: url) == nil)
    }

    @Test("codes that are not 4 alphabet characters are rejected", arguments: [
        "quarry://join?code=TOOLONG1",
        "quarry://join?code=AB",
        "quarry://join?code=O0I1"
    ])
    func malformedCodesAreRejected(link: String) throws {
        let url = try #require(URL(string: link))
        #expect(RoomCode.code(from: url) == nil)
    }
}
