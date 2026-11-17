'use strict';
const C = window.NEXORO_LOADING;
const $ = (id) => document.getElementById(id);
$('logo').textContent = C.serverName.toUpperCase(); $('tagline').textContent = C.tagline; $('dev').textContent = `DEVELOPED BY ${C.developer}`;
$('community').textContent = `Discord: ${C.community.discord}  ·  Web: ${C.community.website}`;
C.rules.forEach((r) => { const li = document.createElement('li'); li.textContent = r; $('rules').append(li); });
C.social.forEach((s) => { const sp = document.createElement('span'); sp.textContent = `${s.label}: ${s.value}`; $('social').append(sp); });

// Panels
const panels = [...C.panels, { title: 'Recruitment', body: C.recruitment }];
panels.forEach(() => $('dots').append(document.createElement('i')));
let pi = 0;
function showPanel() {
  const p = panels[pi % panels.length];
  const node = $('panel'); node.style.animation = 'none'; void node.offsetWidth; node.style.animation = '';
  $('ptitle').textContent = p.title; $('pbody').textContent = p.body;
  [...$('dots').children].forEach((d, i) => d.classList.toggle('on', i === pi % panels.length));
  pi += 1;
}
showPanel(); setInterval(showPanel, 8000);

// Announcements
let ai = 0; function tick() { $('ticker').textContent = C.announcements.length ? C.announcements[ai++ % C.announcements.length] : ''; } tick(); setInterval(tick, 6000);

// Background artwork (optional)
const img = new Image(); img.onload = () => { $('bg').style.backgroundImage = `url(${C.background})`; $('bg').classList.add('art'); }; img.src = C.background;

// Real loading progress from FiveM
const phases = { startInitFunctionOrder: 'Starting game systems', initFunctionInvoking: 'Initialising', startDataFileEntries: 'Loading game data', performMapLoadFunction: 'Loading the map', onDataFileEntry: 'Loading game data' };
let shown = 0;
function setProgress(fraction, text) {
  const pct = Math.max(shown, Math.min(100, Math.round(fraction * 100))); shown = pct;
  $('fill').style.width = `${pct}%`; $('pct').textContent = `${pct}%`; if (text) $('stext').textContent = text;
}
window.addEventListener('message', (e) => {
  const d = e.data; if (!d || !d.eventName) return;
  if (d.eventName === 'loadProgress') setProgress(d.loadFraction || 0, shown >= 99 ? 'Almost there' : 'Loading');
  else if (phases[d.eventName]) {
    let f = shown / 100;
    if (d.idx != null && d.count) f = Math.max(f, d.idx / d.count);
    setProgress(f, phases[d.eventName] + (d.name ? `: ${String(d.name).slice(0, 28)}` : ''));
  }
});

// Music (controls disabled when the track is missing)
const audio = $('audio'), play = $('play'), mute = $('mute'), vol = $('vol');
const store = { get: (k, d) => { try { const v = localStorage.getItem(k); return v === null ? d : v; } catch (e) { return d; } }, set: (k, v) => { try { localStorage.setItem(k, v); } catch (e) { /* storage unavailable */ } } };
vol.value = store.get('nexoro_vol', Math.round(C.music.volume * 100)); audio.volume = vol.value / 100; audio.muted = store.get('nexoro_mute', '0') === '1';
const refresh = () => { play.textContent = audio.paused ? '▶' : '❚❚'; mute.textContent = audio.muted ? '✕' : '♪'; };
audio.addEventListener('error', () => { [play, mute, vol].forEach((c) => { c.disabled = true; }); $('mhint').textContent = 'No music file installed'; });
audio.src = C.music.file;
audio.play().then(refresh).catch(refresh);
play.addEventListener('click', () => { if (audio.paused) audio.play().then(refresh); else { audio.pause(); refresh(); } });
mute.addEventListener('click', () => { audio.muted = !audio.muted; store.set('nexoro_mute', audio.muted ? '1' : '0'); refresh(); });
vol.addEventListener('input', () => { audio.volume = vol.value / 100; if (audio.muted && vol.value > 0) { audio.muted = false; store.set('nexoro_mute', '0'); } store.set('nexoro_vol', vol.value); refresh(); });
refresh();
