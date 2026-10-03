// Initialize
document.addEventListener('DOMContentLoaded', function() {
    initializeNavbar();
    initializeDownloadButtons();
    initializeScrollAnimations();
    initializeDownloadCounter();
    initializeMobileMenu();
});

// Navbar Sticky Behavior
function initializeNavbar() {
    const navbar = document.querySelector('.navbar');
    let lastScrollPosition = 0;

    window.addEventListener('scroll', function() {
        const currentScroll = window.pageYOffset;

        if (currentScroll > 100) {
            navbar.style.boxShadow = '0 2px 15px rgba(0, 0, 0, 0.08)';
        } else {
            navbar.style.boxShadow = 'none';
        }

        lastScrollPosition = currentScroll;
    });

    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            const href = this.getAttribute('href');
            if (href !== '#' && document.querySelector(href)) {
                e.preventDefault();
                const element = document.querySelector(href);
                const offsetTop = element.offsetTop - 70;
                window.scrollTo({ top: offsetTop, behavior: 'smooth' });
            }
        });
    });
}

// Mobile Menu
function initializeMobileMenu() {
    const hamburger = document.querySelector('.hamburger');
    const navMenu = document.querySelector('.nav-menu');
    let menuOpen = false;

    if (hamburger) {
        hamburger.addEventListener('click', function() {
            menuOpen = !menuOpen;
            if (menuOpen) {
                navMenu.style.display = 'flex';
                hamburger.style.gap = '8px';
                hamburger.querySelectorAll('span').forEach((span, index) => {
                    if (index === 0) span.style.transform = 'rotate(45deg) translateY(10px)';
                    else if (index === 1) span.style.opacity = '0';
                    else span.style.transform = 'rotate(-45deg) translateY(-10px)';
                });
            } else {
                navMenu.style.display = 'none';
                hamburger.querySelectorAll('span').forEach(span => {
                    span.style.transform = 'none';
                    span.style.opacity = '1';
                });
            }
        });
    }
}

// Download Button Handler
function initializeDownloadButtons() {
    const downloadButtons = document.querySelectorAll('[data-action="download"]');
    const apkUrl = 'https://github.com/ananbusiness88-hue/Hena/releases/latest/download/hena.apk';
    downloadButtons.forEach(button => {
        button.addEventListener('click', function() {
            window.location.href = apkUrl;
        });
    });
}

// Scroll Animations
function initializeScrollAnimations() {
    const cards = document.querySelectorAll('.fade-in-on-scroll');
    if ('IntersectionObserver' in window) {
        const observer = new IntersectionObserver(function(entries) {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.style.animationPlayState = 'running';
                    observer.unobserve(entry.target);
                }
            });
        }, { threshold: 0.1, rootMargin: '0px 0px -50px 0px' });
        cards.forEach(card => {
            card.style.animationPlayState = 'paused';
            observer.observe(card);
        });
    } else {
        cards.forEach(card => {
            card.style.animation = 'fadeInUp 0.6s ease forwards';
        });
    }
}

// Download Counter
function initializeDownloadCounter() {
    const counterNumber = document.querySelector('.counter-number');
    if (counterNumber) counterNumber.textContent = '669';
}

window.addEventListener('load', function() {
    observeElements();
});

function observeElements() {
    const elements = document.querySelectorAll('[class*="fade"]');
    if ('IntersectionObserver' in window) {
        const observer = new IntersectionObserver(function(entries) {
            entries.forEach(entry => {
                if (entry.isIntersecting) entry.target.style.opacity = '1';
            });
        }, { threshold: 0.1 });
        elements.forEach(el => observer.observe(el));
    }
}