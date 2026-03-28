import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _abrirWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/5493413513973?text=Hola,%20quiero%20consultar%20sobre%20materias%20y%20homologaciones',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _llamar() async {
    final uri = Uri.parse('tel:+543413513973');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Animación de fade + slide hacia arriba
  Widget _fadeSlide({required Widget child, int delayMs = 0}) {
    const animMs = 600;
    final totalMs = animMs + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Curves.linear,
      builder: (context, value, _) {
        final elapsedMs = value * totalMs;
        final progress = ((elapsedMs - delayMs) / animMs).clamp(0.0, 1.0);
        final curved = Curves.easeOutCubic.transform(progress);
        final dy = (1 - curved) * 20;
        return Opacity(
          opacity: curved,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
    );
  }

  /// Animación de escala elástica para el CTA
  Widget _scaleIn({required Widget child, int delayMs = 0}) {
    const animMs = 700;
    final totalMs = animMs + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Curves.linear,
      builder: (context, value, _) {
        final elapsedMs = value * totalMs;
        final progress = ((elapsedMs - delayMs) / animMs).clamp(0.0, 1.0);
        final curved = Curves.elasticOut.transform(progress);
        final scale = 0.9 + (1.0 - 0.9) * curved;
        return Transform.scale(scale: scale, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: CustomScrollView(
        slivers: [
          // ============ TOP BAR ============
          // Top bar removido

          // ============ HERO SECTION ============
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1F3D66), Color(0xFF162C4D)], // azul navy aclarado
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  _fadeSlide(
                    delayMs: 0,
                    child: Container(
                      width: isWide ? 180 : 150,
                      height: isWide ? 180 : 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.school_rounded,
                              size: 64,
                              color: AppTheme.primaryColor,
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Nombre institucional
                  _fadeSlide(
                    delayMs: 120,
                    child: Text(
                      'Instituto Superior',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isWide ? 18 : 15,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _fadeSlide(
                    delayMs: 200,
                    child: Text(
                      'LAPLACE',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isWide ? 48 : 38,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 6.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _fadeSlide(
                    delayMs: 260,
                    child: Text(
                      'ROSARIO',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.65),
                        letterSpacing: 4.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Línea decorativa dorada
                  _fadeSlide(
                    delayMs: 320,
                    child: Container(
                      width: 60,
                      height: 2,
                      color: AppTheme.accentColor,
                    ),
                  ),

                  const SizedBox(height: 16),

                  _fadeSlide(
                    delayMs: 380,
                    child: Text(
                      'Fundado en 1992',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botón destacado de Admin (único)
                  _scaleIn(
                    delayMs: 480,
                    child: SizedBox(
                      width: isWide ? 280 : double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/admin'),
                        icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.black87),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'ACCESO ADMIN',
                            style: GoogleFonts.inter(
                              fontSize: isWide ? 16 : 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF2C94C), // dorado claro y visible
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.black.withOpacity(0.08)),
                          ),
                          elevation: 10,
                          shadowColor: Colors.black.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Línea inferior decorativa
                  Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppTheme.accentColor.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 0),
                ],
              ),
            ),
          ),

          // ============ CONTENIDO PRINCIPAL ============
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 40 : 20,
                vertical: 32,
              ),
              child: Column(
                children: [
                  // --- Sección: Autorización ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.accentColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppTheme.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Autorizado a la enseñanza oficial N° 9250',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // --- Sección: Oferta Académica ---
                  Text(
                    'Oferta Académica',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 40,
                    height: 2,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(height: 24),

                  // Card de carrera principal
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.dividerColor.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header de la card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.school_rounded,
                                color: AppTheme.accentColor,
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Técnico Superior en',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withOpacity(0.7),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Seguridad e Higiene\nen el Trabajo',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        // Body de la card
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _buildCarreraDetalle(
                                Icons.access_time_rounded,
                                'Duración',
                                '3 años',
                              ),
                              const SizedBox(height: 12),
                              _buildCarreraDetalle(
                                Icons.card_membership_rounded,
                                'Título',
                                'Título oficial con validez nacional',
                              ),
                              const SizedBox(height: 12),
                              _buildCarreraDetalle(
                                Icons.calendar_today_rounded,
                                'Modalidad',
                                'Presencial',
                              ),
                              const SizedBox(height: 20),

                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  const SizedBox(height: 48),

                  // ============ FOOTER INSTITUCIONAL ============
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppTheme.dividerColor),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Logo pequeño en footer
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.dividerColor,
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.jpg',
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'INSTITUTO SUPERIOR LAPLACE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rosario, Santa Fe, Argentina',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Formando profesionales desde 1992',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textSecondary.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildCarreraDetalle(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.accentColor),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
