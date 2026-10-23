import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The editor shell draws its own title bar (spec 006, T012): hide the
    // native one and keep the traffic lights over the full-size content
    // view, whose title bar keeps a leading inset clear for them.
    self.titlebarAppearsTransparent = true
    self.titleBarStyle = .fullSizeContentView
    self.isMovableByWindowBackground = true

    super.awakeFromNib()
  }
}
