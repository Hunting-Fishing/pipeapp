# Pipe Buyer Design System

Status: active UI contract

## Visual intent

Pipe Buyer is a modern industrial marketplace. The interface should communicate trust, mechanical/industrial competence, clarity, and commercial seriousness. It should not drift into generic purple SaaS styling, toy-like gradients, or unrelated visual systems.

The implementation source of truth for current Flutter theme tokens is `lib/core/design/pipe_buyer_theme.dart`. Agents must reuse the existing theme and reusable components before creating new visual primitives.

## Brand palette

Use the existing `PipeBuyerColors` constants rather than introducing local hard-coded colors.

- primary/action orange: `#FF6A00`;
- pressed orange: `#E85F00`;
- soft orange: `#FFF1E8`;
- industrial blue: `#0F52BA`;
- ink: `#0D1117`;
- charcoal: `#151A20`;
- graphite: `#1E2938`;
- slate: `#475569`;
- muted: `#64748B`;
- light canvas: `#F6F7F9`;
- surface: `#FFFFFF`;
- surface-muted: `#F1F4F7`;
- field: `#F8FAFC`;
- line: `#E2E8F0`;
- success: `#148A45`;
- warning: `#F59E0B`;
- danger: `#D92D20`.

Dark-mode tokens already exist in the theme and must be preserved.

## Shape and controls

Current theme contracts:

- cards: 14 px radius;
- standard controls: 12 px radius;
- dialogs: 18 px radius;
- modal bottom-sheet top radius: 24 px;
- primary controls: minimum height 50 px;
- text buttons: minimum height 48 px;
- bottom navigation height: 70 px.

Do not create a competing radius/button system inside feature pages.

## Typography

Retain the established product typography and weight hierarchy. The active product roadmap specifies Outfit headings and Manrope interface text. Where font wiring is centralized, reuse it rather than applying local font families in feature files.

- major headings: strong, compact hierarchy;
- page and card titles: high-weight, high legibility;
- body text: readable line-height and restrained density;
- labels/actions: clear and semantically descriptive;
- avoid decorative text effects that reduce industrial/professional credibility.

## Layout and responsiveness

Design every product surface for:

- compact phone;
- medium tablet;
- landscape tablet/small desktop;
- wide desktop/web.

Required acceptance reference sizes are 390x844, 768x1024, 1024x768, and 1440x1000 unless a domain runbook specifies more.

Rules:

1. keep phone bottom navigation;
2. use adaptive tablet/desktop navigation instead of stretching the phone shell;
3. constrain wide content to readable widths;
4. use one-, two-, three-, and four-column marketplace layouts where card width permits;
5. preserve explicit user density preferences while clamping to readable card widths;
6. avoid fixed widths/heights that break text scaling or localization;
7. use shared page headers, cards, status chips, seller summaries, action bars, tables, and state components before introducing new variants.

## Component reuse law

Before adding a new visual component, search for an existing equivalent.

An autonomous change must not introduce a new:

- color token;
- button treatment;
- card treatment;
- status-chip style;
- page-header pattern;
- dialog structure;
- loading/empty/error pattern;
- navigation pattern;
- spacing scale

when an existing theme token or shared component can express the requirement.

If a genuinely new primitive is required, add it centrally and test it before using it across multiple pages.

## State design

Every network/data-driven surface must deliberately handle applicable states:

- loading;
- empty;
- offline;
- unavailable;
- denied/unauthorized;
- failed command;
- retry/recovery;
- stale or partial information when explicitly supported.

Do not expose raw provider/Firebase exception text to users.

## Marketplace-specific expectations

- cards should prioritize industrial imagery, title, core specifications, price/commercial state, location context, and seller trust signals without visual overload;
- listing details should use structured specifications and persistent primary actions appropriate to viewport size;
- admin surfaces should favor dense, scannable operational tables and filters over oversized marketing cards;
- messaging should use single-pane mobile and split-pane desktop patterns where appropriate;
- maps are contextual tools, not replacements for accessible list results.

## Accessibility

UI work must preserve or improve:

- semantic labels for non-text controls;
- keyboard operation on supported web/desktop surfaces;
- visible focus states;
- sufficient contrast;
- screen-reader ordering;
- scrollability and legibility at 200% text;
- touch-target sizing;
- recovery/error messages that identify the user action, not raw implementation details.

## Visual regression rule

Large UI refactors must be split from unrelated feature behavior. A refactor should first preserve user-visible behavior and pass existing tests/visual acceptance, then a later increment may intentionally change the design.

Agents must not restore archived visual systems merely because archived screens appear more complete. Archived Buyer/Seller boards are workflow references only.
