const app = document.getElementById('app');
const closeBtn = document.getElementById('close-btn');
const vehicleList = document.getElementById('vehicle-list');
const garageTitle = document.getElementById('garage-title');
const searchInput = document.getElementById('search-input');

// Nickname Modal Elements
const nicknameModal = document.getElementById('nickname-modal');
const nicknameInput = document.getElementById('nickname-input');
const promptPlateInfo = document.getElementById('prompt-plate-info');
const saveNicknameBtn = document.getElementById('save-nickname-btn');
const cancelNicknameBtn = document.getElementById('cancel-nickname-btn');

let currentMode = 'garage'; // 'garage' or 'list'
let currentGarageId = null;
let allVehicles = [];
let targetPlateForNickname = null;

function closeNUI() {
    app.classList.add('hidden');
    nicknameModal.classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

closeBtn.addEventListener('click', closeNUI);

window.addEventListener('keyup', (e) => {
    if (e.key === 'Escape') {
        if (!nicknameModal.classList.contains('hidden')) {
            nicknameModal.classList.add('hidden');
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
        } else if (veh.spawnType === 'out') {
            statusBadgeClass = 'status-out';
        } else if (veh.spawnType === 'impound') {
            statusBadgeClass = 'status-impound';
        }

        const isListMode = currentMode === 'list';
        let actionButtonHtml = '';

        if (isListMode) {
            let trackBtnHtml = '';
            if (veh.streetCoords) {
                trackBtnHtml = `<button class="btn-icon btn-track" title="Marcar GPS"><i class="fas fa-location-dot"></i></button>`;
            }

            let unparkBtnHtml = '';
            if (veh.isSpawnable) {
                unparkBtnHtml = `<button class="btn-spawn btn-unpark" data-plate="${veh.plate}"><i class="fas fa-key"></i> RETIRAR</button>`;
            } else {
                unparkBtnHtml = `<button class="btn-spawn" disabled><i class="fas fa-lock"></i> UNVAILABLE</button>`;
            }

            actionButtonHtml = `
                ${trackBtnHtml}
                <button class="btn-icon btn-edit-nick" title="Editar Apelido"><i class="fas fa-pen"></i></button>
                ${unparkBtnHtml}
            `;
        } else {
            actionButtonHtml = `
                <button class="btn-icon btn-edit-nick" title="Editar Apelido"><i class="fas fa-pen"></i></button>
                <button class="btn-spawn btn-garage-spawn" data-plate="${veh.plate}"><i class="fas fa-car-side"></i> RETIRAR</button>
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
                fetch(`https://${GetParentResourceName()}/trackVehicle`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        x: veh.streetCoords.x,
                        y: veh.streetCoords.y
                    })
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

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'openGarage') {
        currentMode = 'garage';
        currentGarageId = data.garageId;
        garageTitle.innerText = data.title || 'Haze Garages';
        searchInput.value = '';
        allVehicles = data.vehicles || [];
        renderCards(allVehicles);
        app.classList.remove('hidden');
    } else if (data.action === 'openVehicleList') {
        currentMode = 'list';
        currentGarageId = null;
        garageTitle.innerText = data.title || '🚗 Meus Veículos';
        searchInput.value = '';
        allVehicles = data.vehicles || [];
        renderCards(allVehicles);
        app.classList.remove('hidden');
    } else if (data.action === 'closeGarage') {
        app.classList.add('hidden');
        nicknameModal.classList.add('hidden');
    }
});
