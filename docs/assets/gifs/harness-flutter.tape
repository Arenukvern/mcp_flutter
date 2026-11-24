# Regenerate: vhs docs/assets/gifs/harness-flutter.tape
# Prereq: regenerate_cli_gifs.sh prebuilds web + intentcall symlink.
Output docs/assets/gifs/harness-flutter.gif

Require make
Set Shell "bash"
Set FontSize 14
Set Width 1008
Set Height 540
Set Padding 24
Set Theme "GitHub Dark"
Set PlaybackSpeed 2.0
Set MarginFill "#0d1117"

Type "dart run showcase/drivers/bin/drive_flutter.dart --device chrome"
Enter
Sleep 38s