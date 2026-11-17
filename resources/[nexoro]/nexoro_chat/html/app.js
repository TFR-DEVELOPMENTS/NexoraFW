'use strict';
const post = (n, d) => fetch(`https://${GetParentResourceName()}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d || {}) });
const log = document.getElementById('log'), chat = document.getElementById('chat'), form = document.getElementById('input');
const text = document.getElementById('text'), channel = document.getElementById('channel');
const safeColour = (c) => (/^#[0-9a-fA-F]{6}$/.test(c) ? c : '#ffffff');

function add(m) {
  const row = document.createElement('div');
  row.className = 'msg' + (m.action ? ' action' : '');
  const mk = (cls, t, colour) => { const s = document.createElement('span'); s.className = cls; s.textContent = t; if (colour) s.style.color = safeColour(colour); return s; };
  if (m.time) row.append(mk('t', m.time));
  if (m.channel && m.channel !== 'local' && m.channelLabel) row.append(mk('c', `[${m.channelLabel}]`, m.channelColour));
  if (m.prefix) row.append(mk('p', `[${m.prefix.label}]`, m.prefix.colour));
  if (m.name) row.append(mk('n', m.pmTo ? `${m.name} to ${m.pmTo}` : m.name, m.prefix && m.prefix.colour));
  row.append(mk('x', (m.name ? ': ' : '') + m.text));   // textContent only: message text can never inject markup
  log.append(row);
  while (log.children.length > 120) log.firstChild.remove();
  log.scrollTop = log.scrollHeight;
  setTimeout(() => row.classList.add('old'), 9000);
}

window.addEventListener('message', (e) => {
  const m = e.data;
  if (m.action === 'message') add(m.message);
  else if (m.action === 'openInput') { chat.classList.add('active'); form.classList.remove('hidden'); text.value = ''; text.focus(); }
  else if (m.action === 'closeInput') { chat.classList.remove('active'); form.classList.add('hidden'); }
});
form.addEventListener('submit', (e) => { e.preventDefault(); post('submit', { text: text.value, channel: channel.value }); });
window.addEventListener('keydown', (e) => { if (e.key === 'Escape') post('close'); });
