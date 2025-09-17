import 'dart:convert';
import 'package:http/http.dart' as http;
import 'spotify_service.dart';

class LrcLibService {
  static const String _baseUrl = 'https://lrclib.net/api';

  /// Search for lyrics by track name and artist name
  static Future<String?> searchLyrics(
    String trackName,
    String artistName,
  ) async {
    try {
      // Clean the track name (remove file extension if present)
      final cleanTrackName = trackName.replaceAll('.mp3', '').trim();

      // URL encode the parameters
      final encodedTrack = Uri.encodeComponent(cleanTrackName);
      final encodedArtist = Uri.encodeComponent(artistName);

      final url = Uri.parse(
        '$_baseUrl/search?track_name=$encodedTrack&artist_name=$encodedArtist',
      );

      print('LRCLib API Request: $url'); // Debug print

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'Flutter Music Player v1.0.0',
          'Accept': 'application/json',
        },
      );

      print(
        'LRCLib API Response Status: ${response.statusCode}',
      ); // Debug print

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        if (results.isNotEmpty) {
          final firstResult = results[0];
          final syncedLyrics = firstResult['syncedLyrics'] as String?;
          final plainLyrics = firstResult['plainLyrics'] as String?;

          // Prefer synced lyrics, fallback to plain lyrics
          final lyrics = syncedLyrics ?? plainLyrics;

          if (lyrics != null && lyrics.isNotEmpty) {
            print('LRCLib: Found lyrics for $cleanTrackName by $artistName');
            return lyrics;
          }
        }
      }

      print('LRCLib: No lyrics found for $cleanTrackName by $artistName');
      return null;
    } catch (e) {
      print('LRCLib API Error: $e');
      return null;
    }
  }

  /// Get lyrics by specific track ID
  static Future<String?> getLyricsById(int id) async {
    try {
      final url = Uri.parse('$_baseUrl/get/$id');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'Flutter Music Player v1.0.0',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final syncedLyrics = result['syncedLyrics'] as String?;
        final plainLyrics = result['plainLyrics'] as String?;

        return syncedLyrics ?? plainLyrics;
      }

      return null;
    } catch (e) {
      print('LRCLib API Error: $e');
      return null;
    }
  }

  /// Enhanced search using Spotify API for accurate artist info
  static Future<String?> searchLyricsWithSpotify(String trackName) async {
    try {
      // First, get accurate track info from Spotify
      print('Getting track info from Spotify for: $trackName');
      final spotifyTrack = await SpotifyService.searchTrack(trackName);

      if (spotifyTrack != null) {
        print(
          'Spotify found: "${spotifyTrack.name}" by ${spotifyTrack.artist}',
        );

        // Use Spotify's accurate track and artist info for lyrics search
        final lyrics = await searchLyrics(
          spotifyTrack.name,
          spotifyTrack.artist,
        );

        if (lyrics != null) {
          print('LRCLib: Found lyrics using Spotify metadata');
          return lyrics;
        }
      }

      // Fallback to original search if Spotify fails
      print('Falling back to basic search for: $trackName');
      return await searchLyrics(trackName, 'Unknown Artist');
    } catch (e) {
      print('Enhanced search error: $e');
      // Final fallback to basic search
      return await searchLyrics(trackName, 'Unknown Artist');
    }
  }
}
