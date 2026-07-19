import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '/components/click_here_w_t_widget.dart';

// Focus widget keys for this walkthrough
final containerQ5sxfnwf = GlobalKey();
final choiceChipsTe9ed1xe = GlobalKey();

/// LeadCapture
///
///
List<TargetFocus> createWalkthroughTargets(BuildContext context) => [
      /// Step 1
      TargetFocus(
        keyTarget: containerQ5sxfnwf,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.Circle,
        color: Colors.black,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, __) => const ClickHereWTWidget(),
          ),
        ],
      ),

      /// Step 2
      TargetFocus(
        keyTarget: choiceChipsTe9ed1xe,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.Circle,
        color: Colors.black,
        contents: [
          TargetContent(
            align: ContentAlign.left,
            builder: (context, __) => const ClickHereWTWidget(),
          ),
        ],
      ),
    ];
