import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'dark_theme_rounded_button_model.dart';
export 'dark_theme_rounded_button_model.dart';

class DarkThemeRoundedButtonWidget extends StatefulWidget {
  const DarkThemeRoundedButtonWidget({super.key});

  @override
  State<DarkThemeRoundedButtonWidget> createState() =>
      _DarkThemeRoundedButtonWidgetState();
}

class _DarkThemeRoundedButtonWidgetState
    extends State<DarkThemeRoundedButtonWidget> {
  late DarkThemeRoundedButtonModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DarkThemeRoundedButtonModel());

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
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F24),
          boxShadow: [
            BoxShadow(
              blurRadius: 3.0,
              color: Color(0x33000000),
              offset: Offset(
                0.0,
                -1.0,
              ),
              spreadRadius: 0.0,
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  color: const Color(0xFF292F34),
                  borderRadius: BorderRadius.circular(23.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  borderRadius: 23.0,
                  buttonSize: 46.0,
                  fillColor: Colors.transparent,
                  icon: const Icon(
                    Icons.home_rounded,
                    color: Color(0xFF9EA4AB),
                    size: 24.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
              ),
              Container(
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  color: const Color(0xFF292F34),
                  borderRadius: BorderRadius.circular(23.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  borderRadius: 23.0,
                  buttonSize: 46.0,
                  fillColor: Colors.transparent,
                  icon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF9EA4AB),
                    size: 24.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
              ),
              Container(
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primary,
                  borderRadius: BorderRadius.circular(23.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  borderRadius: 23.0,
                  buttonSize: 46.0,
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
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  color: const Color(0xFF292F34),
                  borderRadius: BorderRadius.circular(23.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  borderRadius: 23.0,
                  buttonSize: 46.0,
                  fillColor: Colors.transparent,
                  icon: const Icon(
                    Icons.favorite_border_rounded,
                    color: Color(0xFF9EA4AB),
                    size: 24.0,
                  ),
                  onPressed: () {
                    debugPrint('IconButton pressed ...');
                  },
                ),
              ),
              Container(
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  color: const Color(0xFF292F34),
                  borderRadius: BorderRadius.circular(23.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  borderRadius: 23.0,
                  buttonSize: 46.0,
                  fillColor: Colors.transparent,
                  icon: const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF9EA4AB),
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
