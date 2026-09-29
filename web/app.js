const app = document.getElementById('app');
const closeBtn = document.getElementById('close-btn');

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

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'openGarage') {
        app.classList.remove('hidden');
    } else if (data.action === 'closeGarage') {
        app.classList.add('hidden');
    }
});
