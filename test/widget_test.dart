import 'package:flutter_test/flutter_test.dart';
import 'package:bima_fleet/main.dart';

void main() {
  test('BimaFleet exposes the release APK URL', () {
    expect(apkUrl, contains('github.com/kennedy-blip/bima-fleet/releases'));
  });
}
