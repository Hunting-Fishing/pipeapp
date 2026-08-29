from pathlib import Path
import re

repairs = {
    Path("lib/marketplace/marketplace_dispatch_subscription_checkout.dart"): 1,
    Path("lib/marketplace/marketplace_vip_subscription_checkout.dart"): 3,
}

pattern = re.compile(
    r"return const SizedBox\(\n"
    r"(?P<indent>[ \t]+)width: double\.infinity,\n"
    r"(?P=indent)child: OutlinedButton\.icon\("
)

for path, expected_count in repairs.items():
    source = path.read_text(encoding="utf-8")
    matches = list(pattern.finditer(source))
    if len(matches) != expected_count:
        raise SystemExit(
            f"{path}: expected {expected_count} invalid const OutlinedButton wrapper(s), "
            f"found {len(matches)}"
        )

    repaired, replaced = pattern.subn(
        lambda match: (
            "return SizedBox(\n"
            f"{match.group('indent')}width: double.infinity,\n"
            f"{match.group('indent')}child: OutlinedButton.icon("
        ),
        source,
    )
    if replaced != expected_count:
        raise SystemExit(
            f"{path}: expected to repair {expected_count} wrapper(s), repaired {replaced}"
        )
    if pattern.search(repaired):
        raise SystemExit(f"{path}: invalid const wrapper remains")

    path.write_text(repaired, encoding="utf-8")
    print(f"Repaired {replaced} const wrapper(s) in {path}")
