// One-off / CI forensics: row-wise #22AA55 coverage in capture PNGs.
import 'dart:io';
import 'package:image/image.dart' as img;

void main(List<String> args) {
  final path = args.single;
  final im = img.decodeImage(File(path).readAsBytesSync())!;
  stdout.writeln('size ${im.width}x${im.height}');
  bool exact(int x, int y) {
    final p = im.getPixel(x, y);
    return p.a == 255 && p.r == 0x22 && p.g == 0xAA && p.b == 0x55;
  }
  for (var y = 0; y < 100; y++) {
    var e = 0;
    for (var x = 0; x < im.width; x++) {
      if (exact(x, y)) e++;
    }
    final f = e / im.width;
    if (y <= 30 || f > 0.5) stdout.writeln('y=$y exact_frac=$f');
  }
  final y = 10;
  final bad = <String, int>{};
  for (var x = 0; x < im.width; x++) {
    if (!exact(x, y)) {
      final p = im.getPixel(x, y);
      final k = '${p.r},${p.g},${p.b},${p.a}';
      bad[k] = (bad[k] ?? 0) + 1;
    }
  }
  final topBad = bad.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  stdout.writeln('row$y non-exact count=${bad.values.fold<int>(0, (a, b) => a + b)}');
  stdout.writeln('row$y non-exact top colors: ${topBad.take(8).map((e) => '${e.key}:${e.value}').join(' | ')}');
  var tolHits = 0;
  for (var x = 0; x < im.width; x++) {
    final p = im.getPixel(x, y);
    const tol = 24;
    if (p.a == 255 &&
        (p.r - 0x22).abs() <= tol &&
        (p.g - 0xAA).abs() <= tol &&
        (p.b - 0x55).abs() <= tol) {
      tolHits++;
    }
  }
  stdout.writeln('row$y tolerantGreenFrac=${tolHits / im.width}');
  var bandT = 0, bandH = 0;
  for (var y = 0; y < 21; y++) {
    for (var x = 0; x < im.width; x++) {
      bandT++;
      final p = im.getPixel(x, y);
      if (p.a == 255 &&
          (p.r - 0x22).abs() <= 24 &&
          (p.g - 0xAA).abs() <= 24 &&
          (p.b - 0x55).abs() <= 24) {
        bandH++;
      }
    }
  }
  stdout.writeln('rows0-20 tolerantGreenRatio=${bandT == 0 ? 0 : bandH / bandT}');
  for (final top in [0, 42, 52, 63, 74, 84]) {
    var total = 0, hits = 0;
    for (var y = top; y < top + 21 && y < im.height; y++) {
      for (var x = 0; x < im.width; x++) {
        total++;
        if (exact(x, y)) hits++;
      }
    }
    stdout.writeln('top=$top band21 ratio=${total == 0 ? 0 : hits / total}');
  }
}
