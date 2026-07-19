import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bottom_navigation_bar_glowing_neon_icons_model.dart';
export 'bottom_navigation_bar_glowing_neon_icons_model.dart';

class BottomNavigationBarGlowingNeonIconsWidget extends StatefulWidget {
  const BottomNavigationBarGlowingNeonIconsWidget({super.key});

  @override
  State<BottomNavigationBarGlowingNeonIconsWidget> createState() =>
      _BottomNavigationBarGlowingNeonIconsWidgetState();
}

class _BottomNavigationBarGlowingNeonIconsWidgetState
    extends State<BottomNavigationBarGlowingNeonIconsWidget> {
  late BottomNavigationBarGlowingNeonIconsModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model =
        createModel(context, () => BottomNavigationBarGlowingNeonIconsModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 98.0,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        boxShadow: [
          BoxShadow(
            blurRadius: 10.0,
            color: Color(0x33000000),
            offset: Offset(
              0.0,
              -2.0,
            ),
            spreadRadius: 0.0,
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12.0, 16.0, 12.0, 16.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 45.0,
                  height: 45.0,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0x331E88E5), Colors.black],
                      stops: [0.0, 1.0],
                      begin: AlignmentDirectional(0.0, -1.0),
                      end: AlignmentDirectional(0, 1.0),
                    ),
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  child: const Icon(
                    Icons.home_rounded,
                    color: Color(0xFF4B39EF),
                    size: 24.0,
                  ),
                ),
                Text(
                  FFLocalizations.of(context).getText(
                    'xy8y8jct' /* Home */,
                  ),
                  style: FlutterFlowTheme.of(context).labelSmall.override(
                        font: GoogleFonts.manrope(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelSmall.fontStyle,
                        ),
                        color: const Color(0xFF4B39EF),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelSmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelSmall.fontStyle,
                      ),
                ),
              ].divide(const SizedBox(height: 4.0)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 45.0,
                  height: 45.0,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0x33FF1493), Colors.black],
                      stops: [0.0, 1.0],
                      begin: AlignmentDirectional(0.0, -1.0),
                      end: AlignmentDirectional(0, 1.0),
                    ),
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFFF1493),
                    size: 24.0,
                  ),
                ),
                Text(
                  FFLocalizations.of(context).getText(
                    'suhz4bd6' /* Search */,
                  ),
                  style: FlutterFlowTheme.of(context).labelSmall.override(
                        font: GoogleFonts.manrope(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelSmall.fontStyle,
                        ),
                        color: const Color(0xFFFF1493),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelSmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelSmall.fontStyle,
                      ),
                ),
              ].divide(const SizedBox(height: 4.0)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 45.0,
                  height: 45.0,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0x3300FF9F), Colors.black],
                      stops: [0.0, 1.0],
                      begin: AlignmentDirectional(0.0, -1.0),
                      end: AlignmentDirectional(0, 1.0),
                    ),
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFF00FF9F),
                    size: 24.0,
                  ),
                ),
                Text(
                  FFLocalizations.of(context).getText(
                    'oka4fk52' /* Favorites */,
                  ),
                  style: FlutterFlowTheme.of(context).labelSmall.override(
                        font: GoogleFonts.manrope(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelSmall.fontStyle,
                        ),
                        color: const Color(0xFF00FF9F),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelSmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelSmall.fontStyle,
                      ),
                ),
              ].divide(const SizedBox(height: 4.0)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 45.0,
                  height: 45.0,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0x33666666), Colors.black],
                      stops: [0.0, 1.0],
                      begin: AlignmentDirectional(0.0, -1.0),
                      end: AlignmentDirectional(0, 1.0),
                    ),
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF666666),
                    size: 24.0,
                  ),
                ),
                Text(
                  FFLocalizations.of(context).getText(
                    '6wtx3rjl' /* Profile */,
                  ),
                  style: FlutterFlowTheme.of(context).labelSmall.override(
                        font: GoogleFonts.manrope(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelSmall.fontStyle,
                        ),
                        color: const Color(0xFF666666),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelSmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelSmall.fontStyle,
                      ),
                ),
              ].divide(const SizedBox(height: 4.0)),
            ),
          ],
        ),
      ),
    );
  }
}
