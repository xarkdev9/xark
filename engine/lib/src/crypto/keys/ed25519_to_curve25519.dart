import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Ed25519 to Curve25519 (X25519) key conversion utilities.
///
/// Matches libsodium's `crypto_sign_ed25519_pk_to_curve25519` and
/// `crypto_sign_ed25519_sk_to_curve25519`.
///
/// These functions are essential for the X3DH protocol where identity
/// keys are Ed25519 but Diffie-Hellman requires X25519 keys.
class Ed25519ToCurve25519 {
  Ed25519ToCurve25519._();

  /// Converts an Ed25519 private key (32-byte seed) to an X25519
  /// private key.
  ///
  /// Steps:
  /// 1. SHA-512(seed) -> 64 bytes
  /// 2. Take first 32 bytes
  /// 3. Clamp the scalar for X25519
  static Future<Uint8List> convertPrivateKey(
    Uint8List ed25519Seed,
  ) async {
    assert(ed25519Seed.length == 32, 'Ed25519 seed must be 32 bytes');

    final sha512 = Sha512();
    final hash = await sha512.hash(ed25519Seed);
    final scalar = Uint8List.fromList(hash.bytes.sublist(0, 32));

    // Clamp the scalar (standard X25519 clamping).
    scalar[0] &= 248; // clear bits 0, 1, 2
    scalar[31] &= 127; // clear bit 255
    scalar[31] |= 64; // set bit 254

    return scalar;
  }

  /// Converts an Ed25519 public key to an X25519 public key.
  ///
  /// The Ed25519 public key is a compressed Edwards25519 point
  /// encoding the y-coordinate with the sign of x in the most
  /// significant bit of the last byte.
  ///
  /// Formula: `u = (1 + y) / (1 - y) mod p` where
  /// `p = 2^255 - 19`.
  static Uint8List convertPublicKey(Uint8List ed25519Public) {
    assert(
      ed25519Public.length == 32,
      'Ed25519 public key must be 32 bytes',
    );

    // Decode y from the Ed25519 compressed point.
    // The sign bit of x is in MSB of byte[31]; mask it off.
    final yBytes = Uint8List.fromList(ed25519Public);
    yBytes[31] &= 0x7F;

    final y = _Fe.fromBytes(yBytes);
    final one = _Fe.one();

    // u = (1 + y) * inverse(1 - y) mod p
    final numerator = one.add(y);
    final denominator = one.sub(y);
    final denominatorInv = denominator.invert();
    final u = numerator.mul(denominatorInv);

    return u.toBytes();
  }
}

// ------------------------------------------------------------------
// Field element in GF(2^255 - 19).
//
// Represented as 10 limbs of ~25.5 bits each (alternating 26 and 25
// bits), matching the representation used by ref10 and TweetNaCl.
// ------------------------------------------------------------------

class _Fe {
  _Fe(this._limbs);

  /// Multiplicative identity.
  factory _Fe.one() {
    final l = Int64List(10);
    l[0] = 1;
    return _Fe(l);
  }

  /// Carry propagation after a multiplication.
  factory _Fe._carried(Int64List h) {
    final carry = Int64List(10);

    carry[0] = (h[0] + (1 << 25)) >> 26;
    h[1] += carry[0];
    h[0] -= carry[0] << 26;

    carry[4] = (h[4] + (1 << 25)) >> 26;
    h[5] += carry[4];
    h[4] -= carry[4] << 26;

    carry[1] = (h[1] + (1 << 24)) >> 25;
    h[2] += carry[1];
    h[1] -= carry[1] << 25;

    carry[5] = (h[5] + (1 << 24)) >> 25;
    h[6] += carry[5];
    h[5] -= carry[5] << 25;

    carry[2] = (h[2] + (1 << 25)) >> 26;
    h[3] += carry[2];
    h[2] -= carry[2] << 26;

    carry[6] = (h[6] + (1 << 25)) >> 26;
    h[7] += carry[6];
    h[6] -= carry[6] << 26;

    carry[3] = (h[3] + (1 << 24)) >> 25;
    h[4] += carry[3];
    h[3] -= carry[3] << 25;

    carry[7] = (h[7] + (1 << 24)) >> 25;
    h[8] += carry[7];
    h[7] -= carry[7] << 25;

    carry[4] = (h[4] + (1 << 25)) >> 26;
    h[5] += carry[4];
    h[4] -= carry[4] << 26;

    carry[8] = (h[8] + (1 << 25)) >> 26;
    h[9] += carry[8];
    h[8] -= carry[8] << 26;

    carry[9] = (h[9] + (1 << 24)) >> 25;
    h[0] += carry[9] * 19;
    h[9] -= carry[9] << 25;

    carry[0] = (h[0] + (1 << 25)) >> 26;
    h[1] += carry[0];
    h[0] -= carry[0] << 26;

    return _Fe(h);
  }

  /// Decode a 32-byte little-endian field element.
  factory _Fe.fromBytes(Uint8List bytes) {
    assert(bytes.length == 32, 'Field element must be 32 bytes');

    final h = Int64List(10);

    int load3(int i) =>
        bytes[i] | (bytes[i + 1] << 8) | (bytes[i + 2] << 16);

    int load4(int i) =>
        bytes[i] |
        (bytes[i + 1] << 8) |
        (bytes[i + 2] << 16) |
        (bytes[i + 3] << 24);

    final carry = Int64List(10);

    h[0] = load4(0);
    h[1] = load3(4) << 6;
    h[2] = load3(7) << 5;
    h[3] = load3(10) << 3;
    h[4] = load3(13) << 2;
    h[5] = load4(16);
    h[6] = load3(20) << 7;
    h[7] = load3(23) << 5;
    h[8] = load3(26) << 4;
    h[9] = (load3(29) & 0x7FFFFF) << 2;

    carry[9] = (h[9] + (1 << 24)) >> 25;
    h[0] += carry[9] * 19;
    h[9] -= carry[9] << 25;

    for (var i = 1; i < 9; i += 2) {
      carry[i] = (h[i] + (1 << 24)) >> 25;
      h[i + 1] += carry[i];
      h[i] -= carry[i] << 25;
    }
    for (var i = 0; i < 10; i += 2) {
      carry[i] = (h[i] + (1 << 25)) >> 26;
      if (i + 1 < 10) {
        h[i + 1] += carry[i];
      } else {
        h[0] += carry[i] * 19;
      }
      h[i] -= carry[i] << 26;
    }

    return _Fe(h);
  }

  final Int64List _limbs;

  /// Encode as a 32-byte little-endian array, fully reduced mod p.
  Uint8List toBytes() {
    final h = Int64List.fromList(_limbs);
    final carry = Int64List(10);

    // Determine whether subtraction of p is needed.
    var q = (19 * h[9] + (1 << 24)) >> 25;
    for (var i = 0; i < 10; i++) {
      if (i == 0) {
        q = (h[0] + q) >> 26;
      } else if (i.isOdd) {
        q = (h[i] + q) >> 25;
      } else {
        q = (h[i] + q) >> 26;
      }
    }
    h[0] += 19 * q;

    carry[0] = h[0] >> 26;
    h[1] += carry[0];
    h[0] -= carry[0] << 26;
    for (var i = 1; i < 10; i++) {
      if (i.isOdd) {
        carry[i] = h[i] >> 25;
      } else {
        carry[i] = h[i] >> 26;
      }
      if (i + 1 < 10) {
        h[i + 1] += carry[i];
      }
      if (i.isOdd) {
        h[i] -= carry[i] << 25;
      } else {
        h[i] -= carry[i] << 26;
      }
    }

    final s = Uint8List(32);
    s[0] = h[0] & 0xFF;
    s[1] = (h[0] >> 8) & 0xFF;
    s[2] = (h[0] >> 16) & 0xFF;
    s[3] = ((h[0] >> 24) | (h[1] << 2)) & 0xFF;
    s[4] = (h[1] >> 6) & 0xFF;
    s[5] = (h[1] >> 14) & 0xFF;
    s[6] = ((h[1] >> 22) | (h[2] << 3)) & 0xFF;
    s[7] = (h[2] >> 5) & 0xFF;
    s[8] = (h[2] >> 13) & 0xFF;
    s[9] = ((h[2] >> 21) | (h[3] << 5)) & 0xFF;
    s[10] = (h[3] >> 3) & 0xFF;
    s[11] = (h[3] >> 11) & 0xFF;
    s[12] = ((h[3] >> 19) | (h[4] << 6)) & 0xFF;
    s[13] = (h[4] >> 2) & 0xFF;
    s[14] = (h[4] >> 10) & 0xFF;
    s[15] = (h[4] >> 18) & 0xFF;
    s[16] = h[5] & 0xFF;
    s[17] = (h[5] >> 8) & 0xFF;
    s[18] = (h[5] >> 16) & 0xFF;
    s[19] = ((h[5] >> 24) | (h[6] << 1)) & 0xFF;
    s[20] = (h[6] >> 7) & 0xFF;
    s[21] = (h[6] >> 15) & 0xFF;
    s[22] = ((h[6] >> 23) | (h[7] << 3)) & 0xFF;
    s[23] = (h[7] >> 5) & 0xFF;
    s[24] = (h[7] >> 13) & 0xFF;
    s[25] = ((h[7] >> 21) | (h[8] << 4)) & 0xFF;
    s[26] = (h[8] >> 4) & 0xFF;
    s[27] = (h[8] >> 12) & 0xFF;
    s[28] = ((h[8] >> 20) | (h[9] << 6)) & 0xFF;
    s[29] = (h[9] >> 2) & 0xFF;
    s[30] = (h[9] >> 10) & 0xFF;
    s[31] = (h[9] >> 18) & 0xFF;
    return s;
  }

  /// Add two field elements.
  _Fe add(_Fe other) {
    final result = Int64List(10);
    for (var i = 0; i < 10; i++) {
      result[i] = _limbs[i] + other._limbs[i];
    }
    return _Fe(result);
  }

  /// Subtract two field elements.
  _Fe sub(_Fe other) {
    final result = Int64List(10);
    for (var i = 0; i < 10; i++) {
      result[i] = _limbs[i] - other._limbs[i];
    }
    return _Fe(result);
  }

  /// Multiply two field elements (schoolbook, reduction by 19).
  _Fe mul(_Fe other) {
    final f = _limbs;
    final g = other._limbs;

    final f0 = f[0];
    final f1 = f[1];
    final f2 = f[2];
    final f3 = f[3];
    final f4 = f[4];
    final f5 = f[5];
    final f6 = f[6];
    final f7 = f[7];
    final f8 = f[8];
    final f9 = f[9];

    final g0 = g[0];
    final g1 = g[1];
    final g2 = g[2];
    final g3 = g[3];
    final g4 = g[4];
    final g5 = g[5];
    final g6 = g[6];
    final g7 = g[7];
    final g8 = g[8];
    final g9 = g[9];

    final f12 = 2 * f1;
    final f32 = 2 * f3;
    final f52 = 2 * f5;
    final f72 = 2 * f7;
    final f92 = 2 * f9;

    final g119 = 19 * g1;
    final g219 = 19 * g2;
    final g319 = 19 * g3;
    final g419 = 19 * g4;
    final g519 = 19 * g5;
    final g619 = 19 * g6;
    final g719 = 19 * g7;
    final g819 = 19 * g8;
    final g919 = 19 * g9;

    final h = Int64List(10);
    h[0] = f0 * g0 + f12 * g919 + f2 * g819 + f32 * g719 +
        f4 * g619 + f52 * g519 + f6 * g419 + f72 * g319 +
        f8 * g219 + f92 * g119;
    h[1] = f0 * g1 + f1 * g0 + f2 * g919 + f3 * g819 +
        f4 * g719 + f5 * g619 + f6 * g519 + f7 * g419 +
        f8 * g319 + f9 * g219;
    h[2] = f0 * g2 + f12 * g1 + f2 * g0 + f32 * g919 +
        f4 * g819 + f52 * g719 + f6 * g619 + f72 * g519 +
        f8 * g419 + f92 * g319;
    h[3] = f0 * g3 + f1 * g2 + f2 * g1 + f3 * g0 +
        f4 * g919 + f5 * g819 + f6 * g719 + f7 * g619 +
        f8 * g519 + f9 * g419;
    h[4] = f0 * g4 + f12 * g3 + f2 * g2 + f32 * g1 +
        f4 * g0 + f52 * g919 + f6 * g819 + f72 * g719 +
        f8 * g619 + f92 * g519;
    h[5] = f0 * g5 + f1 * g4 + f2 * g3 + f3 * g2 +
        f4 * g1 + f5 * g0 + f6 * g919 + f7 * g819 +
        f8 * g719 + f9 * g619;
    h[6] = f0 * g6 + f12 * g5 + f2 * g4 + f32 * g3 +
        f4 * g2 + f52 * g1 + f6 * g0 + f72 * g919 +
        f8 * g819 + f92 * g719;
    h[7] = f0 * g7 + f1 * g6 + f2 * g5 + f3 * g4 +
        f4 * g3 + f5 * g2 + f6 * g1 + f7 * g0 +
        f8 * g919 + f9 * g819;
    h[8] = f0 * g8 + f12 * g7 + f2 * g6 + f32 * g5 +
        f4 * g4 + f52 * g3 + f6 * g2 + f72 * g1 +
        f8 * g0 + f92 * g919;
    h[9] = f0 * g9 + f1 * g8 + f2 * g7 + f3 * g6 +
        f4 * g5 + f5 * g4 + f6 * g3 + f7 * g2 +
        f8 * g1 + f9 * g0;

    return _Fe._carried(h);
  }

  /// Square a field element.
  _Fe square() => mul(this);

  /// Multiplicative inverse via Fermat's little theorem:
  /// `a^(p-2) mod p` where `p = 2^255 - 19`.
  _Fe invert() {
    final z2 = square();
    var t = z2.square().square(); // z^8
    final z9 = t.mul(this); // z^9
    final z11 = z9.mul(z2); // z^11

    t = z11.square(); // z^22
    final z50 = t.mul(z9); // z^31 = z^(2^5 - 1)

    t = z50;
    for (var i = 0; i < 5; i++) {
      t = t.square();
    }
    final z100 = t.mul(z50); // z^(2^10 - 1)

    t = z100;
    for (var i = 0; i < 10; i++) {
      t = t.square();
    }
    final z200 = t.mul(z100); // z^(2^20 - 1)

    t = z200;
    for (var i = 0; i < 20; i++) {
      t = t.square();
    }
    t = t.mul(z200); // z^(2^40 - 1)

    for (var i = 0; i < 10; i++) {
      t = t.square();
    }
    final z500 = t.mul(z100); // z^(2^50 - 1)

    t = z500;
    for (var i = 0; i < 50; i++) {
      t = t.square();
    }
    final z1000 = t.mul(z500); // z^(2^100 - 1)

    t = z1000;
    for (var i = 0; i < 100; i++) {
      t = t.square();
    }
    t = t.mul(z1000); // z^(2^200 - 1)

    for (var i = 0; i < 50; i++) {
      t = t.square();
    }
    t = t.mul(z500); // z^(2^250 - 1)

    // z^(2^255 - 21) = z^(p - 2)
    t = t.square().square().square().square().square();
    t = t.mul(z11); // 2^255 - 32 + 11 = 2^255 - 21

    return t;
  }
}
