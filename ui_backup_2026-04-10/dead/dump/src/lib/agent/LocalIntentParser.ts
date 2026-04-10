import { AddExpenseMutation, UpdateDatesMutation, RenameSpaceMutation } from '../store/crdt-types';

export interface ParsedIntent {
  action: 'ADD_EXPENSE' | 'UPDATE_DATES' | 'RENAME_SPACE' | 'UNKNOWN';
  amount?: number;
  description?: string;
  startDate?: string;
  endDate?: string;
  newTitle?: string;
  confidence: number;
}

const MONTH_MAP: Record<string, number> = {
  jan: 0, january: 0, feb: 1, february: 1, mar: 2, march: 2,
  apr: 3, april: 3, may: 4, jun: 5, june: 5,
  jul: 6, july: 6, aug: 7, august: 7, sep: 8, september: 8,
  oct: 9, october: 9, nov: 10, november: 10, dec: 11, december: 11,
};

function parseSimpleDateRange(text: string): { startDate: string; endDate: string } | null {
  const singleMonth = text.match(/(\w+)\s+(\d{1,2})\s*[-–to]+\s*(\d{1,2})/i);
  if (singleMonth) {
    const month = MONTH_MAP[singleMonth[1].toLowerCase()];
    if (month !== undefined) {
      const year = new Date().getFullYear();
      const start = new Date(year, month, parseInt(singleMonth[2]));
      const end = new Date(year, month, parseInt(singleMonth[3]));
      if (end < new Date()) {
        start.setFullYear(year + 1);
        end.setFullYear(year + 1);
      }
      return {
        startDate: start.toISOString().split("T")[0],
        endDate: end.toISOString().split("T")[0],
      };
    }
  }

  const twoMonth = text.match(/(\w+)\s+(\d{1,2})\s+to\s+(\w+)\s+(\d{1,2})/i);
  if (twoMonth) {
    const m1 = MONTH_MAP[twoMonth[1].toLowerCase()];
    const m2 = MONTH_MAP[twoMonth[3].toLowerCase()];
    if (m1 !== undefined && m2 !== undefined) {
      const year = new Date().getFullYear();
      const start = new Date(year, m1, parseInt(twoMonth[2]));
      const end = new Date(year, m2, parseInt(twoMonth[4]));
      if (end < new Date()) {
        start.setFullYear(year + 1);
        end.setFullYear(year + 1);
      }
      return {
        startDate: start.toISOString().split("T")[0],
        endDate: end.toISOString().split("T")[0],
      };
    }
  }

  return null;
}

export class LocalIntentParser {
  async parseSpotlightQuery(query: string): Promise<ParsedIntent> {
    
    // 1. Rename Rules
    const renameMatch = query.match(/(?:rename|set)\s+(?:space|this|it|group|title)\s+to\s+(.+)/i);
    if (renameMatch) {
      return {
        action: 'RENAME_SPACE',
        newTitle: renameMatch[1].trim(),
        confidence: 1.0
      };
    }

    // 2. Date Rules
    const dateMatch = query.match(/(?:set|change|update|modify)\s+(?:trip\s+)?dates?\s+to\s+(.+)/i);
    if (dateMatch) {
      const dateText = dateMatch[1].trim();
      const parsed = parseSimpleDateRange(dateText);
      if (parsed) {
         return {
            action: 'UPDATE_DATES',
            startDate: parsed.startDate,
            endDate: parsed.endDate,
            confidence: 1.0
         };
      }
    }
    
    // 3. Expense Rules
    const expenseRegex = /(paid|spent|cost)\s+\$?(\d+(?:\.\d{2})?)\s+(for|on)\s+(.+)/i;
    const expenseMatch = query.match(expenseRegex);

    if (expenseMatch) {
      const parsedAmount = parseFloat(expenseMatch[2]);
      return {
        action: 'ADD_EXPENSE',
        amount: Math.round(parsedAmount * 100),
        description: expenseMatch[4].trim(),
        confidence: 0.95
      };
    }

    return {
      action: 'UNKNOWN',
      confidence: 0.1
    };
  }

  buildCrdtMutation(intent: ParsedIntent, userId: string, activeMembers: string[]): AddExpenseMutation | UpdateDatesMutation | RenameSpaceMutation | null {
    const timestamp = new Date().toISOString();
    const id = `mut_${crypto.randomUUID()}`;

    if (intent.action === 'ADD_EXPENSE' && intent.amount && intent.description) {
      return {
        id,
        type: 'ADD_EXPENSE',
        timestamp,
        authorId: userId,
        payload: {
          expenseId: `exp_local_${crypto.randomUUID()}`,
          amount: intent.amount,
          description: intent.description,
          paidBy: userId,
          splitAmong: activeMembers
        }
      };
    }

    if (intent.action === 'UPDATE_DATES' && intent.startDate && intent.endDate) {
       return {
          id,
          type: 'UPDATE_DATES',
          timestamp,
          authorId: userId,
          payload: {
            startDate: intent.startDate,
            endDate: intent.endDate
          }
       };
    }

    if (intent.action === 'RENAME_SPACE' && intent.newTitle) {
       return {
          id,
          type: 'RENAME_SPACE',
          timestamp,
          authorId: userId,
          payload: {
            newTitle: intent.newTitle
          }
       };
    }

    return null;
  }
}
