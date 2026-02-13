import 'package:flutter/material.dart';

/// Soft indigo/slate blue for the wave hills.
const Color _kHillColor = Color(0xFF5C6BC0);
const Color _kHillColorLight = Color(0xFF7986CB);
const Color _kSkyWhite = Color(0xFFFFFFFF);
const Color _kCloudGray = Color(0xFFE0E0E0);
const Color _kPineGreen = Color(0xFF2E7D32);
const Color _kCarRed = Color(0xFFD32F2F);
const Color _kManSweater = Color(0xFF8D6E63);
const Color _kManPants = Color(0xFF37474F);
const Color _kPinBlue = Color(0xFF4285F4);
const Color _kPinRed = Color(0xFFEA4335);

/// Full-screen background for login: white sky + indigo wave hills.
class LoginBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Sky (top ~55%)
    final skyRect = Rect.fromLTWH(0, 0, w, h * 0.55);
    canvas.drawRect(skyRect, Paint()..color = _kSkyWhite);

    // Wave hills (two overlapping waves from bottom)
    final hillPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.45)
      ..quadraticBezierTo(w * 0.25, h * 0.25, w * 0.5, h * 0.42)
      ..quadraticBezierTo(w * 0.75, h * 0.58, w, h * 0.38)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hillPath, Paint()..color = _kHillColor);

    final hillPath2 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.4, h * 0.35, w * 0.7, h * 0.48)
      ..quadraticBezierTo(w * 0.9, h * 0.55, w, h * 0.48)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hillPath2, Paint()..color = _kHillColorLight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simple clouds (soft gray ellipses).
class CloudsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _kCloudGray;
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.2, size.height * 0.25), width: 48, height: 28), paint);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.28, size.height * 0.22), width: 36, height: 22), paint);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.35, size.height * 0.28), width: 42, height: 24), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Minimalist airplane shape (white with slight shadow).
class AirplanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const w = 40.0;
    const h = 24.0;
    final path = Path()
      ..moveTo(4, h * 0.5)
      ..lineTo(w - 8, h * 0.5)
      ..lineTo(w - 4, h * 0.35)
      ..lineTo(w, h * 0.5)
      ..lineTo(w - 4, h * 0.65)
      ..lineTo(w - 8, h * 0.5)
      ..lineTo(4, h * 0.5)
      ..moveTo(12, h * 0.5)
      ..lineTo(16, h * 0.2)
      ..lineTo(20, h * 0.5)
      ..lineTo(16, h * 0.8)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(path, Paint()..color = const Color(0xFFB0BEC5)..style = PaintingStyle.stroke..strokeWidth = 1);
    // Vapor trail
    canvas.drawLine(Offset(0, h * 0.5), Offset(8, h * 0.5), Paint()..color = Colors.white.withValues(alpha: 0.5)..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Stylized pine tree (triangle + trunk).
class PineTreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const w = 36.0;
    const h = 48.0;
    final paint = Paint()..color = _kPineGreen;
    // Trunk
    canvas.drawRect(Rect.fromLTWH(w * 0.4, h * 0.65, w * 0.2, h * 0.35), paint);
    // Foliage (two triangles)
    final tri = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(0, h * 0.5)
      ..close();
    canvas.drawPath(tri, paint);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.2)
        ..lineTo(w * 0.85, h * 0.55)
        ..lineTo(w * 0.15, h * 0.55)
        ..close(),
      Paint()..color = _kPineGreen.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Man with camera (minimalist: circle head, body, camera rect).
class ManWithCameraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const w = 32.0;
    const h = 56.0;
    // Head
    canvas.drawCircle(Offset(w * 0.5, 10), 6, Paint()..color = const Color(0xFFFFDBAC));
    // Sweater
    canvas.drawRect(Rect.fromLTWH(w * 0.2, 18, w * 0.6, 18), Paint()..color = _kManSweater);
    // Pants
    canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.64, w * 0.5, h * 0.36), Paint()..color = _kManPants);
    // Camera (held up to eye)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.5, 8, 14, 10), const Radius.circular(2)),
      Paint()..color = Colors.black87,
    );
    canvas.drawCircle(Offset(w * 0.5 + 7, 12), 3, Paint()..color = Colors.grey.shade300);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Composite login background: sky + hills + all illustrations.
class LoginBackground extends StatelessWidget {
  const LoginBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final h = size.height;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Sky + wave hills
        CustomPaint(
          size: size,
          painter: LoginBackgroundPainter(),
        ),
        // 2. Clouds (top left)
        Positioned(
          left: w * 0.02,
          top: h * 0.06,
          width: w * 0.35,
          height: h * 0.12,
          child: CustomPaint(painter: CloudsPainter()),
        ),
        // 3. Airplane (top left, above clouds)
        Positioned(
          left: w * 0.08,
          top: h * 0.12,
          width: 44,
          height: 28,
          child: CustomPaint(painter: AirplanePainter()),
        ),
        // 4. Pine tree (bottom left, on hill)
        Positioned(
          left: w * 0.02,
          bottom: h * 0.22,
          width: 36,
          height: 48,
          child: CustomPaint(painter: PineTreePainter()),
        ),
        // 5. Red travel car (left, on hill)
        Positioned(
          left: w * 0.12,
          bottom: h * 0.20,
          width: 44,
          height: 28,
          child: Icon(Icons.directions_car_rounded, size: 44, color: _kCarRed),
        ),
        // 6. Blue map pin (left, foreground)
        Positioned(
          left: w * 0.18,
          bottom: h * 0.32,
          child: Icon(Icons.location_on_rounded, size: 44, color: _kPinBlue),
        ),
        // 7. Man with camera (right, on slope)
        Positioned(
          right: w * 0.08,
          bottom: h * 0.24,
          width: 32,
          height: 56,
          child: CustomPaint(painter: ManWithCameraPainter()),
        ),
        // 8. Red map pin (right, mid-ground)
        Positioned(
          right: w * 0.15,
          bottom: h * 0.48,
          child: Icon(Icons.location_on_rounded, size: 40, color: _kPinRed),
        ),
      ],
    );
  }
}
