.pragma library

// ============================================================
// Index helpers
// ============================================================
function clampIndex(i, l) { return l <= 0 ? 0 : Math.max(0, Math.min(l - 1, i)) }
function selectProfileIndex(i, d, p) { var v = Array.isArray(p) ? p : []; return v.length === 0 ? 0 : clampIndex(i + d, v.length) }
function clamp(v, mn, mx) { return Math.max(mn, Math.min(mx, v)) }
