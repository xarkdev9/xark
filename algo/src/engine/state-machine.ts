/**
 * Configurable State Machine
 *
 * Drives item state transitions based on a StateFlowConfig.
 * Each DecisionSpace can have its own state flow.
 */

export interface StateTransition {
  from: string;
  to: string;
  trigger: "reaction" | "commitment" | "manual";
}

export interface StateFlowConfig {
  name: string;
  initialState: string;
  lockedState: string;
  transitions: StateTransition[];
}

export class StateMachine {
  private readonly config: StateFlowConfig;
  private readonly transitionMap: Map<string, StateTransition[]>;

  constructor(config: StateFlowConfig) {
    this.config = config;
    this.transitionMap = new Map();
    for (const t of config.transitions) {
      const key = `${t.from}:${t.trigger}`;
      const existing = this.transitionMap.get(key) ?? [];
      existing.push(t);
      this.transitionMap.set(key, existing);
    }
  }

  getInitialState(): string {
    return this.config.initialState;
  }

  getLockedState(): string {
    return this.config.lockedState;
  }

  isLocked(state: string): boolean {
    return state === this.config.lockedState;
  }

  canTransition(from: string, to: string): boolean {
    return this.config.transitions.some((t) => t.from === from && t.to === to);
  }

  transition(state: string, trigger: "reaction" | "commitment" | "manual"): string | null {
    const key = `${state}:${trigger}`;
    const transitions = this.transitionMap.get(key);
    if (!transitions || transitions.length === 0) return null;
    return transitions[0]!.to;
  }

  getName(): string {
    return this.config.name;
  }

  getConfig(): StateFlowConfig {
    return this.config;
  }
}
