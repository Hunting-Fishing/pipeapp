import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'floatingnavigation_semi_transparent_b_g02_model.dart';
export 'floatingnavigation_semi_transparent_b_g02_model.dart';

class FloatingnavigationSemiTransparentBG02Widget extends StatefulWidget {
  const FloatingnavigationSemiTransparentBG02Widget({super.key});

  @override
  State<FloatingnavigationSemiTransparentBG02Widget> createState() =>
      _FloatingnavigationSemiTransparentBG02WidgetState();
}

class _FloatingnavigationSemiTransparentBG02WidgetState
    extends State<FloatingnavigationSemiTransparentBG02Widget> {
  late FloatingnavigationSemiTransparentBG02Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(
        context, () => FloatingnavigationSemiTransparentBG02Model());

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
          color: FlutterFlowTheme.of(context).primaryBackground,
          boxShadow: const [
            BoxShadow(
              blurRadius: 10.0,
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
          padding: const EdgeInsetsDirectional.fromSTEB(8.0, 16.0, 8.0, 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 55.0,
                height: 55.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primary,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12.0,
                      color: FlutterFlowTheme.of(context).primary,
                      offset: const Offset(
                        0.0,
                        4.0,
                      ),
                      spreadRadius: 0.0,
                    )
                  ],
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  buttonSize: 55.0,
                  fillColor: Colors.transparent,
                  icon: Icon(
                    Icons.home_rounded,
                    color: FlutterFlowTheme.of(context).info,
                    size: 24.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
              ),
              Container(
                width: 55.0,
                height: 55.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondary,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12.0,
                      color: FlutterFlowTheme.of(context).secondary,
                      offset: const Offset(
                        0.0,
                        4.0,
                      ),
                      spreadRadius: 0.0,
                    )
                  ],
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  buttonSize: 55.0,
                  fillColor: Colors.transparent,
                  icon: Icon(
                    Icons.search_rounded,
                    color: FlutterFlowTheme.of(context).info,
                    size: 24.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
              ),
              Container(
                width: 55.0,
                height: 55.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).tertiary,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12.0,
                      color: FlutterFlowTheme.of(context).tertiary,
                      offset: const Offset(
                        0.0,
                        4.0,
                      ),
                      spreadRadius: 0.0,
                    )
                  ],
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  buttonSize: 55.0,
                  fillColor: Colors.transparent,
                  icon: Icon(
                    Icons.add_rounded,
                    color: FlutterFlowTheme.of(context).info,
                    size: 24.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
              ),
              Container(
                width: 55.0,
                height: 55.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).success,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12.0,
                      color: FlutterFlowTheme.of(context).success,
                      offset: const Offset(
                        0.0,
                        4.0,
                      ),
                      spreadRadius: 0.0,
                    )
                  ],
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  buttonSize: 55.0,
                  fillColor: Colors.transparent,
                  icon: Icon(
                    Icons.favorite_rounded,
                    color: FlutterFlowTheme.of(context).info,
                    size: 24.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
              ),
              Container(
                width: 55.0,
                height: 55.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).error,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12.0,
                      color: FlutterFlowTheme.of(context).error,
                      offset: const Offset(
                        0.0,
                        4.0,
                      ),
                      spreadRadius: 0.0,
                    )
                  ],
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  buttonSize: 55.0,
                  fillColor: Colors.transparent,
                  icon: Icon(
                    Icons.person_rounded,
                    color: FlutterFlowTheme.of(context).info,
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
