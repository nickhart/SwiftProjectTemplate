import XCTest

@MainActor
final class TestAppUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testExample() {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.exists)
  }
}
