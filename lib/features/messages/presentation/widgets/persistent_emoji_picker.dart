import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../../../../shared/theme/app_colors.dart';

class PersistentEmojiPicker extends StatefulWidget {
  final TextEditingController textEditingController;
  final bool isVisible;
  final VoidCallback onEmojiSelected;

  const PersistentEmojiPicker({
    super.key,
    required this.textEditingController,
    required this.isVisible,
    required this.onEmojiSelected,
  });

  @override
  State<PersistentEmojiPicker> createState() => _PersistentEmojiPickerState();
}

class _PersistentEmojiPickerState extends State<PersistentEmojiPicker> {
  late final Config _config;

  @override
  void initState() {
    super.initState();
    _config = Config(
      height: 256,
      checkPlatformCompatibility: true,
      // We removed GoogleFonts to use system default emoji fonts,
      // which are significantly faster to render during transitions.
      emojiViewConfig: EmojiViewConfig(
        emojiSizeMax: 28 *
            (foundation.defaultTargetPlatform == TargetPlatform.iOS
                ? 1.2
                : 1.0),
        columns: 7,
        backgroundColor: AppColors.bgPrimary,
        noRecents: const Text(
          'Нет недавних эмодзи',
          style: TextStyle(fontSize: 16, color: AppColors.textTertiary),
          textAlign: TextAlign.center,
        ),
      ),
      categoryViewConfig: CategoryViewConfig(
        backgroundColor: AppColors.bgPrimary,
        indicatorColor: AppColors.accentBlue,
        iconColorSelected: AppColors.accentBlue,
        iconColor: AppColors.textTertiary,
      ),
      bottomActionBarConfig: const BottomActionBarConfig(
        showBackspaceButton: true,
        showSearchViewButton: true,
      ),
      searchViewConfig: SearchViewConfig(
        backgroundColor: AppColors.bgPrimary,
        buttonIconColor: AppColors.textTertiary,
        hintText: 'Поиск эмодзи...',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !widget.isVisible,
      child: SafeArea(
        top: false,
        child: RepaintBoundary(
          child: SizedBox(
            height: 256,
            child: EmojiPicker(
              textEditingController: widget.textEditingController,
              onEmojiSelected: (category, emoji) => widget.onEmojiSelected(),
              config: _config,
            ),
          ),
        ),
      ),
    );
  }
}
