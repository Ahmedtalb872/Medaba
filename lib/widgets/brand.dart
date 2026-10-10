import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';

/// شعار المؤسسة: سنابل قمح ذهبية بجانب اسم المؤسسة.
///
/// الكلمة الأولى من اسم المؤسسة تُكتب كبيرة، وبقية الاسم تحتها عند [showRest]،
/// فيتغير الشعار تلقائياً إذا غُيّر الاسم من الإعدادات.
class BrandLogo extends StatelessWidget {
  /// على خلفية داكنة (القائمة الجانبية) يكون الاسم ذهبياً.
  final bool onDark;
  final double size;
  final bool showRest;

  /// اسم المؤسسة؛ إن لم يُمرَّر يؤخذ من بيانات التطبيق.
  final String? name;
  const BrandLogo({
    super.key,
    this.onDark = false,
    this.size = 40,
    this.showRest = true,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        (this.name ?? context.select<AppState, String>((s) => s.company.name))
            .trim();
    final space = name.indexOf(' ');
    final first = space < 0 ? name : name.substring(0, space);
    final rest = space < 0 || !showRest ? '' : name.substring(space + 1);
    final color = onDark ? AppColors.navAccent : AppColors.brand;
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
                  color: onDark ? Colors.white : color,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ],
          ],
        ),
        SizedBox(width: size * 0.2),
        WheatMark(size: size * 1.4),
      ],
    );
  }
}

/// سنبلتا قمح ذهبيتان: رمز «طيبة».
class WheatMark extends StatelessWidget {
  final double size;
  const WheatMark({super.key, required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size * 0.7,
    height: size,
    child: CustomPaint(painter: _WheatPainter()),
  );
}

class _WheatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF6D77A), Color(0xFFC98A1C)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    final stroke = Paint()
      ..shader = paint.shader
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.06;

    // سنبلة: ساق منحنية تتوزع عليها حبات على الجانبين.
    void stalk(Offset base, Offset top, double lean, int grains) {
      final ctrl = Offset(
        (base.dx + top.dx) / 2 + lean,
        (base.dy + top.dy) / 2,
      );
      final path = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, top.dx, top.dy);
      canvas.drawPath(path, stroke);
      final metric = path.computeMetrics().first;
      for (var i = 0; i < grains; i++) {
        final t = metric.length * (0.42 + i * 0.58 / grains);
        final tan = metric.getTangentForOffset(t)!;
        final angle = tan.angle;
        for (final side in [-1.0, 1.0]) {
          canvas.save();
          canvas.translate(tan.position.dx, tan.position.dy);
          canvas.rotate(-angle + side * 0.55);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(0, -w * 0.09 * side),
              width: w * 0.15,
              height: w * 0.3,
            ).shift(Offset(-w * 0.02, 0)),
            paint,
          );
          canvas.restore();
        }
      }
      canvas.drawOval(
        Rect.fromCenter(center: top, width: w * 0.12, height: w * 0.24),
        paint,
      );
    }

    stalk(Offset(w * 0.45, h), Offset(w * 0.62, h * 0.05), -w * 0.1, 4);
    stalk(Offset(w * 0.4, h), Offset(w * 0.18, h * 0.3), w * 0.12, 3);
    // ورقة طويلة تلتف حول الساقين.
    final leaf = Path()
      ..moveTo(w * 0.42, h)
      ..quadraticBezierTo(w * 1.0, h * 0.75, w * 0.95, h * 0.35)
      ..quadraticBezierTo(w * 0.8, h * 0.75, w * 0.42, h)
      ..close();
    canvas.drawPath(leaf, paint);
  }

  @override
  bool shouldRepaint(_WheatPainter old) => false;
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
        const Padding(
          padding: EdgeInsetsDirectional.only(end: 16, top: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.bottomEnd,
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

/// كومة صناديق كرتونية ونبتة، مرسومة بالأشكال.
class _Boxes extends StatelessWidget {
  const _Boxes();

  Widget _box(double w, double h, Color color) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color.lerp(color, Colors.white, 0.18)!, color],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0x33000000), width: 0.6),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 5,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: w * 0.16,
        height: h * 0.35,
        color: const Color(0x26000000),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const a = Color(0xFFCF9B5E), b = Color(0xFFDDAE72), c = Color(0xFFC48A4E);
    // صفوف الكومة من الأسفل للأعلى: (المسافة من النهاية، الارتفاع من الأسفل، العرض، الارتفاع، اللون).
    const boxes = [
      (0.0, 0.0, 70.0, 64.0, a),
      (72.0, 0.0, 78.0, 70.0, b),
      (152.0, 0.0, 72.0, 62.0, c),
      (226.0, 0.0, 64.0, 56.0, a),
      (30.0, 64.0, 66.0, 54.0, c),
      (98.0, 70.0, 74.0, 60.0, a),
      (174.0, 62.0, 62.0, 52.0, b),
      (70.0, 130.0, 64.0, 46.0, b),
      (136.0, 120.0, 58.0, 48.0, c),
    ];
    return SizedBox(
      width: 360,
      height: 190,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // نبتة خلف الصناديق.
          const PositionedDirectional(
            end: 262,
            bottom: 30,
            child: Icon(Icons.eco, size: 110, color: Color(0xFF2E6B3F)),
          ),
          const PositionedDirectional(
            end: 290,
            bottom: 70,
            child: Icon(Icons.spa, size: 70, color: Color(0xFF3C8250)),
          ),
          for (final (end, bottom, w, h, color) in boxes)
            PositionedDirectional(
              end: end,
              bottom: bottom,
              child: _box(w, h, color),
            ),
        ],
      ),
    );
  }
}
