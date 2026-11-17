'use strict';
const post = (n, d) => fetch(`https://${GetParentResourceName()}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d || {}) }).then((r) => r.json()).catch(() => ({ ok: false, error: 'nui_error' }));
const rpc = (name, payload) => post('rpc', { name: name.includes(':') && name.startsWith('nexoro_banking') ? name : `nexoro_phone:${name}`, payload });
const $ = (id) => document.getElementById(id);
const el = (tag, props, ...kids) => { const n = document.createElement(tag); for (const [k, v] of Object.entries(props || {})) { if (k === 'class') n.className = v; else if (k === 'text') n.textContent = v; else if (k.startsWith('on')) n.addEventListener(k.slice(2), v); else if (v != null) n.setAttribute(k, v); } kids.flat().forEach((c) => c != null && n.append(c)); return n; };
const fmt = (n) => (/^07\d{9}$/.test(n) ? `${n.slice(0, 5)} ${n.slice(5)}` : n);
const ERR = { no_phone: 'You need a phone.', battery_dead: 'Battery dead.', invalid_number: 'Enter a valid UK mobile number (07xxx xxxxxx).', number_not_found: 'That number is not in service.', unavailable: 'The person you are calling is not available.', busy: 'Line busy.', already_in_call: 'You are already on a call.', own_number: 'That is your own number.', invalid_message: 'Type a message first.', contact_limit: 'Contact list is full.', invalid_name: 'Enter a name (30 characters max).', address_not_found: 'That email address does not exist.', invalid_address: 'Enter a valid email address.', invalid_subject: 'Add a subject.', advert_cooldown: 'You can place another advert in a few minutes.', cannot_afford_advert: 'You cannot afford that advert.', invalid_price: 'Enter a valid price.', insufficient_funds: 'Insufficient funds.', cannot_pay_yourself: 'You cannot pay yourself.', recipient_not_found: 'No character has that Citizen ID.', invalid_recipient: 'Enter a valid Citizen ID.', invalid_amount: 'Enter a valid amount.', rate_limited: 'Slow down a little.', timeout: 'Network busy. Try again.', balance_limit: 'That would exceed the balance limit.' };
const errText = (e) => ERR[e] || 'That did not work. Try again.';

const S = { d: null, stack: [], contacts: [], names: {} };
let toastT;
function toast(msg, ok) { const t = $('toast'); t.textContent = msg; t.className = ok ? 'ok' : ''; clearTimeout(toastT); toastT = setTimeout(() => t.classList.add('hidden'), 3500); }
const nameOf = (n) => S.names[n] || fmt(n);
function setContacts(list) { S.contacts = list; S.names = {}; list.forEach((c) => { S.names[c.number] = c.name; }); }
const money = (n) => `£${Number(n).toLocaleString('en-GB', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

/* ---------- navigation ---------- */
function go(title, build, opts = {}) {
  S.stack.push({ title, build, opts }); draw();
}
function back() { if (S.stack.length > 1) { S.stack.pop(); draw(); } }
function home() { S.stack = []; go('Home', homeScreen, { home: true }); }
async function draw() {
  const cur = S.stack[S.stack.length - 1];
  const scr = $('screen'); [...scr.querySelectorAll('.page')].forEach((n) => n.remove());
  const page = el('div', { class: 'page', style: 'display:flex;flex-direction:column;flex:1;min-height:0' });
  if (!cur.opts.home) page.append(el('div', { class: 'bar' }, el('button', { type: 'button', 'aria-label': 'Back', onclick: back }, '‹'), cur.title));
  const body = el('div', { class: 'body' }); page.append(body); scr.prepend(page);
  await cur.build(body);
}

/* ---------- home ---------- */
const APPS = [['Phone', '☎', phoneApp], ['Messages', '✉', messagesApp], ['Contacts', '☺', contactsApp], ['Bank', '£', bankApp], ['Jobs', '⚒', jobsApp], ['Maps', '⌖', mapsApp], ['Mail', '@', mailApp], ['Adverts', '⚑', advertsApp], ['Chirp', '✦', chirpApp], ['Settings', '⚙', settingsApp]];
const SOON = [['Camera', '◉', 'Needs a screenshot resource'], ['Gallery', '▣', 'Needs a screenshot resource'], ['Gov', '⚖', 'Arrives with public services'], ['Cars', '⛟', 'Arrives with vehicles'], ['Homes', '⌂', 'Arrives with housing'], ['Business', '▤', 'Arrives with businesses']];
function homeScreen(b) {
  const g = el('div', { class: 'grid' });
  APPS.forEach(([name, icon, fn]) => {
    const badge = name === 'Messages' ? S.d.unreadMessages : name === 'Mail' ? S.d.unreadMail : 0;
    g.append(el('button', { class: 'app', type: 'button', onclick: () => go(name, fn) }, el('i', { text: icon }), name, badge > 0 ? el('b', { text: badge }) : null));
  });
  SOON.forEach(([name, icon, why]) => g.append(el('button', { class: 'app off', type: 'button', title: why, onclick: () => toast(`${name}: ${why}.`) }, el('i', { text: icon }), name)));
  b.append(g, el('p', { class: 'muted centre', text: `Your number: ${fmt(S.d.number)}` }));
}

/* ---------- phone ---------- */
async function phoneApp(b) {
  let num = '';
  const shown = el('div', { id: 'dialed' });
  const keys = el('div', { class: 'keys' }, ...'123456789*0#'.split('').map((k) => el('button', { type: 'button', onclick: () => { if (num.length < 11) { num += k; shown.textContent = num; } } }, k)));
  const emergency = el('div', { class: 'row' }, ...[['999', 'Emergency'], ['101', 'Police'], ['111', 'Medical']].map(([n, l]) => el('button', { type: 'button', class: 'g', onclick: () => dial(n) }, `${n}`)));
  b.append(shown, keys, el('div', { class: 'row' }, el('button', { type: 'button', class: 'g', onclick: () => { num = num.slice(0, -1); shown.textContent = num; } }, '⌫'), el('button', { type: 'button', class: 'ok', onclick: () => dial(num) }, 'Call')), el('p', { class: 'muted', text: 'Emergency: 999 · Police non-emergency: 101 · NHS advice: 111' }), emergency);
  const res = await rpc('callLog');
  if (res.ok && res.data.length) { b.append(el('p', { class: 'muted', text: 'Recent' })); res.data.slice(0, 8).forEach((c) => b.append(el('button', { class: 'item', type: 'button', onclick: () => dial(c.number) }, el('span', {}, nameOf(c.number), el('small', { text: `${c.direction} · ${c.status} · ${c.date}` })), el('span', { class: 'r', text: '☎' })))); }
}
async function dial(number) {
  const res = await rpc('call', { to: number });
  if (!res.ok) return toast(errText(res.error));
  if (res.data && res.data.emergency) return toast(`Connected to ${number}. Describe your emergency.`, true);
  S.d.lastDial = number;
  callScreen(number, 'Calling…', false);
}
function callScreen(number, label, ringing, id) {
  closeCall();
  const buttons = [];
  if (ringing) buttons.push(el('button', { type: 'button', class: 'ok', onclick: async () => { const r = await rpc('answer', { id }); if (r.ok) callScreen(number, 'On call', false); else closeCall(); } }, 'Answer'));
  buttons.push(el('button', { type: 'button', class: 'd', onclick: async () => { await rpc('hangup'); closeCall(); } }, ringing ? 'Decline' : 'Hang up'));
  $('screen').append(el('div', { id: 'call' }, el('div', { class: 'muted', text: label }), el('h2', { text: nameOf(number) }), el('div', { class: ringing || label === 'Calling…' ? 'pulse muted' : 'muted', text: fmt(number) }), el('div', { class: 'row', style: 'width:80%' }, buttons)));
}
function closeCall() { const c = $('call'); if (c) c.remove(); }

/* ---------- messages ---------- */
async function messagesApp(b) {
  b.append(el('button', { class: 'p', type: 'button', onclick: () => go('New message', composeTo) }, 'New message'));
  const res = await rpc('messages:conversations'); if (!res.ok) return toast(errText(res.error));
  if (!res.data.length) b.append(el('p', { class: 'muted centre', text: 'No messages yet.' }));
  res.data.forEach((c) => b.append(el('button', { class: 'item', type: 'button', onclick: () => go(nameOf(c.number), (bb) => threadApp(bb, c.number)) }, el('span', {}, nameOf(c.number), el('small', { text: c.last.slice(0, 40) })), c.unread ? el('span', { class: 'r', text: `${c.unread} new` }) : null)));
}
function composeTo(b) { const to = el('input', { type: 'text', placeholder: 'Number (07…)', maxlength: 13 }); b.append(to, el('button', { class: 'p', type: 'button', onclick: () => { S.stack.pop(); go(nameOf(to.value.replace(/\s/g, '')), (bb) => threadApp(bb, to.value.replace(/\s/g, ''))); } }, 'Open conversation')); }
async function threadApp(b, number) {
  const log = el('div', {}); b.append(log);
  const load = async () => { const r = await rpc('messages:thread', { number }); log.replaceChildren(); if (!r.ok) return toast(errText(r.error)); r.data.forEach((m) => log.append(el('div', { class: `bub ${m.mine ? 'me' : 'them'}` }, m.body, el('small', { text: `${m.date} ${m.time}` })))); b.scrollTop = b.scrollHeight; };
  await load();
  const box = el('input', { type: 'text', maxlength: 250, placeholder: 'Message' });
  const send = async () => { if (!box.value.trim()) return; const r = await rpc('messages:send', { to: number, body: box.value }); if (!r.ok) return toast(errText(r.error)); box.value = ''; load(); };
  box.addEventListener('keydown', (e) => { if (e.key === 'Enter') send(); });
  b.append(box, el('button', { class: 'p', type: 'button', onclick: send }, 'Send'), el('button', { class: 'g', type: 'button', onclick: () => dial(number) }, 'Call'));
  S.refresh = load;
}

/* ---------- contacts ---------- */
async function contactsApp(b) {
  b.append(el('button', { class: 'p', type: 'button', onclick: () => go('Add contact', contactForm) }, 'Add contact'));
  if (!S.contacts.length) b.append(el('p', { class: 'muted centre', text: 'No contacts saved.' }));
  S.contacts.forEach((c) => b.append(el('div', { class: 'item' }, el('span', {}, c.name, el('small', { text: fmt(c.number) })), el('span', { class: 'row' },
    el('button', { type: 'button', class: 'g', onclick: () => dial(c.number) }, '☎'), el('button', { type: 'button', class: 'g', onclick: () => go(c.name, (bb) => threadApp(bb, c.number)) }, '✉'),
    el('button', { type: 'button', class: 'g', onclick: async () => { const r = await rpc('contacts:delete', { id: c.id }); if (r.ok) { setContacts(r.data); draw(); } else toast(errText(r.error)); } }, '✕')))));
}
function contactForm(b, preset) {
  const name = el('input', { type: 'text', placeholder: 'Name', maxlength: 30 }), num = el('input', { type: 'text', placeholder: 'Number (07…)', maxlength: 13, value: preset || '' });
  b.append(name, num, el('button', { class: 'p', type: 'button', onclick: async () => { const r = await rpc('contacts:save', { name: name.value, number: num.value }); if (!r.ok) return toast(errText(r.error)); setContacts(r.data); toast('Contact saved.', true); back(); } }, 'Save'));
}

/* ---------- bank ---------- */
async function bankApp(b) {
  const r = await rpc('nexoro_banking:account'); if (!r.ok) return toast(errText(r.error));
  const a = r.data;
  b.append(el('div', { class: 'centre' }, el('div', { class: 'muted', text: a.name }), el('div', { class: 'big', text: a.bankText }), el('div', { class: 'muted', text: `Cash in hand ${a.cashText} · Citizen ID ${a.citizenId}` })));
  const amount = el('input', { type: 'number', min: '0.01', step: '0.01', placeholder: 'Amount (£)' });
  const act = (name, label, cls) => el('button', { type: 'button', class: cls, onclick: async () => { const x = await rpc(name, { amount: Number(amount.value) }); if (!x.ok) return toast(errText(x.error)); toast('Done.', true); draw(); } }, label);
  b.append(amount, el('div', { class: 'row' }, act('nexoro_banking:deposit', 'Deposit', 'p'), act('nexoro_banking:withdraw', 'Withdraw', 'g')),
    el('p', { class: 'muted', text: 'Transfer' }));
  const cid = el('input', { type: 'text', placeholder: 'Recipient Citizen ID', maxlength: 10 }), note = el('input', { type: 'text', placeholder: 'Reference (optional)', maxlength: 100 });
  b.append(cid, note, el('button', { class: 'p', type: 'button', onclick: async () => { const x = await rpc('nexoro_banking:transfer', { citizenId: cid.value.trim().toUpperCase(), amount: Number(amount.value), note: note.value }); if (!x.ok) return toast(errText(x.error)); toast('Transfer sent.', true); draw(); } }, 'Send money'),
    el('button', { class: 'g', type: 'button', onclick: () => go('Statement', statement) }, 'View statement'));
}
async function statement(b) {
  const r = await rpc('nexoro_banking:statement', { page: 0 }); if (!r.ok) return toast(errText(r.error));
  if (!r.data.length) b.append(el('p', { class: 'muted centre', text: 'No transactions yet.' }));
  r.data.forEach((t) => b.append(el('div', { class: 'item' }, el('span', {}, t.type.replace('_', ' '), el('small', { text: `${t.date}${t.counterparty ? ' · ' + t.counterparty : ''}${t.note ? ' · ' + t.note : ''}` })), el('span', { class: 'r', style: `color:${t.delta < 0 ? '#ff5a4d' : '#4ade80'}`, text: t.amount }))));
}

/* ---------- jobs / maps ---------- */
async function jobsApp(b) {
  const r = await rpc('jobs'); if (!r.ok) return toast(errText(r.error));
  const j = r.data.current;
  b.append(el('div', { class: 'item' }, el('span', {}, j ? j.label : 'Unemployed', el('small', { text: j ? `${j.gradeLabel} · ${money(j.salary)} per payday${j.onDuty ? ' · On duty' : ''}` : '' }))), el('p', { class: 'muted', text: 'Jobs open to everyone. Visit the Job Centre (see Maps) to apply.' }));
  r.data.open.forEach((o) => b.append(el('div', { class: 'item' }, el('span', {}, o.label, el('small', { text: o.category })), el('span', { class: 'r', text: o.salary }))));
}
function mapsApp(b) { b.append(el('p', { class: 'muted', text: 'Tap a place to set your GPS waypoint.' })); S.d.config.gps.forEach((p) => b.append(el('button', { class: 'item', type: 'button', onclick: () => post('gps', { x: p.x, y: p.y }) }, p.name, el('span', { class: 'r', text: 'Route' })))); }

/* ---------- mail ---------- */
async function mailApp(b) {
  b.append(el('div', { class: 'muted', text: S.d.email }), el('button', { class: 'p', type: 'button', onclick: () => go('New email', mailForm) }, 'Compose'));
  const r = await rpc('mail:inbox'); if (!r.ok) return toast(errText(r.error));
  if (!r.data.length) b.append(el('p', { class: 'muted centre', text: 'Inbox empty.' }));
  r.data.forEach((m) => b.append(el('button', { class: 'item', type: 'button', onclick: () => go(m.subject, (bb) => mailView(bb, m)) }, el('span', {}, m.subject, el('small', { text: `${m.from_address} · ${m.date}` })), m.is_read ? null : el('span', { class: 'r', text: 'new' }))));
}
async function mailView(b, m) {
  rpc('mail:read', { id: m.id }); b.append(el('div', { class: 'muted', text: `From ${m.from_address}` }), el('p', { text: m.body, style: 'white-space:pre-wrap;font-size:14px' }),
    el('button', { class: 'g', type: 'button', onclick: () => { S.stack.pop(); go('New email', (bb) => mailForm(bb, m.from_address, 'Re: ' + m.subject)); } }, 'Reply'),
    el('button', { class: 'g', type: 'button', onclick: async () => { await rpc('mail:delete', { id: m.id }); back(); } }, 'Delete'));
}
function mailForm(b, to, subject) {
  const t = el('input', { type: 'text', placeholder: 'To (name@nexoro.co.uk)', maxlength: 80, value: to || '' }), s = el('input', { type: 'text', placeholder: 'Subject', maxlength: 60, value: subject || '' }), body = el('textarea', { maxlength: 1000, placeholder: 'Message' });
  b.append(t, s, body, el('button', { class: 'p', type: 'button', onclick: async () => { const r = await rpc('mail:send', { to: t.value, subject: s.value, body: body.value }); if (!r.ok) return toast(errText(r.error)); toast('Email sent.', true); back(); } }, 'Send'));
}

/* ---------- adverts / chirp ---------- */
async function advertsApp(b) {
  b.append(el('button', { class: 'p', type: 'button', onclick: () => go('New advert', advertForm) }, 'Place an advert (£25)'));
  const r = await rpc('ads:list'); if (!r.ok) return toast(errText(r.error));
  if (!r.data.length) b.append(el('p', { class: 'muted centre', text: 'No adverts right now.' }));
  r.data.forEach((a) => b.append(el('div', { class: 'item', style: 'align-items:flex-start' }, el('span', {}, a.title, el('small', { text: a.body }), el('small', { text: `${a.date} · ${fmt(a.number)}` })), el('span', {}, a.price ? el('div', { class: 'r', text: a.price }) : null,
    a.mine ? el('button', { type: 'button', class: 'g', onclick: async () => { await rpc('ads:delete', { id: a.id }); draw(); } }, '✕') : el('button', { type: 'button', class: 'g', onclick: () => dial(a.number) }, '☎')))));
}
function advertForm(b) {
  const t = el('input', { type: 'text', placeholder: 'Title', maxlength: 40 }), body = el('textarea', { maxlength: 250, placeholder: 'Details' }), price = el('input', { type: 'number', min: '0', step: '0.01', placeholder: 'Price £ (optional)' });
  b.append(t, body, price, el('button', { class: 'p', type: 'button', onclick: async () => { const r = await rpc('ads:post', { title: t.value, body: body.value, price: price.value === '' ? undefined : Number(price.value) }); if (!r.ok) return toast(errText(r.error)); toast('Advert placed.', true); back(); } }, 'Pay and post'));
}
async function chirpApp(b) {
  const box = el('textarea', { maxlength: 200, placeholder: `What's happening? (${S.d.handle})` });
  b.append(box, el('button', { class: 'p', type: 'button', onclick: async () => { const r = await rpc('social:post', { body: box.value }); if (!r.ok) return toast(errText(r.error)); draw(); } }, 'Chirp'));
  const r = await rpc('social:feed'); if (!r.ok) return;
  r.data.forEach((p) => b.append(el('div', { class: 'item', style: 'align-items:flex-start' }, el('span', {}, el('b', { text: p.handle }), el('small', { text: p.body, style: 'color:#fff;font-size:13px' }), el('small', { text: p.date })), p.mine ? el('button', { type: 'button', class: 'g', onclick: async () => { await rpc('social:delete', { id: p.id }); draw(); } }, '✕') : null)));
}

/* ---------- settings ---------- */
function settingsApp(b) {
  const wp = el('select', {}, S.d.config.wallpapers.map((w) => el('option', { value: w, text: w.replace('nexoro_', '') }))); wp.value = S.d.wallpaper;
  const rt = el('select', {}, S.d.config.ringtones.map((w) => el('option', { value: w, text: w }))); rt.value = S.d.ringtone;
  b.append(el('p', { class: 'muted', text: `Number ${fmt(S.d.number)}` }), el('p', { class: 'muted', text: `Email ${S.d.email}` }), el('p', { class: 'muted', text: `Chirp ${S.d.handle}` }), el('div', { class: 'muted', text: 'Wallpaper' }), wp, el('div', { class: 'muted', style: 'margin-top:8px', text: 'Ringtone' }), rt,
    el('button', { class: 'p', type: 'button', onclick: async () => { const r = await rpc('settings:save', { wallpaper: wp.value, ringtone: rt.value }); if (!r.ok) return toast(errText(r.error)); S.d.wallpaper = r.data.wallpaper; S.d.ringtone = r.data.ringtone; post('setRingtone', { ringtone: r.data.ringtone }); applyWallpaper(); toast('Saved.', true); } }, 'Save'));
}
function applyWallpaper() { $('screen').className = `w-${S.d.wallpaper}`; }
function setBattery(l) { const b = $('batt'); b.textContent = `${l}%`; b.className = l <= 15 ? 'low' : ''; }

/* ---------- events ---------- */
window.addEventListener('message', (e) => {
  const m = e.data;
  if (m.action === 'open') { S.d = m.data; setContacts(S.d.contacts); $('phone').classList.remove('hidden'); applyWallpaper(); setBattery(S.d.battery); home(); if (S.d.incoming) callScreen(S.d.incoming.from, 'Incoming call', true, S.d.incoming.id); }
  else if (m.action === 'close') { $('phone').classList.add('hidden'); closeCall(); }
  else if (m.action === 'clock') $('clock').textContent = m.time;
  else if (m.action === 'battery') setBattery(m.level);
  else if (m.action === 'incoming') { if (S.d) callScreen(m.call.from, 'Incoming call', true, m.call.id); }
  else if (m.action === 'answered') { const c = $('call'); if (c) callScreen(S.d.lastDial || '', 'On call', false); }
  else if (m.action === 'ended') { closeCall(); if (m.info && m.info.status === 'missed') toast('Call missed.'); }
  else if (m.action === 'message') { if (S.d) S.d.unreadMessages += 1; if (S.refresh && S.stack.length) S.refresh(); }
  else if (m.action === 'mail') { if (S.d) S.d.unreadMail += 1; }
});
$('home').addEventListener('click', home);
window.addEventListener('keydown', (e) => { if (e.key === 'Escape') post('close'); });
