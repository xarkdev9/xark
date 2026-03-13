// XARK OS v2.0 — HEART-SORT ENGINE (SSOT)
export interface Possibility {
  id: string;
  title: string;
  imageUrl: string;
  weightedScore: number;
  agreementScore: number;
  isLocked: boolean;
  createdAt: number;
}

export type ConsensusState = "seeking" | "steady" | "ignited";

export function getConsensusState(agreementScore: number): ConsensusState {
  if (agreementScore > 0.8) return "ignited";
  if (agreementScore > 0.3) return "steady";
  return "seeking";
}

export function heartSort(items: Possibility[]): Possibility[] {
  return [...items].sort((a, b) => {
    if (a.isLocked !== b.isLocked) return a.isLocked ? 1 : -1;
    if (b.weightedScore !== a.weightedScore) return b.weightedScore - a.weightedScore;
    return a.createdAt - b.createdAt;
  });
}
