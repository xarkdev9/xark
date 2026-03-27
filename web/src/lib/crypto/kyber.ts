// hello OS v2.0 — Kyber KEM Types & Stub
// Re-exports KEM interface and stub implementations from pqxdh.ts.
// When a production Kyber-1024 WASM/JS library is available,
// add the real implementation here alongside the stub.

export type { KemAlgorithm, KemKeyPair, KemEncapsulation } from './pqxdh';
export { StubKyber, DeterministicStubKyber } from './pqxdh';
