import { exec, toast } from 'kernelsu-alt';
import '@material/web/all.js';
import * as file from './file.js';
import { loadTranslations, translations } from './language.js';

const moddir = '/data/adb/modules/mountify';
export let config = {};
let configMetadata = {};
const functions = { isKsu };

async function checkReq(req) {
    for (const [reqKey, reqValue] of Object.entries(req)) {
        if (reqKey === "JavaScript") {
            if (typeof reqValue !== 'object') continue;
            for (const [funcName, expected] of Object.entries(reqValue)) {
                if (typeof functions[funcName] !== 'function') {
                    toast(`invalid function ${funcName}`);
                    return false;
                }
                try {
                    const result = await functions[funcName]();
                    if (result !== expected) {
                        return false;
                    }
                } catch (e) {
                    console.error(e);
                    return false;
                }
            }
        } else {
            if (config[reqKey] !== reqValue) {
                return false;
            }
        }
    }
    return true;
}

function showDescription(title, description) {
    const dialog = document.getElementById('description-dialog');
    const closeBtn = dialog.querySelector('[value="close"]');
    const headline = dialog.querySelector('[slot="headline"]');
    const content = dialog.querySelector('[slot="content"]');
    headline.innerHTML = title;
    content.innerHTML = description.replace(/\n/g, '<br>');
    closeBtn.onclick = () => dialog.close();
    window.onscroll = () => dialog.close();
    dialog.show();
}

async function appendInputGroup() {
    for (const key in config) {
        if (Object.prototype.hasOwnProperty.call(config, key)) {
            const value = config[key];
            const metadata = configMetadata[key] || false;
            const options = metadata?.option || [];
            const header = key.split('_').map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()).join(' ');
            const container = document.getElementById(`content-${metadata.type}`);
            const div = document.createElement('div');
            div.className = 'input-group content';
            div.dataset.key = key;

            if (!metadata) continue;
            if (metadata.option) {
                if (metadata.option[0] === 'allow-other') { // Fixed options + custom input
                    appendTextField(key, value, div, options, header);
                } else { // Fixed options only
                    appendSelect(key, value, div, options, header);
                }
            } else { // Raw text field
                appendTextField(key, value, div, null, header);
            }
            container.appendChild(div);
        }
    }

    // Requirement
    for (const key in configMetadata) {
        const metadata = configMetadata[key];
        if (metadata.require) {
            const dependentGroup = document.querySelector(`.input-group[data-key="${key}"]`);
            if (!dependentGroup) continue;
            const dependentInput = dependentGroup.querySelector('md-outlined-select, md-outlined-text-field');
            if (!dependentInput) continue;

            const checkAndSetDisabled = async () => {
                const satisfied = (await Promise.all(metadata.require.map(checkReq))).every(Boolean);
                dependentInput.disabled = !satisfied;
            };

            metadata.require.forEach(req => {
                Object.keys(req).forEach(reqKey => {
                    const requirementGroup = document.querySelector(`.input-group[data-key="${reqKey}"]`);
                    if (requirementGroup) {
                        const requirementInput = requirementGroup.querySelector('md-outlined-select, md-outlined-text-field');
                        if (requirementInput) {
                            const eventType = requirementInput.tagName.toLowerCase() === 'md-outlined-select' ? 'change' : 'input';
                            requirementInput.addEventListener(eventType, checkAndSetDisabled);
                        }
                    }
                });
            });
            checkAndSetDisabled();
        }
    }

    setupKeyboard();
    appendExtras();
}

/**
 * Append text field with options or raw text field if no option provided
 * @param {string} key - config name
 * @param {string} value - config value
 * @param {HTMLElement} el - Parent element to append
 * @param {string[]} options - options to show
 * @param {string} header - Help menu header
 * @returns {void}
 */
function appendTextField(key, value, el, options, header) {
    const textField = document.createElement('md-outlined-text-field');
    textField.label = key;
    textField.value = value;
    textField.innerHTML = `
        <md-icon-button slot="trailing-icon">
            <md-icon>info</md-icon>
        </md-icon-button>
    `;
    textField.querySelector('md-icon-button').onclick = () => {
        showDescription(header, translations['desc_' + key]);
    }
    el.appendChild(textField);

    if (!options) { // Raw text field
        textField.addEventListener('input', (event) => {
            const newValue = event.target.value;
            if (typeof config[key] === 'number') {
                config[key] = parseInt(newValue) || 0;
            } else {
                config[key] = newValue;
            }
        });
        return;
    }

    const menu = document.createElement('md-menu');
    menu.defaultFocus = '';
    menu.skipRestoreFocus = true;
    menu.anchorCorner = 'start-start';
    menu.menuCorner = 'end-start';
    menu.anchorElement = textField;
    el.appendChild(menu);

    // append all options once and toggle visibility with style.display on filter
    options.slice(1).forEach(opt => {
        const menuItem = document.createElement('md-menu-item');
        menuItem.dataset.option = opt;
        menuItem.innerHTML = `<div slot="headline">${opt}</div>`;
        menuItem.addEventListener('click', () => {
            textField.value = opt;
            if (typeof config[key] === 'number') {
                config[key] = parseInt(opt) || 0;
            } else {
                config[key] = opt;
            }
            menu.close();
        });
        menu.appendChild(menuItem);
    });

    const filterMenuItems = (value) => {
        const newValue = String(value || '');
        if (typeof config[key] === 'number') {
            config[key] = parseInt(newValue) || 0;
        } else {
            config[key] = newValue;
        }

        const needle = newValue.toLowerCase();
        let visible = 0;
        menu.querySelectorAll('md-menu-item').forEach(mi => {
            const opt = (mi.dataset.option || '').toLowerCase();
            const show = opt.includes(needle) && opt !== needle;
            mi.style.display = show ? '' : 'none';
            if (show) visible++;
        });

        if (visible > 0) {
            menu.show();
        } else {
            menu.close();
        }
    }

    textField.addEventListener('input', (event) => filterMenuItems(event.target.value));
    textField.addEventListener('focus', (event) => {
        setTimeout(() => {
            if (document.activeElement === textField) filterMenuItems(event.target.value);
        }, 100);
    });
}

/**
 * Append select options
 * @param {string} key - config name
 * @param {string} value - config value
 * @param {HTMLElement} el - Parent element to append
 * @param {string[]} options - options to show
 * @param {string} header - Help menu header
 * @returns {void}
 */
function appendSelect(key, value, el, options, header) {
    const select = document.createElement('md-outlined-select');
    select.label = key;
    select.innerHTML = `
        <md-icon-button slot="trailing-icon">
            <md-icon>info</md-icon>
        </md-icon-button>
    `;
    select.querySelector('md-icon-button').addEventListener('click', (e) => {
        e.stopPropagation();
        showDescription(header, translations['desc_' + key]);
    });

    options.forEach(opt => {
        const option = document.createElement('md-select-option');
        option.value = opt;
        option.innerHTML = `<div slot="headline">${opt}</div>`;
        if (opt == value) option.selected = true;
        select.appendChild(option);
    });

    select.addEventListener('change', (event) => {
        const newValue = event.target.value;
        if (typeof config[key] === 'number') {
            config[key] = parseInt(newValue) || 0;
        } else {
            config[key] = newValue;
        }
        file.writeConfig();
    });
    el.appendChild(select);
}

function appendExtras(value) {
    document.querySelectorAll('.input-group').forEach(group => {
        const key = group.dataset.key;
        if (!key) return;

        if (key === 'mountify_mounts') {
            const button = document.createElement('md-filled-icon-button');
            button.innerHTML = `<md-icon>checklist_rtl</md-icon>`;
            button.onclick = showModuleSelector;
            group.appendChild(button);

            const select = group.querySelector('md-outlined-select');
            const toggleButton = () => button.disabled = config[key] !== 1;

            select.addEventListener('change', (event) => {
                const newValue = event.target.value;
                config[key] = parseInt(newValue) || 0;
                file.writeConfig();
                toggleButton();
            });
            toggleButton();
        }

        if (key === 'FAKE_MOUNT_NAME') {
            const button = document.createElement('md-filled-icon-button');
            button.innerHTML = `<md-icon>casino</md-icon>`;
            button.onclick = () => {
                const input = group.querySelector('md-outlined-text-field');
                const randomName = Math.random().toString(36).substring(2, 12);
                input.value = randomName;
                config['FAKE_MOUNT_NAME'] = randomName;
                file.writeConfig();
            };
            group.appendChild(button);
        }
    });
}

async function showModuleSelector() {
    const dialog = document.getElementById('module-selector-dialog');
    const saveBtn = dialog.querySelector('md-text-button');
    const list = document.getElementById('module-list');
    list.innerHTML = '';
    dialog.show();

    const moduleList = await exec(`
        dir=/data/adb/modules
        for module in $(ls $dir); do
            if ls $dir/$module/system >/dev/null 2>&1 && ! ls $dir/$module/system/etc/hosts >/dev/null 2>&1; then
                echo $module
            fi
        done
    `);

    exec(`cat /data/adb/mountify/modules.txt`).then((result) => {
        const selected = result.stdout.trim().split('\n').map(line => line.trim()).filter(Boolean);
        const modules = moduleList.stdout.trim().split('\n').filter(Boolean);

        list.innerHTML = modules.map(module => {
            const isChecked = selected.includes(module);
            return `
                <md-list-item>
                    <div slot="headline">${module}</div>
                    <md-checkbox slot="end" data-module-name="${module}" ${isChecked ? 'checked' : ''}></md-checkbox>
                </md-list-item>
            `;
        }).join('');
    }).catch(() => { });

    const saveConfig = () => {
        const selectedModules = Array.from(list.querySelectorAll('md-checkbox'))
            .filter(checkbox => checkbox.checked)
            .map(checkbox => checkbox.dataset.moduleName);

        exec(`echo "${selectedModules.join('\n').trim()}" > /data/adb/mountify/modules.txt`).then((result) => {
            if (result.errno !== 0) {
                toast('Failed to save: ' + result.stderr);
            }
        }).catch(() => { });
    }

    saveBtn.onclick = () => {
        saveConfig();
        dialog.close();
    };
    window.onscroll = () => dialog.close();
}

function setupKeyboard() {
    const keyboardInset = document.querySelector('.keyboard-inset');
    document.querySelectorAll('md-outlined-text-field').forEach(input => {
        input.addEventListener('focus', () => {
            keyboardInset.classList.add('active');
            setTimeout(() => {
                input.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }, 300);
        });
        input.addEventListener('blur', () => {
            file.writeConfig();
            setTimeout(() => {
                const activeEl = document.activeElement;
                if (!activeEl || !['md-outlined-text-field', 'md-outlined-select'].includes(activeEl.tagName.toLowerCase())) {
                    keyboardInset.classList.remove('active');
                }
            }, 100);
        });
    });
}

function isKsu() {
    return new Promise((resolve) => {
        // No su (sucompat disabled)
        // ksud in PATH when running with su
        exec('! command -v su || su -c "ksud -h"').then((result) => {
            resolve(result.errno === 0);
        }).catch(() => {
            resolve(false);
        });
    });
}

function toggleAdvanced(advanced) {
    document.querySelectorAll('.input-group').forEach(group => {
        const key = group.dataset.key;
        if (!key) return;
        const metadata = configMetadata[key] || false;
        if (metadata.advanced) {
            group.style.display = advanced ? '' : 'none';
        }
    });
}

// Overwrite default dialog animation
document.querySelectorAll('md-dialog').forEach(dialog => {
    const defaulfOpenAnim = dialog.getOpenAnimation;
    const defaultCloseAnim = dialog.getCloseAnimation;

    dialog.getOpenAnimation = () => {
        const defaultAnim = defaulfOpenAnim.call(dialog);
        const customAnim = {};
        Object.keys(defaultAnim).forEach(key => customAnim[key] = defaultAnim[key]);

        customAnim.dialog = [
            [
                [{ opacity: 0, transform: 'translateY(50px)' }, { opacity: 1, transform: 'translateY(0)' }],
                { duration: 300, easing: 'ease' }
            ]
        ];
        customAnim.scrim = [
            [
                [{ 'opacity': 0 }, { 'opacity': 0.32 }],
                { duration: 300, easing: 'linear' },
            ],
        ];
        customAnim.container = [];

        return customAnim;
    };

    dialog.getCloseAnimation = () => {
        const defaultAnim = defaultCloseAnim.call(dialog);
        const customAnim = {};
        Object.keys(defaultAnim).forEach(key => customAnim[key] = defaultAnim[key]);

        customAnim.dialog = [
            [
                [{ opacity: 1, transform: 'translateY(0)' }, { opacity: 0, transform: 'translateY(-50px)' }],
                { duration: 300, easing: 'ease' }
            ]
        ];
        customAnim.scrim = [
            [
                [{ 'opacity': 0.32 }, { 'opacity': 0 }],
                { duration: 300, easing: 'linear' },
            ],
        ];
        customAnim.container = [];

        return customAnim;
    };
});

function initTab() {
    const mdTab = document.querySelector('md-tabs');
    const contentContainers = document.querySelectorAll('.content-container');

    const updateTabPositions = () => {
        const activeTab = mdTab.querySelector('md-primary-tab[active]');
        if (!activeTab) return;

        const tabIndex = Array.from(mdTab.querySelectorAll('md-primary-tab')).indexOf(activeTab);
        contentContainers.forEach((container, index) => {
            const translateX = (index - tabIndex) * 100;
            container.style.transform = `translateX(${translateX}%)`;
            setTimeout(() => {
                container.style.transition = 'transform 0.3s ease';
                container.classList.remove('unresolved');
            }, 10);
        });
    };

    contentContainers.forEach((container, index) => {
        const translateX = index * 100;
        container.style.transform = `translateX(${translateX}%)`;
    });

    updateTabPositions();
    mdTab.addEventListener('change', async () => {
        await Promise.resolve();
        updateTabPositions();
    });
}

function initUpdateSwitch() {
    const updateSwitch = document.getElementById('update');
    function checkUpdateState() {
        exec(`grep -q "^updateJson=" ${moddir}/module.prop`).then((result) => {
            updateSwitch.selected = result.errno === 0;
        });
    }
    checkUpdateState();
    updateSwitch.addEventListener('change', () => {
        const cmd = updateSwitch.selected ? `"s/updateLink/updateJson/g"` : `"s/updateJson/updateLink/g"`;
        exec(`sed -i ${cmd} ${moddir}/module.prop`).then((result) => {
            checkUpdateState();
            if (result.errno !== 0) toast('Failed to toggle update: ' + result.stderr);
        }).catch(() => { });
    });
}

function initRebootButton() {
    document.getElementById('reboot').onclick = () => {
        const confirmationDialog = document.getElementById('confirm-reboot-dialog');
        confirmationDialog.show();
        window.onscroll = () => confirmationDialog.close();
        confirmationDialog.querySelectorAll('md-text-button').forEach(btn => {
            btn.onclick = () => {
                confirmationDialog.close();
                if (btn.value === 'reboot') {
                    exec('/system/bin/reboot').then((result) => {
                        if (result.errno !== 0) toast('Failed to reboot: ' + result.stderr);
                    }).catch(() => { });
                }
            }
        });
    }
}

function initLanguageButton() {
    const langaugeDialog = document.getElementById('language-dialog');
    document.getElementById('language').onclick = () => {
        langaugeDialog.show();
        window.onscroll = () => langaugeDialog.close();
        langaugeDialog.querySelectorAll('label, md-text-button').forEach(el => {
            el.onclick = () => langaugeDialog.close();
        });
    }
}

document.addEventListener('DOMContentLoaded', async () => {
    await loadTranslations();
    document.querySelectorAll('[unresolved]').forEach(el => el.removeAttribute('unresolved'));

    [config, configMetadata] = await Promise.all([file.loadConfig(), file.loadConfigMetadata()]);
    const advanced = document.getElementById('advanced');
    advanced.selected = localStorage.getItem('mountify_advanced') === 'true';
    advanced.addEventListener('change', () => {
        localStorage.setItem('mountify_advanced', advanced.selected ? 'true' : 'false');
        if (config) toggleAdvanced(advanced.selected);
    });
    if (config) {
        await appendInputGroup();
        toggleAdvanced(advanced.selected);
    }
    file.loadVersion();

    initTab();

    initLanguageButton();
    initRebootButton();
    initUpdateSwitch();
});
