import messages from './language-messages.json';

export const languageOptions = [
    { value: 'en', label: 'English' }, { value: 'fr', label: 'Français' },
    { value: 'es', label: 'Español' }, { value: 'ar', label: 'العربية' },
    { value: 'it', label: 'Italiano' },
];
const storageKey = 'yestream-tv-language';
function readLanguage() {
    try { return localStorage.getItem(storageKey); } catch { return null; }
}
const selected = readLanguage();
export const tvLanguage = languageOptions.find(option => option.value === selected)?.value ?? 'en';
const translationIndex = languageOptions.findIndex(option => option.value === tvLanguage) - 1;
if (typeof document !== 'undefined') {
    document.documentElement.lang = tvLanguage;
    document.documentElement.dir = tvLanguage === 'ar' ? 'rtl' : 'ltr';
}
export function tr(text: string): string {
    return (messages as Record<string, string[]>)[text]?.[translationIndex] ?? text;
}
export function setTvLanguage(language: string) {
    if (language === tvLanguage || !languageOptions.some(option => option.value === language)) return;
    localStorage.setItem(storageKey, language);
    location.reload();
}
