import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _bg = Color(0xFFF4EFE6);
  static const _ink = Color(0xFF1A1814);
  static const _accent = Color(0xFFD94D1A);
  static const _mute = Color(0xFF6B6158);
  static const _hair = Color(0x331A1814);

  Widget _fadeSlide({required Widget child, int delayMs = 0, double dy = 18}) {
    const animMs = 720;
    final totalMs = animMs + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Curves.linear,
      builder: (context, value, _) {
        final elapsedMs = value * totalMs;
        final progress = ((elapsedMs - delayMs) / animMs).clamp(0.0, 1.0);
        final curved = Curves.easeOutCubic.transform(progress);
        return Opacity(
          opacity: curved,
          child: Transform.translate(
            offset: Offset(0, dy * (1 - curved)),
            child: child,
          ),
        );
      },
    );
  }

  TextStyle _mono({
    double size = 11,
    FontWeight w = FontWeight.w500,
    Color? c,
    double ls = 1.8,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: w,
    color: c ?? _ink,
    letterSpacing: ls,
  );

  TextStyle _serif({
    double size = 24,
    FontWeight w = FontWeight.w400,
    FontStyle style = FontStyle.normal,
    Color? c,
    double height = 1.1,
    double ls = 0,
  }) => GoogleFonts.fraunces(
    fontSize: size,
    fontWeight: w,
    fontStyle: style,
    color: c ?? _ink,
    height: height,
    letterSpacing: ls,
  );

  TextStyle _sans({
    double size = 13,
    FontWeight w = FontWeight.w400,
    Color? c,
    double ls = 0,
    double height = 1.45,
  }) => GoogleFonts.manrope(
    fontSize: size,
    fontWeight: w,
    color: c ?? _ink,
    letterSpacing: ls,
    height: height,
  );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 720;
    final hPad = isWide ? 64.0 : 24.0;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _topRail(hPad)),
          SliverToBoxAdapter(child: _hairline(hPad)),
          SliverToBoxAdapter(child: _hero(isWide, hPad)),
          SliverToBoxAdapter(child: _stripe()),
          SliverToBoxAdapter(child: _section01(isWide, hPad)),
          SliverToBoxAdapter(child: _hairline(hPad)),
          SliverToBoxAdapter(child: _section02(isWide, hPad)),
          SliverToBoxAdapter(child: _adminCta(context, isWide, hPad)),
          SliverToBoxAdapter(child: _footer(isWide, hPad)),
        ],
      ),
    );
  }

  Widget _topRail(double hPad) => Padding(
    padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 14),
    child: Row(
      children: [
        Text('EST · MCMXCII', style: _mono(size: 10, c: _mute, ls: 2.4)),
        const SizedBox(width: 12),
        Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
        ),
        const Spacer(),
        Text('ROSARIO · SANTA FE · AR', style: _mono(size: 10, c: _mute, ls: 2.4)),
      ],
    ),
  );

  Widget _hairline(double hPad) => Container(
    margin: EdgeInsets.symmetric(horizontal: hPad),
    height: 1,
    color: _hair,
  );

  Widget _hero(bool isWide, double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, isWide ? 80 : 52, hPad, isWide ? 52 : 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fadeSlide(
            delayMs: 0,
            child: Container(
              width: isWide ? 124 : 96,
              height: isWide ? 124 : 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _bg,
                border: Border.all(color: _ink, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: _ink.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo_laplace.jpg',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school_rounded,
                    color: _ink,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          _fadeSlide(
            delayMs: 80,
            child: Row(
              children: [
                Container(width: 22, height: 1, color: _ink),
                const SizedBox(width: 10),
                Text('INSTITUTO SUPERIOR', style: _mono(size: 11, ls: 3.2)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _fadeSlide(
            delayMs: 140,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Lap',
                      style: _serif(
                        size: isWide ? 176 : 96,
                        w: FontWeight.w400,
                        ls: -4,
                        height: 0.95,
                      ),
                    ),
                    TextSpan(
                      text: 'l',
                      style: _serif(
                        size: isWide ? 176 : 96,
                        w: FontWeight.w400,
                        style: FontStyle.italic,
                        c: _accent,
                        ls: -4,
                        height: 0.95,
                      ),
                    ),
                    TextSpan(
                      text: 'ace',
                      style: _serif(
                        size: isWide ? 176 : 96,
                        w: FontWeight.w400,
                        ls: -4,
                        height: 0.95,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _fadeSlide(
            delayMs: 260,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                'Formación técnica superior en Rosario —\ncon título oficial y validez nacional desde 1992.',
                style: _serif(
                  size: isWide ? 22 : 17,
                  w: FontWeight.w300,
                  style: FontStyle.italic,
                  c: _ink,
                  height: 1.45,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          _fadeSlide(
            delayMs: 360,
            child: Row(
              children: [
                Text('DESDE', style: _mono(size: 10, c: _mute, ls: 2.4)),
                const SizedBox(width: 10),
                Text('1992', style: _serif(size: 16, w: FontWeight.w500)),
                const SizedBox(width: 20),
                Container(width: 1, height: 14, color: _hair),
                const SizedBox(width: 20),
                Text('REG', style: _mono(size: 10, c: _mute, ls: 2.4)),
                const SizedBox(width: 10),
                Text('N° 9250', style: _serif(size: 16, w: FontWeight.w500)),
              ],
            ),
          ),
          SizedBox(height: isWide ? 64 : 44),
          _fadeSlide(delayMs: 520, child: const _ScrollHint()),
        ],
      ),
    );
  }

  Widget _stripe() {
    return Container(
      height: 14,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: CustomPaint(
        painter: _SafetyStripe(ink: _ink, accent: _accent),
      ),
    );
  }

  Widget _section01(bool isWide, double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, isWide ? 72 : 48, hPad, isWide ? 72 : 48),
      child: _sectionScaffold(
        number: '01',
        label: 'AUTORIZACIÓN OFICIAL',
        isWide: isWide,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'N°',
              style: _sans(size: isWide ? 22 : 18, w: FontWeight.w300, c: _mute),
            ),
            const SizedBox(width: 12),
            Text(
              '9250',
              style: _serif(
                size: isWide ? 96 : 64,
                w: FontWeight.w500,
                ls: -2,
                height: 0.95,
              ),
            ),
            const SizedBox(width: 24),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Reconocimiento ministerial.\nTítulo oficial con validez nacional.',
                  style: _sans(size: 13, c: _mute, height: 1.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section02(bool isWide, double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, isWide ? 72 : 48, hPad, isWide ? 48 : 32),
      child: _sectionScaffold(
        number: '02',
        label: 'OFERTA ACADÉMICA',
        isWide: isWide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Técnico Superior en',
              style: _serif(
                size: isWide ? 26 : 20,
                w: FontWeight.w300,
                style: FontStyle.italic,
                c: _mute,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seguridad e Higiene\nen el Trabajo',
              style: _serif(
                size: isWide ? 56 : 34,
                w: FontWeight.w500,
                ls: -1.2,
                height: 1.02,
              ),
            ),
            const SizedBox(height: 40),
            _dataBlock(isWide),
          ],
        ),
      ),
    );
  }

  Widget _sectionScaffold({
    required String number,
    required String label,
    required Widget child,
    required bool isWide,
  }) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: _serif(
                    size: 64,
                    w: FontWeight.w400,
                    c: _accent,
                    ls: -2,
                    height: 0.9,
                  ),
                ),
                const SizedBox(height: 12),
                Text(label, style: _mono(size: 10, ls: 2.8)),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(child: child),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              number,
              style: _serif(
                size: 42,
                w: FontWeight.w400,
                c: _accent,
                ls: -1,
                height: 0.9,
              ),
            ),
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(label, style: _mono(size: 10, ls: 2.6)),
            ),
          ],
        ),
        const SizedBox(height: 28),
        child,
      ],
    );
  }

  Widget _dataBlock(bool isWide) {
    const rows = [
      ['DURACIÓN', '3 años'],
      ['TÍTULO', 'Oficial · validez nacional'],
      ['MODALIDAD', 'Presencial'],
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _hair, width: 1)),
      ),
      child: Column(
        children: [
          for (final r in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _hair, width: 1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: isWide ? 160 : 110,
                    child: Text(r[0], style: _mono(size: 10, ls: 2.4, c: _mute)),
                  ),
                  Expanded(
                    child: Text(
                      r[1],
                      style: _serif(size: isWide ? 22 : 18, w: FontWeight.w400),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _adminCta(BuildContext context, bool isWide, double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, isWide ? 96 : 64),
      child: Material(
        color: _ink,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/admin'),
          splashColor: _accent.withOpacity(0.3),
          highlightColor: _accent.withOpacity(0.08),
          hoverColor: _accent.withOpacity(0.06),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 20,
              vertical: isWide ? 30 : 24,
            ),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: _accent, width: 4)),
            ),
            child: Row(
              children: [
                Text('ACCESO', style: _mono(size: 10, c: _accent, ls: 3.2)),
                const SizedBox(width: 12),
                Container(
                  width: 14,
                  height: 1,
                  color: _accent.withOpacity(0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Panel interno',
                    style: _serif(
                      size: isWide ? 28 : 22,
                      w: FontWeight.w400,
                      style: FontStyle.italic,
                      c: _bg,
                    ),
                  ),
                ),
                Text(
                  '→',
                  style: _serif(
                    size: isWide ? 36 : 28,
                    w: FontWeight.w300,
                    c: _bg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(bool isWide, double hPad) {
    return Container(
      color: _ink,
      padding: EdgeInsets.fromLTRB(hPad, isWide ? 64 : 44, hPad, isWide ? 64 : 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: _bg),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo_laplace.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.school_rounded, color: _ink, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INSTITUTO SUPERIOR LAPLACE',
                      style: _mono(size: 10, c: _bg, ls: 2.8),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Formando profesionales desde 1992',
                      style: _serif(
                        size: 14,
                        style: FontStyle.italic,
                        c: _bg.withOpacity(0.72),
                        w: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(height: 1, color: _bg.withOpacity(0.12)),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'ROSARIO · SANTA FE · ARGENTINA',
                style: _mono(size: 10, c: _bg.withOpacity(0.6), ls: 2.2),
              ),
              const Spacer(),
              Text(
                'MMXXVI',
                style: _mono(size: 10, c: _bg.withOpacity(0.6), ls: 2.2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScrollHint extends StatefulWidget {
  const _ScrollHint();
  @override
  State<_ScrollHint> createState() => _ScrollHintState();
}

class _ScrollHintState extends State<_ScrollHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_c.value);
        final dy = t * 10.0;
        final opacity = 0.5 + 0.45 * t;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'CONTINUAR',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: HomeScreen._mute,
                    letterSpacing: 2.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Container(width: 22, height: 1, color: HomeScreen._hair),
              ],
            ),
            const SizedBox(height: 10),
            Transform.translate(
              offset: Offset(0, dy),
              child: Opacity(
                opacity: opacity,
                child: Text(
                  '↓',
                  style: GoogleFonts.fraunces(
                    fontSize: 30,
                    color: HomeScreen._accent,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SafetyStripe extends CustomPainter {
  final Color ink;
  final Color accent;
  _SafetyStripe({required this.ink, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const stripeWidth = 18.0;
    const gap = 18.0;
    const total = stripeWidth + gap;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    var toggle = 0;
    for (double x = -size.height; x < size.width + size.height; x += total) {
      paint.color = toggle.isEven ? ink : accent;
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + stripeWidth, size.height)
        ..lineTo(x + stripeWidth + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, paint);
      toggle++;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
