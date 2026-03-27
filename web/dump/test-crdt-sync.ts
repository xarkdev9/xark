import { initialGroupState, CrdtMutationType, VoteMutation, AddExpenseMutation } from '../src/lib/store/crdt-types';
import { useCrdtStore } from '../src/lib/store/useCrdtStore';

function runCrdtValidation() {
  console.log("--- Starting E2EE CRDT Sync Validation (Task 2.1) ---");

  // Get the Zustand store instance correctly based on how we export it 
  const store = useCrdtStore.getState();

  console.log("1. Initializing Materialized Store...");
  console.log("Initial state:", JSON.stringify(store.state, null, 2));

  console.log("\n2. Client A dispatches a VOTE mutation (Upvote Nobu)...");
  
  const voteMutation: VoteMutation = {
    id: `vote_${Date.now()}`,
    type: 'VOTE',
    timestamp: new Date().toISOString(),
    authorId: 'user_A',
    payload: {
      itemId: 'place_nobu_123',
      value: 1
    }
  };

  // Simulate network broadcast
  console.log(`[Network] -> Broadcasting ciphertext with msg_type='crdt_mutation'`);

  // Simulate Client B receiving, decrypting, and applying
  console.log("\n3. Client B decrypts ciphertext and applies mutation...");
  store.applyMutation(voteMutation);
  
  console.log("Updated state after Vote:", JSON.stringify(useCrdtStore.getState().state.votes, null, 2));


  console.log("\n4. Client C dispatches an EXPENSE mutation (A paid $320 for Nobu, split with B and C)...");
  
  const expenseMutation: AddExpenseMutation = {
    id: `exp_${Date.now()}`,
    type: 'ADD_EXPENSE',
    timestamp: new Date().toISOString(),
    authorId: 'user_A',
    payload: {
      expenseId: 'exp_001',
      amount: 32000, // $320.00
      description: 'Dinner at Nobu',
      paidBy: 'user_A',
      splitAmong: ['user_A', 'user_B', 'user_C'] // Includes payer in split
    }
  };

  console.log(`[Network] -> Broadcasting ciphertext with msg_type='crdt_mutation'`);
  
  console.log("\n5. Client B decrypts and applies Expense mutation...");
  store.applyMutation(expenseMutation);

  console.log("Updated Ledger State:", JSON.stringify(useCrdtStore.getState().state.ledger, null, 2));
  
  const finalState = useCrdtStore.getState();
  
  // Verify state correctness
  const isVoteCorrect = finalState.state.votes['place_nobu_123'] === 1;
  const isBalanceCorrect = 
    Math.abs(finalState.state.ledger.balances['user_A'] - 21333.33) < 0.01 && 
    Math.abs(finalState.state.ledger.balances['user_B'] - (-10666.66)) < 0.01;

  if (isVoteCorrect && isBalanceCorrect) {
    console.log("\n✅ Validation SUCCESS: E2EE CRDT engine correctly materializes group state.");
  } else {
    console.error("\n❌ Validation FAILED: CRDT engine produced incorrect state.");
    process.exit(1);
  }
}

// Scaffold validation execution
runCrdtValidation();
