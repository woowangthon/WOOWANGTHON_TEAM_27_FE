import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:liferadar_core/liferadar_core.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LifeRadar design system
//
// 브랜드: primary #5865F2 (blurple) · secondary #23272A · neutral #FFFFFF.
// 스타일: 차분한 중립 표면 + 주 색상 하나. 강조색(amber)은 경고와 마감에만.
// 다크 모드: 순수 검정·순수 흰색을 쓰지 않고(눈부심·번짐 방지), 표면은 secondary #23272A 계열,
// 주 색상은 한 단계 밝고 채도를 낮춘 #8E96F8 + 어두운 글자 (Material 3 방식, 대비 ≥ 4.5:1).
// 그라데이션은 brand → violet 두 색만, 넓은 배경의 은은한 빛과 브랜드 글자에만 쓴다.
// 모든 컴포넌트는 이 토큰만 사용하며 화면 코드에 hex 값을 직접 쓰지 않는다.
// ─────────────────────────────────────────────────────────────────────────────

/// 간격 — 4/8dp 리듬.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// 화면 가장자리 안쪽 여백.
  static const gutter = 20.0;
}

/// 모서리 반경.
abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

/// 애니메이션 시간. 사용자가 "동작 줄이기"를 켜면 0.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;

  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

/// 의미 기반 색상 (ThemeExtension). 위젯에서: `context.palette.textMuted`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.primarySoft,
    required this.primaryStrong,
    required this.primaryAlt,
    required this.onPrimary,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.skeleton,
  });

  final Color background, surface, surfaceAlt, border;
  final Color text, textMuted;
  final Color primary, primarySoft, onPrimary;

  /// 연한 primary 배경(선택된 칩·세그먼트) 위의 글자 — 작은 글자도 대비 ≥ 4.5:1.
  final Color primaryStrong;

  /// 그라데이션 짝 (violet). 브랜드 글자·배경 빛에만.
  final Color primaryAlt;

  /// 경고 / 마감 (amber).
  final Color accent, accentSoft;
  final Color danger, dangerSoft;
  final Color info, infoSoft;
  final Color skeleton;

  static const light = AppPalette(
    background: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF0F6),
    border: Color(0xFFE2E4EC),
    text: Color(0xFF23272A), // secondary — 흰색 위 15:1
    textMuted: Color(0xFF5B616E), // 흰색 위 6.2:1
    primary: Color(0xFF5865F2), // 흰색 위 4.6:1
    primarySoft: Color(0xFFEBEDFE),
    primaryStrong: Color(0xFF4752C4), // primarySoft 위 ≥ 6:1
    primaryAlt: Color(0xFF8B5CF6),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFB45309),
    accentSoft: Color(0xFFFEF3C7),
    danger: Color(0xFFD83C3E),
    dangerSoft: Color(0xFFFDECEC),
    info: Color(0xFF0E7490),
    infoSoft: Color(0xFFE0F4F7),
    skeleton: Color(0xFFE7E9F0),
  );

  static const dark = AppPalette(
    background: Color(0xFF1A1B1F),
    surface: Color(0xFF23272A), // secondary
    surfaceAlt: Color(0xFF2C3035),
    border: Color(0xFF363A40),
    text: Color(0xFFE4E6EB), // 순수 흰색 대신 — surface 위 12:1
    textMuted: Color(0xFFA2A7B1), // surface 위 6.2:1
    primary: Color(0xFF8E96F8), // surface 위 5.6:1
    primarySoft: Color(0xFF2B2F55),
    primaryStrong: Color(0xFF8E96F8),
    primaryAlt: Color(0xFFB49AF7),
    onPrimary: Color(0xFF12153A), // primary 위 6.6:1
    accent: Color(0xFFF2B544),
    accentSoft: Color(0xFF3A2F17),
    danger: Color(0xFFF07A7D),
    dangerSoft: Color(0xFF3D2124),
    info: Color(0xFF5FC4D4),
    infoSoft: Color(0xFF17343A),
    skeleton: Color(0xFF2A2E33),
  );

  /// 브랜드 그라데이션 (blurple → violet).
  LinearGradient get brandGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryAlt],
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      border: l(border, other.border),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      primary: l(primary, other.primary),
      primarySoft: l(primarySoft, other.primarySoft),
      primaryStrong: l(primaryStrong, other.primaryStrong),
      primaryAlt: l(primaryAlt, other.primaryAlt),
      onPrimary: l(onPrimary, other.onPrimary),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      skeleton: l(skeleton, other.skeleton),
    );
  }
}

extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  TextTheme get textStyles => Theme.of(this).textTheme;
}

/// 지도 마커 — 두 테마 모두에서 지도 타일 위에 잘 보이는 차분한 색.
abstract final class AppColors {
  static const brand = Color(0xFF5865F2);
  static const plan = Color(0xFF5865F2);
  static const recommended = Color(0xFFE8890C);
  static const contest = Color(0xFF8B5CF6);
  static const route = Color(0xFF0D9488);
}

const appFontFamily = 'LifeRadarSans';

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primarySoft,
    onPrimaryContainer: p.primaryStrong,
    secondary: p.primaryAlt,
    onSecondary: p.onPrimary,
    secondaryContainer: p.surfaceAlt,
    onSecondaryContainer: p.text,
    tertiary: p.accent,
    onTertiary: p.surface,
    tertiaryContainer: p.accentSoft,
    onTertiaryContainer: p.accent,
    error: p.danger,
    onError: p.surface,
    errorContainer: p.dangerSoft,
    onErrorContainer: p.danger,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.textMuted,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surfaceAlt,
    surfaceContainerHigh: p.surfaceAlt,
    surfaceContainerHighest: p.surfaceAlt,
    outline: p.textMuted,
    outlineVariant: p.border,
    inverseSurface: p.text,
    onInverseSurface: p.background,
    inversePrimary: p.primarySoft,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  // Pretendard 기반 글꼴: 한글과 라틴 문자가 같은 스타일, 숫자가 또렷하다.
  final base = ThemeData(brightness: brightness, useMaterial3: true, fontFamily: appFontFamily);
  final t = base.textTheme.apply(bodyColor: p.text, displayColor: p.text);
  final text = t.copyWith(
    headlineMedium: t.headlineMedium?.copyWith(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.25),
    headlineSmall: t.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.3),
    titleLarge: t.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.35),
    titleMedium: t.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2, height: 1.4),
    titleSmall: t.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.4),
    bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.55, letterSpacing: -0.1),
    bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.5, letterSpacing: -0.1),
    bodySmall: t.bodySmall?.copyWith(fontSize: 12.5, height: 1.45, color: p.textMuted),
    labelLarge: t.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1),
    labelMedium: t.labelMedium?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.textMuted),
    labelSmall: t.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: p.textMuted),
  );

  RoundedRectangleBorder rounded(double r, {Color? side}) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r),
        side: side == null ? BorderSide.none : BorderSide(color: side),
      );

  return base.copyWith(
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerColor: p.border,
    // 안드로이드: 누른 자리에서 반짝이며 퍼지는 물결 (웹은 셰이더 지원이 달라 기본 물결).
    splashFactory: !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? InkSparkle.splashFactory : InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    extensions: [p],
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: Space.gutter,
      titleTextStyle: text.titleLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      elevation: 0,
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.primarySoft,
      indicatorShape: rounded(Radii.md),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? p.primary : p.textMuted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall!.copyWith(
          fontSize: 11.5,
          letterSpacing: 0,
          color: s.contains(WidgetState.selected) ? p.primary : p.textMuted,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: rounded(Radii.lg, side: p.border),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        disabledBackgroundColor: p.surfaceAlt,
        disabledForegroundColor: p.textMuted,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        shape: rounded(Radii.md),
        textStyle: text.labelLarge,
        animationDuration: const Duration(milliseconds: 120),
      ).copyWith(
        // 3D 버튼: 평소에는 아래 그림자, 누르면 그림자가 사라지며 "눌린다". 비활성은 평평.
        elevation: WidgetStateProperty.resolveWith((st) {
          if (st.contains(WidgetState.disabled) || st.contains(WidgetState.pressed)) return 0;
          return dark ? 0 : 3;
        }),
        shadowColor: WidgetStatePropertyAll(Color.lerp(p.primary, Colors.black, 0.35)!.withValues(alpha: 0.55)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        side: BorderSide(color: p.border),
        shape: rounded(Radii.md),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        minimumSize: const Size(48, 44),
        shape: rounded(Radii.sm),
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.textMuted, minimumSize: const Size(44, 44)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.primarySoft,
      disabledColor: p.surfaceAlt,
      checkmarkColor: p.primary,
      side: WidgetStateBorderSide.resolveWith(
        (s) => BorderSide(color: s.contains(WidgetState.selected) ? p.primary.withValues(alpha: 0.45) : p.border),
      ),
      shape: rounded(Radii.md),
      // 상태별 글자 스타일(WidgetStateTextStyle)은 칩 폭 계산과 어긋나 글자가 잘렸다 → 한 가지 스타일.
      // 선택 상태는 배경(primarySoft)과 테두리로 구분한다.
      labelStyle: text.bodyMedium!.copyWith(fontWeight: FontWeight.w500, color: p.text),
      secondaryLabelStyle: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: p.primaryStrong),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm),
      iconTheme: IconThemeData(size: 18, color: p.textMuted),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        shape: WidgetStatePropertyAll(rounded(Radii.md)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primarySoft : p.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primaryStrong : p.textMuted,
        ),
        textStyle: WidgetStatePropertyAll(text.labelMedium!.copyWith(fontSize: 13)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceAlt,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
      hintStyle: text.bodyMedium!.copyWith(color: p.textMuted),
      labelStyle: text.bodyMedium!.copyWith(color: p.textMuted),
      prefixIconColor: p.textMuted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: p.primary, width: 1.5),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.surface,
      showDragHandle: true,
      dragHandleColor: p.border,
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.text,
      contentTextStyle: text.bodyMedium!.copyWith(color: p.background),
      actionTextColor: p.primarySoft,
      shape: rounded(Radii.md),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(Radii.xl),
    ),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
      iconColor: p.textMuted,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall,
      minVerticalPadding: Space.md,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary, linearTrackColor: p.surfaceAlt),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onPrimary : p.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.surfaceAlt),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.text, borderRadius: BorderRadius.circular(Radii.sm)),
      textStyle: text.bodySmall!.copyWith(color: p.background),
    ),
    badgeTheme: BadgeThemeData(backgroundColor: p.primary, textColor: p.onPrimary),
  );
}

IconData categoryIcon(EventCategory c) => switch (c) {
      EventCategory.contest => Icons.emoji_events_outlined,
      EventCategory.conference => Icons.co_present_outlined,
      EventCategory.hackathon => Icons.code_rounded,
      EventCategory.concert => Icons.music_note_outlined,
      EventCategory.festival => Icons.celebration_outlined,
      EventCategory.meetup => Icons.groups_outlined,
      EventCategory.job => Icons.work_outline,
      EventCategory.scholarship => Icons.school_outlined,
      EventCategory.performance => Icons.theater_comedy_outlined,
      EventCategory.exhibition => Icons.museum_outlined,
      EventCategory.classes => Icons.draw_outlined,
      EventCategory.startupSupport => Icons.rocket_launch_outlined,
    };

IconData signalIcon(SignalType t) => switch (t) {
      SignalType.event => Icons.event_outlined,
      SignalType.weather => Icons.wb_sunny_outlined,
      SignalType.traffic => Icons.directions_transit_outlined,
      SignalType.deadline => Icons.schedule_outlined,
    };

// ─────────────────────────── 관심사 색상 ───────────────────────────

/// 관심사용 색상 팔레트: 구분되지만 차분한 색.
/// Light: 글자 700, 배경 100. Dark: 글자 300, 배경은 같은 색의 16% 투명.
/// 두 모드 모두 글자/배경 대비 ≥ 4.5:1.
enum Hue {
  teal(Color(0xFF0F766E), Color(0xFFCCFBF1), Color(0xFF5EEAD4)),
  cyan(Color(0xFF0E7490), Color(0xFFCFFAFE), Color(0xFF67E8F9)),
  sky(Color(0xFF0369A1), Color(0xFFE0F2FE), Color(0xFF7DD3FC)),
  blue(Color(0xFF1D4ED8), Color(0xFFDBEAFE), Color(0xFF93C5FD)),
  indigo(Color(0xFF4338CA), Color(0xFFE0E7FF), Color(0xFFA5B4FC)),
  violet(Color(0xFF6D28D9), Color(0xFFEDE9FE), Color(0xFFC4B5FD)),
  pink(Color(0xFFBE185D), Color(0xFFFCE7F3), Color(0xFFF9A8D4)),
  rose(Color(0xFFBE123C), Color(0xFFFFE4E6), Color(0xFFFDA4AF)),
  orange(Color(0xFFC2410C), Color(0xFFFFEDD5), Color(0xFFFDBA74)),
  amber(Color(0xFFB45309), Color(0xFFFEF3C7), Color(0xFFFCD34D)),
  lime(Color(0xFF4D7C0F), Color(0xFFECFCCB), Color(0xFFBEF264)),
  green(Color(0xFF15803D), Color(0xFFDCFCE7), Color(0xFF86EFAC));

  const Hue(this._fgLight, this._bgLight, this._fgDark);
  final Color _fgLight, _bgLight, _fgDark;

  /// (글자/아이콘 색, 배경색)
  (Color fg, Color bg) of(BuildContext context) => Theme.of(context).brightness == Brightness.dark
      ? (_fgDark, _fgDark.withValues(alpha: 0.16))
      : (_fgLight, _bgLight);
}
