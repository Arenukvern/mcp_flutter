import Cocoa
import FlutterMacOS

/// Minimal native view for MCP showcase platform-view capture routing.
final class ShowcasePlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withViewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> NSView {
    let box = NSBox(frame: NSRect(x: 0, y: 0, width: 120, height: 40))
    box.boxType = .custom
    box.borderType = .noBorder
    box.fillColor = NSColor.systemBlue.withAlphaComponent(0.85)
    box.cornerRadius = 4

    let label = NSTextField(labelWithString: "Native")
    label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
    label.textColor = .white
    label.translatesAutoresizingMaskIntoConstraints = false
    box.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: box.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: box.centerYAnchor),
    ])
    return box
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }
}
