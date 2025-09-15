import { exec, spawn, toast } from './assets/kernelsu.js';

const moddir = '/data/adb/modules/mountify';
let config = {};
let configMetadata = {};

function loadVersion() {
    exec(`grep "^version=" ${moddir}/module.prop | cut -d= -f2`).then((result) =>{
        if (result.errno !== 0) reuturn;
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
        const response = await fetch('./config.json');
        if (!response.ok) {
            toast('Failed to load config.json');
            return {};
        }
        return await response.json();
    } catch (e) {
        toast('Failed to load config.json: ' + e);
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
                let value = config[key];
                let command;
                if (typeof value === 'string') {
                    value = value.replace(/"/g, '\"');
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

function showDescription(description) {
    const modal = document.querySelector('.modal');
    
    modal.querySelector('p').innerHTML = description.replace(/\n/g, '</br><br>');
    modal.classList.add('show');

    modal.querySelector('.close-button').onclick = () => {
        modal.classList.remove('show');
    };

    window.onclick = (event) => {
        if (event.target === modal) {
            modal.classList.remove('show');
        }
    };
}

function appendInputGroup() {
    const container = document.getElementById('input-group-container');
    container.innerHTML = '';
    for (const key in config) {
        if (Object.prototype.hasOwnProperty.call(config, key)) {
            const value = config[key];
            const metadata = configMetadata[key];
            const div = document.createElement('div');
            div.className = 'input-group';
            div.dataset.key = key;

            let inputElement;
            if (metadata && metadata.option) {
                if (metadata.option[0] === 'allow-other') {
                    const datalistId = `datalist-${key}`;
                    const options = metadata.option.slice(1).map(opt => `<option value="${opt}"></option>`).join('');
                    inputElement = `
                        <input type="text" list="${datalistId}" placeholder="${metadata.option[1]}" value="${value}" autocapitalize="none" />
                        <datalist id="${datalistId}">
                            ${options}
                        </datalist>
                    `;
                } else {
                    const options = metadata.option.map(opt => `<option value="${opt}" ${opt == value ? 'selected' : ''}>${opt}</option>`).join('');
                    inputElement = `<div class="select-group">
                        <select>${options}</select>
                        <svg class="arrow" xmlns="http://www.w3.org/2000/svg" viewBox="0 -960 960 960"><path d="M480-360 280-560h400L480-360Z"/></svg>
                    </div>`;
                }
            } else {
                inputElement = `<input type="text" placeholder="${key}" value="${value}" autocapitalize="none" />`;
            }

            let descriptionButton = '';
            if (metadata && metadata.description) {
                descriptionButton = `<button class="description-button">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -960 960 960"><path d="M478-240q21 0 35.5-14.5T528-290q0-21-14.5-35.5T478-340q-21 0-35.5 14.5T428-290q0 21 14.5 35.5T478-240Zm-36-154h74q0-33 7.5-52t42.5-52q26-26 41-49.5t15-56.5q0-56-41-86t-97-30q-57 0-92.5 30T342-618l66 26q5-18 22.5-39t53.5-21q32 0 48 17.5t16 38.5q0 20-12 37.5T506-526q-44 39-54 59t-10 73Zm38 314q-83 0-156-31.5T197-197q-54-54-85.5-127T80-480q0-83 31.5-156T197-763q54-54 127-85.5T480-880q83 0 156 31.5T763-763q54 54 85.5 127T880-480q0 83-31.5 156T763-197q-54 54-127 85.5T480-80Z"/></svg>
                </button>`;
            }

            div.innerHTML = `
                <div class="input-title">
                    <p>${key.split('_').map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()).join(' ')}</p>
                    ${descriptionButton}
                </div>
                ${inputElement}
            `;

            const input = div.querySelector('input, select');
            input.addEventListener('input', (event) => {
                const newValue = event.target.value;
                if (typeof config[key] === 'number') {
                    config[key] = parseInt(newValue, 10) || 0;
                } else {
                    config[key] = newValue;
                }
            });

            if (descriptionButton) {
                const button = div.querySelector('.description-button');
                button.addEventListener('click', () => {
                    showDescription(metadata.description);
                });
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
            const button = document.createElement('button');
            button.className = 'input-btn';
            button.textContent = 'SELECT MODULES';
            button.onclick = showModuleSelector;
            group.appendChild(button);

            const select = group.querySelector('select');
            const toggleButton = () => {
                button.style.display = select.value === '1' ? 'block' : 'none';
            };

            select.addEventListener('change', toggleButton);
            toggleButton();
        }

        if (key === 'FAKE_MOUNT_NAME') {
            const button = document.createElement('button');
            button.className = 'input-btn';
            button.textContent = 'RANDOM';
            button.onclick = () => {
                const input = group.querySelector('input');
                const randomName = Math.random().toString(36).substring(2, 12);
                input.value = randomName;
                config['FAKE_MOUNT_NAME'] = randomName;
                writeConfig();
            };
            group.appendChild(button);
        }

        if (key === 'use_ext4_sparse') {
            const h3 = document.createElement('h3');
            h3.textContent = 'ext4 configuration';
            group.before(h3);
        }
    });
}

async function showModuleSelector() {
    const selector = document.querySelector('.module-selector');
    const list = selector.querySelector('.module-list');
    list.innerHTML = '';
    selector.classList.add('show');

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
                <li class="module-item">
                    <p class="module-name">${module}</p>
                    <div class="checkbox-wrapper">
                        <input type="checkbox" class="checkbox" id="checkbox_${module}" data-module-name="${module}" ${isChecked ? 'checked' : ''} disabled />
                        <label for="checkbox_${module}" class="custom-checkbox">
                            <span class="tick-symbol">
                                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -3 26 26" width="16px" height="16px"><path d="M 22.566406 4.730469 L 20.773438 3.511719 C 20.277344 3.175781 19.597656 3.304688 19.265625 3.796875 L 10.476563 16.757813 L 6.4375 12.71875 C 6.015625 12.296875 5.328125 12.296875 4.90625 12.71875 L 3.371094 14.253906 C 2.949219 14.675781 2.949219 15.363281 3.371094 15.789063 L 9.582031 22 C 9.929688 22.347656 10.476563 22.613281 10.96875 22.613281 C 11.460938 22.613281 11.957031 22.304688 12.277344 21.839844 L 22.855469 6.234375 C 23.191406 5.742188 23.0625 5.066406 22.566406 4.730469 Z"/></svg>
                            </span>
                        </label>
                    </div>
                </li>
            `;
        }).join('');

        list.querySelectorAll('.module-item').forEach(item => {
            item.addEventListener('click', () => {
                const checkbox = item.querySelector('input[type="checkbox"]');
                checkbox.checked = !checkbox.checked;
            });
        });
    });


    const saveConfig = () => {
        const selectedModules = Array.from(list.querySelectorAll('input[type="checkbox"]:checked'))
            .map(input => input.dataset.moduleName);
        
        exec(`echo "${selectedModules.join('\n').trim()}" > ${moddir}/modules.txt`).then((result) => {
            if (result.errno !== 0) {
                toast('Failed to save: ' + result.stderr);
            }
        });
    }

    selector.querySelector('.close-button').onclick = () => {
        saveConfig();
        selector.classList.remove('show');
    };

    window.onclick = (event) => {
        if (event.target === selector) {
            saveConfig();
            selector.classList.remove('show');
        }
    };
}

function setupKeyboard() {
    const keyboardInset = document.querySelector('.keyboard-inset');
    document.querySelectorAll('input[type="text"]').forEach(input => {
        input.addEventListener('focus', () => {
            keyboardInset.classList.add('active');
            const inputRect = input.getBoundingClientRect();
            const viewportHeight = window.innerHeight;
            if (inputRect.bottom > viewportHeight / 2) {
                setTimeout(() => {
                    input.scrollIntoView({ block: 'center' });
                }, 100);
            }
        });
        input.addEventListener('blur', () => {
            writeConfig();
            setTimeout(() => {
                const activeEl = document.activeElement;
                if (!activeEl || !['input', 'select'].includes(activeEl.tagName.toLowerCase())) {
                    keyboardInset.classList.remove('active');
                }
            }, 100);
        });
    });
    document.querySelectorAll('select').forEach(select => {
        select.addEventListener('change', () => {
            writeConfig();
        });
    });
}

document.addEventListener('DOMContentLoaded', async () => {
    [config, configMetadata] = await Promise.all([loadConfig(), loadConfigMetadata()]);
    if (config) {
        appendInputGroup();
    }
    loadVersion();
    
    let scrollTimeout;
    window.addEventListener('scroll', () => {
        clearTimeout(scrollTimeout);
        scrollTimeout = setTimeout(() => {
            document.querySelectorAll('input[type="text"]').forEach(input => {
                if (document.activeElement === input) {
                    input.blur();
                    input.focus();
                }
            });
        }, 100);
    });
});
