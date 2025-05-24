import 'package:devtools_mcp_extension/common_imports.dart';

extension DateTimeX on DateTime {
  String format({final String pattern = 'dd/MM/yyyy', final String? locale}) {
    if (locale != null && locale.isNotEmpty) {
      Intl.defaultLocale = 'en_EN';
    }
    return DateFormat(pattern, locale).format(this);
  }

  String formatDdMmYyyy() => toLocal().format(pattern: 'dd.MM.yyyy');
}
