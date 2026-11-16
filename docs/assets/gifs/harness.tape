# Regenerate: vhs docs/assets/gifs/harness.tape
Output docs/assets/gifs/harness.gif

Require dart
Set Shell "bash"
Set FontSize 15
Set Width 960
Set Height 540
Set Padding 24
Set Theme "GitHub Dark"
Set PlaybackSpeed 2.1
Set MarginFill "#0d1117"

Type "cd docs/assets/gifs/scenarios"
Enter
Sleep 300ms

Type "sed -n '1,24p' harness_counter_smoke.dart"
Enter
Sleep 2s

Type "dart run harness_counter_smoke.dart"
Enter
Sleep 26s