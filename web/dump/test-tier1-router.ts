import { LocalIntentParser } from "./src/lib/agent/LocalIntentParser";

async function runTests() {
  console.log("=== Testing Tier 1 CRDT Integration ===\n");

  const intentParser = new LocalIntentParser();
  const userId = "user_ram_456";
  const activeMembers = [userId, "user_kai_789"];

  // Test 1: Date Command
  console.log("Test 1: Admin Command - Date Change");
  const dateIntent = await intentParser.parseSpotlightQuery("@xark set dates to june 1-5");
  if (dateIntent.action === 'UPDATE_DATES' && dateIntent.startDate) {
     console.log("✅ Correctly intercepted 'set dates' command");
     const mutation = intentParser.buildCrdtMutation(dateIntent, userId, activeMembers);
     if (mutation && mutation.type === 'UPDATE_DATES') {
        console.log(`✅ CRDT Built: [${mutation.type}] ${mutation.payload.startDate} to ${mutation.payload.endDate}`);
     } else {
        console.error("❌ Failed to build CRDT Mutation");
        process.exit(1);
     }
  } else {
     console.error("❌ Failed Date Command", dateIntent);
     process.exit(1);
  }

  // Test 2: Rename Command
  console.log("\nTest 2: Admin Command - Rename Space");
  const renameIntent = await intentParser.parseSpotlightQuery("@xark rename space to Tahoe 2026");
  if (renameIntent.action === 'RENAME_SPACE' && renameIntent.newTitle === 'Tahoe 2026') {
     console.log("✅ Correctly intercepted 'rename space' command");
     const mutation = intentParser.buildCrdtMutation(renameIntent, userId, activeMembers);
     if (mutation && mutation.type === 'RENAME_SPACE') {
        console.log(`✅ CRDT Built: [${mutation.type}] ${mutation.payload.newTitle}`);
     } else {
        console.error("❌ Failed to build CRDT Mutation");
        process.exit(1);
     }
  } else {
     console.error("❌ Failed Rename Command", renameIntent);
     process.exit(1);
  }

  // Test 3: Local Intent Parser (Expenses)
  console.log("\nTest 3: Local Intent Parser - Add Expense");
  const expenseIntent = await intentParser.parseSpotlightQuery("paid $300 for dinner");
  
  if (expenseIntent.action === 'ADD_EXPENSE' && expenseIntent.amount === 30000) {
      console.log("✅ Intent Parser correctly extracted ADD_EXPENSE");
      const mutation = intentParser.buildCrdtMutation(expenseIntent, userId, activeMembers);
      if (mutation && mutation.type === 'ADD_EXPENSE') {
          console.log(`✅ CRDT Built: [${mutation.type}] amount: ${mutation.payload.amount}, desc: ${mutation.payload.description}`);
      } else {
          console.error("❌ Failed to build CRDT Mutation");
          process.exit(1);
      }
  } else {
      console.error("❌ Failed to parse expense intent", expenseIntent);
      process.exit(1);
  }

  console.log("\n🎉 All Tier 1 Routing Tests Passed!");
}

runTests().catch(console.error);
