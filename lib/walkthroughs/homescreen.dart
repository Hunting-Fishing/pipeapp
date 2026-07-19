import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '/components/click_here_w_t_widget.dart';

// Focus widget keys for this walkthrough
final iconButtonZ5hul7vi = GlobalKey();
final dropDownZmjyzp07 = GlobalKey();
final columnLbgwm5cd = GlobalKey();
final container3txzrrni = GlobalKey();

/// Homescreen
///
///
List<TargetFocus> createWalkthroughTargets(BuildContext context) => [
      /// Step 1
      TargetFocus(
        keyTarget: iconButtonZ5hul7vi,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.Circle,
        color: Colors.black,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder: (context, __) => const ClickHereWTWidget(),
          ),
        ],
      ),

      /// Step 2
      TargetFocus(
        keyTarget: dropDownZmjyzp07,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.Circle,
        color: Colors.black,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder: (context, __) => const ClickHereWTWidget(),
          ),
        ],
      ),

      /// Step 3
      TargetFocus(
        keyTarget: columnLbgwm5cd,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomLeft,
        shape: ShapeLightFocus.Circle,
        color: Colors.black,
        contents: [
          TargetContent(
            align: ContentAlign.left,
            builder: (context, __) => const ClickHereWTWidget(),
          ),
        ],
      ),

      /// Step 4
      TargetFocus(
        keyTarget: container3txzrrni,
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
