import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_tab.dart';
import 'icons_tab.dart';
import 'images_tab.dart';
import 'lottie_tab.dart';

/// Screen for browsing and managing asset files.
///
/// Contains a [TabBar] with four tabs: Images, Audio, Lottie, Icons.
/// Each tab will display the corresponding asset category contents.
class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assets'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.image_outlined), text: 'Images'),
            Tab(icon: Icon(Icons.audiotrack_outlined), text: 'Audio'),
            Tab(icon: Icon(Icons.animation_outlined), text: 'Lottie'),
            Tab(icon: Icon(Icons.emoji_symbols_outlined), text: 'Icons'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ImagesTab(),
          AudioTab(),
          LottieTab(),
          IconsTab(),
        ],
      ),
    );
  }
}
