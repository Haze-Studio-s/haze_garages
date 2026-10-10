const app = document.getElementById('app');
const closeBtn = document.getElementById('close-btn');
const vehicleList = document.getElementById('vehicle-list');
const garageTitle = document.getElementById('garage-title');
const searchInput = document.getElementById('search-input');
const modalContainer = document.querySelector('.modal-container');

// Nickname Modal Elements
const nicknameModal = document.getElementById('nickname-modal');
const nicknameInput = document.getElementById('nickname-input');
const promptPlateInfo = document.getElementById('prompt-plate-info');
const saveNicknameBtn = document.getElementById('save-nickname-btn');
const cancelNicknameBtn = document.getElementById('cancel-nickname-btn');

// Phone Preview Elements (/garagemapp)
const phonePreviewModal = document.getElementById('phone-preview-modal');
const closePhoneBtn = document.getElementById('close-phone-btn');
const phoneIframe = document.getElementById('phone-iframe');

// Corporate Logs Elements (Fase 2)
const corporateLogsBtn = document.getElementById('corporate-logs-btn');
const corporateLogsModal = document.getElementById('corporate-logs-modal');
const closeLogsBtn = document.getElementById('close-logs-btn');
const closeLogsFooterBtn = document.getElementById('close-logs-footer-btn');
const logsSearchInput = document.getElementById('logs-search-input');
const logsTbody = document.getElementById('logs-tbody');
const noLogsMsg = document.getElementById('no-logs-msg');
const logsModalTitle = document.getElementById('logs-modal-title');
let currentGarageLogs = [];

let currentMode = 'garage'; // 'garage' or 'list'
let currentGarageId = null;
let allVehicles = [];
let targetPlateForNickname = null;
let hasTransferContract = false;

function closeNUI() {
    app.classList.add('hidden');
    nicknameModal.classList.add('hidden');
    if (phonePreviewModal) phonePreviewModal.classList.add('hidden');
    if (corporateLogsModal) corporateLogsModal.classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

function closeLogsModal() {
    if (corporateLogsModal) {
        corporateLogsModal.classList.add('hidden');
    }
}

closeBtn.addEventListener('click', closeNUI);
if (closePhoneBtn) closePhoneBtn.addEventListener('click', closeNUI);
if (closeLogsBtn) closeLogsBtn.addEventListener('click', closeLogsModal);
if (closeLogsFooterBtn) closeLogsFooterBtn.addEventListener('click', closeLogsModal);

window.addEventListener('keyup', (e) => {
    if (e.key === 'Escape') {
        if (!nicknameModal.classList.contains('hidden')) {
            nicknameModal.classList.add('hidden');
        } else if (corporateLogsModal && !corporateLogsModal.classList.contains('hidden')) {
            closeLogsModal();
        } else {
            closeNUI();
        }
    }
});

// Search Filter
searchInput.addEventListener('input', (e) => {
    const query = e.target.value.toLowerCase().trim();
    filterAndRenderVehicles(query);
});

function filterAndRenderVehicles(query) {
    if (!query) {
        renderCards(allVehicles);
        return;
    }

    const filtered = allVehicles.filter(veh => {
        const modelStr = (veh.model || '').toLowerCase();
        const nickStr = (veh.nickname || '').toLowerCase();
        const plateStr = (veh.plate || '').toLowerCase();
        const labelStr = (veh.label || '').toLowerCase();

        return modelStr.includes(query) || nickStr.includes(query) || plateStr.includes(query) || labelStr.includes(query);
    });

    renderCards(filtered);
}

function openNicknameModal(plate, currentNickname) {
    targetPlateForNickname = plate;
    promptPlateInfo.innerText = `PLACA: ${plate}`;
    nicknameInput.value = currentNickname || '';
    nicknameModal.classList.remove('hidden');
    setTimeout(() => nicknameInput.focus(), 50);
}

cancelNicknameBtn.addEventListener('click', () => {
    nicknameModal.classList.add('hidden');
    targetPlateForNickname = null;
});

saveNicknameBtn.addEventListener('click', () => {
    if (!targetPlateForNickname) return;
    const newNick = nicknameInput.value.trim();

    fetch(`https://${GetParentResourceName()}/setNickname`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            plate: targetPlateForNickname,
            nickname: newNick
        })
    }).then(res => res.json()).then(data => {
        if (data.ok) {
            const veh = allVehicles.find(v => v.plate === targetPlateForNickname);
            if (veh) {
                veh.nickname = data.nickname || '';
            }
            filterAndRenderVehicles(searchInput.value.toLowerCase().trim());
        }
        nicknameModal.classList.add('hidden');
        targetPlateForNickname = null;
    });
});

function renderCards(vehicles) {
    vehicleList.innerHTML = '';

    if (!vehicles || vehicles.length === 0) {
        vehicleList.innerHTML = '<div class="no-vehicles">Nenhum veículo encontrado.</div>';
        return;
    }

    vehicles.forEach(veh => {
        const card = document.createElement('div');
        card.className = 'vehicle-card';

        const enginePct = Math.min(100, Math.max(0, Math.round((veh.engine / 1000) * 100)));
        const bodyPct = Math.min(100, Math.max(0, Math.round((veh.body / 1000) * 100)));
        const fuelPct = Math.min(100, Math.max(0, Math.round(veh.fuel)));
        const mileageVal = veh.mileage ? parseFloat(veh.mileage).toFixed(1) : '0.0';

        const hasNickname = veh.nickname && veh.nickname.trim() !== '';
        const nicknameHtml = hasNickname ? `<span class="nickname-tag"><i class="fas fa-tag"></i> ${veh.nickname}</span>` : '';

        // Status Badge Logic
        let statusBadgeClass = 'status-fixed';
        let statusText = veh.statusLabel || 'Garagem';
        if (veh.spawnType === 'street') {
            statusBadgeClass = 'status-street';
        } else if (veh.spawnType === 'stranded') {
            statusBadgeClass = 'status-stranded';
        } else if (veh.spawnType === 'out') {
            statusBadgeClass = 'status-out';
        } else if (veh.spawnType === 'impound') {
            statusBadgeClass = 'status-impound';
        }

        const isListMode = currentMode === 'list';
        let actionButtonHtml = '';

        const transferBtnHtml = hasTransferContract ? `<button class="btn-icon btn-transfer" title="Transferir Veículo (Contrato)"><i class="fas fa-file-contract"></i></button>` : '';

        if (isListMode) {
            let trackBtnHtml = '';
            let mainActionBtnHtml = '';

            if (veh.spawnType === 'street' && veh.streetCoords) {
                trackBtnHtml = `<button class="btn-icon btn-track" title="Marcar Localização na Rua"><i class="fas fa-location-dot"></i></button>`;
                mainActionBtnHtml = `<button class="btn-spawn btn-unpark" data-plate="${veh.plate}"><i class="fas fa-key"></i> RETIRAR (RUA)</button>`;
            } else if (veh.spawnType === 'stranded') {
                trackBtnHtml = `<button class="btn-icon btn-track-garage" data-garage="${veh.garage || 'legion_square'}" title="Local da Garagem Bloqueada"><i class="fas fa-ban"></i></button>`;
                mainActionBtnHtml = `<button class="btn-spawn btn-recover-stranded" data-plate="${veh.plate}"><i class="fas fa-truck-pickup"></i> REBOCAR P/ CENTRAL ($500)</button>`;
            } else if (veh.spawnType === 'fixed') {
                trackBtnHtml = `<button class="btn-icon btn-track-garage" data-garage="${veh.garage || 'legion_square'}" title="Marcar Garagem no GPS"><i class="fas fa-location-dot"></i></button>`;
                mainActionBtnHtml = `<button class="btn-spawn btn-track-garage" data-garage="${veh.garage || 'legion_square'}"><i class="fas fa-location-dot"></i> MARCAR GARAGEM</button>`;
            } else if (veh.spawnType === 'impound') {
                trackBtnHtml = `<button class="btn-icon btn-track-garage" data-garage="impound_main" title="Marcar Pátio Impound no GPS"><i class="fas fa-truck-pickup"></i></button>`;
                mainActionBtnHtml = `<button class="btn-spawn btn-track-garage" data-garage="impound_main"><i class="fas fa-truck-pickup"></i> IR AO IMPOUND</button>`;
            } else {
                mainActionBtnHtml = `<button class="btn-spawn" disabled><i class="fas fa-car-side"></i> EM USO NA RUA</button>`;
            }

            actionButtonHtml = `
                ${trackBtnHtml}
                ${transferBtnHtml}
                <button class="btn-icon btn-edit-nick" title="Editar Apelido"><i class="fas fa-pen"></i></button>
                ${mainActionBtnHtml}
            `;
        } else {
            let garageActionBtn = '';
            if (veh.isSpawnable) {
                garageActionBtn = `<button class="btn-spawn btn-garage-spawn" data-plate="${veh.plate}"><i class="fas fa-car-side"></i> RETIRAR</button>`;
            } else if (veh.spawnType === 'out') {
                garageActionBtn = `<button class="btn-spawn" disabled><i class="fas fa-car-side"></i> JÁ FORA (EM USO)</button>`;
            } else if (veh.spawnType === 'fixed_other') {
                garageActionBtn = `
                    <button class="btn-spawn btn-valet-action" data-plate="${veh.plate}" title="Manobrista busca o veículo e traz até você ($150)"><i class="fas fa-bell-concierge"></i> VALET ($150)</button>
                    <button class="btn-spawn btn-track-garage" data-garage="${veh.garage}" style="margin-left: 6px;"><i class="fas fa-location-dot"></i> GPS</button>
                `;
            } else if (veh.spawnType === 'impound') {
                garageActionBtn = `<button class="btn-spawn" disabled><i class="fas fa-lock"></i> NO IMPOUND</button>`;
            } else if (veh.spawnType === 'locked_grade') {
                garageActionBtn = `<button class="btn-spawn" disabled style="opacity: 0.65; cursor: not-allowed; background: #2a2c33; color: #9ca3af; border-color: rgba(239, 68, 68, 0.4);"><i class="fas fa-lock"></i> PATENTE INSUFICIENTE (${veh.minGrade}+)</button>`;
            } else {
                garageActionBtn = `<button class="btn-spawn" disabled><i class="fas fa-lock"></i> INDISPONÍVEL</button>`;
            }

            actionButtonHtml = `
                ${transferBtnHtml}
                <button class="btn-icon btn-edit-nick" title="Editar Apelido"><i class="fas fa-pen"></i></button>
                ${garageActionBtn}
            `;
        }

        card.innerHTML = `
            <div class="card-top">
                <div class="vehicle-info">
                    <div class="vehicle-title-row">
                        <h3>${veh.model}</h3>
                        ${nicknameHtml}
                        <span class="status-badge ${statusBadgeClass}">${statusText}</span>
                    </div>
                    <p class="plate-sub">PLACA: ${veh.plate}</p>
                </div>
                <div class="card-actions">
                    ${actionButtonHtml}
                </div>
            </div>
            <div class="stats-grid">
                <div class="stat-item">
                    <span class="stat-label"><span><i class="fas fa-microchip"></i> Motor</span> <b>${enginePct}%</b></span>
                    <div class="progress-bar-bg">
                        <div class="progress-bar-fill" style="width: ${enginePct}%"></div>
                    </div>
                </div>
                <div class="stat-item">
                    <span class="stat-label"><span><i class="fas fa-car-crash"></i> Lataria</span> <b>${bodyPct}%</b></span>
                    <div class="progress-bar-bg">
                        <div class="progress-bar-fill" style="width: ${bodyPct}%"></div>
                    </div>
                </div>
                <div class="stat-item">
                    <span class="stat-label"><span><i class="fas fa-gas-pump"></i> Combustível</span> <b>${fuelPct}%</b></span>
                    <div class="progress-bar-bg">
                        <div class="progress-bar-fill" style="width: ${fuelPct}%"></div>
                    </div>
                </div>
                <div class="stat-item">
                    <span class="stat-label"><span><i class="fas fa-road"></i> KM</span> <b>${mileageVal}</b></span>
                    <div class="progress-bar-bg">
                        <div class="progress-bar-fill" style="width: ${Math.min(100, Math.round(mileageVal / 10))}%"></div>
                    </div>
                </div>
            </div>
        `;

        // Event Listeners
        const editNickBtn = card.querySelector('.btn-edit-nick');
        if (editNickBtn) {
            editNickBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                openNicknameModal(veh.plate, veh.nickname);
            });
        }

        const trackBtn = card.querySelector('.btn-track');
        if (trackBtn) {
            trackBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                if (veh.streetCoords) {
                    fetch(`https://${GetParentResourceName()}/trackVehicle`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            x: veh.streetCoords.x,
                            y: veh.streetCoords.y
                        })
                    });
                }
            });
        }

        const trackGarageBtns = card.querySelectorAll('.btn-track-garage');
        trackGarageBtns.forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                const gid = btn.getAttribute('data-garage') || veh.garage || 'legion_square';
                fetch(`https://${GetParentResourceName()}/trackGarage`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        garageId: gid
                    })
                });
            });
        });

        const valetActionBtns = card.querySelectorAll('.btn-valet-action');
        valetActionBtns.forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                closeApp();
                fetch(`https://${GetParentResourceName()}/valetGarageVehicle`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ plate: veh.plate })
                });
            });
        });

        const recoverBtn = card.querySelector('.btn-recover-stranded');
        if (recoverBtn) {
            recoverBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                recoverBtn.disabled = true;
                recoverBtn.innerHTML = `<i class="fas fa-spinner fa-spin"></i> REBOCANDO...`;
                fetch(`https://${GetParentResourceName()}/recoverStrandedVehicle`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ plate: veh.plate })
                }).then(res => res.json()).then(resp => {
                    if (resp && resp.ok) {
                        closeApp();
                    } else {
                        recoverBtn.disabled = false;
                        recoverBtn.innerHTML = `<i class="fas fa-truck-pickup"></i> REBOCAR P/ CENTRAL ($500)`;
                    }
                }).catch(() => {
                    recoverBtn.disabled = false;
                    recoverBtn.innerHTML = `<i class="fas fa-truck-pickup"></i> REBOCAR P/ CENTRAL ($500)`;
                });
            });
        }

        const garageSpawnBtn = card.querySelector('.btn-garage-spawn');
        if (garageSpawnBtn) {
            garageSpawnBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                fetch(`https://${GetParentResourceName()}/spawnVehicle`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        plate: veh.plate,
                        garageId: currentGarageId
                    })
                });
            });
        }

        const transferBtn = card.querySelector('.btn-transfer');
        if (transferBtn) {
            transferBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                fetch(`https://${GetParentResourceName()}/transferVehicle`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        plate: veh.plate
                    })
                });
            });
        }

        const unparkBtn = card.querySelector('.btn-unpark');
        if (unparkBtn) {
            unparkBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                fetch(`https://${GetParentResourceName()}/unparkVehicle`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        plate: veh.plate
                    })
                });
            });
        }

        vehicleList.appendChild(card);
    });
}

function renderLogsTable(logs) {
    if (!logsTbody) return;
    logsTbody.innerHTML = '';

    if (!logs || logs.length === 0) {
        if (noLogsMsg) noLogsMsg.classList.remove('hidden');
        return;
    }

    if (noLogsMsg) noLogsMsg.classList.add('hidden');

    logs.forEach(log => {
        const tr = document.createElement('tr');

        const isRetirada = log.action === 'retirada';
        const actionHtml = isRetirada 
            ? `<span class="badge-action badge-action-retirada"><i class="fas fa-arrow-up"></i> Retirada</span>`
            : `<span class="badge-action badge-action-devolucao"><i class="fas fa-arrow-down"></i> Devolução</span>`;

        const fuelVal = Math.min(100, Math.max(0, Math.round(log.fuel || 100)));
        const fuelHtml = `
            <div style="display: flex; align-items: center; gap: 6px;">
                <i class="fas fa-gas-pump" style="color: ${fuelVal < 25 ? '#ef4444' : '#10b981'}; font-size: 0.75rem;"></i>
                <span style="font-weight: 600;">${fuelVal}%</span>
            </div>
        `;

        const eng = Math.round(log.engine_health || 1000);
        const bdy = Math.round(log.body_health || 1000);

        let healthCls = 'health-intact';
        let healthLabel = 'Intacto';
        if (eng < 650 || bdy < 650) {
            healthCls = 'health-critical';
            healthLabel = 'Crítico';
        } else if (eng < 880 || bdy < 880) {
            healthCls = 'health-damaged';
            healthLabel = 'Avariado';
        }

        const healthHtml = `
            <span class="health-badge ${healthCls}">
                <i class="fas fa-shield"></i> ${healthLabel} (${Math.round((eng / 1000) * 100)}% M / ${Math.round((bdy / 1000) * 100)}% L)
            </span>
        `;

        tr.innerHTML = `
            <td style="color: var(--text-muted); font-family: 'JetBrains Mono', monospace; font-size: 0.72rem;">${log.formatted_date || 'Recente'}</td>
            <td>${actionHtml}</td>
            <td>
                <div class="condutor-info">
                    <span class="condutor-name">${log.player_name || 'Agente'}</span>
                    <span class="condutor-id">${log.citizenid || 'N/A'}</span>
                </div>
            </td>
            <td>
                <span style="font-weight: 600;">${log.model || 'Viatura'}</span><br>
                <span class="plate-badge-sm">${log.plate}</span>
            </td>
            <td>${fuelHtml}</td>
            <td>${healthHtml}</td>
        `;

        logsTbody.appendChild(tr);
    });
}

if (corporateLogsBtn) {
    corporateLogsBtn.addEventListener('click', () => {
        if (!currentGarageId) return;
        fetch(`https://${GetParentResourceName()}/fetchGarageLogs`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ garageId: currentGarageId })
        }).then(res => res.json()).then(resp => {
            if (resp && resp.success) {
                currentGarageLogs = resp.logs || [];
                if (logsModalTitle) logsModalTitle.innerText = `Livro de Bordo — ${resp.garageLabel || 'Corporação'}`;
                renderLogsTable(currentGarageLogs);
                if (corporateLogsModal) corporateLogsModal.classList.remove('hidden');
            }
        });
    });
}

if (logsSearchInput) {
    logsSearchInput.addEventListener('input', (e) => {
        const q = e.target.value.toLowerCase().trim();
        if (!q) {
            renderLogsTable(currentGarageLogs);
            return;
        }
        const filtered = currentGarageLogs.filter(l => {
            const name = (l.player_name || '').toLowerCase();
            const cid = (l.citizenid || '').toLowerCase();
            const plate = (l.plate || '').toLowerCase();
            const model = (l.model || '').toLowerCase();
            return name.includes(q) || cid.includes(q) || plate.includes(q) || model.includes(q);
        });
        renderLogsTable(filtered);
    });
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'openGarage') {
        currentMode = 'garage';
        currentGarageId = data.garageId;
        hasTransferContract = !!data.hasTransferContract;
        garageTitle.innerText = data.title || 'Haze Garages';
        searchInput.value = '';
        allVehicles = data.vehicles || [];
        renderCards(allVehicles);

        if (corporateLogsBtn) {
            if (data.canViewLogs) {
                corporateLogsBtn.classList.remove('hidden');
            } else {
                corporateLogsBtn.classList.add('hidden');
            }
        }

        if (modalContainer) modalContainer.classList.remove('hidden');
        if (phonePreviewModal) phonePreviewModal.classList.add('hidden');
        if (corporateLogsModal) corporateLogsModal.classList.add('hidden');
        app.classList.remove('hidden');
    } else if (data.action === 'openVehicleList') {
        currentMode = 'list';
        currentGarageId = null;
        hasTransferContract = !!data.hasTransferContract;
        garageTitle.innerText = data.title || '🚗 Meus Veículos';
        searchInput.value = '';
        allVehicles = data.vehicles || [];
        renderCards(allVehicles);

        if (corporateLogsBtn) corporateLogsBtn.classList.add('hidden');
        if (modalContainer) modalContainer.classList.remove('hidden');
        if (phonePreviewModal) phonePreviewModal.classList.add('hidden');
        if (corporateLogsModal) corporateLogsModal.classList.add('hidden');
        app.classList.remove('hidden');
    } else if (data.action === 'openPhoneNUI') {
        if (modalContainer) modalContainer.classList.add('hidden');
        if (corporateLogsModal) corporateLogsModal.classList.add('hidden');
        if (phonePreviewModal) {
            phonePreviewModal.classList.remove('hidden');
            if (phoneIframe && phoneIframe.contentWindow) {
                phoneIframe.contentWindow.postMessage({ action: 'refreshPhoneVehicles' }, '*');
            }
        }
        app.classList.remove('hidden');
    } else if (data.action === 'openCorporateLogs') {
        currentGarageLogs = data.logs || [];
        if (logsModalTitle) logsModalTitle.innerText = `Livro de Bordo — ${data.garageLabel || 'Corporação'}`;
        renderLogsTable(currentGarageLogs);
        if (modalContainer) modalContainer.classList.add('hidden');
        if (phonePreviewModal) phonePreviewModal.classList.add('hidden');
        if (corporateLogsModal) corporateLogsModal.classList.remove('hidden');
        app.classList.remove('hidden');
    } else if (data.action === 'closeGarage') {
        app.classList.add('hidden');
        nicknameModal.classList.add('hidden');
        if (phonePreviewModal) phonePreviewModal.classList.add('hidden');
        if (corporateLogsModal) corporateLogsModal.classList.add('hidden');
    }
});
