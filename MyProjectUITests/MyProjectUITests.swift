import XCTest

final class MyProjectUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testExample() throws {
    let app = XCUIApplication()
    app.launch()

    // Verify the app launched successfully
    XCTAssertTrue(app.exists)
  }
}
