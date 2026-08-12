from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one match, found {count}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


test_path = 'firebase/functions/test/dispatch_command_policy.test.js'
obsolete_review_assert = '''  assert.throws(
      () => validateDispatchQuote({
        job: {createdByUid: "customer", status: "open"},
        carrier: {
          ownerUid: "carrier",
          status: "active",
          availableForHire: true,
        },
        membership: {
          ownerUid: "carrier",
          active: true,
          currentPeriodEnd: now.getTime() + 30 * 24 * 60 * 60 * 1000,
        },
        vehicle: {
          ownerUid: "carrier",
          available: true,
          maximumPayloadKg: 25000,
        },
        existingBid: null,
        actorUid: "carrier",
        data: {
          jobId: "job",
          amount: 2500,
          availableDate: now.getTime() + 24 * 60 * 60 * 1000,
        },
        now,
      }),
      (error) => error.code === "permission-denied",
  );
'''
replace_once(test_path, obsolete_review_assert, '')
print('Removed obsolete provider-review quote assertion.')
