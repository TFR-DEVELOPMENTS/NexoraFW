'use strict';
const $ = (id) => document.getElementById(id);
const RINGS = [['health', 'HP'], ['armour', 'AR'], ['hunger', 'FD'], ['thirst', 'WT'], ['stress', 'ST'], ['stamina', 'SP']];
const gbp = (n) => (n == null ? '' : '£' + Number(n).toLocaleString('en-GB', { minimumFractionDigits: 2, maximumFractionDigits: 2 }));
const ringEls = {};
RINGS.forEach(([key, label]) => {
  const ring = document.createElement('div'); ring.className = `ring ${key}`; ring.dataset.el = key;
  const s = document.createElement('span'); s.textContent = label; ring.append(s); $('rings').append(ring); ringEls[key] = ring;
});
function applySettings(s) {
  $('hud').dataset.pos = s.position; document.documentElement.style.setProperty('--scale', s.scale);
  document.querySelectorAll('[data-el]').forEach((e) => { e.dataset.hidden = s.hidden && s.hidden[e.dataset.el] ? '1' : '0'; });
}
function update(d) {
  $('hud').classList.remove('hidden');
  RINGS.forEach(([key]) => {
    const v = Math.max(0, Math.min(100, d[key] ?? 0));
    ringEls[key].style.setProperty('--p', key === 'stress' || key === 'stamina' ? v : v);
    ringEls[key].classList.toggle('low', (key === 'health' || key === 'hunger' || key === 'thirst') && v <= 15);
  });
  $('who').textContent = d.name ? `${d.name}  ·  ID ${d.id}` : `ID ${d.id}`;
  $('job').textContent = d.job ? `${d.job}${d.onDuty ? ' · On duty' : ''}` : '';
  $('cash').textContent = gbp(d.cash); $('bank').textContent = gbp(d.bank);
  $('compass').textContent = d.compass || ''; $('street').textContent = d.street || ''; $('zone').textContent = d.zone || '';
  $('mic').classList.toggle('on', !!d.talking); $('vmode').textContent = d.voiceMode || ''; $('radio').textContent = d.radio ? d.radio : '';
  const v = d.vehicle; $('vehicle').classList.toggle('hidden', !v);
  if (v) { $('spd').textContent = v.speed; $('fuel').style.width = `${v.fuel}%`; $('eng').style.width = `${v.engine}%`; $('belt').textContent = v.seatbelt ? 'Seatbelt on' : 'Seatbelt off (B)'; $('belt').classList.toggle('on', v.seatbelt); }
}
window.addEventListener('message', (e) => {
  const m = e.data;
  if (m.action === 'update') update(m.data);
  else if (m.action === 'settings') applySettings(m.settings);
  else if (m.action === 'clear') $('hud').classList.add('hidden');
});
