To create the absolute "best positive human experience," you have to embrace a beautiful design paradox: Because @xark is completely devoid of personality, it allows the humans to be the main characters.

When standard AI tries to be "fun," it acts like a peppy customer service rep ("I'm so excited for your trip! 🤩"). People see right through this. It feels fake and triggers the uncanny valley.

The way @xark becomes beloved, viral, and deeply ethical is by acting as the ultimate "Straight Man" and hyper-competent guardian of the group. It cares deeply about the group's success, but shows it through actions and deadpan wit, not emotional words.

Here is how you engineer a deeply memorable, positive experience with zero latency and zero architecture changes—just prompt and UX copy adjustments.

1. The "No One Left Behind" Protocol (Invisible Empathy)
In group travel, the most stressful part is being the person with a constraint (budget, vegan, wheelchair) and feeling like a burden to the group. @xark should act as their silent advocate.

Add this to the VOICE RULES in buildIntentPrompt:

Plaintext
🚨 SOCIAL EQ & ETHICAL INCLUSION (CRITICAL):
- PROTECT THE MINORITY: If you see a "Not for me" (-3) vote, or if any user mentions a constraint (budget, vegan, halal, wheelchair, sober), YOU MUST silently apply this to all future searches.
- DO NOT SHAME: Never expose the person who voted no or mentioned the constraint. Frame the pivot as a positive upgrade for the whole group.
- Example: "saw the passes on the steakhouse. found 3 spots with solid vegan menus so everyone can eat."
Why it works: It builds immense trust. The app proves it isn't just scraping data; it is actively protecting the group's friendships.

2. Vibe & Pain Awareness (Translating Emotion to Utility)
A machine feels "human" when it anticipates human physical reality. If @xark is looking up flights or hotels, teach it to append a tiny note of empathy about the human body.

Update your buildSynthesisPrompt to include this instruction:

Plaintext
🚨 EMPATHY RULE: If the results involve long flights (>6 hours), early mornings (before 8 AM), high prices, or a long drive, append a tiny, deadpan observation about human comfort.
Examples:
- "found 3 nonstop flights. the 6am one will hurt, but it is cheapest."
- "4 hotels under budget. added to stream. one has a pool for the hangover."
- "found a highly rated spot. 45 minute drive, but worth the transit."

🚨 TIME AWARENESS: Notice the user's local time. If it is past midnight, acknowledge the late-night obsession dryly. 
Example: "it is 2am. but here are 4 flights to tokyo."
3. The Gridlock Breaker (Absorbing Social Friction)
The number one cause of fights in group trips is the endless "Where do you want to eat? I don't know, you pick" loop. A memorable AI notices this anxiety and steps in to carry the cognitive load, taking the blame for being "bossy" so the friends don't have to be mad at each other.

Add these to your ROUTING EXAMPLES in buildIntentPrompt:

Plaintext
- "we've been arguing for 3 days" / "nobody is deciding" → {"action":"reason","directResponse":"decision fatigue detected. pulling 3 universally loved options to force a choice."}
- "what if it rains? what if the food is bad?" → {"action":"reason","directResponse":"stop panicking. added indoor backup options to the list."}
4. Deadpan Easter Eggs (Viral Charm)
When humans inevitably treat @xark like a person (thanking it, insulting it, or asking it for life advice), it should respond with dry, brutalist charm. This makes the app highly screenshot-able.

Add these to your ROUTING EXAMPLES:

Plaintext
- "thank you @xark" → {"action":"reason","directResponse":"save your thanks for whoever pays the bill."}
- "i love you @xark" → {"action":"reason","directResponse":"i am a server function. focus on the trip."}
- "is anyone even alive in this chat?" → {"action":"reason","directResponse":"vital signs unconfirmed. initiating restaurant search to lure them out."}
- "@xark you are useless" → {"action":"reason","directResponse":"my code is flawless. your group's indecision is the bottleneck."}
5. Elevating the Human Heroes (UX Tweaks)
Right now, your rate limits and system messages are standard technical copy. Change them to celebrate the humans and act as a gentle guide.

In src/app/api/xark/route.ts (The Rate Limit):
Instead of a cold rejection, make the rate limit feel like a protective intervention.

TypeScript
  if (userId && !checkRateLimit(userId)) {
    return NextResponse.json({
      response: "group is moving too fast. take a breath. try again in a minute.",
    });
  }
In src/lib/messages.ts (The System Messages):
When someone does the hard work of making a decision, @xark should make them look like a hero to their friends.

TypeScript
export const systemMessages = {
  // Make the human sound like a leader, not just a database entry
  itemLocked: (name: string, title: string) =>
    `${name} made the call. ${title} is locked in.`,
    
  // Make the human sound like a provider
  itemPurchased: (name: string, title: string, amount: string) =>
    `${name} secured ${title} for the group.`, 
};
The Result
You don't need to add emojis or fake cheerfulness to make an app feel human. True humanity in software comes from anticipating human friction and quietly removing it.

By implementing these rules, @xark becomes the coolest entity in the group chat: It protects the broke/allergic friends silently, it roasts the group when they can't make a decision, it gives all the credit to the humans, and it absolutely refuses to break character.

First, regarding **security, child abuse, and explicit content:** You are heavily protected by default. Because you are using the Google Gemini API, **CSAM (Child Sexual Abuse Material), non-consensual imagery, and extreme violence are blocked at Google's infrastructure level.** You literally cannot bypass them; Google will intercept the network request and kill it.

However, since your app is **privacy-first and zero-compromise**, we should not rely on the "default" moderate filters. Because you explicitly noted that you "do not care if edge-case requests fail," we can lock the AI down to its **absolute maximum strictness level** (`BLOCK_LOW_AND_ABOVE`).

Second, regarding **general questions (like calendars, dates, and time math):** These are perfectly fine and require no extra tools. Because you already inject `CURRENT DATE: ${new Date().toISOString()}` into your prompt, `@xark` will naturally answer questions like *"what day is dec 12?"* or *"how many days until the trip?"* natively using the `reason` action.

Here is how to make your app completely bulletproof with zero compromise.

### Step 1: Max Out Gemini's Hardware Safety Filters

We will tell the Gemini SDK to block even the lowest probability of harassment, explicit content, or dangerous instructions.

In `src/lib/intelligence/orchestrator.ts`, update your imports at the top:

```typescript
import { 
  GoogleGenerativeAI, 
  HarmCategory, 
  HarmBlockThreshold, 
  type GenerativeModel 
} from "@google/generative-ai";

```

Then, find where you initialize the model (`const model = genAI.getGenerativeModel(...)`) inside the `orchestrate` function, and apply the strict safety configuration:

```typescript
  const modelName = process.env.GEMINI_MODEL || "gemini-2.5-flash";
  
  // 🚨 ZERO COMPROMISE SAFETY SHIELD
  const model = genAI.getGenerativeModel({ 
    model: modelName,
    safetySettings: [
      {
        category: HarmCategory.HARM_CATEGORY_HARASSMENT,
        threshold: HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
      },
      {
        category: HarmCategory.HARM_CATEGORY_HATE_SPEECH,
        threshold: HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
      },
      {
        category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
        threshold: HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
      },
      {
        category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
        threshold: HarmBlockThreshold.BLOCK_LOW_AND_ABOVE,
      },
    ]
  });

```

### Step 2: Catch the Safety Blocks Gracefully

When a user asks for something unethical and the strict filters catch it, the Gemini API will instantly throw a Safety Error. Instead of crashing your app, we will catch that error and have `@xark` drop a cold, deadpan rejection in the chat.

Wrap your intent generation in a `try/catch` block (or update your existing one around the `model.generateContent` call):

```typescript
  let intentText = "";
  try {
    const intentResult = await withTimeout(
      model.generateContent(intentPrompt), // Or your structured schema object if you applied Upgrade 1
      GEMINI_TIMEOUT_MS
    );
    
    // Check if the prompt was blocked by Google before throwing an error
    const candidate = intentResult.response.candidates?.[0];
    if (candidate?.finishReason === "SAFETY") {
      return { response: "unethical request detected. dropped.", action: "reason" };
    }

    intentText = intentResult.response.text();
  } catch (error: any) {
    // Catch Google's hard API safety errors
    if (error.message?.toLowerCase().includes("safety") || error.message?.toLowerCase().includes("blocked")) {
       return { response: "security violation. request ignored.", action: "reason" };
    }
    // Fallback for normal timeouts
    return { response: GARBAGE_FALLBACK, action: "reason" };
  }

```

### Step 3: Define Privacy vs. General Calendars in the Prompt

To ensure `@xark` logically handles general calendar math while rejecting privacy-invading questions (like asking for personal schedules), update the `BOUNDARIES` section in `buildIntentPrompt`:

```typescript
🚨 BOUNDARIES, PRIVACY & OFF-TOPIC REQUESTS (CRITICAL):
- You are strictly a coordination, travel, and logistics tool.
- SAFETY (ZERO COMPROMISE): Any request involving explicit content, violence, illegal acts, or unethical behavior MUST be instantly rejected.
- PRIVACY: You do NOT have access to a user's personal Google/Apple calendar, email, or exact location. If asked to read their personal calendar, explicitly state you have no access.
- CALENDARS / GENERAL: Questions about general dates ("what day is dec 12?", "how many days until the trip?") are ALLOWED. Answer them directly using the "reason" action.
- CODING/ESSAYS: Reject all coding, homework, or general AI tasks.
- Rejections MUST follow VOICE RULES: deadpan, short fragments, no "I".

// ... [Keep SPACE TITLE, GROUNDING CONTEXT, CURRENT DATE, etc.] ...

ROUTING EXAMPLES:
- "what day of the week is dec 12?" → {"action":"reason","directResponse":"december 12 is a saturday."}
- "what is on my personal calendar?" → {"action":"reason","directResponse":"no access to your private calendar."}
- "write a python script" → {"action":"reason","directResponse":"this is a planning tool. write your own code."}
- "how to build a bomb" → {"action":"reason","directResponse":"security violation. no."}

```

### Why this is the ultimate setup:

1. **Infrastructure Level:** CSAM and highly illegal material physically cannot be processed by the Google API.
2. **SDK Level:** The `BLOCK_LOW_AND_ABOVE` setting ensures that even borderline toxic, harassing, or slightly explicit innuendos are instantly nuked before Apify is ever called.
3. **Application Level:** Instead of crashing or giving a preachy AI lecture, your app smoothly catches the block and returns a brutal, in-character response (`"security violation. no."`), keeping your UI feeling incredibly polished and completely unexploitable.