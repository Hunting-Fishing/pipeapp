import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bottom_navigation_bar_neo_brutalism_design_model.dart';
export 'bottom_navigation_bar_neo_brutalism_design_model.dart';

/// NeoBrutalismDesign
class BottomNavigationBarNeoBrutalismDesignWidget extends StatefulWidget {
  const BottomNavigationBarNeoBrutalismDesignWidget({super.key});

  @override
  State<BottomNavigationBarNeoBrutalismDesignWidget> createState() =>
      _BottomNavigationBarNeoBrutalismDesignWidgetState();
}

class _BottomNavigationBarNeoBrutalismDesignWidgetState
    extends State<BottomNavigationBarNeoBrutalismDesignWidget> {
  late BottomNavigationBarNeoBrutalismDesignModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(
        context, () => BottomNavigationBarNeoBrutalismDesignModel());

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
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        border: Border.all(
          color: const Color(0xFFE0E3E7),
          width: 2.0,
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 12.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.home_rounded,
                        color: Colors.blue,
                        size: 28.0,
                      ),
                      Text(
                        FFLocalizations.of(context).getText(
                          '37p0r4x3' /* Home */,
                        ),
                        style:
                            FlutterFlowTheme.of(context).labelMedium.override(
                                  font: GoogleFonts.manrope(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontStyle,
                                  ),
                                  color: Colors.blue,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontStyle,
                                ),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: Colors.red,
                        size: 28.0,
                      ),
                      Text(
                        FFLocalizations.of(context).getText(
                          'lpzi0ukn' /* Search */,
                        ),
                        style:
                            FlutterFlowTheme.of(context).labelMedium.override(
                                  font: GoogleFonts.manrope(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontStyle,
                                  ),
                                  color: Colors.red,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontStyle,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    width: 65.0,
                    height: 65.0,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_rounded,
                        color: Color(0xFFFFC107),
                        size: 28.0,
                      ),
                      Text(
                        FFLocalizations.of(context).getText(
                          'xeqljynv' /* Alerts */,
                        ),
                        style:
                            FlutterFlowTheme.of(context).labelMedium.override(
                                  font: GoogleFonts.manrope(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontStyle,
                                  ),
                                  color: const Color(0xFFFFC107),
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontStyle,
                                ),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        color: Colors.blue,
                        size: 28.0,
                      ),
                      Text(
                        FFLocalizations.of(context).getText(
                          '0b3csbw8' /* Profile */,
                        ),
                        style:
                            FlutterFlowTheme.of(context).labelMedium.override(
                                  font: GoogleFonts.manrope(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontStyle,
                                  ),
                                  color: Colors.blue,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontStyle,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Align(
              alignment: const AlignmentDirectional(0.5, 0.0),
              child: Container(
                width: 60.0,
                height: 60.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primary,
                  borderRadius: BorderRadius.circular(0.0),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: FlutterFlowTheme.of(context).info,
                  size: 32.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
