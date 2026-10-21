// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    initNavbar();
    initDownloadCounters();
    document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') {
            initDownloadCounters();
        }
    });
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

// Download counter initialization
let henaCounterFetchInFlight = false;
let henaCounterLastFetchAt = 0;

async function initDownloadCounters() {
    const counterElement = document.getElementById('download-count');
    if (!counterElement) return;

    const now = Date.now();
    if (henaCounterFetchInFlight || now - henaCounterLastFetchAt < 5000) return;

    henaCounterFetchInFlight = true;
    henaCounterLastFetchAt = now;

    const apiBase = 'https://api.github.com/repos/ananbusiness88-hue/Hena/releases';
    counterElement.title = 'جارٍ تحديث عدد التنزيلات الفعلي';

    try {
        let totalDownloads = 0;
        let page = 1;

        while (true) {
            const response = await fetch(
                `${apiBase}?per_page=100&page=${page}`,
                { cache: 'no-store' }
            );

            if (!response.ok) {
                throw new Error(`GitHub API returned HTTP ${response.status}`);
            }

            const releases = await response.json();

            for (const release of releases) {
                for (const asset of (release.assets || [])) {
                    if (asset.name.toLowerCase() === 'hena.apk') {
                        totalDownloads += Number(asset.download_count) || 0;
                    }
                }
            }

            if (releases.length < 100) break;
            page += 1;
        }

        counterElement.textContent = totalDownloads.toLocaleString('ar-EG');
        counterElement.title = 'إجمالي التنزيلات المسجلة لملفات hena.apk على GitHub؛ يتحدث عند فتح الصفحة والعودة إليها';
        counterElement.setAttribute(
            'aria-label',
            `إجمالي تنزيلات التطبيق: ${totalDownloads}`
        );
    } catch (error) {
        console.error('تعذر تحميل عداد تنزيلات هِنا:', error);
        if (!counterElement.textContent || counterElement.textContent === '…') {
            counterElement.textContent = '—';
        }
        counterElement.title = 'تعذر تحديث عدد التنزيلات الفعلي حاليًا';
    } finally {
        henaCounterFetchInFlight = false;
    }
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