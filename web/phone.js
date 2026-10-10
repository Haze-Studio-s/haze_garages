const searchInput = document.getElementById('phone-search-input');
const vehicleList = document.getElementById('phone-vehicle-list');
const refreshBtn = document.getElementById('refresh-btn');
const countInfo = document.getElementById('vehicle-count-info');

let allVehicles = [];

const RESOURCE_NAME = 'haze_garages';

function fetchNui(event, data = {}) {
    const parentResource = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : RESOURCE_NAME;
    return fetch(`https://${parentResource}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).then(res => res.json()).catch(err => console.error('Error fetching NUI:', err));
}

function loadVehicles() {
    if (!vehicleList) return;
    vehicleList.innerHTML = `
        <div class="loading-state">
            <i class="fas fa-spinner fa-spin"></i>
            <p>Carregando seus veículos...</p>
        </div>
    `;

    fetchNui('getPhoneVehicles').then(res => {
        if (res && res.vehicles) {
            allVehicles = res.vehicles;
            renderVehicles(allVehicles);
        } else {
            renderVehicles([]);
        }
    }).catch(() => {
        renderVehicles([]);
    });
}

function renderVehicles(vehicles) {
    if (!vehicleList) return;
    vehicleList.innerHTML = '';
    if (countInfo) countInfo.innerText = `${vehicles.length} veículo(s) cadastrado(s)`;

    if (!vehicles || vehicles.length === 0) {
        vehicleList.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-car-side"></i>
                <p>Nenhum veículo encontrado.</p>
            </div>
        `;
        return;
    }

    vehicles.forEach(veh => {
        const card = document.createElement('div');
        card.className = 'phone-card';

        const enginePct = Math.min(100, Math.max(0, Math.round((veh.engine / 1000) * 100)));
        const bodyPct = Math.min(100, Math.max(0, Math.round((veh.body / 1000) * 100)));
        const fuelPct = Math.min(100, Math.max(0, Math.round(veh.fuel || 100)));

        // Status Badge Logic
        let statusClass = 'status-fixed';
        let statusText = veh.statusLabel || 'Garagem';
        if (veh.spawnType === 'street') {
            statusClass = 'status-street';
        } else if (veh.spawnType === 'out') {
            statusClass = 'status-out';
        } else if (veh.spawnType === 'impound') {
            statusClass = 'status-impound';
        } else if (veh.spawnType === 'insurance' || veh.state === 3) {
            statusClass = 'status-insurance';
        }

        // Tracker Tag Logic
        let trackerHtml = '';
        let canTrack = false;
        if (!veh.trackerInstalled) {
            trackerHtml = `<span class="tracker-tag tracker-none"><i class="fas fa-unlink"></i> Sem Rastreador GPS</span>`;
        } else if (veh.isJammed) {
            trackerHtml = `<span class="tracker-tag tracker-jammed"><i class="fas fa-ban"></i> Sinal GPS Bloqueado (Jammer)</span>`;
        } else {
            trackerHtml = `<span class="tracker-tag tracker-active"><i class="fas fa-satellite-dish"></i> GPS Ativo</span>`;
            canTrack = true;
        }

        const nickHtml = veh.nickname ? `<span class="nick-tag"><i class="fas fa-tag"></i> ${veh.nickname}</span>` : '';

        let actionsHtml = '';
        if (veh.spawnType === 'insurance' || veh.state === 3) {
            actionsHtml = `
                <button class="action-btn btn-insurance" data-plate="${veh.plate}" style="background-color: rgba(220, 38, 38, 0.85); color: #fff; width: 100%; border: 1px solid #ef4444;">
                    <i class="fas fa-shield-halved"></i> Acionar Mors Mutual
                </button>
            `;
        } else {
            actionsHtml = `
                <button class="action-btn btn-gps" ${!canTrack ? 'disabled' : ''} title="${canTrack ? 'Marcar localização no mapa' : 'GPS indisponível'}">
                    <i class="fas fa-location-dot"></i> Rastrear
                </button>
                <button class="action-btn btn-valet" data-plate="${veh.plate}">
                    <i class="fas fa-key"></i> Valet
                </button>
                ${veh.isOwner !== false ? `<button class="action-btn btn-coowner" data-plate="${veh.plate}" title="Gerenciar Condutor Autorizado ($1.000)"><i class="fas fa-user-friends"></i> Condutor</button>` : ''}
            `;
        }

        card.innerHTML = `
            <div class="card-header-row">
                <div class="veh-name-group">
                    <h3>${veh.model}</h3>
                    ${nickHtml}
                    <span class="plate-code">PLACA: ${veh.plate}</span>
                </div>
                <span class="status-badge ${statusClass}">${statusText}</span>
            </div>

            <div class="tracker-row">
                <span style="color: var(--text-muted); font-size: 0.68rem;">Rastreador:</span>
                ${trackerHtml}
            </div>

            <div class="stats-row">
                <div class="mini-stat">
                    <span class="mini-stat-label"><span>Motor</span> <b>${enginePct}%</b></span>
                    <div class="mini-bar-bg"><div class="mini-bar-fill" style="width: ${enginePct}%"></div></div>
                </div>
                <div class="mini-stat">
                    <span class="mini-stat-label"><span>Lataria</span> <b>${bodyPct}%</b></span>
                    <div class="mini-bar-bg"><div class="mini-bar-fill" style="width: ${bodyPct}%"></div></div>
                </div>
                <div class="mini-stat">
                    <span class="mini-stat-label"><span>Combustível</span> <b>${fuelPct}%</b></span>
                    <div class="mini-bar-bg"><div class="mini-bar-fill" style="width: ${fuelPct}%"></div></div>
                </div>
            </div>

            <div class="card-actions-row">
                ${actionsHtml}
            </div>
        `;

        const insuranceBtn = card.querySelector('.btn-insurance');
        if (insuranceBtn) {
            insuranceBtn.addEventListener('click', () => {
                fetchNui('openInsuranceManager', { plate: veh.plate });
            });
        }

        const gpsBtn = card.querySelector('.btn-gps');
        if (gpsBtn && canTrack) {
            gpsBtn.addEventListener('click', () => {
                fetchNui('trackPhoneVehicle', { plate: veh.plate });
            });
        }

        const valetBtn = card.querySelector('.btn-valet');
        if (valetBtn) {
            valetBtn.addEventListener('click', () => {
                fetchNui('valetPhoneVehicle', { plate: veh.plate });
            });
        }

        const coownerBtn = card.querySelector('.btn-coowner');
        if (coownerBtn) {
            coownerBtn.addEventListener('click', () => {
                fetchNui('openCoOwnerManager', { plate: veh.plate });
            });
        }

        vehicleList.appendChild(card);
    });
}

if (searchInput) {
    searchInput.addEventListener('input', (e) => {
        const q = e.target.value.toLowerCase().trim();
        if (!q) {
            renderVehicles(allVehicles);
            return;
        }
        const filtered = allVehicles.filter(v => {
            return (v.model || '').toLowerCase().includes(q) ||
                   (v.nickname || '').toLowerCase().includes(q) ||
                   (v.plate || '').toLowerCase().includes(q);
        });
        renderVehicles(filtered);
    });
}

if (refreshBtn) {
    refreshBtn.addEventListener('click', loadVehicles);
}

// Trigger initial vehicle load
loadVehicles();

window.addEventListener('message', (e) => {
    if (e.data && e.data.action === 'refreshPhoneVehicles') {
        loadVehicles();
    }
});
