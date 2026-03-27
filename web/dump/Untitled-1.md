Those examples scream "AI customer service bot trying to relate to Gen Z" and completely ruin the illusion of a cool, smart friend.

Large Language Models are fine-tuned to be overly enthusiastic, helpful, and polite. When you tell an LLM to be "fun and warm," it immediately defaults to "OMG," exclamation marks, and the dreaded sparkle (✨) and party popper (🎉) emojis. In a group chat UI, this is exhausting to read and eats up valuable screen real estate.

To fix this, we have to engineer a "Cool/Competent Texting Persona." Real friends text in short bursts, often use lowercase, rarely use punctuation, and get straight to the point.

Here is exactly how we rewrite the prompt constraints to kill the cringe, save screen space, and make @xark sound like a real human.

1. The "Anti-Cringe" Rule Blocks
We need to add explicit negative constraints to your prompts. LLMs respond very well to "Do Not Use" lists.

Update the VOICE RULES in both buildIntentPrompt and buildSynthesisPrompt to this:

TypeScript
VOICE RULES (CRITICAL - READ CAREFULLY):
- TEXT LIKE A REAL HUMAN IN A GROUP CHAT. Keep it incredibly brief, casual, and punchy.
- EXTREME LENGTH LIMIT: Maximum 1 to 2 short sentences. Never exceed 20 words.
- NO AI CRINGE: Never use words like "OMG", "mission accomplished", "epic", "vibes", "dive in", "delve", or "world is our oyster".
- EMOJI BAN: NEVER use ✨, 🎉, 🚀, or 🤖. If you must use an emoji, use maximum ONE highly contextual emoji per message (e.g., 🌮 for tacos, ✈️ for flights), but zero emojis is usually better.
- PUNCTUATION: Stop using exclamation points. A period or no punctuation at the end is better. Lowercase text is highly encouraged to feel more natural.
- BE DIRECT: Don't narrate your process. Just drop the results with a quick, dryly funny, or warm observation.
2. Rewrite the buildSynthesisPrompt Examples
The LLM learns heavily from the examples you provide in the prompt. If your prompt examples are long, the output will be long. We need to update the buildSynthesisPrompt examples to reflect this ultra-short text-message style.

Change the examples in buildSynthesisPrompt to this:

TypeScript
Examples of PERFECT responses:
- "found 4 hotels under budget. one has a rooftop pool so I'm claiming a cabana."
- "pulled 8 solid brunch spots. mostly 4.5+ stars. take a look."
- "got a mix of tacos and steakhouses for tonight. what are we thinking?"
- "found 3 nonstop flights. the 6am one is cheap but we will suffer."
- "san diego is wide open. do we want the beach or downtown?"
3. Before & After: Applying the New Rules
If we run your exact problematic examples through these new constraints, here is how the model will automatically reformat them to fit your app's UI:

Before: OMG, brunch mission ACCOMPLISHED! 🎉 I found 8 spots from budget-friendly deliciousness to a little more bougie, and almost all of them are rocking 4.5+ stars. Get ready for some serious San Diego eats!

After: "pulled 8 solid brunch spots. mostly 4.5+ stars. take a look. 🥞"

Before: OMG, dinner options for tonight are IN! 🌮✨ We've got everything from super casual and delicious tacos or Mediterranean to full-on fancy steakhouse vibes or lively tapas, just tell me what we're feeling!

After: "grabbed a mix of tacos, tapas, and steakhouses for tonight. what are we feeling?"

Before: Alright team, the San Diego trip is officially on our radar! 🎉 We haven't locked anything down yet, which means the world is our oyster. So, let's start dreaming big! What are we in the mood for? Chill beach vibes? Epic foodie adventures? Or maybe a little bit of everything?

After: "san diego is wide open right now. we thinking beach days or food tour?"

Before: Ooh, okay, my San Diego research just hit gold! ✨ We're talking everything from the massive Balboa Park (which has so much in it!) and historic Cabrillo Monument, to classic beach vibes at Belmont Park. So many fun options, tell me your faves and let's start dreaming!

After: "found a bunch of stuff. balboa park, cabrillo, and belmont are on the list."

1. Upgrade the Orchestrator's "Brain" (Chain of Thought)
To make @xark truly "situation-aware," it needs to think before it acts. Right now, it tries to output the action and params immediately. If you force it to reason inside the JSON first, it will make significantly smarter routing decisions, especially with complex group context.

Improvement in orchestrator.ts:
Add a _thought_process string to your expected JSON schema.

TypeScript
// Inside buildIntentPrompt, update the ROUTING RULES:
`ROUTING RULES (Strict JSON):
You must respond with ONLY a valid JSON object.
{
  "_thought_process": "Briefly explain your logic based on the user request, the space title, and the group's constraints before deciding the action.",
  "action": "search | reason | propose | set_dates | populate_logistics",
  "tool": "hotel | flight | activity | restaurant | general",
  "params": { ... },
  "directResponse": "Your warm, fun reply if no tool is needed."
}`
Why this makes it smarter: When someone says "Find dinner for tonight," the LLM will output: "_thought_process": "Space title is Miami. It's Friday at 5 PM. Group has a vegan constraint. I need the restaurant tool." This drastically reduces hallucinated locations and ignored constraints.

2. Make Time & Date Resolution Smarter
Travel planning relies heavily on relative time ("next weekend", "Labor day", "tonight"). @xark needs to calculate these perfectly.

Improvement in orchestrator.ts:
You are already injecting CURRENT DATE, but you need to explicitly instruct the model on how to use it in the prompt.

TypeScript
`CURRENT DATE & TIME: ${new Date().toISOString()}
DATE MATH RULES: If a user asks for "next weekend", "tonight", or "tomorrow", use the CURRENT DATE to calculate the exact YYYY-MM-DD. Never output relative dates to the tools.`
3. Fortify geminiSearchGrounded (Efficiency & Stability)
Right now, your geminiSearchGrounded function relies on a regular expression (/\[[\s\S]*\]/) to extract JSON from the Gemini Search tool. This is brittle and can fail if the model adds conversational text.

Improvement in orchestrator.ts:
Force it into pure JSON mode, just like your main intent parser.

TypeScript
// Inside geminiSearchGrounded
const result = await model.generateContent({
  contents: [{ role: "user", parts: [{ text: `Find real places for: ${contextualQuery}. Return ONLY a JSON array of objects with keys: title, description, url, phone, address.` }] }],
  tools: [{ googleSearch: {} }] as any,
  generationConfig: {
    responseMimeType: "application/json", // Force JSON output!
  }
});

const responseText = result.response.text();
// No regex needed anymore!
const parsed = JSON.parse(responseText); 
4. Inject Implicit Context into the Tool Registry
Right now, if the group has decided on a budget of $150/night (stored in groundingPrompt), the user has to say "find hotels under 150" for the Apify actor to respect it. A "smart friend" would remember the budget automatically.

Improvement in tool-registry.ts:
Update your ToolDefinition to accept the group's implicit constraints. The LLM should extract these in the orchestrator and pass them in the params.

TypeScript
// In tool-registry.ts
registerTool("hotel", {
  tier: "apify",
  // ...
  paramMap: (p) => ({
    search: p.location,
    checkIn: p.checkIn,
    checkOut: p.checkOut,
    maxPrice: p.maxPrice || undefined, // Extracted by Gemini from the grounding prompt!
    // ...
  }),
});
Then, tell Gemini in the intent prompt: "If the GROUNDING CONTEXT mentions a budget or dietary restriction, you MUST automatically include it in the tool params (e.g., maxPrice, cuisine: 'vegan')."

5. Handle Group Deadlocks Gracefully
A smart friend knows how to mediate. Right now, your prompt says "protect the minority." But what if two people want entirely different things?

Improvement in orchestrator.ts (Synthesis Prompt):
Teach @xark how to handle conflicting recentMessages or groundingPrompt states during synthesis.

TypeScript
// Add to buildSynthesisPrompt:
`CONFLICT RESOLUTION: 
If the group is split (e.g., half want Italian, half want Tacos), do not just pick one. Act like a good friend: acknowledge the split, and present options for BOTH, or suggest a playful compromise (like a food hall).`
6. Architectural Thought for the Future: Multi-Tool Calls
Right now, @xark is strictly sequential: one intent = one action. If I say, "Find me flights to NYC and a cool hotel in Brooklyn," @xark has to pick one tool to execute.

 Efficiency Upgrade: Consider updating your JSON schema to return an array of actions ("actions": [{ "tool": "flight" }, { "tool": "hotel" }]). Your orchestrator would then execute the Apify actors via Promise.all(), cutting the waiting time in half and providing a complete itinerary in one response.