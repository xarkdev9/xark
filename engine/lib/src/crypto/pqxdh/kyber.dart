/// Kyber KEM types — re-export barrel for PQXDH.
///
/// NOTE: The concrete `StubKyber` and `DeterministicStubKyber` classes
/// are **defined in `pqxdh.dart`**, not here. This file exists solely
/// to provide a stable `kyber.dart` import path for callers. When a
/// production Kyber-1024 library becomes available in pure Dart, add
/// the real implementation either inline here or alongside the stubs
/// in `pqxdh.dart` and export it from this barrel.
library;

export 'pqxdh.dart'
    show
        KemAlgorithm,
        KemKeyPair,
        KemEncapsulation,
        StubKyber,
        DeterministicStubKyber;
