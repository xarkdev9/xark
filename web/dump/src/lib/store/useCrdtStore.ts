import { create } from 'zustand';
import { CrdtMutation, MaterializedGroupState, initialGroupState, VoteMutation, AddExpenseMutation, UpdateDatesMutation, RenameSpaceMutation } from './crdt-types';

interface CrdtStoreState {
  state: MaterializedGroupState;
  
  // Applies a decrypted mutation received from the E2EE network pipe
  applyMutation: (mutation: CrdtMutation) => void;
  
  // Utility for the UI to clear state on space switch
  reset: () => void;
}

export const useCrdtStore = create<CrdtStoreState>((set) => ({
  state: initialGroupState,
  
  applyMutation: (mutation: CrdtMutation) => set((currentState) => {
    // We deep clone the state for safety in Zustand, 
    // structuredClone is safe for simple JSON objects
    const nextState = structuredClone(currentState.state);
    
    switch (mutation.type) {
      case 'VOTE': {
        const voteMut = mutation as VoteMutation;
        const currentCount = nextState.votes[voteMut.payload.itemId] || 0;
        nextState.votes[voteMut.payload.itemId] = currentCount + voteMut.payload.value;
        break;
      }
      
      case 'ADD_EXPENSE': {
        const expenseMut = mutation as AddExpenseMutation;
        const { amount, paidBy, splitAmong } = expenseMut.payload;
        
        // 1. Add to expense ledger
        nextState.ledger.expenses.push({
          id: expenseMut.payload.expenseId,
          amount,
          description: expenseMut.payload.description,
          paidBy,
          splitAmong,
          timestamp: expenseMut.timestamp
        });
        
        // 2. Update balances
        // The payer gets a positive credit for the amount they covered for others
        const splitCount = splitAmong.length;
        if (splitCount === 0) break;
        
        const splitAmount = amount / splitCount;
        
        // Payer balance increases by total amount minus their own share
        const payerCurrent = nextState.ledger.balances[paidBy] || 0;
        nextState.ledger.balances[paidBy] = payerCurrent + amount;
        
        // Everyone in split has their balance decreased
        splitAmong.forEach(userId => {
          const userCurrent = nextState.ledger.balances[userId] || 0;
          nextState.ledger.balances[userId] = userCurrent - splitAmount;
        });
        
        break;
      }
      
      case 'UPDATE_DATES': {
        const dateMut = mutation as UpdateDatesMutation;
        nextState.metadata.startDate = dateMut.payload.startDate;
        nextState.metadata.endDate = dateMut.payload.endDate;
        if (dateMut.payload.label) {
            nextState.metadata.title = dateMut.payload.label;
        }
        break;
      }
      
      case 'RENAME_SPACE': {
        const renameMut = mutation as RenameSpaceMutation;
        nextState.metadata.title = renameMut.payload.newTitle;
        break;
      }
      
      default:
        console.warn('Unknown CRDT mutation type', mutation);
    }
    
    return { state: nextState };
  }),
  
  reset: () => set({ state: initialGroupState })
}));
