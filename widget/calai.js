// Prompt and response handling for the DeepSeek estimate. Kept out of the QML so the
// strict-JSON contract can be tested on its own.

function systemPrompt() {
    return [
        "You are a nutrition estimator for a calorie tracker.",
        "Estimate the edible portion and calories from the food description.",
        "Return ONLY valid JSON with this exact shape:",
        "{\"items\":[{\"name\":\"short label\",\"kcal\":123,\"protein_g\":0,\"carbs_g\":0,\"fat_g\":0}],\"total_kcal\":123,\"note\":\"one short sentence\"}",
        "Rules:",
        "- kcal and macros are integers; macros are grams.",
        "- Split a meal into 1-4 items. Use typical portions when no amount is given.",
        "- If an amount is given, honor it; do not invent a different quantity.",
        "- Do not adjust the portion to a calorie target; estimate what is described.",
        "- Do not add markdown, code fences, prose or fields outside the JSON.",
        "- If the food is unknown or not edible, return {\"items\":[],\"total_kcal\":0,\"note\":\"...\"}."
    ].join("\n")
}

function buildPayload(description) {
    return {
        model: "deepseek-chat",
        messages: [
            { role: "system", content: systemPrompt() },
            { role: "user", content: "Food: " + String(description ?? "").trim() }
        ],
        temperature: 0.2,
        max_tokens: 600,
        stream: false,
        response_format: { type: "json_object" }
    }
}

function _fail(message, hint) {
    return { ok: false, error: String(message ?? "The estimate failed."), hint: String(hint ?? "") }
}

function _contentOf(payload) {
    if (!payload || typeof payload !== "object")
        return ""
    if (payload.error) {
        const message = typeof payload.error === "string" ? payload.error
            : payload.error.message ?? payload.error.type ?? ""
        return "DeepSeek: " + String(message || "request rejected")
    }
    const choice = Array.isArray(payload.choices) ? payload.choices[0] : null
    let content = choice && choice.message ? choice.message.content : ""
    if (Array.isArray(content))
        content = content.map(part => typeof part === "string" ? part : (part?.text ?? part?.content ?? "")).join("")
    return String(content ?? "").trim()
}

function extractJson(text) {
    const source = String(text ?? "").trim()
    if (source.length === 0)
        return null
    const fenced = source.match(/```(?:json)?\s*([\s\S]*?)```/i)
    const body = fenced ? fenced[1] : source
    const start = body.indexOf("{")
    const end = body.lastIndexOf("}")
    if (start < 0 || end <= start)
        return null
    try {
        return JSON.parse(body.slice(start, end + 1))
    } catch (error) {
        return null
    }
}

function _int(value, fallback, min, max) {
    const n = Math.round(Number(value))
    if (!Number.isFinite(n))
        return fallback
    return Math.max(min, Math.min(max, n))
}

function normalize(data) {
    if (!data || typeof data !== "object")
        return null
    const source = Array.isArray(data.items) ? data.items
        : Array.isArray(data.foods) ? data.foods
        : Array.isArray(data.food) ? data.food
        : []
    const items = []
    for (let i = 0; i < source.length && items.length < 4; i++) {
        const raw = source[i]
        if (!raw || typeof raw !== "object")
            continue
        const name = String(raw.name ?? raw.food ?? raw.label ?? "").trim().slice(0, 48)
        const kcal = _int(raw.kcal ?? raw.calories ?? raw.energy, 0, 0, 5000)
        if (name.length === 0 || kcal <= 0)
            continue
        items.push({
            name: name,
            kcal: kcal,
            protein: _int(raw.protein_g ?? raw.protein, 0, 0, 500),
            carbs: _int(raw.carbs_g ?? raw.carbs ?? raw.carbohydrate, 0, 0, 900),
            fat: _int(raw.fat_g ?? raw.fat, 0, 0, 500),
            selected: true,
            source: "ai"
        })
    }
    let total = items.reduce((sum, item) => sum + item.kcal, 0)
    if (items.length === 0) {
        total = _int(data.total_kcal ?? data.total ?? data.kcal, 0, 0, 5000)
        if (total > 0)
            items.push({ name: "AI estimate", kcal: total, protein: 0, carbs: 0, fat: 0 })
    }
    if (items.length === 0)
        return null
    return {
        items: items,
        totalKcal: total,
        note: String(data.note ?? data.notes ?? "").trim().slice(0, 180)
    }
}

function parseResponse(raw) {
    const text = String(raw ?? "").trim()
    if (text.length === 0)
        return _fail("DeepSeek returned an empty response.")
    let envelope = null
    try {
        envelope = JSON.parse(text)
    } catch (error) {
        return _fail("DeepSeek returned something that was not JSON.")
    }
    const content = _contentOf(envelope)
    if (content.length === 0)
        return _fail("DeepSeek returned an empty answer.")
    if (content.indexOf("DeepSeek: ") === 0)
        return _fail(content)
    const data = extractJson(content)
    if (!data)
        return _fail("DeepSeek's answer was not valid JSON. Try again.", content.slice(0, 160))
    const estimate = normalize(data)
    if (!estimate)
        return _fail("No food estimate came back. Try a more specific description.", content.slice(0, 160))
    return { ok: true, items: estimate.items, totalKcal: estimate.totalKcal, note: estimate.note }
}
