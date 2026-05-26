/// Gradle `preBuild` hook — inject into `android/app/build.gradle.kts` once.
const kAndroidGradleCodegenHook = '''
// agentkit-platform: begin
tasks.named("preBuild").configure {
    doFirst {
        exec {
            workingDir = rootProject.layout.projectDirectory.dir("../../").asFile
            commandLine(
                "flutter-mcp-toolkit",
                "codegen",
                "sync",
                "--platform",
                "android",
            )
        }
    }
}
// agentkit-platform: end
''';

/// Xcode Run Script build phase — add to iOS/macOS target once.
const kAppleXcodeCodegenRunScript = r'''
# agentkit-platform: begin
cd "${SRCROOT}/.."
flutter-mcp-toolkit codegen sync --platform ios,macos || exit 1
# agentkit-platform: end
''';

/// Documents where hook templates live for `init agentkit-platform`.
const kPlatformHookTemplatePaths = <String, String>{
  'android': 'agentkit_platform Gradle hook (kAndroidGradleCodegenHook)',
  'ios': 'agentkit_platform Xcode Run Script (kAppleXcodeCodegenRunScript)',
  'macos': 'agentkit_platform Xcode Run Script (kAppleXcodeCodegenRunScript)',
};
