import 'db.dart';

/// The three numbers on the profile page, from what's already stored.
class ProfileCounts {
  const ProfileCounts(this.songs, this.favorites, this.playlists);
  final int songs, favorites, playlists;
}

ProfileCounts profileCounts(List<Song> songs, int playlists) =>
    ProfileCounts(songs.length, songs.where((s) => s.favorite).length, playlists);
