# Pre-existing tool template analyzer debt — 2026-08-29

During the marketplace payment-flow repair validation, repository-wide `flutter analyze` reported 38 errors exclusively under `tool/templates/`.

These errors predate the payment repair and are unrelated to runtime application payment code. They include template-local relative imports such as `marketplace_actions_repository.dart`, `marketplace_dispatch_service_taxonomy.dart`, and `../core/design/pipe_buyer_theme.dart` that do not resolve from the template directory.

The payment repair validator therefore analyzes the actual Flutter application/test source (`lib` and `test`) and runs the full Flutter test suite, while this separate template debt remains recorded for a dedicated repair. This is not an analyzer exemption for application source.
