'use strict';
if (globalThis.sociallessFollowing?.owner === config.owner && globalThis.sociallessFollowing.refresh(config.revision)) return;
globalThis.sociallessFollowing?.dispose();
delete globalThis.sociallessFollowing;
if (window !== window.top) return;
const allowed = new Set(config.accounts);
const ownedInert = new Set();
const measuredMedia = new WeakSet();
const approved = new Set();
let seen = new WeakSet(), initialized = false, batchTimer = null, exhausted = false;
const pendingBatch = new Set();
function cancelBatch() {
    if (batchTimer !== null) clearTimeout(batchTimer);
    batchTimer = null; pendingBatch.clear();
}
function settleBatch() {
    batchTimer = null;
    if (disposed || exhausted || !home()) { pendingBatch.clear(); return; }
    const connected = [...pendingBatch].filter(node => node.isConnected);
    pendingBatch.clear();
    if (!connected.length || connected.some(node => approved.has(node))) return;
    exhausted = true;
    observer?.disconnect();
    report('exhausted', marked.size, lastUnknown);
}
let lastUnknown = 0;
const approvedMarker = config.marker + '-allowed';
const candidates = 'main article, main [role="article"], [role="main"] article, [role="main"] [role="article"]';
const interactionEvents = ['click', 'auxclick', 'dblclick', 'contextmenu', 'pointerdown', 'pointerup', 'touchstart', 'touchend'];
function release(node) {
    node.removeAttribute(config.marker);
    if (ownedInert.delete(node)) node.removeAttribute('inert');
}
function blockHiddenInteraction(event) {
    if (disposed || !home() || !marked.size) return;
    const path = event.composedPath();
    const target = path.find(node => node instanceof Element);
    // Do not intercept controls in a foreground dialog or navigation surface.
    if (target?.closest('nav, form, [role="dialog"]')) return;
    if (!path.some(node => marked.has(node))) return;
    event.stopImmediatePropagation();
    // Leave native touch/pointer defaults intact so a swipe can still scroll.
    if (['click', 'auxclick', 'dblclick', 'contextmenu'].includes(event.type)) event.preventDefault();
}
for (const type of interactionEvents) window.addEventListener(type, blockHiddenInteraction, {capture: true, passive: false});
let marked = new Set(), observer = null, timer = null, style = null, disposed = false, lastReport = null;
function report(state, hidden = 0, unknown = 0) {
    const payload = {revision: config.revision, state, hidden, unknown};
    const key = JSON.stringify(payload);
    if (key === lastReport) return;
    lastReport = key;
    window.webkit.messageHandlers.followingHealth.postMessage(payload);
}
function home() {
    const u = new URL(location.href);
    return u.protocol === 'https:' && !u.username && !u.password && (!u.port || u.port === '443') &&
        (u.hostname === 'instagram.com' || u.hostname.endsWith('.instagram.com')) && u.pathname === '/' && !u.search;
}
function firstPartyURL(a) {
    try {
        const u = new URL(a.getAttribute('href'), location.href);
        return u.protocol === 'https:' && !u.username && !u.password && (!u.port || u.port === '443') &&
            (u.hostname === 'instagram.com' || u.hostname.endsWith('.instagram.com')) ? u : null;
    } catch (_) { return null; }
}
function profileName(a) {
    const u = firstPartyURL(a);
    if (!u) return null;
    const match = u.pathname.match(/^\/([A-Za-z0-9_][A-Za-z0-9_.]{0,29})\/?$/);
    if (!match) return null;
    const name = match[1].toLowerCase();
    if (['explore', 'reels', 'direct', 'stories', 'accounts', 'about', 'legal', 'privacy', 'settings'].includes(name)) return null;
    // No body/caption scanning for names; the profile link must name itself.
    return a.textContent.trim().toLowerCase() === name ? name : null;
}
function before(node, media) {
    return !node.contains(media) && !!(node.compareDocumentPosition(media) & Node.DOCUMENT_POSITION_FOLLOWING);
}
function classify(article) {
    // Semantic article boundaries remain mandatory. These are candidate layouts, not captured site markup.
    if (article.parentElement?.closest('article, [role="article"]') || article.closest('nav, form, [role="dialog"]')) return null;
    const headers = article.querySelectorAll('header');
    if (headers.length > 1) return null;
    const links = article.querySelectorAll('a[href]');
    const mediaNodes = article.querySelectorAll('img, video');
    if (links.length > 100 || mediaNodes.length > 100) return null;
    const media = [...mediaNodes].find(node => {
        if (node.closest('header, footer, nav, form, [role="dialog"]')) return false;
        const box = node.getBoundingClientRect();
        if (box.width >= 120 && box.height >= 120) { measuredMedia.add(node); return true; }
        // Percentage-sized media may shrink with its collapsed parent. Reuse only the
        // same previously measured node; author links are still re-evaluated every pass.
        return marked.has(article) && measuredMedia.has(node);
    });
    const hasPermalink = [...links].some(a => {
        const u = firstPartyURL(a);
        return u && /^\/(p|reel)\/[A-Za-z0-9_-]+\/?$/.test(u.pathname);
    });
    // Header layouts may use a plain permalink; ads/unmarked layouts may only expose media.
    if (!hasPermalink && !media) return null;
    if (!headers.length && !media) return null;
    const region = headers[0] || article;
    function inAuthorArea(node) {
        if (node.closest('footer, nav, form, p, figcaption, blockquote, [role="dialog"]')) return false;
        return headers.length ? region.contains(node) : before(node, media);
    }
    const names = new Set();
    for (const a of region.querySelectorAll('a[href]')) {
        if (!inAuthorArea(a)) continue;
        const name = profileName(a);
        if (name) names.add(name);
    }
    // Exact short badges in the author area only; captions and profile names are never ad labels.
    const labels = region.querySelectorAll('span, a, button, div');
    let sponsored = false;
    if (labels.length <= 200) {
        for (const label of labels) {
            if (!inAuthorArea(label) || label.childElementCount !== 0) continue;
            const link = label.closest('a[href]');
            if (link && profileName(link)) continue;
            const value = (label.getAttribute('aria-label') || label.textContent).trim().toLowerCase();
            if (['sponsored', 'publicidad', 'patrocinado', 'patrocinada'].includes(value)) { sponsored = true; break; }
        }
    }
    if (sponsored) return {name: null, sponsored: true};
    return names.size === 1 ? {name: [...names][0], sponsored: false} : null;
}
function restore() {
    for (const node of marked) release(node);
    marked.clear();
    for (const node of approved) node.removeAttribute(approvedMarker);
    approved.clear(); style?.remove(); style = null;
}
function dispose() {
    disposed = true; cancelBatch(); observer?.disconnect(); observer = null;
    for (const type of interactionEvents) window.removeEventListener(type, blockHiddenInteraction, true);
    // Pending microtasks check disposed before touching the document.
    timer = null; restore();
}
function schedule() {
    if (disposed || exhausted || timer !== null) return;
    // MutationObserver runs before rendering; classify additions without a visible debounce window.
    timer = true;
    queueMicrotask(() => { timer = null; if (!disposed) apply(); });
}
function apply() {
    if (disposed || exhausted) return;
    observer?.disconnect();
    try {
        if (!home()) { cancelBatch(); initialized = false; seen = new WeakSet(); restore(); report('outside'); return; }
        const posts = document.querySelectorAll(candidates);
        if (posts.length > 500) throw new Error('limit');
        // Collapse the outer card only. Descendant media remains measurable without unhiding.
        let recognized = 0, unknown = 0;
        const next = new Set(), nextApproved = new Set();
        let additions = false;
        for (const post of posts) {
            // Do not filter nested articles, hidden dialogs or content the website already hid.
            if (post.getClientRects().length === 0 || post.parentElement?.closest('article, [role="article"]') || post.closest('nav, form, [role="dialog"]')) continue;
            if (!seen.has(post)) {
                seen.add(post);
                if (initialized) { pendingBatch.add(post); additions = true; }
            }
            const result = classify(post);
            if (!result) { unknown++; next.add(post); continue; }
            recognized++;
            if (result.sponsored || !allowed.has(result.name)) next.add(post);
            else nextApproved.add(post);
        }
        for (const node of marked) if (!next.has(node)) release(node);
        marked = next;
        for (const node of approved) if (!nextApproved.has(node)) node.removeAttribute(approvedMarker);
        approved.clear();
        for (const node of nextApproved) {
            if (!node.hasAttribute(approvedMarker)) node.setAttribute(approvedMarker, '');
            approved.add(node);
        }
        {
            if (!style?.isConnected) {
                style = document.createElement('style');
                const pending = ':is(' + candidates + '):not([' + approvedMarker + '])' +
                    ':not(nav *, form *, [role="dialog"] *, article article, article [role="article"], [role="article"] article, [role="article"] [role="article"])';
                style.textContent = pending + ' { visibility: hidden !important; }' + '[' + config.marker + '], [' + config.marker + '] * { visibility: hidden !important; pointer-events: none !important; }' +
                    '[' + config.marker + '] { opacity: 0 !important; height: 0 !important; min-height: 0 !important; max-height: 0 !important;' +
                    ' block-size: 0 !important; min-block-size: 0 !important; max-block-size: 0 !important;' +
                    ' margin-top: 0 !important; margin-bottom: 0 !important; padding-top: 0 !important; padding-bottom: 0 !important;' +
                    ' border-top-width: 0 !important; border-bottom-width: 0 !important; overflow: hidden !important; }';
                (document.head || document.documentElement).appendChild(style);
            }
            for (const node of marked) {
                if (!node.hasAttribute(config.marker)) node.setAttribute(config.marker, '');
                if (!node.hasAttribute('inert')) { node.setAttribute('inert', ''); ownedInert.add(node); }
            }
            if ([...marked].some(node => getComputedStyle(node).visibility !== 'hidden' || getComputedStyle(node).opacity !== '0')) {
                dispose(); report('styleBlocked'); return;
            }
        }
        initialized = true;
        lastUnknown = unknown;
        if (additions) {
            if (batchTimer !== null) clearTimeout(batchTimer);
            batchTimer = setTimeout(settleBatch, 500);
        }
        report(!recognized ? 'unsupported' : unknown ? 'partial' : 'active', marked.size, unknown);
        observer ??= new MutationObserver(schedule);
        observer.observe(document.documentElement, {subtree: true, childList: true, characterData: true,
            attributes: true, attributeFilter: ['href', 'role', 'class', 'style', 'hidden', 'inert', config.marker]});
    } catch (_) { dispose(); report('failed'); }
}
function refresh(revision) {
    if (disposed) return false;
    config.revision = revision;
    if (exhausted) { report('exhausted', marked.size, lastUnknown); return true; }
    apply();
    return true;
}
globalThis.sociallessFollowing = {owner: config.owner, refresh, dispose};
apply();
