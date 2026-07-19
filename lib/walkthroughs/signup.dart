import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '/components/click_here_w_t_widget.dart';

// Focus widget keys for this walkthrough
final buttonU1td0zfd = GlobalKey();
final richText9fgovq6b = GlobalKey();

/// signup
///
///
List<TargetFocus> createWalkthroughTargets(BuildContext context) => [
      /// Step 1
      TargetFocus(
        keyTarget: buttonU1td0zfd,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.Circle,
        color: Colors.black,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, __) => const ClickHereWTWidget(),
          ),
        ],
      ),

      /// Step 2
      TargetFocus(
        keyTarget: richText9fgovq6b,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomLeft,
        shape: ShapeLightFocus.Circle,
        color: Colors.black,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder: (context, __) => const ClickHereWTWidget(),
          ),
        ],
      ),
    ];
