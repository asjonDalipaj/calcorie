.pragma library

function pad2(n) {
    return n < 10 ? "0" + n : String(n)
}

function todayKey(date) {
    const d = date ?? new Date()
    return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
}

function comma(value) {
    const n = Math.round(Number(value) || 0)
    return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

function clamp(value, min, max) {
    return Math.max(min, Math.min(max, Number(value) || 0))
}

function defaultProfile() {
    return { sex: "neutral", age: 30, height: 175, weight: 70, activity: 1.375, goal: "keep" }
}

function cleanProfile(raw) {
    const fallback = defaultProfile()
    if (!raw || typeof raw !== "object")
        return fallback
    return {
        sex: ["female", "male", "neutral"].indexOf(raw.sex) >= 0 ? raw.sex : fallback.sex,
        age: clamp(raw.age, 14, 100),
        height: clamp(raw.height, 120, 230),
        weight: clamp(raw.weight, 35, 250),
        activity: [1.2, 1.375, 1.55, 1.725].indexOf(Number(raw.activity)) >= 0 ? Number(raw.activity) : fallback.activity,
        goal: ["cut", "keep", "build"].indexOf(raw.goal) >= 0 ? raw.goal : fallback.goal
    }
}

function parseEntries(raw) {
    if (typeof raw !== "string" || raw.length === 0)
        return []
    try {
        const parsed = JSON.parse(raw)
        if (!Array.isArray(parsed))
            return []
        return parsed.filter(e => e && typeof e.name === "string" && Number.isFinite(Number(e.kcal)))
            .map(e => ({
                id: Number(e.id) || Date.now(),
                name: String(e.name).slice(0, 42),
                kcal: Math.max(0, Math.round(Number(e.kcal))),
                at: String(e.at ?? "")
            }))
            .slice(-80)
    } catch (e) {
        return []
    }
}

function parseProfile(raw) {
    if (typeof raw !== "string" || raw.length === 0)
        return defaultProfile()
    try {
        return cleanProfile(JSON.parse(raw))
    } catch (e) {
        return defaultProfile()
    }
}

function bmr(profile) {
    const p = cleanProfile(profile)
    const base = 10 * p.weight + 6.25 * p.height - 5 * p.age
    if (p.sex === "male")
        return base + 5
    if (p.sex === "female")
        return base - 161
    return base - 78
}

function tdee(profile) {
    const p = cleanProfile(profile)
    return bmr(p) * p.activity
}

function suggested(profile) {
    const p = cleanProfile(profile)
    const maintenance = tdee(p)
    const offset = p.goal === "cut" ? -0.16 * maintenance : p.goal === "build" ? 0.10 * maintenance : 0
    return Math.round(clamp(maintenance + offset, 1200, 5000) / 10) * 10
}

function timeLabel(iso) {
    if (!iso)
        return ""
    const d = new Date(iso)
    if (isNaN(d.getTime()))
        return ""
    return pad2(d.getHours()) + ":" + pad2(d.getMinutes())
}
