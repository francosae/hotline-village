# Hotline Village: shared contract (game <-> voice bridge)

Godot 4.7.2 project at repo root. Web export to `build/web/` with custom HTML shell `web/shell.html`
that loads `web/hotline.js` (Vapi Web SDK, Deepgram STT nova-3 + Deepgram Aura-2 TTS).

## NPC ids (fixed)
- `maple`  : cow shopkeeper, warm, gossipy. Gives fetch quests.
- `clucky` : chicken, hyper and dramatic. Gives fetch quests.
- `juniper`: villager girl (player sprite recolored), dreamy gardener. Gives fetch quests.

## Item ids (fixed enum, collectibles spawned in the world; respawn after pickup)
`egg`, `milk`, `wheat`, `tomato`, `pumpkin`, `wood`, `flower`, `mushroom`

## Godot -> JS (calls on `window.hotline`, via JavaScriptBridge)
- `hotline.hasKey()` -> bool
- `hotline.prewarm(npcId)` : player walked near an NPC; may pre-create the call/assistant to cut latency.
- `hotline.start(npcId, contextJson)` : start talking. contextJson = {"inventory":{"egg":2,...},
  "quests":[{"npc":"maple","item":"egg","count":3,"title":"...","reward":200,"done":false}],
  "bells":123,"items":[...item enum...], "playerName":"Paul"}
- `hotline.stop()` : player walked away / pressed Esc.
- `hotline.inform(text)` : inject a system note mid-call (e.g. "Player now has 3/3 egg.").
- `hotline.drain()` -> JSON string array of queued events (Godot polls every frame).

## JS -> Godot events (from drain())
- `{"type":"status","npc":id,"status":"connecting"|"live"|"ended"|"error","message":"..."}`
- `{"type":"speech","npc":id,"who":"npc"|"player","text":"...","final":true|false}`
- `{"type":"speaking","npc":id,"on":true|false}`   (assistant voice start/stop)
- `{"type":"volume","level":0..1}`
- `{"type":"tool","npc":id,"name":NAME,"args":{...}}` with NAME one of:
  - `emote` {kind: "happy"|"love"|"laugh"|"surprised"|"question"|"angry"|"sad"|"idea"|"music"|"sleepy"}
  - `animate` {kind: "jump"|"spin"|"shake"|"dance"}
  - `give_quest` {item: <item id>, count: 1..5, title: string, reward: int bells}
  - `complete_quest` {item: <item id>}  (game verifies inventory; if short, it informs the agent)
  - `gift` {bells: int}
  - `end_conversation` {}

## Added (round 2)
- Tool `look_up` {query: string}: handled entirely in JS. hotline.js POSTs to the local server `/api/exa` (scripts/serve.py proxies to Exa /answer with EXA_API_KEY from .env; the key never reaches the browser), then injects the answer into the call with `vapi.send({type:'add-message', message:{role:'system', content}, triggerResponseEnabled:true})` so the villager says what they learned. JS also emits:
  `{"type":"lookup","npc":id,"query":"...","status":"start"|"done"|"error","summary":"..."}` -> Godot shows a "Maple is looking it up..." bubble + a book/sparkle emote, then a small "learned" card with the summary.
- Farming (game side): items `seed_tomato`, `seed_wheat`, `sapling`; actions hoe/plant/water/harvest; crops grow through the Basic Plants stages; trees grow from saplings and drop `wood`/fruit. Quests may ask for grown crops (tomato, wheat, pumpkin) and `plant_tree`.
- Tool `give_quest` also accepts item `plant_tree` (count = trees to plant).
- Tool `give_item` {item, count}: villager hands the player seeds/saplings (adds to inventory).
