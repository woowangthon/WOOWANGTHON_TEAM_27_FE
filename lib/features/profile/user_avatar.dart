import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../data/providers.dart';
import '../../data/session.dart';

/// 기본 아바타 4종 — 앱의 주제(찾기·탐색·즐기기·도전)에 맞춘 그라데이션 + 아이콘.
const avatarPresets = <(IconData, List<Color>)>[
  (Icons.radar_rounded, [Color(0xFF5865F2), Color(0xFF8E5CF7)]),
  (Icons.explore_rounded, [Color(0xFF0EA5E9), Color(0xFF14B8A6)]),
  (Icons.music_note_rounded, [Color(0xFFEC4899), Color(0xFF8B5CF6)]),
  (Icons.rocket_launch_rounded, [Color(0xFFF97316), Color(0xFFEF4444)]),
];

/// 처음 들어온 모든 사용자의 아바타 — 로켓 (도전·시작).
const defaultAvatar = 'preset:3';

/// 고른 아바타 (계정별): 'preset:0'..'preset:3' 또는 'photo'(Google 사진).
/// 아무것도 고르지 않았으면 모두 로켓 아바타로 시작한다 (Google 사진은 직접 고를 수 있다).
final avatarChoiceProvider = NotifierProvider<AvatarChoiceController, String?>(AvatarChoiceController.new);

class AvatarChoiceController extends Notifier<String?> {
  late String _key;

  @override
  String? build() {
    _key = 'avatar:${accountScope(ref.watch(sessionProvider))}';
    return ref.read(sharedPrefsProvider).getString(_key);
  }

  Future<void> choose(String value) async {
    state = value;
    await ref.read(sharedPrefsProvider).setString(_key, value);
  }
}

/// 사용자 아바타 — 홈 머리와 내 정보가 같은 것을 쓴다.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(sessionProvider)?.photoUrl;
    final choice = ref.watch(avatarChoiceProvider);
    final usePhoto = photo != null && choice == 'photo';
    if (usePhoto) {
      return ClipOval(
        child: Image.network(
          photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => AvatarArt(index: 0, size: size),
        ),
      );
    }
    final index = int.tryParse((choice ?? defaultAvatar).replaceFirst('preset:', '')) ?? 3;
    return AvatarArt(index: index.clamp(0, avatarPresets.length - 1), size: size);
  }
}

/// 기본 아바타 그림: 천천히 도는 그라데이션 원 + 흰 아이콘. "동작 줄이기"면 멈춘다.
class AvatarArt extends StatefulWidget {
  const AvatarArt({super.key, required this.index, this.size = 48, this.animate = true});
  final int index;
  final double size;
  final bool animate;

  @override
  State<AvatarArt> createState() => _AvatarArtState();
}

class _AvatarArtState extends State<AvatarArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 8));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.animate && !reduce) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, colors) = avatarPresets[widget.index];
    final s = widget.size;
    return SizedBox.square(
      dimension: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [...colors, colors.first],
              transform: GradientRotation(_c.value * 2 * math.pi),
            ),
          ),
          child: child,
        ),
        child: Container(
          margin: EdgeInsets.all(s * 0.06),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          ),
          child: Icon(icon, size: s * 0.5, color: Colors.white),
        ),
      ),
    );
  }
}

/// 아바타 고르기 — 기본 4종 (+ Google 사진이 있으면 사진).
Future<void> showAvatarPicker(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useRootNavigator: true,
  builder: (ctx) => const _AvatarPicker(),
);

class _AvatarPicker extends ConsumerWidget {
  const _AvatarPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final photo = ref.watch(sessionProvider)?.photoUrl;
    final choice = ref.watch(avatarChoiceProvider) ?? defaultAvatar;

    Future<void> pick(String v) async {
      await ref.read(avatarChoiceProvider.notifier).choose(v);
      Toast.show(l10n.avatarChanged);
      if (context.mounted) Navigator.pop(context);
    }

    Widget option(String value, Widget art) {
      final on = choice == value;
      return Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          onTap: () => pick(value),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.normal),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: on ? p.primary : Colors.transparent, width: 3),
            ),
            child: art,
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.avatarTitle, style: context.textStyles.titleMedium),
            const SizedBox(height: Space.lg),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: Space.md,
              runSpacing: Space.md,
              children: [
                for (var i = 0; i < avatarPresets.length; i++) option('preset:$i', AvatarArt(index: i, size: 64)),
                if (photo != null)
                  option(
                    'photo',
                    ClipOval(child: Image.network(photo, width: 64, height: 64, fit: BoxFit.cover)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
