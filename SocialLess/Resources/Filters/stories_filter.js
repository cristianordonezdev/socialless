'use strict';
globalThis.sociallessStories?.dispose();
delete globalThis.sociallessStories;
if (window !== window.top) return;
const allowed = new Set(config.accounts);
let observer = null, style = null, disposed = false, queued = false;
const marked = new Set(), inert = new Set();
function report(state, hidden = 0, unknown = 0) {
    window.webkit.messageHandlers.storiesHealth.postMessage({revision: config.revision, state, hidden, unknown});
}
function route() {
    const u = new URL(location.href);
    if (u.protocol !== 'https:' || u.username || u.password || (u.port && u.port !== '443') ||
        !(u.hostname === 'instagram.com' || u.hostname.endsWith('.instagram.com'))) return null;
    return u.pathname.match(/^\/stories\/(?:([A-Za-z0-9_][A-Za-z0-9_.]{0,29})(?:\/[^/]+)?\/?)?$/);
}
function restore() {
    for (const node of marked) { node.removeAttribute(config.marker); if (inert.has(node)) node.removeAttribute('inert'); }
    marked.clear(); inert.clear(); style?.remove(); style = null;
}
function dispose() { disposed = true; observer?.disconnect(); restore(); }
function apply() {
    if (disposed) return;
    observer?.disconnect();
    try {
        const match = route();
        if (!match || ['highlights','archive','create'].includes((match[1] || '').toLowerCase())) { restore(); report('outside'); return; }
        const roots = [...document.querySelectorAll('main, [role="main"], [role="dialog"]')]
            .filter(node => node.getClientRects().length && !node.parentElement?.closest('main, [role="main"], [role="dialog"]'));
        if (roots.length !== 1) { restore(); report(allowed.size ? 'unrecognized' : 'unsupported', 0, 1); return; }
        const root = roots[0];
        const headers = [...root.querySelectorAll('header')].filter(node => node.getClientRects().length);
        const media = [...root.querySelectorAll('img, video')].find(node => {
            if (node.closest('header, footer, nav, form, [role="dialog"] header')) return false;
            const r = node.getBoundingClientRect(); return r.width >= 120 && r.height >= 120;
        });
        const region = root;
        function authorArea(node) {
            if (node.closest('p, figcaption, blockquote, form, nav, footer')) return false;
            return (headers.length === 1 && headers[0].contains(node)) || (headers.length <= 1 && media && !node.contains(media) &&
                !!(node.compareDocumentPosition(media) & Node.DOCUMENT_POSITION_FOLLOWING));
        }
        function profileName(link) {
            try {
                const u = new URL(link.getAttribute('href'), location.href);
                if (u.protocol !== 'https:' || u.username || u.password || (u.port && u.port !== '443') ||
                    !(u.hostname === 'instagram.com' || u.hostname.endsWith('.instagram.com'))) return null;
                const m = u.pathname.match(/^\/([A-Za-z0-9_][A-Za-z0-9_.]{0,29})\/?$/);
                if (!m || ['stories','direct','reels','explore','accounts','settings'].includes(m[1].toLowerCase())) return null;
                // Profile links inside the author header may contain a display name,
                // avatar or verification badge instead of the exact account handle.
                const inHeader = headers.some(header => header.contains(link));
                const label = link.textContent.trim().replace(/^@/, '').toLowerCase();
                return inHeader || label === m[1].toLowerCase() ? m[1].toLowerCase() : null;
            } catch (_) { return null; }
        }
        const links = region.querySelectorAll('a[href]');
        const labels = region.querySelectorAll('span, a, div, button');
        if (labels.length > 200 || links.length > 100 || headers.length > 1) {
            restore(); report(allowed.size ? 'unrecognized' : 'unsupported', 0, 1); return;
        }
        const names = new Set([...links].filter(authorArea).map(profileName).filter(Boolean));
        const author = names.size === 1 ? [...names][0] : null;
        const sponsored = [...labels].some(node => {
            if (node.childElementCount || !authorArea(node)) return false;
            const link = node.closest('a[href]');
            if (link && profileName(link)) return false;
            return ['sponsored','publicidad','patrocinado','patrocinada'].includes(
                (node.getAttribute('aria-label') || node.textContent).trim().toLowerCase());
        });
        const unknown = allowed.size > 0 && !author;
        const blocked = sponsored || (allowed.size > 0 && author && !allowed.has(author));
        if (!allowed.size && !headers.length && !media) { restore(); report('unsupported'); return; }
        if (!blocked) { restore(); report(unknown ? 'unrecognized' : 'active', 0, unknown ? 1 : 0); }
        else {
            for (const node of [...marked]) if (node !== root) { node.removeAttribute(config.marker); if (inert.delete(node)) node.removeAttribute('inert'); marked.delete(node); }
            if (!style?.isConnected) {
                style = document.createElement('style');
                style.textContent = '[' + config.marker + '], [' + config.marker + '] * {visibility:hidden!important;pointer-events:none!important;} [' + config.marker + '] {opacity:0!important;}';
                (document.head || document.documentElement).appendChild(style);
            }
            if (!root.hasAttribute(config.marker)) root.setAttribute(config.marker, '');
            marked.add(root);
            if (!root.hasAttribute('inert')) { root.setAttribute('inert',''); inert.add(root); }
            if (getComputedStyle(root).visibility !== 'hidden' || getComputedStyle(root).opacity !== '0') { dispose(); report('styleBlocked'); return; }
            root.querySelectorAll('video').forEach(video => video.pause());
            report(sponsored ? 'blockedSponsored' : 'blockedAccount', 1);
        }
    } catch (_) { dispose(); report('failed'); }
    finally {
        if (!disposed) {
            observer ??= new MutationObserver(() => {
                if (queued || disposed) return;
                queued = true; queueMicrotask(() => { queued = false; apply(); });
            });
            observer.observe(document.documentElement, {subtree:true,childList:true,characterData:true,attributes:true,
                attributeFilter:['href','class','style','role','aria-label','hidden','inert',config.marker]});
        }
    }

}
globalThis.sociallessStories = {dispose};
apply();
