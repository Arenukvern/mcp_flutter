import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/src/utils/coordinate_request_int.dart';

void main() {
  group('optionalCoordinateIntFromRequest', () {
    test('missing viewId stays null', () {
      expect(
        optionalCoordinateIntFromRequest(<String, String>{'x': '1'}, 'viewId'),
        isNull,
      );
    });

    test('viewId 0 parses as zero', () {
      expect(
        optionalCoordinateIntFromRequest(
          <String, String>{'viewId': '0'},
          'viewId',
        ),
        0,
      );
    });

    test('empty viewId stays null', () {
      expect(
        optionalCoordinateIntFromRequest(
          <String, String>{'viewId': ''},
          'viewId',
        ),
        isNull,
      );
    });
  });
}
