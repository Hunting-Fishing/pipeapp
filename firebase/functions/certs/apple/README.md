# Apple root certificates

These DER-encoded public root certificates are trust anchors for Apple's
official App Store Server Library. They are public certificates, not secrets.

Source authority: <https://www.apple.com/certificateauthority/>

| File | Source URL | SHA-256 | Valid through |
| --- | --- | --- | --- |
| `AppleRootCA-G2.cer` | `https://www.apple.com/certificateauthority/AppleRootCA-G2.cer` | `c2b9b042dd57830e7d117dac55ac8ae19407d38e41d88f3215bc3a890444a050` | 2039-05-01 |
| `AppleRootCA-G3.cer` | `https://www.apple.com/certificateauthority/AppleRootCA-G3.cer` | `63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179` | 2039-05-01 |

The files were refreshed and fingerprinted on 2026-10-16. Before replacing a
certificate, download it directly from Apple, verify its subject and validity,
update the pinned SHA-256 value above, and run the App Store server tests.
