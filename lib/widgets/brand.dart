import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';

/// شعار المؤسسة: عربة تسوق ذهبية بورقة، والاسم بخط عريض.
///
/// الكلمة الأولى من اسم المؤسسة تُكتب كبيرة وبقية الاسم تحتها،
/// فيتغير الشعار تلقائياً إذا غُيّر الاسم من الإعدادات.
class BrandLogo extends StatelessWidget {
  /// على خلفية داكنة (القائمة الجانبية) يكون الاسم أبيض.
  final bool onDark;
  final double size;
  const BrandLogo({super.key, this.onDark = false, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final name = context.select<AppState, String>((s) => s.company.name).trim();
    final space = name.indexOf(' ');
    final first = space < 0 ? name : name.substring(0, space);
    final rest = space < 0 ? '' : name.substring(space + 1);
    final color = onDark ? Colors.white : AppColors.brand;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              first,
              style: TextStyle(
                color: color,
                fontSize: size,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            if (rest.isNotEmpty) ...[
              SizedBox(height: size * 0.12),
              Text(
                rest,
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ],
          ],
        ),
        SizedBox(width: size * 0.15),
        _CartMark(size: size * 1.5),
      ],
    );
  }
}

/// عربة التسوق بورقة نبات: رمز «طيبة».
class _CartMark extends StatelessWidget {
  final double size;
  const _CartMark({required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      children: [
        Icon(Icons.shopping_cart_outlined, size: size, color: AppColors.gold),
        PositionedDirectional(
          top: size * 0.12,
          start: size * 0.34,
          child: Transform.rotate(
            angle: -math.pi / 8,
            child: Icon(
              Icons.eco,
              size: size * 0.42,
              color: const Color(0xFFD9A43A),
            ),
          ),
        ),
      ],
    ),
  );
}

/// خلفية لافتة الصفحة: موجة خضراء بحافة ذهبية في الجهة اليسرى (بالعربية)،
/// فوقها رسم صناديق وحافظة فواتير.
class BannerArt extends StatelessWidget {
  final double width;
  const BannerArt({super.key, this.width = 420});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _WavePainter(
            mirror: Directionality.of(context) == TextDirection.ltr,
          ),
        ),
        const Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: 24, top: 12),
            child: _Boxes(),
          ),
        ),
      ],
    ),
  );
}

class _WavePainter extends CustomPainter {
  final bool mirror;
  const _WavePainter({required this.mirror});

  @override
  void paint(Canvas canvas, Size size) {
    if (mirror) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final w = size.width, h = size.height;
    // الموجة تُرسم في الجهة اليسرى من المساحة (نهاية السطر بالعربية).
    Path wave(double edge) => Path()
      ..moveTo(0, 0)
      ..lineTo(w * edge, 0)
      ..cubicTo(
        w * (edge - 0.22),
        h * 0.3,
        w * (edge + 0.05),
        h * 0.7,
        w * (edge - 0.18),
        h,
      )
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      wave(0.98),
      Paint()..color = const Color(0xFFE9C46A).withValues(alpha: 0.55),
    );
    canvas.drawPath(
      wave(0.93),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0E5A41), Color(0xFF06311F)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      wave(0.93),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.gold,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.mirror != mirror;
}

/// صناديق كرتونية وحافظة فواتير وقارئ باركود مرسومة بالأشكال.
class _Boxes extends StatelessWidget {
  const _Boxes();

  Widget _box(double size, Color color) => Container(
    width: size,
    height: size * 0.8,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
      boxShadow: const [
        BoxShadow(
          color: Color(0x44000000),
          blurRadius: 6,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Center(
      child: Container(
        width: size * 0.16,
        height: size * 0.8,
        color: const Color(0x22000000),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 270,
    height: 140,
    child: Stack(
      children: [
        PositionedDirectional(
          end: 0,
          bottom: 0,
          child: _box(78, const Color(0xFFD9A066)),
        ),
        PositionedDirectional(
          end: 10,
          bottom: 60,
          child: _box(60, const Color(0xFFE2B07A)),
        ),
        PositionedDirectional(
          end: 82,
          bottom: 0,
          child: _box(66, const Color(0xFF1F6B4B)),
        ),
        PositionedDirectional(
          end: 210,
          bottom: 0,
          child: _box(56, const Color(0xFFC98F55)),
        ),
        PositionedDirectional(
          end: 130,
          bottom: 0,
          child: Container(
            width: 78,
            height: 112,
            decoration: BoxDecoration(
              color: const Color(0xFF2A7A57),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(7),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(
                Icons.receipt_long,
                size: 46,
                color: Color(0xFF9DB7A9),
              ),
            ),
          ),
        ),
        const PositionedDirectional(
          end: 100,
          bottom: 2,
          child: Icon(
            Icons.qr_code_scanner,
            size: 36,
            color: Color(0xFF1C1C1C),
          ),
        ),
      ],
    ),
  );
}
