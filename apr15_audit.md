# CRITICAL DIRECTIVE: ZERO-ASSUMPTION SEQUENTIAL FORENSIC AUDIT

You are operating in **STRICT FORENSIC AUDIT MODE** following a catastrophic data loss and recovery incident (April 15 Incident). Your objective is to validate the exact, literal state of the codebase end-to-end.

**RULES OF ENGAGEMENT (VIOLATION IS A FAILURE):**
1. **ZERO ASSUMPTIONS:** You may not guess the state of any file, error, or git status. You cannot trust your memory of previous conversations.
2. **ZERO HALLUCINATIONS:** Every single claim you make must be mathematically and physically backed by a terminal command output (`stdout`/`stderr`) that you run in *this specific session*.
3. **MANDATORY TERMINAL USE:** You must use the `bash` / `terminal` tool to execute the explicit commands listed for each phase. You must wait for the command to finish and read the outputs before proceeding.
4. **STRICT SEQUENTIAL EXECUTION:** You will execute exactly 5 audits. You must execute Audit 1, read the results, then execute Audit 2, read the results, and so on. Do not parallelize. Do not hallucinate the execution of commands.

Execute the following 5 audits precisely. 

---

### 🔍 AUDIT 1: Git State & Working Tree Integrity
**Focus:** Guarantee no source files are left untracked, preventing another wipe, and ensure `.agent` is ignored.
**Commands you MUST execute:**
1. `git status -s` (Must be empty).
2. `git ls-files --others --exclude-standard` (Must be empty).
3. `find app/lib -type f -name "*.dart" | wc -l` (Count physical Dart files on disk).
4. `git ls-files app/lib | grep "\.dart$" | wc -l` (Count tracked Dart files. Compare this to step 3 to mathematically prove all files are tracked).
5. `cat .gitignore | grep "\.agent" || echo "NOT IGNORED"` (Verify the agent directory is safely ignored).

### 🔍 AUDIT 2: Asset & Dependency Reality Check
**Focus:** Verify all dependencies resolve and all physical assets exist to prevent app crashes.
**Commands you MUST execute:**
1. `flutter clean && flutter pub get` (Ensure flawless dependency resolution).
2. `cat pubspec.yaml | grep -A 15 "assets:"` (Check asset definitions).
3. `ls -la assets/images/ assets/fonts/ 2>/dev/null || echo "MISSING ASSET DIRECTORY"` (Verify physical directories exist).
4. `grep -rn "assets/" app/lib/` (Find all asset strings requested by the code to cross-reference with physical disk files).

### 🔍 AUDIT 3: Deprecated API & Token Sweep
**Focus:** Prove the token migrations (NS1 updates) survived and exactly 0 legacy APIs exist.
**Commands you MUST execute:**
1. `grep -rnw 'app/lib' -e "HelloTypography" -e "successGreen" -e "\.category" -e "HelloText.hero" -e "HelloText.hint" || echo "CLEAN: No legacy tokens"` (Must return empty).
2. `grep -rn "const.*HelloColors" app/lib/ || echo "CLEAN"` (Check for illegal `const` usages with the new brightness-aware getters).
3. `grep -rn "const.*HelloText" app/lib/ || echo "CLEAN"` (Check for illegal `const` usages on text themes).

### 🔍 AUDIT 4: Vulnerable Files & Regression Deep-Dive
**Focus:** Inspect the physical byte-size, line-count, and content of the specific files known to be partially recovered, truncated, or stubbed.
**Commands you MUST execute:**
1. `wc -l app/lib/pages/plans_view.dart app/lib/pages/settlement_page.dart app/lib/theme.dart app/lib/providers/seed_data.dart 2>/dev/null`
2. `tail -n 40 app/lib/pages/settlement_page.dart` (Physically inspect the exact state of the payment CTA stub).
3. `grep -in "stub\|TODO\|placeholder\|Unimplemented" app/lib/pages/settlement_page.dart app/lib/pages/plans_view.dart 2>/dev/null`
4. `cat CLAUDE.md | grep -i "git filter-repo" || echo "WARNING: LANDMINE MISSING"` (Verify the incident landmine documentation was added to guardrails).

### 🔍 AUDIT 5: End-to-End Build & Static Analysis
**Focus:** The ultimate lie-detector. Prove the codebase actually compiles without hidden linking errors.
**Commands you MUST execute:**
1. `dart analyze app/lib/ > analyze_output.txt && tail -n 5 analyze_output.txt` (Verify the exact error/warning/info count without blowing up the context window. We expect 0 errors).
2. `flutter build web --profile` (Execute a headless web build to strictly prove the compilation pipeline linking works. **DO NOT use `flutter run`** as it will hang the terminal).
3. `echo "Build Exit Code: $?"` (Capture the pass/fail state).

---

### 📝 FINAL DELIVERABLE: DETAILED STATUS REPORT
Once (and ONLY once) all 5 audits have been successfully completed via your terminal tools, synthesize your findings into a comprehensive **"Post-Recovery Codebase Status Report"**. 

Organize your report exactly as follows:
1. **Git & Workspace Health:** Exact counts of physical vs tracked files. Are we safe? Is `.agent/` ignored?
2. **Asset & Dependency Health:** List of any missing/broken asset references or pubspec mismatches.
3. **API & Token Drift:** Did any legacy API tokens survive? (List exact files if so).
4. **Vulnerable Files Exact State:** The specific line counts and missing logic inside `settlement_page.dart`, `plans_view.dart`, `theme.dart`, and `seed_data.dart`. Paste the exact stub snippet from `settlement_page.dart`.
5. **Build & Analyze Results:** The exact `dart analyze` summary and the pass/fail exit code of the web build.
6. **Strict Remediation Plan:** A prioritized, numbered list of exact actionable steps needed RIGHT NOW to restore `settlement_page.dart` and `plans_view.dart`, and fix any remaining errors discovered across the 5 audits.

**EXECUTION INSTRUCTION:** Acknowledge this prompt by saying "Initiating Zero-Trust Audit." Then immediately use your bash/terminal tool to execute the commands for AUDIT 1. Do not generate the final report until the bash commands for AUDIT 5 have been executed and analyzed.