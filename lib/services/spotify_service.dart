import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SpotifyTrack {
  final String name;
  final String artist;
  final String album;
  final int durationMs;
  final String? previewUrl;
  final String? imageUrl;

  SpotifyTrack({
    required this.name,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.previewUrl,
    this.imageUrl,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    final artists = json['artists'] as List<dynamic>;
    final artistName = artists.isNotEmpty
        ? artists[0]['name']
        : 'Unknown Artist';

    // Get album image URL (largest available)
    String? imageUrl;
    final album = json['album'];
    if (album != null && album['images'] != null) {
      final images = album['images'] as List<dynamic>;
      if (images.isNotEmpty) {
        imageUrl = images[0]['url']; // First image is usually the largest
      }
    }

    return SpotifyTrack(
      name: json['name'] ?? 'Unknown Track',
      artist: artistName,
      album: json['album']?['name'] ?? 'Unknown Album',
      durationMs: json['duration_ms'] ?? 0,
      previewUrl: json['preview_url'],
      imageUrl: imageUrl,
    );
  }
}

class SpotifyService {
  static const String _baseUrl = 'https://api.spotify.com/v1';
  static const String _authUrl = 'https://accounts.spotify.com/api/token';
  static String? _accessToken;
  static DateTime? _tokenExpiry;

  /// Get Spotify access token using Client Credentials flow
  static Future<String?> _getAccessToken() async {
    // Check if token is still valid
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    try {
      final clientId = dotenv.env['SPOTIFY_CLIENT_ID'];
      final clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET'];

      if (clientId == null || clientSecret == null) {
        print('Spotify credentials not found in .env file');
        return null;
      }

      final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));

      final response = await http.post(
        Uri.parse(_authUrl),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(
          Duration(seconds: expiresIn - 60),
        ); // 1 minute buffer

        print('Spotify access token obtained successfully');
        return _accessToken;
      } else {
        print('Failed to get Spotify access token: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting Spotify access token: $e');
      return null;
    }
  }

  /// Search for a track on Spotify
  static Future<SpotifyTrack?> searchTrack(String trackName) async {
    try {
      final token = await _getAccessToken();
      if (token == null) return null;

      // Clean the track name
      final cleanTrackName = trackName
          .replaceAll('.mp3', '')
          .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
          .trim();

      final encodedQuery = Uri.encodeComponent(cleanTrackName);
      final url = Uri.parse(
        '$_baseUrl/search?q=$encodedQuery&type=track&limit=5',
      );

      print('Spotify API Request: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Spotify API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = data['tracks']['items'] as List<dynamic>;

        if (tracks.isNotEmpty) {
          // Find the best match by comparing track names
          SpotifyTrack? bestMatch;
          double bestScore = 0.0;

          for (final trackData in tracks) {
            final track = SpotifyTrack.fromJson(trackData);
            final score = _calculateSimilarity(
              cleanTrackName.toLowerCase(),
              track.name.toLowerCase(),
            );

            if (score > bestScore) {
              bestScore = score;
              bestMatch = track;
            }
          }

          if (bestMatch != null && bestScore > 0.5) {
            // At least 50% similarity
            print(
              'Spotify: Found track "${bestMatch.name}" by ${bestMatch.artist}',
            );
            return bestMatch;
          }
        }
      }

      print('Spotify: No matching track found for "$cleanTrackName"');
      return null;
    } catch (e) {
      print('Spotify API Error: $e');
      return null;
    }
  }

  /// Calculate similarity between two strings (simple Levenshtein-based approach)
  static double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // Simple similarity check - you can implement more sophisticated matching
    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;

    if (longer.contains(shorter)) return 0.8;
    if (shorter.contains(longer.substring(0, (longer.length * 0.7).round())))
      return 0.6;

    return 0.0;
  }
}
