# Mountify WebUI Localization Guideline

## Add a new langauge

1. [Fork](https://github.com/backslashxx/mountify/fork) this repository.
2. Make a copy of `webui/public/locales/en.xml` to strings folder.
3. Rename it to `{language-code}.xml` by refering [language codes standard](https://support.crowdin.com/developer/language-codes).
4. Add language entrance in `webui/public/locales/languages.json`, format: "language-code": "Language name in your language".
    ```json
    {
        "en": "English",
        "fr": "Français", // Your language, keep alphabetical order
        "zh-CN": "简体中文"
    }
   ```
5. Do translation to all the string value or update existing string value.
6. Add your info to `webui/public/locales/CONTRIBUTOR.md`.
7. Open pull request.

## Update existing langauge

- Same with adding a new language, skip step 2 to 4.
