# Regenerate: bash docs/assets/gifs/regenerate_cli_gifs.sh (injects __VM_WS_URI__).
# Off-camera warm: headless flutter run on showcase/flutter_demo (pinned VM port).
Output docs/assets/gifs/cli-exec.gif

Require bash
Set Shell "bash"
Set FontSize 14
Set Width 1008
Set Height 540
Set Padding 24
Set Theme "GitHub Dark"
Set PlaybackSpeed 1.35
Set MarginFill "#0d1117"

Type "flutter-mcp-toolkit --vm-service-uri __VM_WS_URI__ exec --name semantic_snapshot --pretty"
Enter
Sleep 10s