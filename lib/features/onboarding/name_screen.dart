import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../core/widgets.dart';
import '../../data/session.dart';

/// 로그인 후: "어떻게 불러 드릴까요?" — 홈의 인사에 이 이름을 쓴다.
/// Google 이름(있으면)을 미리 채우지만 사용자가 바꿀 수 있다.
/// [editing] — 프로필에서 열렸을 때 (저장 후 돌아간다).
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key, this.editing = false});
  final bool editing;

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  late final TextEditingController _c = TextEditingController(text: _initial());
  bool _error = false;
  bool _saving = false;

  String _initial() {
    final saved = ref.read(profileNameProvider);
    if (saved != null) return saved;
    final session = ref.read(sessionProvider);
    if (session == null || session.isGuest) return '';
    // Google: 보통 "이름 성" — 첫 단어.
    return (session.name ?? '').trim().split(RegExp(r'\s+')).first;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _c.text.trim();
    if (name.isEmpty) {
      setState(() => _error = true);
      return;
    }
    setState(() => _saving = true);
    await ref.read(profileNameProvider.notifier).save(name);
    if (!mounted) return;
    if (widget.editing) {
      Toast.show(context.l10n.nameSaved);
      context.pop();
    } else {
      context.go(nextAfterAuthOf(ref));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.editing ? null : Colors.transparent,
        automaticallyImplyLeading: widget.editing,
        title: widget.editing ? Text(l10n.editName) : null,
      ),
      // 첫 설정에서는 welcome/login과 같은 그라데이션, 수정할 때는 일반 배경.
      extendBodyBehindAppBar: !widget.editing,
      backgroundColor: widget.editing ? null : Colors.transparent,
      body: DecoratedBox(
        decoration: widget.editing
            ? BoxDecoration(color: p.background)
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.45, 1],
                  colors: [p.primarySoft, p.background, p.background],
                ),
              ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(top: Space.sm),
                        children: [
                          if (!widget.editing)
                            FadeSlideIn(
                              child: Text(l10n.stepOf(1, 2), style: t.labelMedium!.copyWith(color: p.primary)),
                            ),
                          const SizedBox(height: Space.sm),
                          FadeSlideIn(index: 1, child: Text(l10n.nameTitle, style: t.headlineSmall)),
                          const SizedBox(height: Space.sm),
                          FadeSlideIn(
                            index: 2,
                            child: Text(l10n.nameSubtitle, style: t.bodyMedium!.copyWith(color: p.textMuted)),
                          ),
                          const SizedBox(height: Space.xxl),
                          FadeSlideIn(
                            index: 3,
                            child: TextField(
                              controller: _c,
                              autofocus: true,
                              maxLength: 20,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                              style: t.headlineSmall!.copyWith(fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: l10n.nameHint,
                                errorText: _error ? l10n.nameRequired : null,
                                counterText: '',
                              ),
                              onChanged: (_) {
                                if (_error) setState(() => _error = false);
                              },
                              onSubmitted: (_) => _save(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.xl),
                      child: ListenableBuilder(
                        listenable: _c,
                        builder: (context, _) => FilledButton(
                          onPressed: _saving || _c.text.trim().isEmpty ? null : _save,
                          child: _saving
                              ? AppSpinner(size: 20, color: p.textMuted)
                              : Text(widget.editing ? l10n.save : l10n.next),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
