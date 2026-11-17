'use strict';
const post = (n, d) => fetch(`https://${GetParentResourceName()}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d || {}) }).then((r) => r.json()).catch(() => ({ ok: false, error: 'nui_error' }));
const $ = (id) => document.getElementById(id);
const el = (tag, props, ...kids) => { const n = document.createElement(tag); for (const [k, v] of Object.entries(props || {})) { if (k === 'class') n.className = v; else if (k === 'text') n.textContent = v; else if (k.startsWith('on')) n.addEventListener(k.slice(2), v); else if (v != null) n.setAttribute(k, v); } kids.flat().forEach((c) => c != null && n.append(c)); return n; };
const S = { apps: [], forms: {}, appDefs: {}, app: null, call: null };
let msgT;
function msg(t) { const m = $('msg'); m.textContent = t; m.classList.remove('hidden'); clearTimeout(msgT); msgT = setTimeout(() => m.classList.add('hidden'), 3500); }

function renderApps() {
  $('apps').replaceChildren(...S.apps.map((a) => el('button', { type: 'button', class: a.id === S.app ? 'active' : '', onclick: () => selectApp(a.id) }, a.label)));
}
function selectApp(id) {
  S.app = id; S.call = null; renderApps();
  const def = S.appDefs[id];
  $('title').textContent = def.label;
  $('calls').replaceChildren(...def.calls.map((c) => el('button', { type: 'button', onclick: () => selectCall(c) }, (S.forms[c] && S.forms[c].label) || c)));
  $('form').replaceChildren(); $('result').replaceChildren();
  const auto = def.calls.find((c) => S.forms[c] && S.forms[c].auto);
  if (auto) selectCall(auto);
}
function selectCall(name) {
  S.call = name;
  [...$('calls').children].forEach((b) => b.classList.toggle('active', b.textContent === ((S.forms[name] && S.forms[name].label) || name)));
  const form = S.forms[name] || {};
  const inputs = {};
  const fields = (form.fields || []).map((f) => {
    let c;
    if (f.type === 'select') c = el('select', {}, f.options.map((o) => el('option', { value: o, text: o })));
    else c = el('input', { type: f.type === 'number' ? 'number' : 'text', maxlength: 300 });
    inputs[f.name] = c;
    return el('div', {}, el('label', { text: f.label }), c);
  });
  const run = async () => {
    const payload = {};
    for (const [k, c] of Object.entries(inputs)) payload[k] = c.type === 'number' ? (c.value === '' ? undefined : Number(c.value)) : c.value;
    const res = await post('relay', { app: S.app, call: name, payload });
    showResult(res);
  };
  const back = el('button', { type: 'button', onclick: () => { S.call = null; [...$('calls').children].forEach((b) => b.classList.remove('active')); $('form').replaceChildren(); $('result').replaceChildren(); } }, '‹ Back to options');
  const hint = el('p', { class: 'muted', text: form.hint || (form.auto ? 'Loads automatically. Press Refresh to update.' : 'Fill in the fields, then press Run. The result appears below.') });
  $('form').replaceChildren(back, hint, ...fields, fields.length || !form.auto ? el('button', { type: 'button', class: 'primary', onclick: run }, form.auto ? 'Refresh' : 'Run') : null);
  if (form.auto) run();
  else $('result').replaceChildren();
}
function showResult(res) {
  const box = $('result'); box.replaceChildren();
  if (!res.ok) { msg(String(res.error || 'That did not work.')); return; }
  const d = res.data;
  if (Array.isArray(d)) {
    if (d.length === 0) box.append(el('p', { class: 'empty', text: 'Nothing to show.' }));
    d.forEach((row) => box.append(el('div', { class: 'row' }, Object.entries(row).filter(([, v]) => v !== null && typeof v !== 'object').map(([k, v]) => `${k}: ${v}`).join('  ·  '))));
  } else if (d && typeof d === 'object') {
    box.append(el('div', { class: 'row' }, Object.entries(d).filter(([, v]) => typeof v !== 'object').map(([k, v]) => `${k}: ${v}`).join('  ·  ')));
    if (Array.isArray(d.records)) d.records.forEach((r) => box.append(el('div', { class: 'row' }, r.kind ? `${r.date || ''} ${r.kind}: ${r.detail || ''}` : `${r.date || ''} ${r.detail || ''}`)));
  } else box.append(el('p', { text: 'Done.' }));
}

$('close').addEventListener('click', () => post('close'));
window.addEventListener('keydown', (e) => { if (e.key === 'Escape') post('close'); });
window.addEventListener('message', (e) => {
  const m = e.data;
  if (m.action === 'open') {
    S.apps = m.apps; S.forms = m.forms; S.appDefs = m.appDefs;
    // Each app's call list comes from the server-side allowlist via appDefs; the screen just renders them.
    $('tablet').classList.remove('hidden');
    S.app = null; $('apps').replaceChildren(); $('calls').replaceChildren(); $('form').replaceChildren(); $('result').replaceChildren();
    $('title').textContent = 'Select an app';
    if (S.apps.length) selectApp(S.apps[0].id);
  } else if (m.action === 'close') { $('tablet').classList.add('hidden'); }
});
