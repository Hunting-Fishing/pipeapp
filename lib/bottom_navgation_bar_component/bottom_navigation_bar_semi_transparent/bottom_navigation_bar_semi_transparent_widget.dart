import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'bottom_navigation_bar_semi_transparent_model.dart';
export 'bottom_navigation_bar_semi_transparent_model.dart';

class BottomNavigationBarSemiTransparentWidget extends StatefulWidget {
  const BottomNavigationBarSemiTransparentWidget({super.key});

  @override
  State<BottomNavigationBarSemiTransparentWidget> createState() =>
      _BottomNavigationBarSemiTransparentWidgetState();
}

class _BottomNavigationBarSemiTransparentWidgetState
    extends State<BottomNavigationBarSemiTransparentWidget> {
  late BottomNavigationBarSemiTransparentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model =
        createModel(context, () => BottomNavigationBarSemiTransparentModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
      child: Container(
        width: double.infinity,
        height: 80.0,
        decoration: BoxDecoration(
          color: const Color(0x99FFFFFF),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4.0,
              color: Color(0x33000000),
              offset: Offset(
                0.0,
                2.0,
              ),
              spreadRadius: 0.0,
            )
          ],
          borderRadius: BorderRadius.circular(30.0),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 60.0,
                height: 60.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 12.0,
                      color: Color(0x1A000000),
                      offset: Offset(
                        0.0,
                        4.0,
                      ),
                      spreadRadius: 0.0,
                    )
                  ],
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: FlutterFlowIconButton(
                  borderRadius: 25.0,
                  buttonSize: 50.0,
                  fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                  icon: Icon(
                    Icons.home_rounded,
                    color: FlutterFlowTheme.of(context).primary,
                    size: 24.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
              ),
              Container(
                width: 60.0,
                height: 60.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 12.0,
                      color: Color(0x1A000000),
                      offset: Offset(
                        0.0,
                        4.0,
                      ),
                      spreadRadius: 0.0,
                    )
                  ],
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: FlutterFlowIconButton(
                  borderRadius: 25.0,
                  buttonSize: 50.0,
                  fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                  icon: Icon(
                    Icons.search_rounded,
                    color: FlutterFlowTheme.of(context).primary,
                    size: 24.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
              ),
              Container(
                width: 60.0,
                height: 60.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 12.0,
                      color: Color(0x1A000000),
                      offset: Offset(
                        0.0,
                        4.0,
                      ),
                      spreadRadius: 0.0,
                    )
                  ],
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: FlutterFlowIconButton(
                  borderRadius: 25.0,
                  buttonSize: 50.0,
                  fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                  icon: Icon(
                    Icons.favorite_border,
                    color: FlutterFlowTheme.of(context).primary,
                    size: 24.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
              ),
              Container(
                width: 60.0,
                height: 60.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 12.0,
                      color: Color(0x1A000000),
                      offset: Offset(
                        0.0,
                        4.0,
                      ),
                      spreadRadius: 0.0,
                    )
                  ],
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: FlutterFlowIconButton(
                  borderRadius: 25.0,
                  buttonSize: 50.0,
                  fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                  icon: Icon(
                    Icons.person_outline,
                    color: FlutterFlowTheme.of(context).primary,
                    size: 24.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
