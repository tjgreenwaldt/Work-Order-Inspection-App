//
//  Work_Order_Inspection_AppTests.swift
//  Work Order Inspection AppTests
//
//  Created by Tyler Greenwaldt on 5/20/26.
//

import Testing
@testable import Work_Order_Inspection_App

struct Work_Order_Inspection_AppTests {

    @Test func salesforceRichTextFormatterCleansHTMLSamples() async throws {
        #expect(SalesforceRichTextFormatter.displayText(from: "<p>Inspect module condition.</p>") == "Inspect module condition.")
        #expect(SalesforceRichTextFormatter.displayText(from: "<p></p>") == "")
        #expect(SalesforceRichTextFormatter.displayText(from: "<p><br></p>") == "")
        #expect(SalesforceRichTextFormatter.displayText(from: "Line 1<br>Line 2") == "Line 1\nLine 2")
        #expect(SalesforceRichTextFormatter.displayText(from: "Check torque&nbsp;mark") == "Check torque mark")
        #expect(SalesforceRichTextFormatter.displayText(from: "Plain text with no HTML") == "Plain text with no HTML")
    }

}
