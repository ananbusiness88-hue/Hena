// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    initNavbar();
    initDownloadCounters();
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
function initDownloadCounters() {
    const counterElement = document.getElementById('download-count');
    if (counterElement) {
        const initialCount = 669;
        counterElement.textContent = initialCount.toLocaleString('ar-EG');
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