import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Set default window size (1280x800)
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    let windowWidth: CGFloat = 1280
    let windowHeight: CGFloat = 800
    let windowX = (screenFrame.width - windowWidth) / 2 + screenFrame.origin.x
    let windowY = (screenFrame.height - windowHeight) / 2 + screenFrame.origin.y
    let newFrame = NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
    self.setFrame(newFrame, display: true)

    // Set minimum window size
    self.minSize = NSSize(width: 900, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
