/// Kyber KEM types and stub implementation for PQXDH.
///
/// Re-exports the KEM interface and stub from `pqxdh.dart`.
/// When a production Kyber-1024 library becomes available in pure Dart,
/// add the real implementation here alongside the stub.
library;

export 'pqxdh.dart'
    show
        KemAlgorithm,
        KemKeyPair,
        KemEncapsulation,
        StubKyber,
        DeterministicStubKyber;
