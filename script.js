// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    initNavbar();
    initDownloadCounters();
    document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') {
            renderCounter(loadCounterState());
            refreshDownloadCount();
        }
    });
    initDownloadTracking();
    initImageLoading();
    initScrollAnimations();
    initMobileMenu();
});

// Navbar functionality
function initNavbar() {
    const navbar = document.querySelector('.navbar');
    const window_height = window.innerHeight;

    window.addEventListener('scroll', () => {
        if (window.scrollY > window_height * 0.3) {
            navbar.classList.add('scrolled');
        } else {
            navbar.classList.remove('scrolled');
        }
    });

    // Download button click handlers
    const downloadButtons = document.querySelectorAll('.btn-download');
    downloadButtons.forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.preventDefault();
            const url = btn.getAttribute('data-url');
            window.location.href = url;
        });
    });
}

// Mobile menu toggle
function initMobileMenu() {
    const hamburger = document.getElementById('hamburger');
    const navbarMenu = document.getElementById('navbarMenu');

    if (hamburger) {
        hamburger.addEventListener('click', () => {
            navbarMenu.classList.toggle('active');
        });

        // Close menu when link is clicked
        navbarMenu.querySelectorAll('.nav-link').forEach(link => {
            link.addEventListener('click', () => {
                navbarMenu.classList.remove('active');
            });
        });
    }
}

// ---------------------------------------------------------------------------
//  Download counter
//
//  Every Hena APK is published as a GitHub release asset, and GitHub counts
//  one download for every asset request. The QR code, the navbar button, the
//  hero button and the per-architecture links all end up requesting that
//  very same asset, so this counter already sees EVERY download - there is
//  no way to download the app without going through it.
//
//  We read the real number from the public GitHub API and display it.
//  A small optimistic bump is applied on click so the number reacts
//  immediately (GitHub publishes the updated value with a delay), and the
//  bump is reconciled with the real value as soon as GitHub catches up.
// ---------------------------------------------------------------------------

const HENA_RELEASES_API = 'https://api.github.com/repos/ananbusiness88-hue/Hena/releases?per_page=100';
const HENA_COUNTER_STORAGE = 'hena_download_counter_v1';
// The public GitHub API allows 60 requests/hour per IP - stay well below it.
const HENA_COUNTER_MIN_INTERVAL = 90 * 1000;
// Minimum gap between two requests, so a failing API is never hammered.
const HENA_COUNTER_REQUEST_GAP = 15000;
// Safety net: a broken connection can never inflate the number forever.
const HENA_COUNTER_MAX_PENDING = 50;
// Value shown before the first API read succeeds (kept in sync with the
// number hard-coded in index.html).
const HENA_COUNTER_FALLBACK = 102;

let henaCounterRequest = null;
let henaCounterLastRequestAt = 0;

function loadCounterState() {
    const fallback = { global: HENA_COUNTER_FALLBACK, pending: 0, ts: 0 };

    try {
        const raw = localStorage.getItem(HENA_COUNTER_STORAGE);
        if (!raw) return fallback;

        const parsed = JSON.parse(raw);
        if (!parsed || typeof parsed.global !== 'number') return fallback;

        return {
            global: parsed.global,
            pending: typeof parsed.pending === 'number' ? parsed.pending : 0,
            ts: typeof parsed.ts === 'number' ? parsed.ts : 0
        };
    } catch (error) {
        // Storage can be unavailable (private mode / disabled cookies).
        return fallback;
    }
}

function saveCounterState(state) {
    try {
        localStorage.setItem(HENA_COUNTER_STORAGE, JSON.stringify(state));
    } catch (error) {
        // Ignore: the counter still works for the current page view.
    }
}

function formatCounter(value) {
    return Number(value || 0).toLocaleString('ar-EG');
}

function renderCounter(state) {
    const counterElement = document.getElementById('download-count');
    if (!counterElement) return;

    const total = state.global + state.pending;

    counterElement.textContent = formatCounter(total);
    counterElement.setAttribute('data-count', String(total));
    counterElement.setAttribute('aria-label', 'عدد مرات تحميل التطبيق: ' + formatCounter(total));
    counterElement.title = state.pending > 0
        ? 'عدد التنزيلات الفعلي - جارٍ التحديث من GitHub'
        : 'عدد التنزيلات الفعلي للتطبيق';
}

// Sums the download counter GitHub keeps for every APK it published.
async function fetchRemoteCount() {
    const response = await fetch(HENA_RELEASES_API, {
        headers: { Accept: 'application/vnd.github+json' }
    });

    if (!response.ok) {
        throw new Error('GitHub API responded with HTTP ' + response.status);
    }

    const releases = await response.json();
    let total = 0;

    for (const release of releases) {
        for (const asset of release.assets || []) {
            if (/\.apk$/i.test(asset.name)) {
                total += Number(asset.download_count) || 0;
            }
        }
    }

    return total;
}

// Reads the real download number and reconciles it with the optimistic bump.
function refreshDownloadCount(options) {
    const force = !!(options && options.force);
    const state = loadCounterState();
    const now = Date.now();

    if (henaCounterRequest) return;

    if (!force && now - state.ts < HENA_COUNTER_MIN_INTERVAL) return;
    if (now - henaCounterLastRequestAt < HENA_COUNTER_REQUEST_GAP) return;

    henaCounterLastRequestAt = now;

    henaCounterRequest = fetchRemoteCount()
        .then((value) => {
            const current = loadCounterState();
            const hasRemoteValue = current.ts > 0;
            const delta = Math.max(0, value - current.global);

            // GitHub caught up with (part of) the clicks counted locally.
            current.pending = Math.max(0, current.pending - delta);
            // The first real reading replaces the fallback value, later
            // readings never let the counter go backwards.
            current.global = hasRemoteValue ? Math.max(current.global, value) : value;
            current.ts = Date.now();

            saveCounterState(current);
            renderCounter(current);
        })
        .catch((error) => {
            // Keep showing the last known number instead of breaking the page.
            const current = loadCounterState();
            renderCounter(current);

            const counterElement = document.getElementById('download-count');
            if (counterElement) {
                counterElement.title = 'تعذّر تحديث عدد التنزيلات - الرقم المعروض هو آخر عدد معروف';
            }
        })
        .finally(() => {
            henaCounterRequest = null;
        });
}

function initDownloadCounters() {
    renderCounter(loadCounterState());
    refreshDownloadCount();
}

// One delegated listener covers every download entry point: the navbar and
// hero buttons (data-url), the QR link and the per-architecture links
// (href). It only bumps the number locally - GitHub does the real counting
// when the asset is requested.
function initDownloadTracking() {
    document.addEventListener('click', (event) => {
        const target = event.target;
        if (!target || !target.closest) return;

        const element = target.closest('a[href], button[data-url]');
        if (!element) return;

        const url = element.getAttribute('href') || element.getAttribute('data-url') || '';
        if (!/\/releases\/(latest\/)?download\//.test(url)) return;

        const state = loadCounterState();
        state.pending = Math.min(HENA_COUNTER_MAX_PENDING, state.pending + 1);
        saveCounterState(state);
        renderCounter(state);

        // GitHub publishes the new value with a delay - re-read shortly after.
        setTimeout(() => refreshDownloadCount({ force: true }), 4000);
    }, true);
}

// Image loading with error handling
function initImageLoading() {
    const images = document.querySelectorAll('img');

    images.forEach(img => {
        img.addEventListener('load', () => {
            img.classList.add('loaded');
        });

        // Fallback if image is already cached
        if (img.complete) {
            img.classList.add('loaded');
        }

        // Error handling
        img.addEventListener('error', () => {
            // Gracefully handle missing images
            img.style.opacity = '0.3';
        });
    });
}

// Scroll-triggered animations
function initScrollAnimations() {
    const observerOptions = {
        threshold: 0.15,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
            }
        });
    }, observerOptions);

    document.querySelectorAll('.fade-in-scroll').forEach(el => {
        observer.observe(el);
    });
}

// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', (e) => {
        const href = anchor.getAttribute('href');
        if (href !== '#') {
            e.preventDefault();
            const target = document.querySelector(href);
            if (target) {
                const offset = 100;
                const targetPosition = target.offsetTop - offset;
                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        }
    });
});

// Keyboard navigation support
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        const navbarMenu = document.getElementById('navbarMenu');
        if (navbarMenu) {
            navbarMenu.classList.remove('active');
        }
    }
});
