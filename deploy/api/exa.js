// Vercel function: same as scripts/serve.py's /api/exa. The Exa key stays server-side (env EXA_API_KEY).
function short(text, sentences = 2, limit = 320) {
  text = (text || "").replace(/\[\d+\]|\*\*|__|#+ /g, "").replace(/\s+/g, " ").trim().replace(/\s+([.,!?;:])/g, "$1");
  let out = text.split(/(?<=[.!?])\s+/).slice(0, sentences).join(" ").trim();
  if (out.length > limit) out = out.slice(0, limit - 1).replace(/\s+\S*$/, "") + "…";
  return out;
}

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(404).json({ error: "not found" });
  const key = process.env.EXA_API_KEY;
  if (!key) return res.status(500).json({ error: "EXA_API_KEY not set" });
  let body = req.body;
  if (typeof body === "string") { try { body = JSON.parse(body); } catch { return res.status(400).json({ error: "bad json" }); } }
  const query = String(body?.query || "").trim().slice(0, 300);
  if (!query) return res.status(400).json({ error: "query required" });
  try {
    const r = await fetch("https://api.exa.ai/answer", {
      method: "POST",
      headers: { "x-api-key": key, "Content-Type": "application/json" },
      body: JSON.stringify({ query, text: false }),
    });
    if (!r.ok) return res.status(502).json({ error: `exa ${r.status}: ${(await r.text()).slice(0, 300)}` });
    const data = await r.json();
    const answer = typeof data.answer === "string" ? data.answer : data.answer != null ? JSON.stringify(data.answer) : "";
    const sources = (data.citations || []).slice(0, 3).map((c) => ({ title: c.title || c.url || "", url: c.url || "" }));
    return res.status(200).json({ answer: short(answer), sources });
  } catch (e) {
    return res.status(502).json({ error: `exa: ${e}` });
  }
}
