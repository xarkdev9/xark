#!/bin/bash
# =============================================================================
# E2EE Chat Engine — Overnight Build Launcher
# Usage: ./run.sh [--dry-run]
# =============================================================================

set -e

PROJECT_DIR="$HOME/fe2ee"
ORCHESTRATOR_DIR="$PROJECT_DIR/orchestrator"
TRACKER="$ORCHESTRATOR_DIR/tracker/TRACKER.md"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║          E2EE Chat Engine — Overnight Build               ║"
echo "║          Claude Code Sub-Agent Orchestration              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# --- Preflight checks ---
echo -e "${YELLOW}Running preflight checks...${NC}"

# Check Claude Code CLI
if ! command -v claude &> /dev/null; then
  echo -e "${RED}✗ Claude Code CLI not found. Install from: https://claude.ai/code${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Claude Code CLI found${NC}"

# Check Flutter
if ! command -v flutter &> /dev/null; then
  echo -e "${RED}✗ Flutter SDK not found${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Flutter SDK found: $(flutter --version | head -1)${NC}"

# Check project exists
if [ ! -d "$PROJECT_DIR" ]; then
  echo -e "${RED}✗ Project not found at $PROJECT_DIR${NC}"
  echo "  Create it first: flutter create --template=package fe2ee && mv fe2ee ~/"
  exit 1
fi
echo -e "${GREEN}✓ Project found at $PROJECT_DIR${NC}"

# Check CLAUDE.md exists
if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
  echo -e "${RED}✗ CLAUDE.md not found in $PROJECT_DIR${NC}"
  echo "  Copy your CLAUDE.md to $PROJECT_DIR/CLAUDE.md"
  exit 1
fi
echo -e "${GREEN}✓ CLAUDE.md found${NC}"

# Check FEATURES.md exists
if [ ! -f "$PROJECT_DIR/FEATURES.md" ]; then
  echo -e "${RED}✗ FEATURES.md not found in $PROJECT_DIR${NC}"
  exit 1
fi
echo -e "${GREEN}✓ FEATURES.md found${NC}"

# Copy orchestrator files into project
echo -e "${YELLOW}Setting up orchestrator in project...${NC}"
mkdir -p "$ORCHESTRATOR_DIR/agents" "$ORCHESTRATOR_DIR/tracker"

# Copy all agent files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/agents/"*.md "$ORCHESTRATOR_DIR/agents/"
cp "$SCRIPT_DIR/MASTER_PROMPT.md" "$ORCHESTRATOR_DIR/"
cp "$SCRIPT_DIR/tracker/TRACKER_INIT.md" "$ORCHESTRATOR_DIR/tracker/"

# Initialize tracker with timestamp
START_TIME=$(date '+%Y-%m-%d %H:%M:%S %Z')
sed "s/{START_TIME}/$START_TIME/" "$ORCHESTRATOR_DIR/tracker/TRACKER_INIT.md" > "$TRACKER"

# Copy decisions log
cp "$SCRIPT_DIR/tracker/DECISIONS.md" "$ORCHESTRATOR_DIR/tracker/DECISIONS.md"

echo -e "${GREEN}✓ Orchestrator files ready${NC}"

if [ "$1" == "--dry-run" ]; then
  echo -e "\n${YELLOW}Dry run complete. Files are staged. Run without --dry-run to launch.${NC}"
  exit 0
fi

# --- Launch ---
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Launching Master Orchestrator...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Tracker: ${YELLOW}$TRACKER${NC}"
echo -e "  Logs:    ${YELLOW}$ORCHESTRATOR_DIR/build.log${NC}"
echo ""
echo -e "${YELLOW}The orchestrator will now run all 12 agents sequentially.${NC}"
echo -e "${YELLOW}Estimated time: 5-7 hours. You can safely close this terminal.${NC}"
echo -e "${YELLOW}Monitor progress: watch -n 10 cat $TRACKER${NC}"
echo ""

# Build the master prompt — inject paths
MASTER_PROMPT="You are the Master Orchestrator for the E2EE Flutter chat engine build.

Your working directory is: $PROJECT_DIR
All agent definitions are in: $ORCHESTRATOR_DIR/agents/
Tracker file: $TRACKER
CLAUDE.md: $PROJECT_DIR/CLAUDE.md
FEATURES.md: $PROJECT_DIR/FEATURES.md

$(cat $ORCHESTRATOR_DIR/MASTER_PROMPT.md)
"

# Launch Claude Code with the master prompt
cd "$PROJECT_DIR"
echo "$MASTER_PROMPT" | claude \
  --dangerously-skip-permissions \
  2>&1 | tee "$ORCHESTRATOR_DIR/build.log"

# --- Post-run summary ---
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Build run complete.${NC}"
echo ""
echo "Final tracker:"
cat "$TRACKER"
echo ""
echo -e "Full log: ${YELLOW}$ORCHESTRATOR_DIR/build.log${NC}"
