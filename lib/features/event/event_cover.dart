import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liferadar_core/liferadar_core.dart';

import '../../core/theme.dart';

/// 포스터가 없는 행사의 기본 그림 — 앱의 "레이더" 모양 (브랜드 그라데이션, 퍼지는 원,
/// 지도 핀 같은 점) 위에 행사 종류 아이콘. 코드로 그려서 오프라인·다크 모드에서도 같다.
/// 행사 id로 원의 위치를 조금씩 바꿔 카드가 모두 똑같아 보이지 않게 한다.
class EventCover extends StatelessWidget {
  const EventCover({super.key, required this.category, this.seed = '', this.iconSize = 28});
  final EventCategory category;
  final String seed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: p.brandGradient),
      child: CustomPaint(
        painter: _RadarPainter(seed: seed.hashCode, dark: dark),
        child: Center(
          child: Container(
            padding: EdgeInsets.all(iconSize * 0.42),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
            ),
            child: Icon(categoryIcon(category), size: iconSize, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.seed, required this.dark});
  final int seed;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    // 원의 중심: 네 모서리 중 하나 근처.
    final corner = Offset(
      rnd.nextBool() ? size.width * 0.12 : size.width * 0.88,
      rnd.nextBool() ? size.height * 0.15 : size.height * 0.85,
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: dark ? 0.16 : 0.22);
    final step = math.max(size.width, size.height) / 5;
    for (var i = 1; i <= 6; i++) {
      canvas.drawCircle(corner, step * i, ring);
    }
    // 레이더가 훑고 지나간 부채꼴.
    final sweep = Paint()
      ..shader = SweepGradient(
        center: Alignment(corner.dx / size.width * 2 - 1, corner.dy / size.height * 2 - 1),
        colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: dark ? 0.10 : 0.16)],
        stops: const [0.75, 1],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(corner, step * 6, sweep);
    // 지도 핀 같은 작은 점 몇 개.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < 4; i++) {
      final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawCircle(o, 1.6 + rnd.nextDouble() * 1.6, dot);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.seed != seed || old.dark != dark;
}
