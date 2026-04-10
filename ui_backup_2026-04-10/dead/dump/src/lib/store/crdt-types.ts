// Defines the Encrypted CRDT schemas that replace plaintext Layer 3 state
export type CrdtMutationType = 'VOTE' | 'ADD_EXPENSE' | 'MARK_SETTLED' | 'UPDATE_DATES' | 'RENAME_SPACE' | 'REVERT_MUTATION';

export interface BaseCrdtMutation {
  id: string; // Used for identifying mutations so they can be reverted
  type: CrdtMutationType;
  timestamp: string; // ISO string for deterministic ordering
  authorId: string;
}

export interface VoteMutation extends BaseCrdtMutation {
  type: 'VOTE';
  payload: {
    itemId: string; // The ID of the decision card
    value: 1 | -1;  // Upvote or downvote
  };
}

export interface AddExpenseMutation extends BaseCrdtMutation {
  type: 'ADD_EXPENSE';
  payload: {
    expenseId: string; // Unique ID for the expense
    amount: number;    // In cents
    description: string;
    paidBy: string;    // User ID
    splitAmong: string[]; // User IDs
  };
}

export interface UpdateDatesMutation extends BaseCrdtMutation {
  type: 'UPDATE_DATES';
  payload: {
    startDate: string;
    endDate: string;
    label?: string;
  };
}

export interface RenameSpaceMutation extends BaseCrdtMutation {
  type: 'RENAME_SPACE';
  payload: {
    newTitle: string;
  };
}

export interface RevertMutation extends BaseCrdtMutation {
  type: 'REVERT_MUTATION';
  payload: {
    targetMutationId: string; // The ID of the BaseCrdtMutation to revert
  };
}

export type CrdtMutation = VoteMutation | AddExpenseMutation | UpdateDatesMutation | RenameSpaceMutation | RevertMutation;

// The structure of the materialized view
export interface MaterializedGroupState {
  metadata: {
    title?: string;
    startDate?: string;
    endDate?: string;
  };
  votes: Record<string, number>; // itemId -> total score
  ledger: {
    expenses: Array<{
      id: string;
      amount: number;
      description: string;
      paidBy: string;
      splitAmong: string[];
      timestamp: string;
    }>;
    balances: Record<string, number>; // userId -> net balance (positive = owed, negative = owes)
  };
}

export const initialGroupState: MaterializedGroupState = {
  metadata: {},
  votes: {},
  ledger: {
    expenses: [],
    balances: {}
  }
};
