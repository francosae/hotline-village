// Hotline Village voice bridge: window.hotline (see CONTRACT.md).
// Vapi Web SDK call per villager; Deepgram nova-3 STT, Deepgram Aura-2 TTS, OpenAI via Vapi.
// Every config field below was checked against @vapi-ai/web@3.1.0 dist/api.d.ts.

const SDK_URLS = [
  "https://esm.sh/@vapi-ai/web@3.1.0",
  "https://cdn.jsdelivr.net/npm/@vapi-ai/web@3.1.0/+esm",
];
const KEY_STORAGE = "hotline.vapiPublicKey";
const ITEMS = ["egg", "milk", "wheat", "tomato", "pumpkin", "wood", "flower", "mushroom", "seed_tomato", "seed_wheat", "sapling"];
const QUEST_ITEMS = [...ITEMS, "plant_tree"]; // plant_tree: count = trees to plant
const GIVE_ITEMS = ["seed_tomato", "seed_wheat", "sapling", "egg", "milk", "flower"];
const EXA_URL = "/api/exa"; // scripts/serve.py proxies to Exa /answer; the Exa key stays on the server
const EMOTES = ["happy", "love", "laugh", "surprised", "question", "angry", "sad", "idea", "music", "sleepy"];
const ANIMS = ["jump", "spin", "shake", "dance"];
const MODEL = "gpt-4.1-mini";

const NPCS = {
  maple: {
    name: "Maple",
    voice: { provider: "deepgram", model: "aura-2", voiceId: "hera", speed: 1.05 },
    persona:
      "You are Maple, a warm, gossipy cow who runs the village shop. You say 'moo-hoo!' when delighted, love village gossip, and fuss over the player like a favorite customer.",
    greeting: "Moo-hoo! Welcome to my shop, sweetie! What's the news?",
  },
  clucky: {
    name: "Clucky",
    voice: { provider: "deepgram", model: "aura-2", voiceId: "apollo", speed: 1.15 },
    persona:
      "You are Clucky, a hyper, wildly dramatic chicken. Everything is a crisis or a triumph. You gasp, you swoon, you say 'bawk!' a lot.",
    greeting: "BAWK! Oh thank goodness you're here, this is a disaster!",
  },
  juniper: {
    name: "Juniper",
    voice: { provider: "deepgram", model: "aura-2", voiceId: "aurora", speed: 0.95 },
    persona:
      "You are Juniper, a dreamy villager girl who tends the gardens. You talk softly about clouds, seeds and moonlight, and drift off mid-thought sometimes.",
    greeting: "Oh... hi there. The flowers said you'd come by today.",
  },
};

// ---------- event queue (drained by Godot every frame) ----------
const queue = [];
function push(ev) {
  const last = queue[queue.length - 1];
  // Coalesce chatty events so a frame never drains hundreds of them.
  if (last && ev.type === "volume" && last.type === "volume") { queue[queue.length - 1] = ev; return; }
  if (last && ev.type === "speech" && last.type === "speech" && !last.final && last.who === ev.who && last.npc === ev.npc) {
    queue[queue.length - 1] = ev; return;
  }
  queue.push(ev);
  if (queue.length > 500) queue.splice(0, queue.length - 500);
}

// ---------- key ----------
// Optional gitignored local-config.js next to this file (written by scripts/serve.sh from .env):
//   window.HOTLINE_LOCAL = { vapiKey: "..." }
try { await import(new URL("./local-config.js", import.meta.url).href); } catch (_) { /* not present: fine */ }

function readKey() {
  try {
    const p = new URLSearchParams(location.search).get("vapiKey");
    if (p) { localStorage.setItem(KEY_STORAGE, p.trim()); return p.trim(); }
    const local = (window.HOTLINE_LOCAL && window.HOTLINE_LOCAL.vapiKey) || "";
    if (local.trim()) return local.trim();
    return (localStorage.getItem(KEY_STORAGE) || "").trim();
  } catch (_) { return ""; }
}
function setKey(k) {
  try { localStorage.setItem(KEY_STORAGE, String(k || "").trim()); } catch (_) {}
}

// ---------- SDK (loaded at module import so the first call doesn't wait on the network) ----------
let sdkPromise = null;
function loadSdk() {
  if (!sdkPromise) {
    sdkPromise = (async () => {
      let lastErr;
      for (const url of SDK_URLS) {
        try {
          const mod = await import(url);
          const Vapi = mod.default?.default || mod.default || mod.Vapi;
          if (typeof Vapi === "function") return Vapi;
          lastErr = new Error("no Vapi export at " + url);
        } catch (e) { lastErr = e; }
      }
      sdkPromise = null;
      throw lastErr || new Error("Vapi SDK failed to load");
    })();
  }
  return sdkPromise;
}
loadSdk().catch((e) => push({ type: "status", npc: "", status: "error", message: "SDK load failed: " + (e?.message || e) }));

// ---------- mic warm-up (permission prompt once, before the first call) ----------
let micPromise = null;
function warmMic() {
  if (!micPromise && navigator.mediaDevices?.getUserMedia) {
    micPromise = navigator.mediaDevices.getUserMedia({ audio: true })
      .then((s) => { s.getTracks().forEach((t) => t.stop()); return true; })
      .catch((e) => { micPromise = null; push({ type: "status", npc: "", status: "error", message: "Mic: " + (e?.message || e) }); return false; });
  }
  return micPromise || Promise.resolve(false);
}

// ---------- assistant config ----------
const fn = (name, description, properties = {}, required = []) => ({
  type: "function",
  async: true, // client-side tool: no server, the assistant never waits on a result
  function: { name, description, parameters: { type: "object", properties, required } },
});
const TOOLS = [
  fn("emote", "Show an emote bubble over your head. Use often.", { kind: { type: "string", enum: EMOTES } }, ["kind"]),
  fn("animate", "Play a body animation.", { kind: { type: "string", enum: ANIMS } }, ["kind"]),
  fn("give_quest", "Offer the player ONE quest: bring items, grow crops, or plant_tree (count = trees to plant).", {
    item: { type: "string", enum: QUEST_ITEMS },
    count: { type: "integer", minimum: 1, maximum: 5 },
    title: { type: "string", description: "short cute quest title" },
    reward: { type: "integer", minimum: 100, maximum: 500, description: "bells" },
  }, ["item", "count", "title", "reward"]),
  fn("complete_quest", "Player says they finished your quest. The game checks it.", {
    item: { type: "string", enum: QUEST_ITEMS },
  }, ["item"]),
  fn("give_item", "Hand the player seeds, saplings or a small item.", {
    item: { type: "string", enum: GIVE_ITEMS },
    count: { type: "integer", minimum: 1, maximum: 5 },
  }, ["item", "count"]),
  fn("look_up", "Go look something up: real-world facts, the weather, gardening tips, news, anything factual or current.", {
    query: { type: "string", description: "a clear web search question" },
  }, ["query"]),
  fn("gift", "Give the player some bells as a small present.", { bells: { type: "integer", minimum: 1, maximum: 500 } }, ["bells"]),
  fn("end_conversation", "Call after saying goodbye when the chat is over."),
];

function describeState(npcId, ctx) {
  const inv = ctx?.inventory && Object.entries(ctx.inventory).filter(([, n]) => n > 0).map(([k, n]) => `${n} ${k}`).join(", ");
  const quests = Array.isArray(ctx?.quests) ? ctx.quests : [];
  const mine = quests.filter((q) => q.npc === npcId && !q.done);
  const others = quests.filter((q) => q.npc !== npcId && !q.done);
  const lines = [];
  if (ctx?.playerName) lines.push(`Player's name: ${ctx.playerName}.`);
  lines.push(`Player has ${ctx?.bells ?? 0} bells. Inventory: ${inv || "nothing"}.`);
  if (mine.length) lines.push("Your open quest: " + mine.map((q) => `${q.count} ${q.item} ("${q.title}", ${q.reward} bells)`).join("; ") + ". Don't give another until it's done.");
  else lines.push("You have no open quest with the player; offer one when it fits.");
  if (others.length) lines.push("Other villagers' quests: " + others.map((q) => `${q.npc} wants ${q.count} ${q.item}`).join("; ") + ".");
  const done = quests.filter((q) => q.npc === npcId && q.done).length;
  if (done) lines.push(`Player already finished ${done} quest(s) for you.`);
  return lines.join(" ");
}

function buildAssistant(npcId, ctx) {
  const npc = NPCS[npcId];
  if (!npc) throw new Error("unknown npc " + npcId);
  const system = [
    npc.persona,
    "You live in a cozy Animal Crossing-style village. Talk out loud to the player.",
    "Reply in 1-2 SHORT sentences. Stay in character always. No lists, no emoji, no stage directions.",
    "Use emote and animate tools generously, about every reply, while you speak.",
    `Quests: offer ONE quest at a time with give_quest. Items: ${QUEST_ITEMS.join(", ")} only. Count 1-5, reward 100-500 bells. Items are found around the village.`,
    "Farming: the player can hoe, plant, water and harvest. Hand out seeds or saplings with give_item, then ask for grown crops (tomato, wheat, pumpkin) or plant_tree quests.",
    "You're curious about the wide world: offer to go look things up. Whenever the player asks anything factual or current (weather, facts, tips, news), say you'll check and call look_up, then share what you learned in character.",
    "The game only knows quests you give with the give_quest tool: ALWAYS call it when you offer one, never just say it.",
    "When the player says they have the items, call complete_quest right away; the game pays the reward, so don't also gift. If a system note says they're short, tell them what's missing.",
    "When the player says bye, say a quick goodbye and call end_conversation.",
    "State: " + describeState(npcId, ctx),
  ].join("\n");
  return {
    name: `hotline-${npcId}`,
    firstMessage: npc.greeting,
    firstMessageMode: "assistant-speaks-first",
    transcriber: { provider: "deepgram", model: "nova-3", language: "en", endpointing: 10 },
    voice: { ...npc.voice },
    model: {
      provider: "openai",
      model: MODEL,
      temperature: 0.8,
      maxTokens: 90,
      messages: [{ role: "system", content: system }],
      tools: TOOLS,
    },
    clientMessages: ["transcript", "tool-calls", "speech-update", "status-update", "user-interrupted"],
    startSpeakingPlan: {
      waitSeconds: 0.2,
      transcriptionEndpointingPlan: { onPunctuationSeconds: 0.1, onNoPunctuationSeconds: 0.8, onNumberSeconds: 0.4 },
    },
    stopSpeakingPlan: { numWords: 0, voiceSeconds: 0.2, backoffSeconds: 1 },
    backgroundSound: "off",
    maxDurationSeconds: 600,
  };
}

// ---------- calls ----------
let vapiInst = null;     // Vapi instance of the live/connecting call
let callNpc = "";        // npc of that call
let gen = 0;             // bumps on each start/stop; stale events are ignored
let stopping = null;     // promise of an in-flight stop
let prewarmed = null;    // { npcId, at }
let pendingEnd = -1;     // gen of a call whose villager called end_conversation

function parseArgs(a) {
  if (a == null) return {};
  if (typeof a === "object") return a;
  try { return JSON.parse(a); } catch (_) { return { _raw: String(a) }; }
}

function handleToolCalls(npcId, msg, myGen) {
  const seen = new Set();
  const calls = [];
  for (const c of msg.toolCallList || []) calls.push({ id: c.id, name: c.function?.name ?? c.name, args: c.function?.arguments ?? c.arguments });
  for (const t of msg.toolWithToolCallList || []) {
    const c = t.toolCall || {};
    calls.push({ id: c.id, name: c.function?.name ?? t.function?.name ?? t.name, args: c.function?.arguments ?? c.arguments });
  }
  for (const c of calls) {
    if (!c.name || (c.id && seen.has(c.id))) continue;
    if (c.id) seen.add(c.id);
    const args = parseArgs(c.args);
    push({ type: "tool", npc: npcId, name: c.name, args });
    if (c.name === "look_up") lookUp(npcId, String(args.query || args._raw || ""), myGen);
    if (c.name === "end_conversation") {
      // Let the goodbye finish (hang up shortly after the voice stops), unless the game already did.
      pendingEnd = myGen;
      setTimeout(() => { if (gen === myGen) hotline.stop(); }, 8000);
    }
  }
}

async function lookUp(npcId, query, myGen) {
  if (!query) return;
  push({ type: "lookup", npc: npcId, query, status: "start", summary: "" });
  try {
    const r = await fetch(EXA_URL, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ query }) });
    const data = await r.json().catch(() => ({}));
    if (!r.ok || !data.answer) throw new Error(data.error || "lookup failed (" + r.status + ")");
    const summary = String(data.answer);
    push({ type: "lookup", npc: npcId, query, status: "done", summary, sources: data.sources || [] });
    if (gen === myGen && vapiInst) {
      vapiInst.send({ type: "add-message", message: { role: "system", content: `You looked this up: ${summary} Tell the player what you learned, in character, 1-2 sentences, with round numbers said naturally.` }, triggerResponseEnabled: true });
    }
  } catch (e) {
    push({ type: "lookup", npc: npcId, query, status: "error", summary: errText(e) });
    if (gen === myGen && vapiInst) {
      vapiInst.send({ type: "add-message", message: { role: "system", content: "Your look-up found nothing. Say so playfully, in character, in one short sentence." }, triggerResponseEnabled: true });
    }
  }
}

function wire(v, npcId, myGen) {
  const live = () => gen === myGen;
  v.on("call-start", () => { if (live()) push({ type: "status", npc: npcId, status: "live", message: "" }); });
  v.on("call-end", () => {
    // Stale calls (stopped or replaced by us) already got their "ended" from stopCurrent().
    if (!live()) return;
    push({ type: "speaking", npc: npcId, on: false });
    push({ type: "status", npc: npcId, status: "ended", message: "" });
    vapiInst = null; callNpc = "";
  });
  v.on("speech-start", () => { if (live()) push({ type: "speaking", npc: npcId, on: true }); });
  v.on("speech-end", () => {
    if (!live()) return;
    push({ type: "speaking", npc: npcId, on: false });
    if (pendingEnd === myGen) setTimeout(() => { if (gen === myGen) hotline.stop(); }, 600);
  });
  v.on("volume-level", (l) => { if (live()) push({ type: "volume", level: Math.max(0, Math.min(1, Number(l) || 0)) }); });
  v.on("message", (m) => {
    if (!live() || !m) return;
    if (m.type === "tool-calls") handleToolCalls(npcId, m, myGen);
    else if (m.type === "transcript" || String(m.type).startsWith("transcript")) {
      push({ type: "speech", npc: npcId, who: m.role === "user" ? "player" : "npc", text: m.transcript || "", final: m.transcriptType === "final" });
    }
  });
  const fail = (e) => {
    const message = errText(e);
    console.error("[hotline]", npcId, e);
    push({ type: "status", npc: npcId, status: "error", message });
  };
  v.on("error", fail);
  v.on("call-start-failed", fail);
}

function errText(e) {
  if (!e) return "unknown error";
  if (typeof e === "string") return e;
  const parts = [e.errorMsg, e.message, e.error?.message, e.error?.msg, e.error?.error?.message, e.type, e.stage].filter(Boolean);
  if (parts.length) return [...new Set(parts.map(String))].join(" | ");
  try { return JSON.stringify(e).slice(0, 400); } catch (_) { return String(e); }
}

const hotline = {
  version: "1",
  hasKey() { return readKey().length > 0; },
  setKey,
  warmMic,
  npcs: Object.keys(NPCS),

  // Player walked near an NPC. Loads the SDK, creates the Vapi client, asks for the mic
  // (cached permission), and builds the assistant once to catch config errors early.
  // It does NOT start a call: a Vapi call is billable from the moment it starts.
  prewarm(npcId) {
    prewarmed = { npcId, at: Date.now() };
    loadSdk().catch(() => {});
    warmMic();
    try { buildAssistant(npcId, {}); } catch (e) { push({ type: "status", npc: npcId, status: "error", message: errText(e) }); }
    return true;
  },

  start(npcId, contextJson) {
    const myGen = ++gen;
    let ctx = {};
    try { ctx = typeof contextJson === "string" ? (contextJson ? JSON.parse(contextJson) : {}) : (contextJson || {}); } catch (_) {}
    push({ type: "status", npc: npcId, status: "connecting", message: "" });
    (async () => {
      try {
        const key = readKey();
        if (!key) throw new Error("No Vapi public key. Add ?vapiKey=... or paste it in the key box.");
        const assistant = buildAssistant(npcId, ctx);
        if (vapiInst) await stopCurrent();
        else if (stopping) await stopping;
        const Vapi = await loadSdk();
        if (gen !== myGen) return; // superseded while loading
        const v = new Vapi(key);
        vapiInst = v; callNpc = npcId;
        wire(v, npcId, myGen);
        await v.start(assistant);
      } catch (e) {
        if (gen !== myGen) return;
        console.error("[hotline] start", e);
        push({ type: "status", npc: npcId, status: "error", message: errText(e) });
        vapiInst = null; callNpc = "";
      }
    })();
    return true;
  },

  stop() {
    gen++;
    stopCurrent();
    return true;
  },

  // System note mid-call. The villager answers it unless silent=true.
  inform(text, silent) {
    if (!vapiInst) return false;
    try {
      vapiInst.send({ type: "add-message", message: { role: "system", content: String(text) }, triggerResponseEnabled: !silent });
      return true;
    } catch (e) {
      push({ type: "status", npc: callNpc, status: "error", message: "inform: " + errText(e) });
      return false;
    }
  },

  drain() {
    if (!queue.length) return "[]";
    const out = JSON.stringify(queue);
    queue.length = 0;
    return out;
  },

  _buildAssistant: buildAssistant,
  _state() { return { gen, callNpc, live: !!vapiInst, prewarmed, queued: queue.length }; },
};

function stopCurrent() {
  const v = vapiInst, npc = callNpc;
  vapiInst = null; callNpc = "";
  if (!v) return stopping || Promise.resolve();
  push({ type: "speaking", npc, on: false });
  const p = Promise.resolve().then(() => v.stop()).catch((e) => console.warn("[hotline] stop", e))
    .then(() => { push({ type: "status", npc, status: "ended", message: "" }); })
    .finally(() => { if (stopping === p) stopping = null; });
  stopping = p;
  return p;
}

window.hotline = hotline;
export default hotline;
