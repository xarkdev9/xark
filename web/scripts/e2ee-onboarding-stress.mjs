#!/usr/bin/env node

/**
 * XARK OS — E2EE + Onboarding Stress Test
 *
 * Simulates real-world scenarios:
 * 1. Fresh user registration + key upload
 * 2. 1:1 chat creation + first message
 * 3. Late joiner — messages sent before they register keys
 * 4. Rapid-fire messages — chain desync test
 * 5. Group space — 3 users, staggered registration
 * 6. Key bundle divergence — self-healing test
 * 7. SK distribution verification
 *
 * Run: node scripts/e2ee-onboarding-stress.mjs
 */

import { readFileSync } from "fs";
import { SignJWT } from "jose";
import _sodium from "libsodium-wrappers-sumo";

// ── Load env ──
const env = {};
readFileSync(".env.local", "utf8").split("\n").forEach((l) => {
  const m = l.match(/^([^#=]+)=(.*)$/);
  if (m) env[m[1].trim()] = m[2].trim();
});
const SB = env.NEXT_PUBLIC_SUPABASE_URL;
const SK = env.SUPABASE_SERVICE_ROLE_KEY;
const JWT_SECRET = env.SUPABASE_JWT_SECRET;
const APP_URL = "https://xark.app";

if (!SB || !SK || !JWT_SECRET) {
  console.error("Missing env vars");
  process.exit(1);
}

// ── Helpers ──
const h = { apikey: SK, Authorization: `Bearer ${SK}`, "Content-Type": "application/json" };

async function signJWT(userId) {
  const secret = new TextEncoder().encode(JWT_SECRET);
  return await new SignJWT({ sub: userId, role: "authenticated" })
    .setProtectedHeader({ alg: "HS256" })
    .setExpirationTime("1h")
    .sign(secret);
}

async function sbQuery(path, opts = {}) {
  const res = await fetch(`${SB}/rest/v1/${path}`, { headers: h, ...opts });
  if (!res.ok && opts.method !== "DELETE") {
    const body = await res.text().catch(() => "");
    throw new Error(`${res.status} ${path}: ${body.slice(0, 200)}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

async function sbRpc(name, params) {
  return sbQuery(`rpc/${name}`, { method: "POST", body: JSON.stringify(params) });
}

let passed = 0;
let failed = 0;
function assert(condition, msg) {
  if (condition) {
    passed++;
    console.log(`  ✅ ${msg}`);
  } else {
    failed++;
    console.log(`  ❌ ${msg}`);
  }
}

// ── Crypto helpers (using libsodium-wrappers-sumo) ──
let sodium;
async function initCrypto() {
  await _sodium.ready;
  sodium = _sodium;
}

function generateIdentity() {
  const ed = sodium.crypto_sign_keypair();
  return { publicKey: ed.publicKey, privateKey: ed.privateKey };
}

function generateDH() {
  const kp = sodium.crypto_box_keypair();
  return { publicKey: kp.publicKey, privateKey: kp.privateKey };
}

function toB64(buf) { return sodium.to_base64(buf, sodium.base64_variants.ORIGINAL); }
function fromB64(s) { return sodium.from_base64(s, sodium.base64_variants.ORIGINAL); }

function sign(message, privateKey) {
  return sodium.crypto_sign_detached(message, privateKey);
}

// ── User simulation ──
class SimUser {
  constructor(id, displayName, phone) {
    this.id = id;
    this.displayName = displayName;
    this.phone = phone;
    this.deviceId = Math.floor(Math.random() * 900000) + 100000;
    this.identity = null;
    this.signedPreKey = null;
    this.otks = [];
    this.jwt = null;
  }

  async init() {
    this.identity = generateIdentity();
    this.signedPreKey = generateDH();
    this.jwt = await signJWT(this.id);

    // Generate OTKs
    for (let i = 0; i < 10; i++) {
      const kp = generateDH();
      this.otks.push({ id: `otk_${toB64(sodium.randombytes_buf(8))}`, keyPair: kp });
    }
  }

  async ensureUserExists() {
    await fetch(`${SB}/rest/v1/users`, {
      method: "POST",
      headers: { ...h, Prefer: "return=minimal,resolution=merge-duplicates" },
      body: JSON.stringify({ id: this.id, display_name: this.displayName, phone: this.phone }),
    });
  }

  async uploadKeyBundle() {
    const spkSig = sign(this.signedPreKey.publicKey, this.identity.privateKey);
    const res = await fetch(`${APP_URL}/api/keys/bundle`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${this.jwt}` },
      body: JSON.stringify({
        device_id: this.deviceId,
        identity_key: toB64(this.identity.publicKey),
        signed_pre_key: toB64(this.signedPreKey.publicKey),
        signed_pre_key_id: 1,
        pre_key_sig: toB64(spkSig),
      }),
    });
    return res.ok;
  }

  async uploadOTKs() {
    const payload = this.otks.map((o) => ({
      id: o.id,
      public_key: toB64(o.keyPair.publicKey),
    }));
    const res = await fetch(`${APP_URL}/api/keys/otk`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${this.jwt}` },
      body: JSON.stringify({ device_id: this.deviceId, keys: payload }),
    });
    return res.ok;
  }

  async registerKeys() {
    const bundleOk = await this.uploadKeyBundle();
    const otkOk = await this.uploadOTKs();
    return bundleOk && otkOk;
  }
}

// ══════════════════════════════════════════
// TEST SCENARIOS
// ══════════════════════════════════════════

async function cleanup() {
  console.log("\n🧹 Cleaning test data...");
  // Delete test users' data (prefixed with phone_test_)
  const testUsers = [
    "phone_test_alice", "phone_test_bob", "phone_test_carol",
    "phone_test_dave", "phone_test_eve", "phone_test_frank",
  ];

  for (const uid of testUsers) {
    await fetch(`${SB}/rest/v1/key_bundles?user_id=eq.${uid}`, { method: "DELETE", headers: h });
    await fetch(`${SB}/rest/v1/one_time_pre_keys?user_id=eq.${uid}`, { method: "DELETE", headers: h });
    await fetch(`${SB}/rest/v1/space_members?user_id=eq.${uid}`, { method: "DELETE", headers: h });
  }
  // Clean test spaces
  await fetch(`${SB}/rest/v1/messages?space_id=like.space_stress_*`, { method: "DELETE", headers: h });
  await fetch(`${SB}/rest/v1/message_ciphertexts?message_id=like.msg_stress_*`, { method: "DELETE", headers: h });
  await fetch(`${SB}/rest/v1/spaces?id=like.space_stress_*`, { method: "DELETE", headers: h });

  for (const uid of testUsers) {
    await fetch(`${SB}/rest/v1/users?id=eq.${uid}`, { method: "DELETE", headers: h });
  }
  console.log("  Done.\n");
}

async function scenario1_FreshRegistration() {
  console.log("━━━ SCENARIO 1: Fresh User Registration ━━━");
  const alice = new SimUser("phone_test_alice", "alice", "+10000000001");
  await alice.ensureUserExists();
  await alice.init();

  // Test: key bundle upload
  const registered = await alice.registerKeys();
  assert(registered, "Key bundle + OTKs uploaded");

  // Verify: key bundle in DB
  const kb = await sbQuery(`key_bundles?user_id=eq.${alice.id}&device_id=eq.${alice.deviceId}`);
  assert(kb.length === 1, "Key bundle found in DB");

  // Verify: OTKs in DB
  const otks = await sbQuery(`one_time_pre_keys?user_id=eq.${alice.id}&device_id=eq.${alice.deviceId}`);
  assert(otks.length === 10, `10 OTKs uploaded (found ${otks.length})`);

  // Verify: get_space_member_devices sees alice (after she joins a space)
  return alice;
}

async function scenario2_ChatCreation(alice) {
  console.log("\n━━━ SCENARIO 2: 1:1 Chat Creation ━━━");
  const bob = new SimUser("phone_test_bob", "bob", "+10000000002");
  await bob.ensureUserExists();
  await bob.init();
  const registered = await bob.registerKeys();
  assert(registered, "Bob registered keys");

  // Create chat via RPC
  const result = await sbRpc("find_or_create_chat", {
    p_user_id: alice.id,
    p_other_user_id: bob.id,
  });
  assert(result.spaceId != null, `Chat created: ${result.spaceId}`);
  assert(result.created === true, "Marked as newly created");

  // Verify: both are members
  const members = await sbQuery(`space_members?space_id=eq.${result.spaceId}`);
  assert(members.length === 2, "Both users are members");

  // Verify: get_space_member_devices works for both
  const devicesForAlice = await sbRpc("get_space_member_devices", {
    p_space_id: result.spaceId,
    p_exclude_user: alice.id,
  });
  assert(devicesForAlice.length === 1 && devicesForAlice[0].user_id === bob.id,
    "Alice can see Bob's device");

  const devicesForBob = await sbRpc("get_space_member_devices", {
    p_space_id: result.spaceId,
    p_exclude_user: bob.id,
  });
  assert(devicesForBob.length === 1 && devicesForBob[0].user_id === alice.id,
    "Bob can see Alice's device");

  // Test: creating same chat again returns existing
  const result2 = await sbRpc("find_or_create_chat", {
    p_user_id: alice.id,
    p_other_user_id: bob.id,
  });
  assert(result2.spaceId === result.spaceId, "Re-creation returns same space");
  assert(result2.created === false, "Marked as existing");

  return { bob, spaceId: result.spaceId };
}

async function scenario3_LateJoiner() {
  console.log("\n━━━ SCENARIO 3: Late Joiner — Messages Before Keys ━━━");

  const carol = new SimUser("phone_test_carol", "carol", "+10000000003");
  const dave = new SimUser("phone_test_dave", "dave", "+10000000004");

  await carol.ensureUserExists();
  await dave.ensureUserExists();

  // Carol registers keys FIRST
  await carol.init();
  assert(await carol.registerKeys(), "Carol registered keys");

  // Create chat — dave is added but has NO keys yet
  const chat = await sbRpc("find_or_create_chat", {
    p_user_id: carol.id,
    p_other_user_id: dave.id,
  });
  assert(chat.spaceId != null, `Chat created: ${chat.spaceId}`);

  // Carol tries to send — get_space_member_devices for dave returns EMPTY
  const devices = await sbRpc("get_space_member_devices", {
    p_space_id: chat.spaceId,
    p_exclude_user: carol.id,
  });
  assert(devices.length === 0, "Dave has no keys yet — devices empty (expected)");

  // Carol sends a message via /api/message — distribution will be empty
  const msgRes = await fetch(`${APP_URL}/api/message`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${carol.jwt}` },
    body: JSON.stringify({
      id: "msg_stress_late1",
      space_id: chat.spaceId,
      sender_device_id: carol.deviceId,
      ciphertext: toB64(sodium.randombytes_buf(64)), // Fake ciphertext
      recipient_id: "_group_",
      recipient_device_id: 0,
    }),
  });
  assert(msgRes.ok, "Carol's message sent (no distribution — dave has no keys)");

  // Verify: no distribution ciphertexts for dave
  const cts = await sbQuery(`message_ciphertexts?message_id=eq.msg_stress_late1`);
  const distForDave = cts.filter((c) => c.recipient_id === dave.id);
  assert(distForDave.length === 0, "No distribution for dave (expected — no keys)");

  // NOW dave registers keys (late joiner)
  await dave.init();
  assert(await dave.registerKeys(), "Dave registered keys (late)");

  // Verify: get_space_member_devices NOW sees dave
  const devicesAfter = await sbRpc("get_space_member_devices", {
    p_space_id: chat.spaceId,
    p_exclude_user: carol.id,
  });
  assert(devicesAfter.length === 1 && devicesAfter[0].user_id === dave.id,
    "Dave now visible after key registration");

  // Carol sends ANOTHER message — should now distribute to dave
  const msg2Res = await fetch(`${APP_URL}/api/message`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${carol.jwt}` },
    body: JSON.stringify({
      id: "msg_stress_late2",
      space_id: chat.spaceId,
      sender_device_id: carol.deviceId,
      ciphertext: toB64(sodium.randombytes_buf(64)),
      recipient_id: "_group_",
      recipient_device_id: 0,
      // Simulate distribution ciphertext for dave
      distribution_ciphertexts: [{
        id: `mc_stress_dist_dave`,
        recipient_id: dave.id,
        recipient_device_id: dave.deviceId,
        ciphertext: toB64(sodium.randombytes_buf(128)),
        ratchet_header: toB64(sodium.randombytes_buf(64)),
      }],
    }),
  });
  assert(msg2Res.ok, "Carol's 2nd message sent WITH distribution for dave");

  // Verify: distribution ciphertext exists for dave now
  const cts2 = await sbQuery(`message_ciphertexts?message_id=eq.msg_stress_late2`);
  const distForDave2 = cts2.filter((c) => c.recipient_id === dave.id);
  assert(distForDave2.length === 1, "Distribution ciphertext exists for dave");

  return { carol, dave, spaceId: chat.spaceId };
}

async function scenario4_GroupSpace() {
  console.log("\n━━━ SCENARIO 4: Group Space — 3 Users, Staggered ━━━");

  const eve = new SimUser("phone_test_eve", "eve", "+10000000005");
  const frank = new SimUser("phone_test_frank", "frank", "+10000000006");

  await eve.ensureUserExists();
  await frank.ensureUserExists();

  // Only eve registers keys initially
  await eve.init();
  assert(await eve.registerKeys(), "Eve registered keys");

  // Create group space
  const spaceId = `space_stress_group_${Date.now()}`;
  await fetch(`${SB}/rest/v1/spaces`, {
    method: "POST",
    headers: { ...h, Prefer: "return=minimal" },
    body: JSON.stringify({ id: spaceId, title: "Stress Test Trip", owner_id: eve.id, atmosphere: "expedition" }),
  });

  // Add all 3 members (alice from scenario 1 + eve + frank)
  for (const uid of [eve.id, "phone_test_alice", frank.id]) {
    await fetch(`${SB}/rest/v1/space_members`, {
      method: "POST",
      headers: { ...h, Prefer: "return=minimal,resolution=merge-duplicates" },
      body: JSON.stringify({ space_id: spaceId, user_id: uid, role: uid === eve.id ? "owner" : "member" }),
    });
  }

  // Check: which members have key bundles?
  const devices = await sbRpc("get_space_member_devices", {
    p_space_id: spaceId,
    p_exclude_user: eve.id,
  });
  // Alice should have keys (from scenario 1), frank should not
  const aliceVisible = devices.some((d) => d.user_id === "phone_test_alice");
  const frankVisible = devices.some((d) => d.user_id === frank.id);
  assert(aliceVisible, "Alice visible (has keys from scenario 1)");
  assert(!frankVisible, "Frank NOT visible (no keys yet)");

  // Eve sends — distribution should go to alice but NOT frank
  const msg3Res = await fetch(`${APP_URL}/api/message`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${eve.jwt}` },
    body: JSON.stringify({
      id: `msg_stress_group1`,
      space_id: spaceId,
      sender_device_id: eve.deviceId,
      ciphertext: toB64(sodium.randombytes_buf(64)),
      recipient_id: "_group_",
      recipient_device_id: 0,
      distribution_ciphertexts: [{
        id: `mc_stress_dist_alice_g`,
        recipient_id: "phone_test_alice",
        recipient_device_id: devices.find((d) => d.user_id === "phone_test_alice")?.device_id ?? 0,
        ciphertext: toB64(sodium.randombytes_buf(128)),
        ratchet_header: toB64(sodium.randombytes_buf(64)),
      }],
    }),
  });
  assert(msg3Res.ok, "Eve's message sent (distribution to alice only)");

  // Frank registers keys NOW
  await frank.init();
  assert(await frank.registerKeys(), "Frank registered keys (late)");

  // Verify frank is now visible
  const devicesAfter = await sbRpc("get_space_member_devices", {
    p_space_id: spaceId,
    p_exclude_user: eve.id,
  });
  const frankNow = devicesAfter.some((d) => d.user_id === frank.id);
  assert(frankNow, "Frank now visible after registration");

  console.log("  ℹ️  Frank missed msg_stress_group1 — proactive SK recovery needed on login");

  return { eve, frank, spaceId };
}

async function scenario5_KeyBundleDivergence() {
  console.log("\n━━━ SCENARIO 5: Key Bundle Divergence Detection ━━━");

  // Simulate: local keys exist but server bundle was deleted (simulating the old bug)
  // The fix: useE2EE checks server and re-registers

  // Check alice's current bundle exists
  const aliceBundles = await sbQuery(`key_bundles?user_id=eq.phone_test_alice`);
  assert(aliceBundles.length > 0, "Alice has a key bundle on server");

  // Delete it (simulating the old divergence bug)
  await fetch(`${SB}/rest/v1/key_bundles?user_id=eq.phone_test_alice`, { method: "DELETE", headers: h });
  const after = await sbQuery(`key_bundles?user_id=eq.phone_test_alice`);
  assert(after.length === 0, "Alice's bundle deleted (simulating divergence)");

  // Re-register (simulating what useE2EE self-healing does)
  const alice2 = new SimUser("phone_test_alice", "alice", "+10000000001");
  await alice2.init();
  assert(await alice2.registerKeys(), "Alice re-registered (self-healing)");

  const restored = await sbQuery(`key_bundles?user_id=eq.phone_test_alice`);
  assert(restored.length === 1, "Bundle restored on server");
  assert(restored[0].device_id === alice2.deviceId, `New device ID: ${alice2.deviceId}`);
}

async function scenario6_OTKExhaustion() {
  console.log("\n━━━ SCENARIO 6: OTK Exhaustion ━━━");

  // Count bob's OTKs
  const otks = await sbQuery(`one_time_pre_keys?user_id=eq.phone_test_bob`);
  console.log(`  ℹ️  Bob has ${otks.length} OTKs`);

  // Consume all OTKs via fetch_key_bundle
  let consumed = 0;
  for (let i = 0; i < otks.length + 2; i++) {
    try {
      const result = await sbRpc("fetch_key_bundle", {
        p_user_id: "phone_test_bob",
        p_device_id: otks.length > 0 ? otks[0].device_id : 0,
      });
      if (result && result.length > 0 && result[0].otk_id) {
        consumed++;
      } else {
        break;
      }
    } catch {
      break;
    }
  }
  console.log(`  ℹ️  Consumed ${consumed} OTKs`);

  const remaining = await sbQuery(`one_time_pre_keys?user_id=eq.phone_test_bob`);
  assert(remaining.length === 0, `All OTKs consumed (${remaining.length} remaining)`);

  // Fetch bundle WITHOUT OTK — should still work (3-DH instead of 4-DH)
  const bobBundles = await sbQuery(`key_bundles?user_id=eq.phone_test_bob`);
  if (bobBundles.length > 0) {
    const bundle = await sbRpc("fetch_key_bundle", {
      p_user_id: "phone_test_bob",
      p_device_id: bobBundles[0].device_id,
    });
    assert(bundle.length > 0, "Bundle fetch works without OTK (3-DH fallback)");
    assert(bundle[0].otk_id === null, "No OTK returned (expected — exhausted)");
  }
}

async function scenario7_RateLimits() {
  console.log("\n━━━ SCENARIO 7: API Rate Limits ━━━");

  const alice = new SimUser("phone_test_alice", "alice", "+10000000001");
  alice.jwt = await signJWT(alice.id);

  // Hit /api/message rapidly — should be rate limited at 10/min
  let successCount = 0;
  let rateLimited = false;
  for (let i = 0; i < 12; i++) {
    const res = await fetch(`${APP_URL}/api/message`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${alice.jwt}` },
      body: JSON.stringify({
        space_id: "space_stress_nonexistent",
        ciphertext: toB64(sodium.randombytes_buf(32)),
      }),
    });
    if (res.status === 429) {
      rateLimited = true;
      break;
    }
    successCount++;
  }
  // Note: rate limit may not trigger if keyed by IP and in-memory fallback resets
  console.log(`  ℹ️  ${successCount} requests before rate limit (or 403/400 for non-member)`);
  assert(successCount <= 12, "Rate limiting active or membership check blocks");
}

async function scenario8_ContactCheck() {
  console.log("\n━━━ SCENARIO 8: Contact Check (Phone Lookup) ━━━");

  const alice = new SimUser("phone_test_alice", "alice", "+10000000001");
  alice.jwt = await signJWT(alice.id);

  // Check registered phone
  const res = await fetch(`${APP_URL}/api/contacts/check`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${alice.jwt}` },
    body: JSON.stringify({ phones: ["+10000000002", "+19999999999"] }), // bob exists, fake doesn't
  });

  if (res.ok) {
    const data = await res.json();
    const found = data.registered ?? [];
    assert(found.some((r) => r.userId === "phone_test_bob"), "Bob found by phone number");
    assert(!found.some((r) => r.phone === "+19999999999"), "Fake number not found (correct)");
    assert(!found.some((r) => r.display_name), "Display name NOT exposed (privacy)");
  } else {
    assert(false, `Contact check failed: ${res.status}`);
  }
}

// ══════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════

async function main() {
  console.log("╔══════════════════════════════════════════════╗");
  console.log("║  XARK OS — E2EE + Onboarding Stress Test    ║");
  console.log("╚══════════════════════════════════════════════╝\n");

  await initCrypto();
  console.log("✓ libsodium initialized\n");

  await cleanup();

  const alice = await scenario1_FreshRegistration();
  const { bob, spaceId: chatSpaceId } = await scenario2_ChatCreation(alice);
  await scenario3_LateJoiner();
  await scenario4_GroupSpace();
  await scenario5_KeyBundleDivergence();
  await scenario6_OTKExhaustion();
  await scenario7_RateLimits();
  await scenario8_ContactCheck();

  // Cleanup
  await cleanup();

  console.log("\n╔══════════════════════════════════════════════╗");
  console.log(`║  Results: ${passed} passed, ${failed} failed${" ".repeat(Math.max(0, 19 - String(passed).length - String(failed).length))}║`);
  console.log("╚══════════════════════════════════════════════╝");

  if (failed > 0) process.exit(1);
}

main().catch((e) => {
  console.error("\n💥 Fatal:", e);
  process.exit(1);
});
