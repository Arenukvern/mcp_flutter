import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

@Freezed(fromJson: true, toJson: true)
abstract class LiveEditBounds with _$LiveEditBounds {
  const factory LiveEditBounds({
    required final double left,
    required final double top,
    required final double right,
    required final double bottom,
    required final double width,
    required final double height,
  }) = _LiveEditBounds;

  factory LiveEditBounds.fromJson(final Map<String, Object?> json) =>
      _$LiveEditBoundsFromJson(json);
}

enum LiveEditEditMode {
  inspect('inspect'),
  edit('edit'),
  ai('ai');

  const LiveEditEditMode(this.wireName);

  final String wireName;

  static LiveEditEditMode fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditEditMode.values.firstWhere(
      (final mode) => mode.wireName == normalized,
      orElse: () => LiveEditEditMode.inspect,
    );
  }
}
