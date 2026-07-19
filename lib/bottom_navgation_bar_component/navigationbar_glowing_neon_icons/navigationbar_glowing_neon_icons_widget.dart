import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'navigationbar_glowing_neon_icons_model.dart';
export 'navigationbar_glowing_neon_icons_model.dart';

/// White Theme
class NavigationbarGlowingNeonIconsWidget extends StatefulWidget {
  const NavigationbarGlowingNeonIconsWidget({super.key});

  @override
  State<NavigationbarGlowingNeonIconsWidget> createState() =>
      _NavigationbarGlowingNeonIconsWidgetState();
}

class _NavigationbarGlowingNeonIconsWidgetState
    extends State<NavigationbarGlowingNeonIconsWidget> {
  late NavigationbarGlowingNeonIconsModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NavigationbarGlowingNeonIconsModel());

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
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          boxShadow: const [
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
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x1A4B39EF), Color(0x004B39EF)],
                    stops: [0.0, 1.0],
                    begin: AlignmentDirectional(0.0, -1.0),
                    end: AlignmentDirectional(0, 1.0),
                  ),
                  borderRadius: BorderRadius.circular(23.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  borderRadius: 23.0,
                  buttonSize: 46.0,
                  icon: Icon(
                    Icons.home_rounded,
                    color: FlutterFlowTheme.of(context).primary,
                    size: 24.0,
                  ),
                  onPressed: () {},
                ),
              ),
              Container(
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x1AEE8B60), Color(0x00EE8B60)],
                    stops: [0.0, 1.0],
                    begin: AlignmentDirectional(0.0, -1.0),
                    end: AlignmentDirectional(0, 1.0),
                  ),
                  borderRadius: BorderRadius.circular(23.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  borderRadius: 23.0,
                  buttonSize: 46.0,
                  icon: Icon(
                    Icons.search_rounded,
                    color: FlutterFlowTheme.of(context).tertiary,
                    size: 24.0,
                  ),
                  onPressed: () {},
                ),
              ),
              Container(
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x1A39D2C0), Color(0x0039D2C0)],
                    stops: [0.0, 1.0],
                    begin: AlignmentDirectional(0.0, -1.0),
                    end: AlignmentDirectional(0, 1.0),
                  ),
                  borderRadius: BorderRadius.circular(23.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  borderRadius: 23.0,
                  buttonSize: 46.0,
                  icon: Icon(
                    Icons.favorite_rounded,
                    color: FlutterFlowTheme.of(context).secondary,
                    size: 24.0,
                  ),
                  onPressed: () {},
                ),
              ),
              Container(
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x1AFF5963), Color(0x00FF5963)],
                    stops: [0.0, 1.0],
                    begin: AlignmentDirectional(0.0, -1.0),
                    end: AlignmentDirectional(0, 1.0),
                  ),
                  borderRadius: BorderRadius.circular(23.0),
                ),
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  borderRadius: 23.0,
                  buttonSize: 46.0,
                  icon: Icon(
                    Icons.person_rounded,
                    color: FlutterFlowTheme.of(context).error,
                    size: 24.0,
                  ),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
