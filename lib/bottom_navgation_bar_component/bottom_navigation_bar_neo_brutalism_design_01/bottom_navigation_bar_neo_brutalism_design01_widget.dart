import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bottom_navigation_bar_neo_brutalism_design01_model.dart';
export 'bottom_navigation_bar_neo_brutalism_design01_model.dart';

class BottomNavigationBarNeoBrutalismDesign01Widget extends StatefulWidget {
  const BottomNavigationBarNeoBrutalismDesign01Widget({super.key});

  @override
  State<BottomNavigationBarNeoBrutalismDesign01Widget> createState() =>
      _BottomNavigationBarNeoBrutalismDesign01WidgetState();
}

class _BottomNavigationBarNeoBrutalismDesign01WidgetState
    extends State<BottomNavigationBarNeoBrutalismDesign01Widget> {
  late BottomNavigationBarNeoBrutalismDesign01Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(
        context, () => BottomNavigationBarNeoBrutalismDesign01Model());

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
      height: 99.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        border: Border.all(
          color: const Color(0xFFE0E3E7),
          width: 2.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FlutterFlowIconButton(
                  borderRadius: 4.0,
                  buttonSize: 50.0,
                  fillColor: const Color(0xFF4B39EF),
                  icon: Icon(
                    Icons.home_rounded,
                    color: FlutterFlowTheme.of(context).info,
                    size: 28.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
                Text(
                  FFLocalizations.of(context).getText(
                    'zzab2u4e' /* Home */,
                  ),
                  style: FlutterFlowTheme.of(context).labelSmall.override(
                        font: GoogleFonts.manrope(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelSmall.fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelSmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelSmall.fontStyle,
                      ),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FlutterFlowIconButton(
                  borderRadius: 4.0,
                  buttonSize: 50.0,
                  fillColor: const Color(0xFFFF3B30),
                  icon: Icon(
                    Icons.search_rounded,
                    color: FlutterFlowTheme.of(context).info,
                    size: 28.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
                Text(
                  FFLocalizations.of(context).getText(
                    'x2hey81b' /* Search */,
                  ),
                  style: FlutterFlowTheme.of(context).labelSmall.override(
                        font: GoogleFonts.manrope(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelSmall.fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelSmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelSmall.fontStyle,
                      ),
                ),
              ],
            ),
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(32.0, 0.0, 32.0, 0.0),
              child: SizedBox(
                width: 70.0,
                height: 70.0,
                child: FlutterFlowIconButton(
                  borderRadius: 4.0,
                  buttonSize: 70.0,
                  fillColor: const Color(0xFFFFD60A),
                  icon: Icon(
                    Icons.add_rounded,
                    color: FlutterFlowTheme.of(context).info,
                    size: 32.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FlutterFlowIconButton(
                  borderRadius: 4.0,
                  buttonSize: 50.0,
                  fillColor: FlutterFlowTheme.of(context).success,
                  icon: Icon(
                    Icons.favorite_rounded,
                    color: FlutterFlowTheme.of(context).info,
                    size: 28.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
                Text(
                  FFLocalizations.of(context).getText(
                    'elkor029' /* Favorites */,
                  ),
                  style: FlutterFlowTheme.of(context).labelSmall.override(
                        font: GoogleFonts.manrope(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelSmall.fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelSmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelSmall.fontStyle,
                      ),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FlutterFlowIconButton(
                  borderRadius: 4.0,
                  buttonSize: 50.0,
                  fillColor: FlutterFlowTheme.of(context).primary,
                  icon: Icon(
                    Icons.person_rounded,
                    color: FlutterFlowTheme.of(context).info,
                    size: 28.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
                Text(
                  FFLocalizations.of(context).getText(
                    'wyvx5vh7' /* Profile */,
                  ),
                  style: FlutterFlowTheme.of(context).labelSmall.override(
                        font: GoogleFonts.manrope(
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelSmall.fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).labelSmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelSmall.fontStyle,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
