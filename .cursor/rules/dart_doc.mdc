---
alwaysApply: false
---

<!-- description: when generating dartdoc or documentation for dart -->

Please add comprehensive Dart documentation comments to the specified classes, following these guidelines:

0. Always focus on WHY (key Design Decisions) it does what it does in concise manner.
1. Use /// for documentation comments.
2. Start with a brief, single-sentence summary of the class's purpose.
3. Follow with a more detailed description if necessary, keeping it concise.
4. Include an @ai annotation with specific instructions for AI tools on how to interpret and use this class.
5. Document all public members (methods, properties, etc.) with clear, concise explanations of their purpose and usage.
6. Use [bracketed] references for any mentioned identifiers within the class.
7. Include code examples where appropriate, using ```dart code fences.
8. Mention any important relationships with other classes or libraries.
9. Use PREFER, AVOID, or CONSIDER for recommendations about usage patterns.
10. Add @deprecated tags with explanations for any deprecated members.
11. Place doc comments before metadata annotations.
12. Use prose to explain parameters, return values, and exceptions.
13. For boolean properties, start comments with "Whether" followed by a description.
14. Document only the getter for properties with both a getter and setter.
15. Consider including a code sample in the class-level comment.
16. Keep 80-length characters per line.

Example format:

````dart
/// {@template progress_indicator}
/// A widget that displays a customizable progress indicator.
///
/// This class provides a flexible way to show loading progress in your app.
/// It supports both determinate and indeterminate progress modes.
///
/// Use [ProgressIndicator.circular] for a circular indicator, or
/// [ProgressIndicator.linear] for a linear one.
///
/// ```dart
/// ProgressIndicator(
///   value: 0.7,
///   backgroundColor: Colors.grey[300],
///   valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
/// )
/// ```
///
/// See also:
///
///  * [CircularProgressIndicator], which shows progress along a circular arc.
///  * [LinearProgressIndicator], which displays progress along a line.
///
/// @ai When generating code involving this class, ensure proper initialization
/// of [value] and consider the appropriate use of [backgroundColor] and [valueColor].
/// {@endtemplate}
class ProgressIndicator extends StatefulWidget {
  /// {@macro progress_indicator}
  ///
  /// Creates a progress indicator.
  ///
  /// The [value] argument should be null for an indeterminate progress indicator.
  /// For determinate progress indicators, [value] should be a non-null value
  /// between 0.0 and 1.0, inclusive.
  ///
  /// @ai Ensure [value] is within the valid range when provided.
  const ProgressIndicator({
    Key? key,
    this.value,
    this.backgroundColor,
    this.valueColor,
    this.semanticsLabel,
    this.semanticsValue,
  }) : super(key: key);

  /// The progress value between 0.0 and 1.0.
  ///
  /// If null, the progress indicator is indeterminate.
  ///
  /// @ai Use this property to control the progress. Ensure it's between 0.0 and 1.0.
  final double? value;

  /// The progress indicator's background color.
  ///
  /// @ai Consider using a contrasting color to [valueColor] for better visibility.
  final Color? backgroundColor;

  /// The progress indicator's color as an animated value.
  ///
  /// @ai Use [AlwaysStoppedAnimation] for a solid color, or custom animations for dynamic effects.
  final Animation<Color?>? valueColor;

  /// Creates a circular progress indicator.
  ///
  /// @ai Use this constructor for a circular representation of progress.
  const ProgressIndicator.circular({Key? key}) : this(key: key);

  /// Creates a linear progress indicator.
  ///
  /// @ai Use this constructor for a linear representation of progress.
  const ProgressIndicator.linear({Key? key}) : this(key: key);

  /// This method is deprecated and will be removed in the next major version.
  ///
  /// Use [newMethod] instead.
  @Deprecated('Use newMethod() instead')
  void oldMethod() {
    // ...
  }

  @override
  State<ProgressIndicator> createState() => _ProgressIndicatorState();
}
````

Please apply this documentation style to the following classes:

1. ClassA
2. ClassB
3. ClassC

Ensure that the documentation is clear, concise, and provides valuable information for both human developers and AI tools. Use `dart format` to format the code correctly.

References:
@Dart
