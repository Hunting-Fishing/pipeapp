from pathlib import Path

repairs = {
    Path("lib/marketplace/marketplace_dispatch_subscription_checkout.dart"): 1,
    Path("lib/marketplace/marketplace_vip_subscription_checkout.dart"): 3,
}

old = """return const SizedBox(\n          width: double.infinity,\n          child: OutlinedButton.icon("""
new = """return SizedBox(\n          width: double.infinity,\n          child: OutlinedButton.icon("""

for path, expected_count in repairs.items():
    source = path.read_text(encoding="utf-8")
    actual_count = source.count(old)
    if actual_count != expected_count:
        raise SystemExit(
            f"{path}: expected {expected_count} invalid const OutlinedButton wrapper(s), "
            f"found {actual_count}"
        )
    source = source.replace(old, new)
    if source.count(old) != 0:
        raise SystemExit(f"{path}: invalid const wrapper remains")
    path.write_text(source, encoding="utf-8")
    print(f"Repaired {expected_count} const wrapper(s) in {path}")
