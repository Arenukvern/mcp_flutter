# Regenerate: vhs docs/assets/gifs/cli-exec.tape
# Hide: repo showcase launcher (flutter_test_app, pinned VM port via VM_HOST_PORT).
# Show: fmtk auto-discovery from showcase/flutter_test_app cwd (no URI injection).
# Note: Chrome DWDS still uses per-session auth tokens — tokenless ws://127.0.0.1:8181/ws
# applies to macOS/desktop with --disable-service-auth-codes, not this web warm path.
Output docs/assets/gifs/cli-exec.gif

Require make
Set Shell "bash"
Set FontSize 12
Set Width 1008
Set Height 660
Set Padding 20
Set Theme "GitHub Dark"
Set PlaybackSpeed 1.1
Set MarginFill "#0d1117"

Hide
Type "dart run packages/harness/tool/showcase.dart --stop"
Enter
Sleep 2s
Type "WEB_HEADLESS=1 dart run packages/harness/tool/showcase.dart --web --detach"
Enter
Sleep 90s

Show
Type "cd showcase/flutter_test_app"
Enter
Type "flutter-mcp-toolkit exec --name fmt_semantic_snapshot --pretty"
Enter
Sleep 14s