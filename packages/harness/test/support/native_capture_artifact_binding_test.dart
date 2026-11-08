import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'native_capture_artifact_binding.dart';
import 'native_layer_evidence.dart';

void main() {
  test('digestArtifactFile returns sha256, md5, and byte length', () async {
    final dir = await Directory.systemTemp.createTemp('artifact_binding');
    addTearDown(() => dir.delete(recursive: true));
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));
    final file = File('${dir.path}/probe.png')..writeAsBytesSync(png);
    final digest = await digestArtifactFile(file);
    expect(digest['present'], isTrue);
    expect(digest['bytes'], png.length);
    expect(digest['sha256'], sha256.convert(png).toString());
    expect(digest['md5'], md5.convert(png).toString());
  });

  test('writeNativeCaptureArtifactBindings emits on-disk sha256 lengths', () async {
    final dir = await Directory.systemTemp.createTemp('artifact_binding');
    addTearDown(() => dir.delete(recursive: true));
    final before = Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));
    final after = Uint8List.fromList(img.encodePng(img.Image(width: 3, height: 3)));
    await writePng(dir, 'linux_before_increment.png', before);
    await writePng(dir, 'linux_after_increment.png', after);
    await writeNativeCaptureArtifactBindings(
      artifactDir: dir,
      platform: 'linux',
      beforePng: before,
      afterPng: after,
    );
    final bindingsFile = File('${dir.path}/linux_capture_artifact_bindings.json');
    expect(bindingsFile.existsSync(), isTrue);
    final bindings = bindingsFile.readAsStringSync();
    expect(bindings, contains('sha256'));
    expect(bindings, contains('"bytes"'));
    expect(bindings, contains('inMemoryBeforeBytes'));
    expect(bindings, contains('inMemoryAfterBytes'));
  });
}
