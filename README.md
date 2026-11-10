# Hotline Village

An Animal Crossing-style village where every villager is a live **Vapi** voice agent. Walk up to Maple the cow shopkeeper, Clucky the dramatic chicken or Juniper the dreamy gardener and just talk: **Deepgram nova-3** hears you, an OpenAI model (via Vapi) thinks, and a distinct **Deepgram Aura-2** voice answers. Villagers hand out side quests and seeds, ask for grown crops and planted trees, react in-game (emote bubbles, jumps, spins, dances, bell gifts) through tool calls, and can **go look things up** on the real web with **Exa** (weather, facts, gardening tips) and tell you what they learned in character.

Built for the Vapi "Side Quest Hotline" hackathon. Godot 4.7.2 web build, made with Maneki Engine's Godot skills.

## Run it

1. Export the Godot project to Web (preset uses `web/shell.html` as the custom HTML shell) into `build/web/`.
2. Put your Vapi **public** key in `.env` as `VAPI_API_KEY=...` (gitignored), then:
   ```sh
   scripts/serve.sh            # = python3 scripts/serve.py, http://localhost:8060 (mic needs localhost or https)
   ```
   Add `EXA_API_KEY=...` to `.env` for villager look-ups: `serve.py` proxies `POST /api/exa {query}` to Exa `/answer` and returns `{answer, sources}` trimmed to 2 sentences; the Exa key never reaches the browser. It also writes the key into a gitignored `local-config.js` next to `hotline.js` and copies `web/hotline.js` into `build/web/`.
3. Open http://localhost:8060/build/web/index.html (game) or http://localhost:8060/web/test.html (voice loop alone, with a live event log).

No `.env`? The page asks for the key in a small modal (stored in localStorage), or pass `?vapiKey=...` once.

Deepgram: the browser never sees a Deepgram key. Calls use Vapi's Deepgram unless you link your own key in the Vapi dashboard (Provider Credentials, Deepgram).

## Architecture

```
 Godot (GDScript)                          Browser JS (web/hotline.js)              Vapi cloud
 ----------------                          ---------------------------              ----------
 near NPC  --JavaScriptBridge--> hotline.prewarm(npc)  (SDK + mic warm, config built)
 talk      ----------------------> hotline.start(npc, ctxJson) --Vapi Web SDK (WebRTC)--> Deepgram nova-3 STT
                                                                                         -> OpenAI gpt-4.1-mini
                                                                                         -> Deepgram Aura-2 TTS
 every frame <--- hotline.drain() <-- queue <-- 'message' tool-calls (client tools, async)
                                           <-- transcript / speech-start/end / volume / call status
 quest check ----> hotline.inform("Player now has 3/3 egg.")  (add-message, system role)
 look_up tool  -> fetch /api/exa (scripts/serve.py -> Exa /answer) -> add-message "You looked this up: ..." -> villager says it
 walk away  ----> hotline.stop()
```

The contract between the two halves is `CONTRACT.md`. Tools (`emote`, `animate`, `give_quest`, `complete_quest`, `give_item`, `teach`, `look_up`, `remember`, `follow`, `stay`, `go_to`, `help_farm`, `show_me`, `gift`, `end_conversation`) are client-side function tools with no server URL and `async: true`, so the villager never waits on the game: the call arrives as a `tool-calls` client message and becomes a `{"type":"tool",...}` event for Godot.

## Villagers: teachers with a memory

- **Maple** (cow, Aura-2 `hera`, warm female): shopkeeper who teaches money, trading and cooking.
- **Clucky** (chicken, Aura-2 `apollo`, energetic male): coach who teaches science and nature facts with big reactions.
- **Juniper** (gardener, Aura-2 `cora`, soft female): teaches farming and plants step by step.

They answer in 1-2 short sentences and actually teach: `teach` shows a lesson card (2-4 steps + a fun fact), `look_up` fetches real-world facts via Exa, and every `give_quest` carries a one-sentence `lesson`. Ask them to do things and they do it in the world: `follow`, `stay`, `go_to {place}`, `help_farm {action}`, `show_me {topic}`.

**Memory** lives in the browser (localStorage, one record per villager): the last 12 final transcript lines, facts the villager saved with the `remember` tool, the number of talks, the last quest and recent greetings. Each call puts a short "what you remember about this player" block into the system prompt, along with the quests done from the game's context. Greetings are model-generated (`firstMessageMode: assistant-speaks-first-with-model-generated-message`), at most 10 words, use memory when they can and are told never to repeat an earlier one. Reset with `hotline.forget()` (or `hotline.forget("maple")`) in the console.

## Latency choices

- One small per-villager system prompt (persona + rules + the player's state from `start()`'s context), replies capped at 1-2 short sentences and `maxTokens: 90`.
- The greeting is model-generated so it never repeats; that costs one short model call (≤10 words) before the first audio.
- Transcriber `endpointing: 10` (Deepgram's lowest); `startSpeakingPlan.waitSeconds: 0.2` with transcription endpointing 0.1 s after punctuation; no smart-endpointing model in the path.
- `stopSpeakingPlan` `voiceSeconds: 0.2` so the player can interrupt quickly.
- The SDK is imported as soon as the page loads; the mic permission is requested on the first click or keypress and again by `prewarm()`. `prewarm()` does not start a call (Vapi bills from call start).
- Switching villagers stops the old call and starts the new one; stale events from the old call are dropped.

Measured headless (fake mic) on 2026-11-09: `start()` to `live` 1.2-1.5 s, first greeting audio 0.4-0.6 s after that, a reply with tool calls about 1 s after the player's turn, an Exa look-up about 1.5 s from tool call to answer.

## Credits

- Art: [Sprout Lands](https://cupnooble.itch.io/sprout-lands-asset-pack) by Cup Nooble (free for non-commercial use with credit), and [Kenney](https://kenney.nl) assets (CC0).
- Font: [Fredoka](https://fonts.google.com/specimen/Fredoka) (SIL Open Font License).
- Voice: [Vapi](https://vapi.ai) with [Deepgram](https://deepgram.com) nova-3 and Aura-2. Look-ups: [Exa](https://exa.ai) answer API.
- Built with Maneki Engine's Godot skills.
