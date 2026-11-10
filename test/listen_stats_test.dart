import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/library/db.dart';

void main() {
  test('rows add locally and merge by larger value, twice is harmless', () async {
    final a = AppDb(NativeDatabase.memory()), b = AppDb(NativeDatabase.memory());
    addTearDown(a.close);
    addTearDown(b.close);
    await a.addListen('A', '2026-01-01', 'u', 1000, 0);
    await a.addListen('A', '2026-01-01', 'u', 500, 1);
    await b.addListen('B', '2026-01-01', 'u', 200, 0);
    final fromA = await a.listenRows();
    await b.mergeListen(fromA, self: 'B');
    await b.mergeListen(fromA, self: 'B');
    final t = (await b.listenTotals()).single;
    expect([t.ms, t.plays], [1700, 1]);
    await a.addListen('A', '2026-01-01', 'u', 300, 0);
    await b.mergeListen(await a.listenRows(origin: 'A'), self: 'B');
    expect((await b.listenTotals()).single.ms, 2000, reason: 'growth carries, nothing doubles');
  });
}
