'use strict';
const post = (n, d) => fetch(`https://${GetParentResourceName()}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d || {}) }).then((r) => r.json()).catch(() => ({}));
const $ = (id) => document.getElementById(id);
const el = (tag, props, ...kids) => { const n = document.createElement(tag); for (const [k, v] of Object.entries(props || {})) { if (k === 'class') n.className = v; else if (k === 'text') n.textContent = v; else if (k.startsWith('on')) n.addEventListener(k.slice(2), v); else if (v !== undefined && v !== null) n.setAttribute(k, v); } kids.flat().forEach((c) => c != null && n.append(c)); return n; };
const box = $('box');
let mode = null, pTimer = null;

function show(kind, ...nodes) { mode = kind; box.replaceChildren(...nodes); $('overlay').classList.remove('hidden'); }
function hide() { mode = null; $('overlay').classList.add('hidden'); box.replaceChildren(); }
const submit = (result) => post('modalResult', { result });

function context(m) {
  const nodes = [];
  if (m.back) nodes.push(el('button', { class: 'back', type: 'button', onclick: () => post('contextBack') }, '‹ Back'));
  nodes.push(el('h2', { text: m.title }));
  m.options.forEach((o, i) => {
    const meta = (o.metadata || []).map((x) => el('div', { class: 'meta' }, el('span', { text: x.label }), el('span', { text: String(x.value) })));
    const bar = o.progress != null ? el('div', { class: 'bar' }, el('i', { style: `width:${Math.max(0, Math.min(100, o.progress))}%` })) : null;
    nodes.push(el('button', { class: 'opt', type: 'button', disabled: o.disabled ? 'disabled' : null, onclick: () => post('contextSelect', { index: i + 1 }) },
      o.icon ? el('span', { class: 'ic', text: o.icon }) : null,
      el('span', { class: 'tx' }, o.title, o.description ? el('small', { text: o.description }) : null, meta, bar),
      o.arrow ? el('span', { class: 'ar', text: '›' }) : null));
  });
  nodes.push(el('button', { class: 'footer-close', type: 'button', onclick: () => post('modalCancel') }, 'Close menu'));
  show('context', ...nodes);
  const first = box.querySelector('.opt:not(:disabled)'); if (first) first.focus();
}

function inputDialog(m) {
  const form = el('form', { autocomplete: 'off' }, el('h2', { text: m.title }));
  const ctrls = [];
  m.fields.forEach((f) => {
    let c;
    if (f.type === 'select') c = el('select', {}, (f.options || []).map((o) => { const v = typeof o === 'object' ? o.value : o; const l = typeof o === 'object' ? (o.label ?? o.value) : o; return el('option', { value: v, text: l }); }));
    else if (f.type === 'checkbox') c = el('input', { type: 'checkbox', style: 'width:auto' });
    else if (f.type === 'textarea') c = el('textarea', { maxlength: f.maxLength || 500 });
    else if (f.type === 'number') c = el('input', { type: 'number', min: f.min, max: f.max, step: f.step || 'any' });
    else c = el('input', { type: 'text', maxlength: f.maxLength || 100 });
    if (f.placeholder) c.placeholder = f.placeholder;
    if (f.default != null) { if (f.type === 'checkbox') c.checked = !!f.default; else c.value = f.default; }
    const wrap = el('div', { class: 'f' }, el('label', { text: f.label + (f.required ? ' *' : '') }), c);
    ctrls.push([f, c, wrap]);
    form.append(wrap);
  });
  form.append(el('div', { class: 'row' }, el('button', { type: 'button', onclick: () => post('modalCancel') }, 'Cancel'), el('button', { type: 'submit', class: 'primary', text: m.submitLabel || 'Submit' })));
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const out = {}; let bad = false;
    ctrls.forEach(([f, c, wrap]) => {
      let v = f.type === 'checkbox' ? c.checked : f.type === 'number' ? (c.value === '' ? null : Number(c.value)) : c.value.trim();
      const empty = v === '' || v === null;
      if (f.required && empty) { wrap.classList.add('err'); bad = true; } else wrap.classList.remove('err');
      out[f.name] = empty ? null : v;
    });
    if (!bad) submit(out);
  });
  show('input', form);
  const first = form.querySelector('input,select,textarea'); if (first) first.focus();
}

function confirmDialog(m, alert) {
  const nodes = [el('h2', { text: m.title }), el('p', { text: m.text })];
  const row = el('div', { class: 'row' });
  if (!alert) row.append(el('button', { type: 'button', onclick: () => submit(false) }, m.cancelLabel || 'Cancel'));
  const ok = el('button', { type: 'button', class: m.danger ? 'danger' : 'primary', onclick: () => submit(true), text: alert ? (m.buttonLabel || 'OK') : (m.confirmLabel || 'Confirm') });
  row.append(ok); nodes.push(row); show(alert ? 'alert' : 'confirm', ...nodes); ok.focus();
}

window.addEventListener('message', (e) => {
  const m = e.data;
  switch (m.action) {
    case 'opencontext': context(m); break;
    case 'openinput': inputDialog(m); break;
    case 'openconfirm': confirmDialog(m, false); break;
    case 'openalert': confirmDialog(m, true); break;
    case 'closeModal': hide(); break;
    case 'progressStart': {
      $('plabel').textContent = m.label; $('phint').classList.toggle('hidden', !m.canCancel); $('progress').classList.remove('hidden');
      const fill = $('pfill'); fill.style.transition = 'none'; fill.style.width = '0%'; void fill.offsetWidth; fill.style.transition = `width ${m.duration}ms linear`; fill.style.width = '100%';
      break; }
    case 'progressEnd': clearTimeout(pTimer); $('pfill').style.transition = 'none'; $('progress').classList.add('hidden'); break;
    case 'textShow': $('tkey').textContent = m.key || ''; $('ttext').textContent = m.text; $('textui').classList.remove('hidden'); break;
    case 'textHide': $('textui').classList.add('hidden'); break;
  }
});
window.addEventListener('keydown', (e) => { if (e.key === 'Escape' && mode) post('modalCancel'); });
