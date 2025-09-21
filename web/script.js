const raceContainer = document.getElementById('raceContainer');
const raceTimer = document.getElementById('raceTimer');
const p1 = document.getElementById('p1');
const p2 = document.getElementById('p2');
const p3 = document.getElementById('p3');
const youPos = document.getElementById('youPos');
const lapInfo = document.getElementById('lapInfo');
const summaryPanel = document.getElementById('summaryPanel');
const summaryList = document.getElementById('summaryList');
let summaryAutoClose;

function formatTime(ms) {
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  const centi = Math.floor((ms % 1000) / 10);
  return `${String(minutes).padStart(2,'0')}:${String(seconds).padStart(2,'0')}:${String(centi).padStart(2,'0')}`;
}

window.addEventListener('message', (e) => {
  const data = e.data;
  if (!data || !data.action) return;

  switch(data.action){
    case 'show':
      raceContainer.classList.remove('hidden');
      break;
    case 'hide':
      raceContainer.classList.add('hidden');
      break;
    case 'time':
      raceTimer.textContent = formatTime(data.time || 0);
      break;
    case 'positions': {
      const list = data.list || [];
      const me = data.me;
      p1.textContent = `1. ${list[0] ? (list[0].name || list[0].source) : '---'}`;
      p2.textContent = `2. ${list[1] ? (list[1].name || list[1].source) : '---'}`;
      p3.textContent = `3. ${list[2] ? (list[2].name || list[2].source) : '---'}`;
      const myIndex = list.findIndex(p => p.source === me);
      if (myIndex >= 0) {
        youPos.textContent = `Your Place: ${myIndex+1}`;
      }
      break;
    }
    case 'lap': {
      if (typeof data.lap !== 'undefined' && typeof data.laps !== 'undefined') {
        lapInfo.textContent = `Lap ${data.lap}/${data.laps}`;
      }
      break;
    }
    case 'finished':
      break;
    case 'summary': {
      const rows = data.data || [];
      summaryList.innerHTML = '';
      if (!rows.length) {
        summaryList.innerHTML = '<div class="summary-row">No data</div>';
      } else {
        rows.forEach(r => {
          const div = document.createElement('div');
          div.className = 'summary-row' + (r.dnf || !r.finished ? ' dnf' : '');
          const place = r.finished ? r.place : (r.dnf ? 'DNF' : r.place);
          const timeTxt = r.time ? formatTime(r.time) : '--:--:--';
          div.innerHTML = `
            <div>${place}</div>
            <div>${r.name || 'Player'}</div>
            <div>${timeTxt}</div>
            <div>${r.lap ? r.lap : ''}</div>`;
          summaryList.appendChild(div);
        });
      }
      summaryPanel.classList.remove('hidden');
        if (summaryAutoClose) clearTimeout(summaryAutoClose);
        summaryAutoClose = setTimeout(() => {
          summaryPanel.classList.add('hidden');
        }, 15000); // auto hide after 15s
      break;
    }
      case 'hideAll':
        raceContainer.classList.add('hidden');
        summaryPanel.classList.add('hidden');
        break;
  }
});

// Close summary with ESC / Backspace
document.addEventListener('keydown', (e) => {
  if (!summaryPanel.classList.contains('hidden')) {
    if (e.key === 'Escape' || e.key === 'Backspace') {
      summaryPanel.classList.add('hidden');
    }
  }
});
