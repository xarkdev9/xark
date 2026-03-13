// Validate that all 4 SQL migrations (005-008) were deployed correctly.
// Run: npx tsx scripts/validate-migrations.ts

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const supabase = createClient(url, key, {
  auth: { autoRefreshToken: false, persistSession: false },
});

let passed = 0;
let failed = 0;

async function check(name: string, fn: () => Promise<boolean>) {
  try {
    const ok = await fn();
    if (ok) {
      console.log(`  ✓ ${name}`);
      passed++;
    } else {
      console.log(`  ✗ ${name}`);
      failed++;
    }
  } catch (e: any) {
    console.log(`  ✗ ${name} — ${e.message}`);
    failed++;
  }
}

async function main() {
  console.log("\n--- Migration 005: media + user_devices ---");

  await check("media table exists", async () => {
    const { error } = await supabase.from("media").select("id").limit(0);
    return !error;
  });

  await check("user_devices table exists", async () => {
    const { error } = await supabase.from("user_devices").select("user_id").limit(0);
    return !error;
  });

  await check("users.photo_url column exists", async () => {
    const { data, error } = await supabase.from("users").select("photo_url").limit(0);
    return !error;
  });

  console.log("\n--- Migration 006: unreact_to_item ---");

  await check("unreact_to_item function exists", async () => {
    // Call with a fake item — should raise 'item_not_found', proving the function exists
    const { error } = await supabase.rpc("unreact_to_item", { p_item_id: "nonexistent_test_item" });
    // If the function exists, we get an error like 'item_not_found' (not 'function does not exist')
    if (!error) return true;
    return !error.message.includes("Could not find the function") && !error.message.includes("does not exist");
  });

  console.log("\n--- Migration 007: insert_system_message ---");

  await check("insert_system_message function exists", async () => {
    // Call with a fake space — should succeed or raise a FK error, not 'function does not exist'
    const { error } = await supabase.rpc("insert_system_message", {
      p_space_id: "nonexistent_test_space",
      p_content: "migration validation test",
    });
    if (!error) {
      // Clean up the test message
      await supabase.from("messages").delete().eq("content", "migration validation test");
      return true;
    }
    return !error.message.includes("Could not find the function") && !error.message.includes("does not exist");
  });

  console.log("\n--- Migration 008: join_via_invite ---");

  await check("join_via_invite function exists", async () => {
    const { error } = await supabase.rpc("join_via_invite", { p_space_id: "nonexistent_test_space" });
    if (!error) return true;
    // 'space_not_found' means the function exists and works correctly
    return !error.message.includes("Could not find the function") && !error.message.includes("does not exist");
  });

  console.log("\n--- Summary ---");
  console.log(`  ${passed} passed, ${failed} failed`);
  if (failed > 0) {
    console.log("\n  ⚠ Some migrations are missing. Re-run the failed SQL blocks in Supabase SQL Editor.");
    process.exit(1);
  } else {
    console.log("\n  All migrations validated. Ready to launch sessions.");
  }
}

main();
