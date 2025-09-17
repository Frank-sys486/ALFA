import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../services/lrclib_service.dart';
import '../services/spotify_service.dart';
import 'home_page.dart';

class ActivityPage1 extends StatefulWidget {
  const ActivityPage1({super.key});
  @override
  State<ActivityPage1> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<ActivityPage1> {
  // logger for debugging - better than print statements
  final Logger logger = Logger();

  // music player stuff - learned this from youtube tutorial
  final AudioPlayer _player = AudioPlayer();
  int _currentIndex = 0; // which song we playing right now
  double _imageSize = 1.0; // make image bigger or smaller when pause/play
  bool _userIsDraggingSlider = false; // user touching the slider
  bool _isPlaying = false; // is music playing or paused
  Duration _currentTime = Duration.zero; // where we are in the song
  Duration _totalSongTime = Duration.zero; // how long is the song
  double _vol = 1.0; // how loud the music is
  Color _bgColor = Colors.black; // background color from album art
  bool _isFullScreen = false; // big screen mode
  bool _showLyrics = false; // are we showing lyrics or album image
  String? _lyricsText; // the actual lyrics text
  int _lastLyricLine = -1; // which lyric line we scrolled to last time

  // shuffle and repeat buttons - copied from spotify app
  bool _isShuffle = false;
  bool _isRepeat = false;

  // spotify stuff - got this from stackoverflow
  String _currentArtist = "Unknown Artist";
  String? _spotifyImage; // image from spotify

  // cache so we dont spam the api - learned about maps in python
  static final Map<String, String> _cachedLyrics = {};
  static final Map<String, String> _cachedArtists = {};
  static final Map<String, String> _cachedImages = {};

  // list of all songs
  final List<String> songs = [
    "music/skyfall.mp3",
    "music/back to black.mp3",
    "music/feeling good.mp3",
    "music/lose my mind.mp3",
    "music/no time to die.mp3",
    "music/Promiscuous.mp3",
    "music/rock that body.mp3",
    "music/take me to church.mp3",
    "music/writings on the wall from spectre.mp3",
    "music/Love me not.mp3",
  ];

  // locate which lyric line should be highlighted based on timestamps
  // looks at timestamps like [00:32.09] to match with current song time
  int _getCurrentLyricLineIndex(String lyrics, Duration currentSongTime) {
    final lyricLines = lyrics.split('\n');
    final currentSeconds = currentSongTime.inMilliseconds / 1000.0;
    int lastLineIndex = 0;
    for (int i = 0; i < lyricLines.length; i++) {
      final line = lyricLines[i].trim();
      if (line.isEmpty) continue;
      // regex to find timestamp like [01:23.45]
      final timePattern = RegExp(r'\[(\d+):(\d+\.?\d*)\]').firstMatch(line);
      if (timePattern != null) {
        final minutes = int.parse(timePattern.group(1)!);
        final seconds = double.parse(timePattern.group(2)!);
        final lineTimeInSeconds = minutes * 60 + seconds;
        if (lineTimeInSeconds <= currentSeconds) lastLineIndex = i;
        if (lineTimeInSeconds > currentSeconds) break;
      }
    }
    return lastLineIndex;
  }

  // scroll controller for lyrics - needed for auto scroll
  ScrollController? _lyricScrollController;

  // how tall each lyric line is - needed for scrolling math
  static const double lyricLineHeight = 48.0;

  // scroll lyrics to center the current line - auto scroll function
  void _scrollToLyricLine(int lineIndex) {
    if (_lyricScrollController == null) return;
    if (!(_lyricScrollController!.hasClients)) return;
    if (lineIndex == _lastLyricLine) return; // dont scroll if same line

    _lastLyricLine = lineIndex;
    final scrollPosition = _lyricScrollController!.position;
    final screenHeight = scrollPosition.viewportDimension;
    final targetPosition =
        (lineIndex * lyricLineHeight) -
        (screenHeight / 2) +
        (lyricLineHeight / 2);
    final finalPosition = targetPosition.clamp(
      0.0,
      scrollPosition.maxScrollExtent,
    );
    final currentPosition = scrollPosition.pixels;
    final scrollDistance = (currentPosition - finalPosition).abs();

    if (scrollDistance > screenHeight * 0.8) {
      // jump if too far
      _lyricScrollController!.jumpTo(finalPosition);
    } else if (scrollDistance > 5) {
      // smooth scroll if close enough
      _lyricScrollController!.animateTo(
        finalPosition,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // make lyrics scroll to current song position - fixes sync issues
  void _syncLyricsToCurrentPosition() {
    if (!_showLyrics || _lyricsText == null) return;
    final idx = _getCurrentLyricLineIndex(_lyricsText!, _currentTime);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToLyricLine(idx),
    );
  }

  // build the scrollable list of lyrics with highlighting - ui stuff
  Widget buildLyricList(String lyrics, Duration currentSongTime) {
    final lyricLines = lyrics.split('\n');
    final currentLineIndex = _getCurrentLyricLineIndex(lyrics, currentSongTime);
    _lyricScrollController ??= ScrollController();
    return ListView.builder(
      controller: _lyricScrollController,
      itemCount: lyricLines.length,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemBuilder: (context, i) {
        final line = lyricLines[i].trim();
        final displayText = line
            .replaceAll(RegExp(r'\[\d+:\d+\.?\d*\]'), '')
            .trim();
        final isCurrentLine = i == currentLineIndex;
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              displayText.isEmpty ? '' : displayText,
              textAlign: TextAlign.center,
              maxLines: 1, // avoid wrapping
              overflow: TextOverflow.ellipsis, // truncate safely
              softWrap: false, // preent wrapping that causes overflow
              strutStyle: const StrutStyle(
                // stabilize vertical metrics
                forceStrutHeight: true,
                height: 1.2,
                leading: 0.2,
                fontSize: 28,
              ),
              style: TextStyle(
                color: isCurrentLine ? Colors.white : Colors.grey,
                fontSize: 28,
                fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      },
    );
  }

  // get lyrics from internet using spotify and lrclib apis
  // first checks if we already downloaded it before (cache)
  Future<void> _getLyricsFromLrclib(String songName) async {
    try {
      // check if we already have lyrics saved (cache)
      if (_cachedLyrics.containsKey(songName)) {
        logger.i('Using cached lyrics for: $songName');
        setState(() {
          _lyricsText = _cachedLyrics[songName];
          _showLyrics = true;
        });
        return;
      }

      logger.i('Getting lyrics from internet for: $songName');

      // get lyrics from spotify + lrclib api
      final lyrics = await LrcLibService.searchLyricsWithSpotify(songName);

      if (lyrics != null && lyrics.isNotEmpty) {
        // save lyrics so we dont need to download again
        _cachedLyrics[songName] = lyrics;

        setState(() {
          _lyricsText = lyrics;
          _showLyrics = true;
        });
      } else {
        // try to get lyrics from local files
        await _loadLyricFromLocal(songName);
      }
    } catch (e) {
      logger.e('Error getting lyrics from internet: $e');
      // try local files instead
      await _loadLyricFromLocal(songName);
    }
  }

  // load lyrics from files in our app folder
  Future<void> _loadLyricFromLocal(String songName) async {
    // check cache first - maybe we already loaded it before
    if (_cachedLyrics.containsKey(songName)) {
      logger.i('Using cached local lyrics for: $songName');
      setState(() {
        _lyricsText = _cachedLyrics[songName];
        _showLyrics = true;
      });
      return;
    }

    // try to load from assets/lyric folder
    final lyricFilePath = 'assets/lyric/$songName.txt';
    try {
      final text = await DefaultAssetBundle.of(
        context,
      ).loadString(lyricFilePath);

      // save it to cache so we dont load again
      _cachedLyrics[songName] = text;

      setState(() {
        _lyricsText = text;
        _showLyrics = true;
      });
    } catch (e) {
      logger.w('No lyrics found for $songName');
    }
  }

  // get artist name and album image from spotify api
  // this makes the app look more professional
  Future<void> _getArtistInforFromSpotify(String songName) async {
    // check if we already got this info before (dont waste api calls)
    if (_cachedArtists.containsKey(songName)) {
      setState(() {
        _currentArtist = _cachedArtists[songName]!;
        _spotifyImage = _cachedImages.containsKey(songName)
            ? _cachedImages[songName]
            : null;
      });
      logger.i('Using saved artist info for: $songName');
      return;
    }

    try {
      logger.i('Getting artist and image from spotify for: $songName');
      final spotifyTrackInfo = await SpotifyService.searchTrack(songName);

      if (spotifyTrackInfo != null) {
        final artistName = spotifyTrackInfo.artist;
        final albumImageUrl = spotifyTrackInfo.imageUrl;

        // save this info so we dont need to ask spotify again
        _cachedArtists[songName] = artistName;
        if (albumImageUrl != null) {
          _cachedImages[songName] = albumImageUrl;
          logger.i('Saved spotify image for: $songName');
        }

        setState(() {
          _currentArtist = artistName;
          _spotifyImage = albumImageUrl;
        });

        logger.i('Found artist: $artistName for $songName');
        if (albumImageUrl != null) {
          logger.i('Got spotify image: $albumImageUrl');
        } else {
          logger.w('No spotify image for: $songName');
        }
      } else {
        // spotify couldnt find the song
        _cachedArtists[songName] = 'Unknown Artist';

        setState(() {
          _currentArtist = 'Unknown Artist';
          _spotifyImage = null; // no spotify image
        });
        logger.w('Spotify could not find: $songName');
      }
    } catch (e) {
      logger.e('Error getting info from spotify: $e');
      // just use unknown artist if spotify fails
      _cachedArtists[songName] = 'Unknown Artist';

      setState(() {
        _currentArtist = 'Unknown Artist';
        _spotifyImage = null; // no spotify image
      });
    }
  }

  @override
  void initState() {
    super.initState();

    // setup music player listeners - copied from flutter docs
    // this tells us when music starts or stops
    _player.onPlayerStateChanged.listen((state) {
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    // this updates the slider position while music plays
    _player.onPositionChanged.listen((pos) {
      if (!_userIsDraggingSlider) {
        setState(() => _currentTime = pos);
      }
    });

    // this tells us how long the song is
    _player.onDurationChanged.listen((dur) {
      setState(() => _totalSongTime = dur);
    });

    // what to do when song finishes playing
    _player.onPlayerComplete.listen((event) {
      if (_isRepeat) {
        // play same song again
        _playSong(_currentIndex);
      } else {
        // go to next song (random if shuffle is on)
        _nextSong();
      }
    });

    // get info for first song when app starts
    final firstSongName = getSongNameFromPath(songs[_currentIndex]);
    _getArtistInforFromSpotify(firstSongName).then((_) {
      // change background color based on album art
      getBGcolorFromCurrentImage(firstSongName);
    });
  }

  @override
  void dispose() {
    // cleanup when leaving the page - prevents memory leaks
    _player.stop();
    _player.dispose();
    _lyricScrollController?.dispose();
    super.dispose();
  }

  // helper function to get song name from file path
  // like "music/skyfall.mp3" becomes just "skyfall"
  String getSongNameFromPath(String filePath) {
    return filePath
        .split('/') // split by /
        .last // get last part
        .replaceAll('.mp3', ''); // remove .mp3 extension
  }

  // change background color based on album art - makes app look cool
  Future<void> getBGcolorFromCurrentImage(String songName) async {
    if (_spotifyImage != null) {
      // use spotify image for background color
      await _colorFromSpotifyImage(_spotifyImage!);
    } else {
      // use local image for background color
      final localImage = 'assets/images/$songName.jpg';
      await colorFromLocalImage(localImage);
    }
  }

  // get background color from spotify image - downloads and analyzes pixels
  Future<void> _colorFromSpotifyImage(String imageURL) async {
    try {
      logger.d('Getting background color from spotify image: $imageURL');

      final response = await http.get(Uri.parse(imageURL));
      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;
        final decodedImage = await decodeImageFromList(imageBytes);

        final pixelData = await decodedImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final allPixels = pixelData!.buffer.asUint8List();

        // calculate average color from all pixels - math stuff
        int red = 0, green = 0, blue = 0;
        int totalPixels = 0;

        for (int i = 0; i < allPixels.length; i += 4) {
          red += allPixels[i];
          green += allPixels[i + 1];
          blue += allPixels[i + 2];
          totalPixels++;
        }

        if (totalPixels > 0) {
          red = (red / totalPixels).round();
          green = (green / totalPixels).round();
          blue = (blue / totalPixels).round();

          setState(() {
            _bgColor = Color.fromRGBO(red, green, blue, 1.0);
          });
          logger.d(
            'Got background color from spotify: RGB($red, $green, $blue)',
          );
        }
      }
    } catch (e) {
      logger.e('Error getting color from spotify image: $e');
      // use default purple color if failed
      setState(() {
        _bgColor = Colors.purple[400]!;
      });
    }
  }

  // get background color from local image file - fallback method
  Future<void> colorFromLocalImage(String imagePath) async {
    try {
      // check if image file exists in our app
      await DefaultAssetBundle.of(context).load(imagePath);

      final imageProvider = AssetImage(imagePath);
      final imageStream = imageProvider.resolve(const ImageConfiguration());
      final completer = Completer<ui.Image>();

      late ImageStreamListener listener;
      listener = ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(info.image);
        imageStream.removeListener(listener);
      });

      imageStream.addListener(listener);
      final decodedImage = await completer.future;

      // convert image to pixel data - complex image processing stuff
      final pixelBytes = await decodedImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final allPixels = pixelBytes!.buffer.asUint8List();

      // calculate average color from all pixels
      int red = 0, green = 0, blue = 0;
      int pixelCount = 0;

      for (int i = 0; i < allPixels.length; i += 4) {
        red += allPixels[i];
        green += allPixels[i + 1];
        blue += allPixels[i + 2];
        pixelCount++;
      }

      if (pixelCount > 0) {
        red = (red / pixelCount).round();
        green = (green / pixelCount).round();
        blue = (blue / pixelCount).round();

        setState(() {
          _bgColor = Color.fromRGBO(red, green, blue, 1.0);
        });
      }
    } catch (e) {
      // use default color if something goes wrong
      setState(() {
        _bgColor = Colors.purple[400]!;
      });
    }
  }

  // start playing a specific song - main function for music
  Future<void> _playSong(int index) async {
    _currentIndex = index;
    await _player.stop(); // stop current song
    await _player.play(AssetSource(songs[index])); // play new song

    // get artist name and image from spotify
    final songName = getSongNameFromPath(songs[index]);
    await _getArtistInforFromSpotify(songName);

    // change background color to match album art
    await getBGcolorFromCurrentImage(songName);

    setState(() {
      _imageSize = 1.0; // make sure image is normal size when playing
      // reset lyrics stuff when song changes
      _showLyrics = false;
      _lyricsText = null;
      _lastLyricLine = -1; // reset scroll position
    });
  }

  // pause or play music - toggle button function
  Future<void> _pausePlay() async {
    if (_isPlaying) {
      await _player.pause(); // pause the music
      setState(() {
        _imageSize = 1.1; // make image bigger when paused
      });
    } else {
      if (_currentTime > Duration.zero) {
        await _player.resume(); // continue from where we stopped
      } else {
        await _playSong(_currentIndex); // start from beginning
      }
      setState(() {
        _imageSize = 1.0; // normal size when playing
      });
    }
  }

  // go to next song - handles shuffle mode too
  Future<void> _nextSong() async {
    int nextSongIndex;
    if (_isShuffle) {
      // pick random song (but not the same one)
      do {
        nextSongIndex = Random().nextInt(songs.length);
      } while (nextSongIndex == _currentIndex && songs.length > 1);
    } else {
      // just go to next song in order
      nextSongIndex = (_currentIndex + 1) % songs.length;
    }
    await _playSong(nextSongIndex);
  }

  // go to previous song
  Future<void> _prevSong() async {
    final prevSongIndex = (_currentIndex - 1 + songs.length) % songs.length;
    await _playSong(prevSongIndex);
  }

  // turn shuffle on or off
  void _shuffleSong() {
    setState(() {
      _isShuffle = !_isShuffle;
    });
    logger.i('Shuffle ${_isShuffle ? "enabled" : "disabled"}');
  }

  // turn repeat on or off
  void _repeatSong() {
    setState(() {
      _isRepeat = !_isRepeat;
    });
    logger.i('Repeat ${_isRepeat ? "enabled" : "disabled"}');
  }

  // change how loud the music is
  Future<void> _changeVolume(double newVol) async {
    setState(() {
      _vol = newVol;
    });
    await _player.setVolume(newVol);
  }

  // switch between normal and fullscreen mode
  void _fullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  // show list of all songs in popup - copied from tutorial
  void _showSongList() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final isCurrontSong = index == _currentIndex;
            return ListTile(
              title: Text(getSongNameFromPath(songs[index])),
              selected: isCurrontSong,
              onTap: () {
                // close popup and play selected song
                Navigator.pop(context);
                _playSong(index);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // get current song name and calculate progress
    final currentSongTitle = getSongNameFromPath(songs[_currentIndex]);
    double sliderProgress = 0.0;
    if (_totalSongTime.inMilliseconds > 0) {
      sliderProgress =
          _currentTime.inMilliseconds / _totalSongTime.inMilliseconds;
    }

    return Scaffold(
      backgroundColor: Colors.black,

      body: Container(
        // background color changes based on album art
        decoration: BoxDecoration(color: _bgColor),
        child: Column(
          children: [
            // Main content area with image and title
            Expanded(
              child: Container(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Fullscreen toggle button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 600),
                            opacity: _isFullScreen ? 0.0 : 1.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                              transform: Matrix4.translationValues(
                                _isFullScreen
                                    ? -50.0
                                    : 0.0, // slide left when hiding
                                0.0,
                                0.0,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      // pause music before going back (dont stop completely)
                                      if (_isPlaying) {
                                        await _player.pause();
                                      }
                                      if (mounted) {
                                        Navigator.pop(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => HomePage(),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    "Music Player",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _fullScreen,
                                icon: Icon(
                                  _isFullScreen
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                color: Colors.white,
                                icon: const Icon(Icons.queue_music),
                                onPressed: _showSongList,
                              ),
                            ],
                          ),
                        ],
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        height: _isFullScreen
                            ? 10
                            : 20, // reduce spacing in fullscreen
                      ),
                      // Main content: animated switch between lyrics and image
                      Expanded(
                        flex: 4,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                final isLyrics =
                                    child.key == const ValueKey('lyrics');

                                if (isLyrics) {
                                  // Lyrics: scale + blur + fade
                                  return ScaleTransition(
                                    scale: Tween<double>(begin: 1.1, end: 1.0)
                                        .animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeInOut,
                                          ),
                                        ),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: AnimatedBuilder(
                                        animation: animation,
                                        builder: (context, child) {
                                          return ImageFiltered(
                                            imageFilter: ui.ImageFilter.blur(
                                              sigmaX:
                                                  (1.0 - animation.value) * 3.0,
                                              sigmaY:
                                                  (1.0 - animation.value) * 3.0,
                                            ),
                                            child: child,
                                          );
                                        },
                                        child: child,
                                      ),
                                    ),
                                  );
                                } else {
                                  // Image: subtle scale + fade
                                  return ScaleTransition(
                                    scale: Tween<double>(begin: 0.95, end: 1.0)
                                        .animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeInOut,
                                          ),
                                        ),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                }
                              },
                          child: _showLyrics && _lyricsText != null
                              ? GestureDetector(
                                  key: const ValueKey('lyrics'),
                                  onTap: () {
                                    setState(() {
                                      _showLyrics = false;
                                    });
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Builder(
                                      builder: (context) {
                                        final initialLyricIndex =
                                            _getCurrentLyricLineIndex(
                                              _lyricsText!,
                                              _currentTime,
                                            );
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              _scrollToLyricLine(
                                                initialLyricIndex,
                                              );
                                            });
                                        return StreamBuilder<Duration>(
                                          stream: Stream.periodic(
                                            Duration(milliseconds: 100),
                                            (_) => _currentTime,
                                          ),
                                          builder: (context, snapshot) {
                                            final currentSongTime =
                                                snapshot.data ?? _currentTime;
                                            final idx =
                                                _getCurrentLyricLineIndex(
                                                  _lyricsText!,
                                                  currentSongTime,
                                                );
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  _scrollToLyricLine(idx);
                                                });
                                            return buildLyricList(
                                              _lyricsText!,
                                              currentSongTime,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                )
                              : Center(
                                  key: const ValueKey('image'),
                                  child: AnimatedContainer(
                                    curve: Curves.easeInOut,
                                    duration: const Duration(
                                      milliseconds: 600,
                                    ), // Animation duration
                                    transform: Matrix4.identity()
                                      ..scale(_imageSize)
                                      ..translate(
                                        0.0,
                                        _isFullScreen
                                            ? -30.0
                                            : 0.0, // move up in fullscreen
                                        0.0,
                                      ),
                                    transformAlignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          constraints: BoxConstraints(
                                            maxHeight:
                                                MediaQuery.of(
                                                  context,
                                                ).size.height /
                                                1.8,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.2,
                                                ),
                                                spreadRadius: 2,
                                                blurRadius: 15,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            child: GestureDetector(
                                              onTap: () async {
                                                await _getLyricsFromLrclib(
                                                  currentSongTitle,
                                                );
                                              },
                                              child: AspectRatio(
                                                aspectRatio: 1.0,
                                                child: _spotifyImage != null
                                                    ? Image.network(
                                                        _spotifyImage!,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) {
                                                              // Fallback to local image on error
                                                              return Image.asset(
                                                                "assets/images/$currentSongTitle.jpg",
                                                                fit: BoxFit
                                                                    .cover,
                                                              );
                                                            },
                                                        loadingBuilder:
                                                            (
                                                              context,
                                                              child,
                                                              loadingProgress,
                                                            ) {
                                                              if (loadingProgress ==
                                                                  null)
                                                                return child;
                                                              // Show local image while loading Spotify image
                                                              return Image.asset(
                                                                "assets/images/$currentSongTitle.jpg",
                                                                fit: BoxFit
                                                                    .cover,
                                                              );
                                                            },
                                                      )
                                                    : Image.asset(
                                                        "assets/images/$currentSongTitle.jpg",
                                                        fit: BoxFit.cover,
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 600,
                                          ),
                                          curve: Curves.easeInOut,
                                          height: _isFullScreen ? 20 : 0,
                                        ),
                                        AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 600,
                                          ),
                                          opacity: _isFullScreen ? 1.0 : 0.0,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 600,
                                            ),
                                            curve: Curves.easeInOut,
                                            transform: Matrix4.translationValues(
                                              0.0,
                                              _isFullScreen
                                                  ? 0.0
                                                  : 20.0, // slide up when showing
                                              0.0,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Text(
                                                  currentSongTitle,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Music controls at the bottom with animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              transform: Matrix4.translationValues(
                0.0,
                _isFullScreen ? 100.0 : 0.0, // slide down when fullscreen
                0.0,
              ),
              child: AnimatedBuilder(
                animation: AlwaysStoppedAnimation(_isFullScreen ? 0.0 : 1.0),
                builder: (context, child) {
                  return ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: _isFullScreen ? 3.0 : 0.0,
                      sigmaY: _isFullScreen ? 3.0 : 0.0,
                    ),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 600),
                      opacity: _isFullScreen ? 0.0 : 1.0,
                      child: MusicControlsWidget(
                        songTitle: currentSongTitle,
                        artistName: _currentArtist,
                        imageUrl: _spotifyImage,
                        volume: _vol,
                        progress: sliderProgress,
                        position: _currentTime,
                        duration: _totalSongTime,
                        isPlaying: _isPlaying,
                        isDragging: _userIsDraggingSlider,
                        onSliderChanged: (v) async {
                          // when user drags the slider to change song position
                          if (_totalSongTime.inMilliseconds > 0) {
                            final seekTo = Duration(
                              milliseconds: (v * _totalSongTime.inMilliseconds)
                                  .round(),
                            );
                            setState(() {
                              _currentTime = seekTo;
                            });
                            await _player.seek(seekTo);
                          }
                        },
                        onSliderStart: () {
                          // user started dragging slider
                          setState(() {
                            _userIsDraggingSlider = true;
                          });
                        },
                        onSliderEnd: () {
                          // user finished dragging slider
                          setState(() {
                            _userIsDraggingSlider = false;
                          });
                          _syncLyricsToCurrentPosition();
                        },
                        onToggle: _pausePlay,
                        onPrevious: _prevSong,
                        onNext: _nextSong,
                        onShuffle: _shuffleSong,
                        onRepeat: _repeatSong,
                        isShuffleEnabled: _isShuffle,
                        isRepeatEnabled: _isRepeat,
                        onVolumeChanged: _changeVolume,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MusicControlsWidget extends StatelessWidget {
  // CUSTOMIZABLE VARIABLES - ADJUST THESE TO CHANGE HEIGHT AND ICON SIZES
  static const double _containerVerticalPadding = 10;
  static const double _iconSize = 25;

  // idk

  final String songTitle; // Add song title parameter
  final String artistName; // Add artist name parameter
  final String? imageUrl; // Add image URL parameter
  final double volume; // Add volume parameter
  final double progress;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isDragging;
  final Function(double) onSliderChanged;
  final VoidCallback onSliderStart;
  final VoidCallback onSliderEnd;
  final VoidCallback onToggle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final bool isShuffleEnabled;
  final bool isRepeatEnabled;
  final Function(double) onVolumeChanged; // Add volume callback

  const MusicControlsWidget({
    super.key,
    required this.songTitle,
    required this.artistName,
    required this.imageUrl,
    required this.volume,
    required this.progress,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.isDragging,
    required this.onSliderChanged,
    required this.onSliderStart,
    required this.onSliderEnd,
    required this.onToggle,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
    required this.isShuffleEnabled,
    required this.isRepeatEnabled,
    required this.onVolumeChanged,
  });

  String _mmss(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: _containerVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (MediaQuery.of(context).size.width > 1000) ...[
            Expanded(
              flex: 1,
              child: Row(
                spacing: 10,
                children: [
                  imageUrl != null
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          height: 70,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to local image on error
                            return Image.asset(
                              "assets/images/$songTitle.jpg",
                              fit: BoxFit.cover,
                              height: 70,
                            );
                          },
                        )
                      : Image.asset(
                          "assets/images/$songTitle.jpg",
                          fit: BoxFit.cover,
                          height: 70,
                        ),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // Align text to left
                    children: [
                      Text(
                        songTitle,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        artistName,
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: _iconSize,
                      onPressed: onRepeat,
                      icon: Icon(
                        isRepeatEnabled ? Icons.repeat : Icons.repeat_outlined,
                        color: isRepeatEnabled ? Colors.blue : Colors.white,
                      ),
                    ),
                    IconButton(
                      iconSize: _iconSize,
                      onPressed: onPrevious,
                      icon: const Icon(Icons.skip_previous),
                      color: Colors.white,
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        iconSize: _iconSize,
                        onPressed: onToggle,
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: _iconSize,
                      onPressed: onNext,
                      icon: const Icon(Icons.skip_next),
                      color: Colors.white,
                    ),

                    IconButton(
                      iconSize: _iconSize,
                      onPressed: onShuffle,
                      icon: Icon(
                        isShuffleEnabled
                            ? Icons.shuffle
                            : Icons.shuffle_outlined,
                        color: isShuffleEnabled ? Colors.blue : Colors.white,
                      ),
                    ),
                  ],
                ),

                // Time stamps
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _mmss(position),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    SizedBox(
                      height: 30,
                      width: MediaQuery.of(context).size.width * 0.5,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 0,
                          ),
                        ),
                        child: Slider(
                          // Progress Slider
                          value: progress.clamp(0.0, 1.0),
                          onChanged: onSliderChanged,
                          onChangeStart: (_) => onSliderStart(),
                          onChangeEnd: (_) => onSliderEnd(),
                          activeColor: Colors.white,
                          inactiveColor: Colors.grey,
                        ),
                      ),
                    ),
                    Text(
                      _mmss(duration),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (MediaQuery.of(context).size.width > 1000) ...[
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.volume_up, color: Colors.white, size: 20),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 0,
                            ),
                          ),
                          child: Slider(
                            value: volume,
                            onChanged: onVolumeChanged,
                            activeColor: Colors.white,
                            inactiveColor: Colors.grey[600],
                            min: 0.0,
                            max: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
