import { exec, spawn, toast } from './assets/kernelsu.js';

const moddir = '/data/adb/modules/mountify';
let config = {};
let configMetadata = {};

function loadVersion() {
    exec(`grep "^version=" ${moddir}/module.prop | cut -d= -f2`).then((result) => {
        if (result.errno !== 0) return;
        document.getElementById('version').innerHTML = result.stdout.trim();
    });
}

async function loadConfig() {
    try {
        const response = await fetch('./config.sh');
        if (!response.ok) throw new Error('response failed');
        const conf = (await response.text())
            .split('\n')
            .filter(line => line.trim() !== '' && !line.startsWith('#'))
            .map(line => line.split('='))
            .reduce((acc, [key, value]) => {
                if (key && value) {
                    const val = value.trim();
                    if (val.startsWith('"') && val.endsWith('"')) {
                        acc[key.trim()] = val.substring(1, val.length - 1);
                    } else {
                        acc[key.trim()] = parseInt(val, 10);
                    }
                }
                return acc;
            }, {});
        return conf;
    } catch (e) {
        exec(`ln -s "${moddir}/config.sh" "${moddir}/webroot/config.sh"`).then((result) => {
            if (result.errno !== 0) {
                toast("Failed to load config");
                return;
            }
            window.location.reload();
        })
    }
}

async function loadConfigMetadata() {
    try {
        const response = await fetch('./config_mountify.json');
        if (!response.ok) {
            toast('Failed to load config_mountify.json');
            return {};
        }
        return await response.json();
    } catch (e) {
        toast('Failed to load config_mountify.json: ' + e);
        return {};
    }
}


async function writeConfig() {
    const oldConfig = await loadConfig();
    if (!oldConfig) {
        toast('Failed to save config!');
        return;
    }

    const commands = [];
    for (const key in config) {
        if (Object.prototype.hasOwnProperty.call(config, key) && Object.prototype.hasOwnProperty.call(oldConfig, key)) {
            if (config[key] !== oldConfig[key]) {
                let value = config[key]
                let command;
                if (typeof value === 'string') {
                    value = value.replace(/"/g, '\"').replace(/\\/g, '');
                    command = `sed -i 's|^${key}=.*|${key}="${value}"|' ${moddir}/config.sh`;
                } else {
                    command = `sed -i 's|^${key}=.*|${key}=${value}|' ${moddir}/config.sh`;
                }
                commands.push(command);
            }
        }
    }

    if (commands.length > 0) {
        let stderr = [];
        const command = commands.join(' && ');
        const result = spawn(command);
        result.stderr.on('data', (data) => {
            stderr.push(data);
        });
        result.on('exit', (code) => {
            if (code !== 0) {
                toast('Error saving config: ' + stderr.join(' '));
            }
        })
    }
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

function appendInputGroup() {
    for (const key in config) {
        if (Object.prototype.hasOwnProperty.call(config, key)) {
            const value = config[key];
            const metadata = configMetadata[key];
            const header = key.split('_').map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()).join(' ');
            const container = document.getElementById(`content-${metadata.type}`);
            const div = document.createElement('div');
            div.className = 'input-group';
            div.dataset.key = key;

            if (metadata && metadata.hide && metadata.hide === true) continue;
            if (metadata && metadata.option) { // Fixed options
                if (metadata.option[0] === 'allow-other') { // Fixed options + custom input
                    const textField = document.createElement('md-outlined-text-field');
                    textField.label = key;
                    textField.value = value;
                    textField.innerHTML = `
                        <md-icon-button slot="trailing-icon">
                            <md-icon>info</md-icon>
                        </md-icon-button>
                    `;
                    textField.querySelector('md-icon-button').onclick = () => {
                        showDescription(header, metadata.description);
                    }
                    div.appendChild(textField);

                    const menu = document.createElement('md-menu');
                    menu.defaultFocus = '';
                    menu.skipRestoreFocus = true;
                    menu.anchorCorner = 'start-start';
                    menu.menuCorner = 'end-start';
                    menu.anchorElement = textField;
                    div.appendChild(menu);

                    const options = metadata.option.slice(1);
                    // append all options once and toggle visibility with style.display on filter
                    options.forEach(opt => {
                        const menuItem = document.createElement('md-menu-item');
                        menuItem.dataset.option = opt;
                        menuItem.innerHTML = `<div slot="headline">${opt}</div>`;
                        menuItem.addEventListener('click', () => {
                            textField.value = opt;
                            if (typeof config[key] === 'number') {
                                config[key] = parseInt(opt, 10) || 0;
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
                            config[key] = parseInt(newValue, 10) || 0;
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
                        }, 100)
                    });
                } else { // Fixed options only
                    const select = document.createElement('md-outlined-select');
                    select.label = key;
                    select.innerHTML = `
                        <md-icon-button slot="trailing-icon">
                            <md-icon>info</md-icon>
                        </md-icon-button>
                    `;
                    select.querySelector('md-icon-button').addEventListener('click', (e) => {
                        e.stopPropagation();
                        showDescription(header, metadata.description);
                    });

                    const options = metadata.option;

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
                            config[key] = parseInt(newValue, 10) || 0;
                        } else {
                            config[key] = newValue;
                        }
                        writeConfig();
                    });
                    div.appendChild(select);
                }
            } else { // Raw text field
                const textField = document.createElement('md-outlined-text-field');
                textField.label = key;
                textField.value = value;
                textField.innerHTML = `
                    <md-icon-button slot="trailing-icon">
                        <md-icon>info</md-icon>
                    </md-icon-button>
                `;
                textField.querySelector('md-icon-button').onclick = () => {
                    showDescription(header, metadata.description);
                }
                textField.addEventListener('input', (event) => {
                    const newValue = event.target.value;
                    if (typeof config[key] === 'number') {
                        config[key] = parseInt(newValue, 10) || 0;
                    } else {
                        config[key] = newValue;
                    }
                });
                div.appendChild(textField);
            }
            container.appendChild(div);
        }
    }
    setupKeyboard();
    appendExtras();
}

function appendExtras() {
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
                config[key] = parseInt(newValue, 10) || 0;
                writeConfig();
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
                writeConfig();
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

    exec(`cat ${moddir}/modules.txt`).then((result) => {
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
    });

    const saveConfig = () => {
        const selectedModules = Array.from(list.querySelectorAll('md-checkbox'))
            .filter(checkbox => checkbox.checked)
            .map(checkbox => checkbox.dataset.moduleName);
        
        exec(`echo "${selectedModules.join('\n').trim()}" > ${moddir}/modules.txt`).then((result) => {
            if (result.errno !== 0) {
                toast('Failed to save: ' + result.stderr);
            }
        });
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
            writeConfig();
            setTimeout(() => {
                const activeEl = document.activeElement;
                if (!activeEl || !['md-outlined-text-field', 'md-outlined-select'].includes(activeEl.tagName.toLowerCase())) {
                    keyboardInset.classList.remove('active');
                }
            }, 100);
        });
    });
}

function initSwitch(path, id) {
    const element = document.getElementById(id);
    if (!element) return;
    exec(`test -f ${path}`).then((result) => {
        if (result.errno === 0) element.selected = true;
    });
    element.addEventListener('change', () => {
        const cmd = element.selected ? 'touch' : 'rm -f';
        exec(`${cmd} ${path}`).then((result) => {
            if (result.errno !== 0) toast('Failed to toggle ' + path + ': ' + result.stderr);
        });
    });
}

document.addEventListener('DOMContentLoaded', async () => {
    [config, configMetadata] = await Promise.all([loadConfig(), loadConfigMetadata()]);
    if (config) appendInputGroup();
    loadVersion();

    const controller = document.querySelector('md-tabs');
    controller.addEventListener('change', async () => {
        await Promise.resolve();
        controller.querySelectorAll('md-primary-tab').forEach(tab => {
            const panelId = tab.getAttribute('aria-controls');
            const isActive = tab.hasAttribute('active');
            const panel = document.getElementById(panelId);
            isActive ? panel.removeAttribute('hidden') : panel.setAttribute('hidden', '');
        });
    });

    // KernelSU WebUI remove /data/adb/ksud/bin from PATH when we're not executing as su
    // Condition 1: ksud in PATH (likey in third party manager like KSUWEBuiSrandalone, Webui-X)
    // Condition 2: su not available (when sucompat disabled, KernelSU exclusive currently)
    // Condition 3: ksud in path when running with su
    exec('command -v ksud || ! command -v su || su -c command -v ksud').then((isKsu) => {
        if (isKsu.errno !== 0 && isKsu.stderr !== "ksu is not defined") return
        document.getElementById('ksu-tab').classList.remove('hidden');
        initSwitch('/data/adb/ksu/.nomount', 'nomount');
        initSwitch('/data/adb/ksu/.notmpfs', 'notmpfs');
    });
    exec('command -v apd').then((isAp) => {
        if (isAp.errno !== 0 && isAp.stderr !== "ksu is not defined") return
        document.getElementById('ap-tab').classList.remove('hidden');
        initSwitch('/data/adb/.litemode_enable', 'litemode')
    });
});
