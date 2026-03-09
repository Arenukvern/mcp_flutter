import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

func emit(_ payload: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: payload)
    print(String(data: data, encoding: .utf8)!)
}

func normalizeOwnerName(_ value: String) -> String {
    return value.lowercased().replacingOccurrences(
        of: "[^a-z0-9]+",
        with: "",
        options: .regularExpression
    )
}

func matchesOwner(_ owner: String, candidates: Set<String>) -> Bool {
    if candidates.isEmpty {
        return true
    }
    let normalized = normalizeOwnerName(owner)
    for candidate in candidates {
        let normalizedCandidate = normalizeOwnerName(candidate)
        if normalizedCandidate.isEmpty {
            continue
        }
        if normalized == normalizedCandidate ||
            normalized.contains(normalizedCandidate) ||
            normalizedCandidate.contains(normalized) {
            return true
        }
    }
    return false
}

func permissionStatusPayload(_ status: String, message: String) {
    emit([
        "ok": true,
        "status": status,
        "message": message,
        "canRequest": true,
        "canOpenSettings": true,
        "details": [:],
    ])
}

func openSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
        emit([
            "ok": false,
            "error": "settings_url_invalid",
        ])
        return
    }
    NSWorkspace.shared.open(url)
    emit([
        "ok": true,
        "status": "denied",
        "message": "Opened Screen Recording settings.",
        "canRequest": true,
        "canOpenSettings": true,
        "details": ["opened": true],
    ])
}

func capture(candidates: Set<String>) async {
    guard CGPreflightScreenCaptureAccess() else {
        emit([
            "ok": false,
            "error": "screen_recording_not_granted",
            "permissionStatus": "not_determined",
            "details": [
                "action": "request_permission_or_open_settings"
            ],
        ])
        return
    }

    do {
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        var selectedWindow: SCWindow?
        var selectedArea: CGFloat = -1

        for window in shareableContent.windows {
            let owner = window.owningApplication?.applicationName ?? ""
            let frame = window.frame
            guard matchesOwner(owner, candidates: candidates),
                  frame.width > 8,
                  frame.height > 8 else {
                continue
            }

            let area = frame.width * frame.height
            if area > selectedArea {
                selectedWindow = window
                selectedArea = area
            }
        }

        guard let window = selectedWindow else {
            let visibleOwners = Array(Set(shareableContent.windows.compactMap {
                let owner = $0.owningApplication?.applicationName ?? ""
                return owner.isEmpty ? nil : owner
            })).sorted()
            let visibleWindows = shareableContent.windows.prefix(20).map { window in
                [
                    "owner": window.owningApplication?.applicationName ?? "",
                    "title": window.title ?? "",
                    "width": window.frame.size.width,
                    "height": window.frame.size.height,
                ]
            }
            emit([
                "ok": false,
                "error": "window_not_found",
                "details": [
                    "candidates": Array(candidates).sorted(),
                    "visibleOwners": visibleOwners,
                    "visibleWindows": Array(visibleWindows),
                ],
            ])
            return
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = false
        let pointPixelScale = CGFloat(filter.pointPixelScale)
        configuration.width = Int(filter.contentRect.width * pointPixelScale)
        configuration.height = Int(filter.contentRect.height * pointPixelScale)

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            emit([
                "ok": false,
                "error": "png_encoding_failed",
                "details": ["windowId": window.windowID],
            ])
            return
        }

        emit([
            "ok": true,
            "permissionStatus": "granted",
            "appName": window.owningApplication?.applicationName ?? "",
            "windowId": Int(window.windowID),
            "windowBounds": [
                "x": window.frame.origin.x,
                "y": window.frame.origin.y,
                "width": window.frame.size.width,
                "height": window.frame.size.height,
            ],
            "pngBase64": pngData.base64EncodedString(),
        ])
    } catch {
        emit([
            "ok": false,
            "error": "capture_failed",
            "details": ["message": "\(error)"],
        ])
    }
}

@main
struct VisualCaptureHelper {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            emit([
                "ok": false,
                "error": "missing_command",
            ])
            return
        }

        switch command {
        case "status":
            permissionStatusPayload(
                CGPreflightScreenCaptureAccess() ? "granted" : "not_determined",
                message: "macOS Screen Recording preflight completed."
            )
        case "request":
            let granted = CGRequestScreenCaptureAccess()
            permissionStatusPayload(
                granted ? "granted" : "denied",
                message: granted
                    ? "Screen Recording permission granted."
                    : "Screen Recording permission not granted."
            )
        case "open-settings":
            openSettings()
        case "capture":
            let candidates = Set(args.dropFirst().map { $0.lowercased() })
            await capture(candidates: candidates)
        default:
            emit([
                "ok": false,
                "error": "unknown_command",
                "details": ["command": command],
            ])
        }
    }
}
