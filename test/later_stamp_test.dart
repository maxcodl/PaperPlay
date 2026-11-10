import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/library/db.dart';

void main() {
  test('local edit stamps after a future peer stamp', () {
    expect(laterStamp(1000, 5000), 5001);
    expect(laterStamp(1000, 1000), 1001);
    expect(laterStamp(2000, 1000), 2000);
  });
}
