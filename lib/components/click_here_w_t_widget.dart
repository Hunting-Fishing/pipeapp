import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'click_here_w_t_model.dart';
export 'click_here_w_t_model.dart';

class ClickHereWTWidget extends StatefulWidget {
  const ClickHereWTWidget({super.key});

  @override
  State<ClickHereWTWidget> createState() => _ClickHereWTWidgetState();
}

class _ClickHereWTWidgetState extends State<ClickHereWTWidget> {
  late ClickHereWTModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ClickHereWTModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Lottie.asset(
          'assets/jsons/click.json',
          width: 120.0,
          height: 200.0,
          fit: BoxFit.contain,
          animate: true,
        ),
      ],
    );
  }
}
