import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'win11_theme_model.dart';
export 'win11_theme_model.dart';

class Win11ThemeWidget extends StatefulWidget {
  const Win11ThemeWidget({super.key});

  @override
  State<Win11ThemeWidget> createState() => _Win11ThemeWidgetState();
}

class _Win11ThemeWidgetState extends State<Win11ThemeWidget> {
  late Win11ThemeModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Win11ThemeModel());

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
        boxShadow: [
          BoxShadow(
            blurRadius: 8.0,
            color: Color(0x1A000000),
            offset: Offset(
              0.0,
              -2.0,
            ),
            spreadRadius: 0.0,
          )
        ],
        gradient: LinearGradient(
          colors: [Color(0xFFE6D8F3), Color(0xFFC2E7FF), Color(0xFFDCD6F7)],
          stops: [0.0, 0.5, 1.0],
          begin: AlignmentDirectional(1.0, -1.0),
          end: AlignmentDirectional(-1.0, 1.0),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30.0),
          topRight: Radius.circular(30.0),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 20.0,
            sigmaY: 20.0,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8.0, 4.0, 8.0, 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52.0,
                      height: 52.0,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6B4CE3), Color(0xFF4B39EF)],
                          stops: [0.0, 1.0],
                          begin: AlignmentDirectional(0.94, 1.0),
                          end: AlignmentDirectional(-0.94, -1.0),
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Icon(
                        Icons.dashboard_rounded,
                        color: FlutterFlowTheme.of(context).info,
                        size: 26.0,
                      ),
                    ),
                    Text(
                      FFLocalizations.of(context).getText(
                        '1rdt3do2' /* Home */,
                      ),
                      style: FlutterFlowTheme.of(context).labelSmall.override(
                            font: GoogleFonts.manrope(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).primary,
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
                    Container(
                      width: 52.0,
                      height: 52.0,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A8AF4), Color(0xFF63A4FF)],
                          stops: [0.0, 1.0],
                          begin: AlignmentDirectional(0.94, 1.0),
                          end: AlignmentDirectional(-0.94, -1.0),
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Icon(
                        Icons.analytics_rounded,
                        color: FlutterFlowTheme.of(context).info,
                        size: 26.0,
                      ),
                    ),
                    Text(
                      FFLocalizations.of(context).getText(
                        'zhm85gaz' /* Stats */,
                      ),
                      style: FlutterFlowTheme.of(context).labelSmall.override(
                            font: GoogleFonts.manrope(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).primary,
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
                    Container(
                      width: 52.0,
                      height: 52.0,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C4DDB), Color(0xFF9168E5)],
                          stops: [0.0, 1.0],
                          begin: AlignmentDirectional(0.94, 1.0),
                          end: AlignmentDirectional(-0.94, -1.0),
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: FlutterFlowTheme.of(context).info,
                        size: 26.0,
                      ),
                    ),
                    Text(
                      FFLocalizations.of(context).getText(
                        'pr61996f' /* Profile */,
                      ),
                      style: FlutterFlowTheme.of(context).labelSmall.override(
                            font: GoogleFonts.manrope(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).primary,
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
                    Container(
                      width: 52.0,
                      height: 52.0,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5D45E6), Color(0xFF7B68EE)],
                          stops: [0.0, 1.0],
                          begin: AlignmentDirectional(0.94, 1.0),
                          end: AlignmentDirectional(-0.94, -1.0),
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Icon(
                        Icons.settings_rounded,
                        color: FlutterFlowTheme.of(context).info,
                        size: 26.0,
                      ),
                    ),
                    Text(
                      FFLocalizations.of(context).getText(
                        'qy9a9623' /* Settings */,
                      ),
                      style: FlutterFlowTheme.of(context).labelSmall.override(
                            font: GoogleFonts.manrope(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).primary,
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
    );
  }
}
