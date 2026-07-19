import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'nature_theme_bottom_navigation_bar_model.dart';
export 'nature_theme_bottom_navigation_bar_model.dart';

class NatureThemeBottomNavigationBarWidget extends StatefulWidget {
  const NatureThemeBottomNavigationBarWidget({super.key});

  @override
  State<NatureThemeBottomNavigationBarWidget> createState() =>
      _NatureThemeBottomNavigationBarWidgetState();
}

class _NatureThemeBottomNavigationBarWidgetState
    extends State<NatureThemeBottomNavigationBarWidget> {
  late NatureThemeBottomNavigationBarModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NatureThemeBottomNavigationBarModel());

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
      height: 80.0,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x336E4C2F), Color(0x4B8B6253), Color(0x2D7DA3BF)],
          stops: [0.0, 0.5, 1.0],
          begin: AlignmentDirectional(0.0, -1.0),
          end: AlignmentDirectional(0, 1.0),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32.0),
          topRight: Radius.circular(32.0),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10.0,
            sigmaY: 10.0,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8.0, 4.0, 8.0, 4.0),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0x26FFFFFF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32.0),
                  topRight: Radius.circular(32.0),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 4.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FlutterFlowIconButton(
                          borderColor: Colors.transparent,
                          borderRadius: 23.0,
                          buttonSize: 46.0,
                          fillColor: const Color(0x33FFFFFF),
                          icon: const Icon(
                            Icons.forest_rounded,
                            color: Color(0xFFE8F5E9),
                            size: 26.0,
                          ),
                          onPressed: () {
                            debugPrint('IconButton pressed ...');
                          },
                        ),
                        Text(
                          FFLocalizations.of(context).getText(
                            '13mv65xd' /* Nature */,
                          ),
                          style:
                              FlutterFlowTheme.of(context).labelSmall.override(
                                    font: GoogleFonts.manrope(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                    ),
                                    color: const Color(0xFFE8F5E9),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontStyle,
                                  ),
                        ),
                      ].divide(const SizedBox(height: 4.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FlutterFlowIconButton(
                          borderColor: Colors.transparent,
                          borderRadius: 23.0,
                          buttonSize: 46.0,
                          fillColor: const Color(0x33FFFFFF),
                          icon: const Icon(
                            Icons.water_drop_rounded,
                            color: Color(0xFFE8F5E9),
                            size: 26.0,
                          ),
                          onPressed: () {
                            debugPrint('IconButton pressed ...');
                          },
                        ),
                        Text(
                          FFLocalizations.of(context).getText(
                            'h76bcoz7' /* Water */,
                          ),
                          style:
                              FlutterFlowTheme.of(context).labelSmall.override(
                                    font: GoogleFonts.manrope(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                    ),
                                    color: const Color(0xFFE8F5E9),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontStyle,
                                  ),
                        ),
                      ].divide(const SizedBox(height: 4.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FlutterFlowIconButton(
                          borderColor: Colors.transparent,
                          borderRadius: 23.0,
                          buttonSize: 46.0,
                          fillColor: const Color(0x33FFFFFF),
                          icon: const Icon(
                            Icons.terrain_rounded,
                            color: Color(0xFFE8F5E9),
                            size: 26.0,
                          ),
                          onPressed: () {
                            debugPrint('IconButton pressed ...');
                          },
                        ),
                        Text(
                          FFLocalizations.of(context).getText(
                            'lh7ca9l0' /* Earth */,
                          ),
                          style:
                              FlutterFlowTheme.of(context).labelSmall.override(
                                    font: GoogleFonts.manrope(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                    ),
                                    color: const Color(0xFFE8F5E9),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontStyle,
                                  ),
                        ),
                      ].divide(const SizedBox(height: 4.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FlutterFlowIconButton(
                          borderColor: Colors.transparent,
                          borderRadius: 23.0,
                          buttonSize: 46.0,
                          fillColor: const Color(0x33FFFFFF),
                          icon: const Icon(
                            Icons.eco_rounded,
                            color: Color(0xFFE8F5E9),
                            size: 26.0,
                          ),
                          onPressed: () {
                            debugPrint('IconButton pressed ...');
                          },
                        ),
                        Text(
                          FFLocalizations.of(context).getText(
                            'bcotl8fo' /* Flora */,
                          ),
                          style:
                              FlutterFlowTheme.of(context).labelSmall.override(
                                    font: GoogleFonts.manrope(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                    ),
                                    color: const Color(0xFFE8F5E9),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .fontStyle,
                                  ),
                        ),
                      ].divide(const SizedBox(height: 4.0)),
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
