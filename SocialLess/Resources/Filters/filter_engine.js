"use strict";
// This file only runs in SocialLess's isolated WKContentWorld, in the main frame.
// Never inspect text, inputs, cookies, storage, media, or network responses.
const previous = globalThis.sociallessFilters;
if (!config.probeOnly) {
    if (previous) previous.dispose();
    delete globalThis.sociallessFilters;
}

const trustedHost = host => host === config.domain || host.endsWith("." + config.domain);
const protectedPath = path => {
    try {
        const decoded = decodeURIComponent(path).toLowerCase();
        // Ambiguous/double-encoded paths stay visible rather than guessing their purpose.
        return decoded.includes("%") || decoded.includes("\\") ||
            decoded.split("/").some(part => config.protectedSegments.includes(part));
    } catch { return true; }
};
const allowedDocument = () => {
    if (window !== window.top) return false;
    if (config.mode === "demo") return location.href === "about:blank";
    return location.protocol === "https:" && trustedHost(location.hostname) &&
        (!location.port || location.port === "443") && !protectedPath(location.pathname);
};
if (!allowedDocument()) {
    window.webkit?.messageHandlers.sociallessFilterHealth?.postMessage({
        state: "unavailable", counts: {}, passes: 0, revision: config.revision
    });
    return;
}

let marked = new Set();
let observer = null;
let scheduled = null;
let style = null;
let disposed = false;
let paused = config.paused;
let failed = false;
let passes = 0;
let lastReport = "";

function report(state, counts = {}) {
    const payload = { state, counts, passes, revision: config.revision };
    const signature = JSON.stringify({ state, counts });
    if (signature === lastReport) return;
    lastReport = signature;
    // Only bounded counts, known rule IDs and enum states leave the isolated world.
    window.webkit?.messageHandlers.sociallessFilterHealth?.postMessage(payload);
}
function disconnect() {
    observer?.disconnect();
    observer = null;
    if (scheduled !== null) clearTimeout(scheduled);
    scheduled = null;
}
function restore() {
    for (const element of marked) element.removeAttribute(config.marker);
    marked.clear();
    style?.remove();
    style = null;
}
function stopWithFailure(state = "failed") {
    failed = true;
    disconnect();
    restore();
    report(state);
}
function visible(anchor) {
    return anchor.getClientRects().length > 0 &&
        !["hidden", "collapse"].includes(getComputedStyle(anchor).visibility);
}
function navigationAnchor(anchor, rule) {
    if (anchor.closest('nav, [role="navigation"]')) return true;
    // Fixed, route-gated accessibility hint. Never inspect post text or guess class names.
    return rule.navigationLabel && config.mode === "website" && config.domain === "instagram.com" &&
        (anchor.getAttribute("aria-label")?.trim().toLowerCase() === rule.navigationLabel.toLowerCase() ||
         anchor.querySelector(`svg[aria-label="${rule.navigationLabel}" i]`) !== null);
}
function matches(anchor, rule) {
    if (anchor.closest('form, article, [role="article"], [role="dialog"], [role="alertdialog"]')) return false;
    let url;
    try { url = new URL(anchor.getAttribute("href"), document.baseURI); } catch { return false; }
    if (url.protocol !== "https:" || !trustedHost(url.hostname) || url.username || url.password ||
        (url.port && url.port !== "443") || protectedPath(url.pathname)) return false;
    if (rule.exact) return url.pathname === rule.path || url.pathname === rule.path + "/";
    return url.pathname === rule.path || url.pathname.startsWith(rule.path + "/");
}
function apply() {
    if (disposed || failed) return;
    disconnect();
    if (!allowedDocument()) { restore(); report("unavailable"); return; }
    if (paused) { report("paused"); return; }
    if ((!config.enabled && !config.checking) || config.rules.length === 0) { restore(); report("off"); return; }
    try {
        // The Instagram pilot checks exact destinations before examining navigation semantics.
        // Other rules retain the original navigation-only selector.
        const hasInstagramRule = config.rules.some(rule => rule.navigationLabel);
        const anchors = document.querySelectorAll(hasInstagramRule ? 'a[href]' : 'nav a[href], [role="navigation"] a[href]');
        // Bound per-pass work and retained elements. Overload restores the original page.
        if (anchors.length > 1000) { stopWithFailure(); return; }
        passes = Math.min(passes + 1, 1000000);
        const next = new Set();
        const counts = {};
        let unsupportedVisible = 0;
        let missingRule = false;
        for (const rule of config.rules) {
            const ruleMatches = new Set();
            let unsupportedForRule = 0;
            counts[rule.id] = 0;
            for (const anchor of anchors) {
                if (!matches(anchor, rule)) continue;
                if (!navigationAnchor(anchor, rule)) {
                    // A control can lose its label while hidden by our previous pass.
                    // Restore it before measuring whether unsupported links remain visible.
                    if (marked.has(anchor)) anchor.removeAttribute(config.marker);
                    if (rule.navigationLabel && visible(anchor)) unsupportedForRule++;
                    continue;
                }
                // The one-shot check must find a visible link, not a hidden alternate layout.
                if ((config.checking || (config.automaticCheck && !marked.has(anchor))) && !visible(anchor)) continue;
                counts[rule.id]++;
                ruleMatches.add(anchor);
            }
            unsupportedVisible += unsupportedForRule;
            missingRule ||= Boolean(rule.navigationLabel) && ruleMatches.size === 0;
            // A failing optional rule must not disable another compatible rule.
            if (!config.automaticCheck || !unsupportedForRule || config.checking) {
                for (const anchor of ruleMatches) next.add(anchor);
            }
        }
        if (config.checking) {
            // Checking never marks elements, injects CSS, observes mutations or enables a rule.
            dispose();
            report(next.size ? "ready" : unsupportedVisible ? "unsupportedLayout" : "noMatches", counts);
            return;
        }
        // Remembered consent never skips compatibility: check each document and mutation pass
        // before adding markers. Each incompatible rule leaves its controls unchanged.
        for (const element of marked) if (!next.has(element)) element.removeAttribute(config.marker);
        marked = next;
        if (marked.size) {
            if (!style?.isConnected) {
                style = document.createElement("style");
                style.textContent = `[${config.marker}] { display: none !important; }`;
                (document.head || document.documentElement).appendChild(style);
            }
            for (const element of marked) element.setAttribute(config.marker, "");
            // CSP or conflicting site CSS must fail open, never report false success.
            for (const element of marked) {
                if (getComputedStyle(element).display !== "none") { stopWithFailure("styleBlocked"); return; }
            }
        } else { style?.remove(); style = null; }
        report(unsupportedVisible || missingRule ? (marked.size ? "partial" : unsupportedVisible ? "unsupportedLayout" : "noMatches") : marked.size ? "active" : "noMatches", counts);
        observer = new MutationObserver(() => {
            if (scheduled !== null) return;
            scheduled = setTimeout(() => { scheduled = null; apply(); }, 300);
        });
        // A throttled document observer catches SPA subtree replacement as well as href changes.
        // Site edits to our marker are observed; our own writes happen while disconnected.
        observer.observe(document.documentElement, {
            subtree: true, childList: true, attributes: true,
            attributeFilter: ["href", "role", "aria-label", "hidden", "class", "style", config.marker]
        });
    } catch { stopWithFailure(); }
}
function pageHide() { paused = true; disconnect(); }
function pageShow() { paused = config.paused; apply(); }
function dispose() {
    if (disposed) return;
    disposed = true;
    disconnect();
    restore();
    removeEventListener("pagehide", pageHide);
    removeEventListener("pageshow", pageShow);
}
// An independent read-only probe must not replace, restore or stop the active runtime.
if (config.probeOnly) { apply(); return; }
globalThis.sociallessFilters = {
    dispose,
    diagnostics: () => ({ passes, observing: observer !== null, pending: scheduled !== null, marked: marked.size })
};
addEventListener("pagehide", pageHide);
addEventListener("pageshow", pageShow);
apply();
