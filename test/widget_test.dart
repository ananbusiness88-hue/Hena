import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:app/main.dart';

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return Stream<VideoEvent>.empty();
  }

  @override
  Future<void> dispose(int playerId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
  });

  testWidgets('Hena app displays the intro screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: HenaApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(
      find.byType(Scaffold),
    );

    expect(scaffold.backgroundColor, Colors.black);
  });
}