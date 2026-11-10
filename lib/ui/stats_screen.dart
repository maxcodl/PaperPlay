import 'package:flutter/material.dart';

import '../app.dart';
import '../library/db.dart';
import '../stats/listen_recorder.dart';

String _time(int ms) {
  final m = ms ~/ 60000;
  return m >= 60 ? '${m ~/ 60} h ${m % 60} min' : '$m min';
}

enum _Span { week, month, all }

/// Listening time and top songs and artists, from every linked device.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  var _span = _Span.month;

  Future<(List<ListenTotal>, Map<String, int>)> _load() async {
    final from = switch (_span) {
      _Span.week => ListenRecorder.dayOf(DateTime.now().subtract(const Duration(days: 6))),
      _Span.month => ListenRecorder.dayOf(DateTime.now().subtract(const Duration(days: 29))),
      _Span.all => '0000-00-00',
    };
    final db = app.db;
    return (await db.listenTotals(fromDay: from), await db.listenPerDay(fromDay: from));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Listening')),
        body: FutureBuilder(
          future: _load(),
          builder: (context, snap) {
            final data = snap.data;
            if (data == null) return const Center(child: CircularProgressIndicator());
            final (songs, days) = data;
            final total = days.values.fold(0, (a, b) => a + b);
            final artists = <String, int>{};
            for (final s in songs) {
              if (s.artist != null) artists[s.artist!] = (artists[s.artist!] ?? 0) + s.ms;
            }
            final topArtists = artists.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SegmentedButton<_Span>(
                    segments: const [
                      ButtonSegment(value: _Span.week, label: Text('7 days')),
                      ButtonSegment(value: _Span.month, label: Text('30 days')),
                      ButtonSegment(value: _Span.all, label: Text('All time')),
                    ],
                    selected: {_span},
                    onSelectionChanged: (s) => setState(() => _span = s.first),
                  ),
                ),
                ListTile(
                  title: Text(_time(total), style: Theme.of(context).textTheme.headlineMedium),
                  subtitle: Text('${days.length} days with music'),
                ),
                if (songs.isEmpty) const ListTile(title: Text('Nothing yet. Play some songs.')),
                if (topArtists.isNotEmpty) const ListTile(title: Text('Top artists')),
                for (final a in topArtists.take(5)) ListTile(dense: true, title: Text(a.key), trailing: Text(_time(a.value))),
                if (songs.isNotEmpty) const ListTile(title: Text('Top songs')),
                for (final s in songs.take(20))
                  ListTile(
                    dense: true,
                    title: Text(s.title ?? 'Unknown song'),
                    subtitle: Text('${s.artist ?? ''}${s.plays > 0 ? ' · ${s.plays} plays' : ''}'),
                    trailing: Text(_time(s.ms)),
                  ),
              ],
            );
          },
        ),
      );
}
