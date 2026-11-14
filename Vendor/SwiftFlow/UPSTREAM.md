# SwiftFlow upstream provenance

- Repository: https://github.com/aaurelions/SwiftFlow
- Revision: 3515701fad73d3c6f8722bd65c22ef0813dc11a0
- License: MIT, retained in LICENSE.md.
- Vendored Sources, Tests, Package.swift and README.md from that exact revision.

Local patch: localized string lookup uses Bundle.swiftFlowResources, which searches the signed application's Contents/Resources before the upstream generated Bundle.module fallback. Without this, SwiftPM looks at the app bundle root (codesign rejects resource bundles there), then an absolute build-directory fallback. Engine algorithms and interaction behavior are unchanged.

To update: fetch/review a specific upstream revision, replace upstream files, reapply only this resource lookup patch, update this provenance and THIRD_PARTY_NOTICES.md, run upstream tests plus scripts/verify-background.sh. Do not silently follow upstream main. No telemetry or networking is added by the engine.
