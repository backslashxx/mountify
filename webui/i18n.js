let currentLocale = 'en';
let translations = {};
let fallbackLocale = 'en';


export async function init(locale = null) {
    const savedLocale = localStorage.getItem('locale');
    const browserLocale = navigator.language || navigator.userLanguage;
    
    currentLocale = locale || savedLocale || browserLocale || fallbackLocale;
    
    // 'en-us' -> 'en'
    currentLocale = normalizeLocale(currentLocale);
    
    await loadTranslations(currentLocale);
    updatePageText();
}

export function getAvailableLocales() {
    return [
        { code: 'en', name: 'English' },
        { code: 'zh-CN', name: '简体中文' },
        { code: 'zh-TW', name: '繁體中文（台灣）' },
        { code: 'zh-HK', name: '繁體中文（香港）' }
    ];
}

function normalizeLocale(locale) {
    const map = {
        'zh': 'zh-CN',
        'zh-cn': 'zh-CN',
        'zh-tw': 'zh-TW',
        'zh-hk': 'zh-HK',
        'en': 'en',
        'en-us': 'en',
        'en-gb': 'en'
    };
    return map[locale.toLowerCase()] || locale;
}


async function loadTranslations(locale) {
    try {
        const response = await fetch(`./locales/${locale}.json`);
        if (!response.ok) {
            console.warn(`Failed to load locale ${locale}, falling back to ${fallbackLocale}`);
            if (locale !== fallbackLocale) {
                const fallbackResponse = await fetch(`./locales/${fallbackLocale}.json`);
                translations = await fallbackResponse.json();
                currentLocale = fallbackLocale;
            }
            return;
        }
        translations = await response.json();
        localStorage.setItem('locale', locale);
    } catch (e) {
        console.error('Failed to load translations:', e);
        translations = {};
    }
}


export function t(key, params = {}) {
    const keys = key.split('.');
    let value = translations;
    
    for (const k of keys) {
        if (value && typeof value === 'object' && k in value) {
            value = value[k];
        } else {
            console.warn(`Translation key not found: ${key}`);
            return key;
        }
    }
    
    if (typeof value !== 'string') {
        console.warn(`Translation key is not a string: ${key}`);
        return key;
    }
    
    return value.replace(/\{(\w+)\}/g, (match, param) => {
        return params[param] !== undefined ? params[param] : match;
    });
}


export async function setLocale(locale) {
    locale = normalizeLocale(locale);
    if (locale === currentLocale) return;
    
    await loadTranslations(locale);
    updatePageText();

    window.dispatchEvent(new CustomEvent('localeChanged', { detail: { locale } }));
}


export function getLocale() {
    return currentLocale;
}

export function getConfigMetadata() {
    return translations.config || {};
}





export function updatePageText() {
    document.querySelectorAll('[data-i18n]').forEach(element => {
        const key = element.getAttribute('data-i18n');
        if (key) {
            element.textContent = t(key);
        }
    });
    
    document.querySelectorAll('[data-i18n-placeholder]').forEach(element => {
        const key = element.getAttribute('data-i18n-placeholder');
        if (key) {
            element.setAttribute('placeholder', t(key));
        }
    });
    
    document.querySelectorAll('[data-i18n-title]').forEach(element => {
        const key = element.getAttribute('data-i18n-title');
        if (key) {
            element.setAttribute('title', t(key));
        }
    });
    
    document.querySelectorAll('[data-i18n-label]').forEach(element => {
        const key = element.getAttribute('data-i18n-label');
        if (key) {
            element.setAttribute('label', t(key));
        }
    });
}

export function formatKey(key) {
    return key
        .split('_')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(' ');
}
