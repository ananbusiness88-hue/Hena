import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'auth_gate.dart';

class IntroVideoPage extends StatefulWidget {
  const IntroVideoPage({super.key});

  @override
  State<IntroVideoPage> createState() => _IntroVideoPageState();
}

class _IntroVideoPageState extends State<IntroVideoPage> {
  late final VideoPlayerController _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(
      'assets/branding/intoApp.mp4',
    );

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    await _controller.initialize();

    if (!mounted) return;

    await _controller.setVolume(1.0);

    _controller.addListener(_videoListener);

    await _controller.play();

    setState(() {});
  }

  void _videoListener() {
    if (!_controller.value.isInitialized) return;

    final position = _controller.value.position;
    final duration = _controller.value.duration;

    if (!_finished &&
        duration > Duration.zero &&
        position >= duration &&
        !_controller.value.isPlaying) {
      _finished = true;

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AuthGate(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
      ),
    );
  }
}
