import XCTest
@testable import NotchoraCore

final class SSEParserTests: XCTestCase {
    func testDispatchesEventsAtBlankLine() {
        var parser = SSEParser()
        XCTAssertNil(parser.consume(line: ": keep-alive"))
        XCTAssertNil(parser.consume(line: "event: message_start"))
        XCTAssertNil(parser.consume(line: "data: {\"a\":1}"))
        XCTAssertNil(parser.consume(line: "data: {\"b\":2}"))
        XCTAssertEqual(
            parser.consume(line: ""),
            SSEEvent(event: "message_start", data: "{\"a\":1}\n{\"b\":2}")
        )
        XCTAssertNil(parser.consume(line: ""))
    }

    func testDoneTerminator() {
        var parser = SSEParser()
        XCTAssertNil(parser.consume(line: "data: [DONE]"))
        XCTAssertEqual(parser.consume(line: ""), SSEEvent(event: nil, data: "[DONE]"))
    }

    func testCRLFLineIsNormalized() {
        var parser = SSEParser()
        XCTAssertNil(parser.consume(line: "data: value\r"))
        XCTAssertEqual(parser.consume(line: "\r"), SSEEvent(event: nil, data: "value"))
    }

    func testFlushWithoutBlankLine() {
        var parser = SSEParser()
        XCTAssertNil(parser.consume(line: "data: tail"))
        XCTAssertEqual(parser.flush(), SSEEvent(event: nil, data: "tail"))
        XCTAssertNil(parser.flush())
    }

    func testEventWithoutDataStillDispatches() {
        var parser = SSEParser()
        XCTAssertNil(parser.consume(line: "event: ping"))
        XCTAssertEqual(parser.consume(line: ""), SSEEvent(event: "ping", data: ""))
    }
}
