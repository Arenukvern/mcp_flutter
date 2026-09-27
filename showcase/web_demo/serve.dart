// Dependency-free static file server for the web demo page.
//
//   dart run showcase/web_demo/serve.dart            # port 8791
//   dart run showcase/web_demo/serve.dart 9000       # custom port
//
// Serves `index.html` (and nothing else) from this script's directory on
// loopback only — the target `drive_web_demo.dart` and a human browser
// share.
import 'dart:io';

Future<void> main(final List<String> arguments) async {
  final port = arguments.isEmpty ? 8791 : int.parse(arguments.first);
  final root = File.fromUri(Platform.script).parent.path;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  // ignore: avoid_print
  print('[web_demo] serving $root at http://127.0.0.1:$port/');
  await for (final request in server) {
    final page = File('$root/index.html');
    if (!page.existsSync()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('index.html missing next to serve.dart');
      await request.response.close();
      continue;
    }
    request.response.headers.contentType = ContentType.html;
    await request.response.addStream(page.openRead());
    await request.response.close();
  }
}
