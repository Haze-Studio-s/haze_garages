const app = document.getElementById('app');
const closeBtn = document.getElementById('close-btn');
const vehicleList = document.getElementById('vehicle-list');
const garageTitle = document.getElementById('garage-title');

let currentGarageId = null;

function closeNUI() {
    app.classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

closeBtn.addEventListener('click', closeNUI);

window.addEventListener('keyup', (e) => {
    if (e.key === 'Escape') {
        closeNUI();
    }
});

function renderVehicles(vehicles, garageId) {
    currentGarageId = garageId;
    vehicleList.innerHTML = '';

    if (!vehicles || vehicles.length === 0) {
        vehicleList.innerHTML = '<div class="no-vehicles">Nenhum veículo disponível nesta garagem.</div>';
        return;
    }

    vehicles.forEach(veh => {
        const card = document.createElement('div');
        card.className = 'vehicle-card';

        const enginePct = Math.min(100, Math.max(0, Math.round((veh.engine / 1000) * 100)));
        const bodyPct = Math.min(100, Math.max(0, Math.round((veh.body / 1000) * 100)));
        const fuelPct = Math.min(100, Math.max(0, Math.round(veh.fuel)));

        card.innerHTML = `
            <div class="card-top">
                <div class="vehicle-info">
                    <h3>${veh.model}</h3>
                    <p>PLACA: ${veh.plate}</p>
                </div>
                <button class="btn-spawn" data-plate="${veh.plate}">RETIRAR</button>
            </div>
            <div class="stats-grid">
                <div class="stat-item">
                    <span class="stat-label"><i class="fas fa-engine"></i> Motor: ${enginePct}%</span>
                    <div class="progress-bar-bg">
                        <div class="progress-bar-fill" style="width: ${enginePct}%"></div>
                    </div>
                </div>
                <div class="stat-item">
                    <span class="stat-label"><i class="fas fa-car-crash"></i> Lataria: ${bodyPct}%</span>
                    <div class="progress-bar-bg">
                        <div class="progress-bar-fill" style="width: ${bodyPct}%"></div>
                    </div>
                </div>
                <div class="stat-item">
                    <span class="stat-label"><i class="fas fa-gas-pump"></i> Combustível: ${fuelPct}%</span>
                    <div class="progress-bar-bg">
                        <div class="progress-bar-fill" style="width: ${fuelPct}%"></div>
                    </div>
                </div>
            </div>
        `;

        const spawnBtn = card.querySelector('.btn-spawn');
        spawnBtn.addEventListener('click', (e) => {
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

        vehicleList.appendChild(card);
    });
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'openGarage') {
        garageTitle.innerText = data.title || 'Haze Garages';
        renderVehicles(data.vehicles || [], data.garageId);
        app.classList.remove('hidden');
    } else if (data.action === 'closeGarage') {
        app.classList.add('hidden');
    }
});
