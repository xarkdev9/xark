import { isRecallQuestion, getRecallWhisper } from "./src/lib/local-recall";

async function runTests() {
  console.log("=== Testing Tier 2 E2EE Memory Engine ===\n");

  const recallQueries = [
    "@xark what was that hotel nina mentioned?",
    "@xark who said they wanted sushi?",
    "remember when we went to tahoe?",
    "what did ram share about the itinerary?",
    "@xark find that message with the airbnb link",
    "look up the restaurant booking"
  ];

  const searchQueries = [
    "@xark search for hotels in miami",
    "look up flights to tokyo",
    "what is the weather like in New York?",
    "suggest a good place for dinner tonight"
  ];

  console.log("Testing Recall Queries (Should be TRUE):");
  let recallFailed = false;
  for (const q of recallQueries) {
      if (isRecallQuestion(q)) {
          console.log(`✅ [TRUE]  ${q}`);
      } else {
          console.error(`❌ [FALSE] ${q} (Expected TRUE)`);
          recallFailed = true;
      }
  }

  console.log("\nTesting Search Queries (Should be FALSE):");
  let searchFailed = false;
  for (const q of searchQueries) {
      if (!isRecallQuestion(q)) {
          console.log(`✅ [FALSE] ${q}`);
      } else {
          console.error(`❌ [TRUE]  ${q} (Expected FALSE)`);
          searchFailed = true;
      }
  }

  console.log("\nTesting Whisper Logic:");
  const highTierWhisper = getRecallWhisper("high");
  const lowTierWhisper = getRecallWhisper("low");
  console.log(`High Tier: "${highTierWhisper}"`);
  console.log(`Low Tier: "${lowTierWhisper}"`);

  if (recallFailed || searchFailed) {
      console.error("\n❌ Some tests failed.");
      process.exit(1);
  } else {
      console.log("\n🎉 All Tier 2 Recall Detection Tests Passed!");
  }
}

runTests().catch(console.error);
