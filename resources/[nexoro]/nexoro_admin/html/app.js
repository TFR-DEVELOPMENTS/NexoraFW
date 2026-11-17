'use strict';
const post = (n, d) => fetch(`https://${GetParentResourceName()}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d || {}) }).then((r) => r.json()).catch(() => ({ ok: false, error: 'nui_error' }));
const api = (endpoint, payload) => post('api', { endpoint, payload });
const $ = (id) => document.getElementById(id);
const el = (tag, props, ...kids) => { const n = document.createElement(tag); for (const [k, v] of Object.entries(props || {})) { if (k === 'class') n.className = v; else if (k === 'text') n.textContent = v; else if (k.startsWith('on')) n.addEventListener(k.slice(2), v); else n.setAttribute(k, v); } kids.flat().forEach((c) => n.append(c)); return n; };

const ERR = { forbidden: 'You do not have permission for that.', confirmation_required: 'Please tick the confirmation box.', reason_required: 'Enter a reason (3 to 200 characters).',
  target_not_found: 'That player is no longer online.', target_outranks_you: 'You cannot act on someone of equal or higher staff rank.', cannot_target_self: 'You cannot do that to yourself.',
  target_has_no_character: 'That player has not chosen a character yet.', insufficient_funds: 'They do not have enough money.', unknown_job: 'That job does not exist.', unknown_grade: 'That grade does not exist.',
  unknown_item: 'That item does not exist.', not_enough: 'They do not have that many.', invalid_amount: 'Enter a valid amount (max 2 decimal places).', invalid_duration: 'That duration is not allowed for your rank.',
  rank_too_high: 'You cannot assign a rank at or above your own.', rate_limited: 'Slow down a little.', resource_not_allowed: 'That resource cannot be restarted from here.', not_on_duty: 'Go on staff duty first.',
  invalid_model: 'Enter a valid vehicle model name.', invalid_weather: 'Unknown weather type.', too_heavy: 'Their inventory is too heavy.', no_space: 'Their inventory is full.', no_position: 'Could not get that player\'s position.', no_return_position: 'Nothing to return to.', ban_not_found: 'That ban was not found or is already lifted.' };
const errText = (e) => ERR[e] || (typeof e === 'string' ? e.replaceAll('_', ' ') : 'Something went wrong.');

const REASON = { name: 'reason', label: 'Reason (recorded in the audit log)', type: 'text' };
const ACTIONS = {
  goto: { label: 'Go to player' }, bring: { label: 'Bring player' }, return: { label: 'Return player' },
  freeze: { label: 'Freeze' }, unfreeze: { label: 'Unfreeze' }, spectate: { label: 'Spectate' }, stopspectate: { label: 'Stop spectating' },
  heal: { label: 'Heal' }, revive: { label: 'Revive' }, armour: { label: 'Give armour' },
  message: { label: 'Send message', fields: [{ name: 'text', label: 'Message to player', type: 'text' }] },
  mute: { label: 'Mute chat', fields: [{ name: 'minutes', label: 'Minutes', type: 'number', value: 10 }] }, unmute: { label: 'Unmute' },
  warn: { label: 'Warn', fields: [REASON] }, kick: { label: 'Kick', fields: [REASON], danger: true },
  tempban: { label: 'Temporary ban', fields: [{ name: 'minutes', label: 'Minutes', type: 'number', value: 1440 }, REASON], sensitive: true, danger: true },
  ban: { label: 'Ban', fields: [{ name: 'minutes', label: 'Minutes (0 = permanent)', type: 'number', value: 0 }, REASON], sensitive: true, danger: true },
  unban: { label: 'Lift ban', fields: [REASON], sensitive: true },
  addmoney: { label: 'Add money', fields: [{ name: 'account', label: 'Account', type: 'select', options: ['cash', 'bank'] }, { name: 'amount', label: 'Amount (£)', type: 'number', step: '0.01' }, REASON], sensitive: true },
  removemoney: { label: 'Remove money', fields: [{ name: 'account', label: 'Account', type: 'select', options: ['cash', 'bank'] }, { name: 'amount', label: 'Amount (£)', type: 'number', step: '0.01' }, REASON], sensitive: true },
  setjob: { label: 'Set job', fields: [{ name: 'job', label: 'Job name (e.g. taxi)', type: 'text' }, { name: 'grade', label: 'Grade', type: 'number', value: 0 }] },
  giveitem: { label: 'Give item', fields: [{ name: 'item', label: 'Item name (e.g. water)', type: 'text' }, { name: 'amount', label: 'Amount', type: 'number', value: 1 }] },
  removeitem: { label: 'Remove item', fields: [{ name: 'item', label: 'Item name', type: 'text' }, { name: 'amount', label: 'Amount', type: 'number', value: 1 }] },
  clearinventory: { label: 'Clear inventory', fields: [REASON], sensitive: true, danger: true },
  setstaffrank: { label: 'Set staff rank', fields: [{ name: 'rank', label: 'Rank', type: 'select', options: 'RANKS' }, REASON], sensitive: true },
  spawnvehicle: { label: 'Spawn vehicle', fields: [{ name: 'model', label: 'Model name', type: 'text' }, { name: 'plate', label: 'Plate (optional, 8 max)', type: 'text', optional: true }] },
  deletevehicle: { label: 'Delete vehicle' }, repairvehicle: { label: 'Repair vehicle' }, cleanvehicle: { label: 'Clean vehicle' }, flipvehicle: { label: 'Flip vehicle' },
  noclip: { label: 'Noclip' }, god: { label: 'God mode' }, invisible: { label: 'Invisible' }, nametags: { label: 'Player names' },
  tpwaypoint: { label: 'Teleport to waypoint' }, tpcoords: { label: 'Teleport to coordinates', fields: [{ name: 'x', label: 'X', type: 'number', step: 'any' }, { name: 'y', label: 'Y', type: 'number', step: 'any' }, { name: 'z', label: 'Z', type: 'number', step: 'any' }] },
  staffduty: { label: 'Toggle staff duty' },
  announce: { label: 'Server announcement', fields: [{ name: 'text', label: 'Announcement', type: 'text' }] },
  weather: { label: 'Set weather', fields: [{ name: 'type', label: 'Weather', type: 'select', options: 'WEATHERS' }] },
  time: { label: 'Set time', fields: [{ name: 'hour', label: 'Hour (0-23)', type: 'number', value: 12 }, { name: 'minute', label: 'Minute', type: 'number', value: 0 }] },
  freezetime: { label: 'Freeze / unfreeze time' }, maintenance: { label: 'Toggle maintenance mode', sensitive: true, danger: true },
  vimpound: { label: 'Impound', fields: [{ name: 'reason', label: 'Reason (recorded)', type: 'text' }, { name: 'fee', label: 'Release fee (£)', type: 'number', step: '0.01', value: 150 }], danger: true },
  vrelease: { label: 'Release from impound' }, vrepair: { label: 'Repair' },
  vtransfer: { label: 'Transfer ownership', fields: [{ name: 'citizenId', label: 'New owner Citizen ID', type: 'text' }, REASON], sensitive: true },
  vdelete: { label: 'Scrap vehicle', fields: [REASON], sensitive: true, danger: true },
  restartresource: { label: 'Restart resource', fields: [{ name: 'name', label: 'Resource', type: 'select', options: 'RESOURCES' }, REASON], sensitive: true },
};
const HINTS = {
  goto: 'Teleports you to the selected player.', bring: 'Teleports the selected player to you.', return: 'Sends the player back to where they were before a goto, bring or spectate.',
  freeze: 'Stops the player moving until you unfreeze them.', unfreeze: 'Lets a frozen player move again.', spectate: 'Watches the player from their point of view. Stop spectating to return.',
  heal: 'Restores the player to full health.', revive: 'Brings a dead player back on the spot.', armour: 'Gives the player full body armour.',
  message: 'Sends a private notice to the player only.', mute: 'Stops the player using chat for the minutes you set.', unmute: 'Lets the player use chat again.',
  warn: 'Records a warning against the player. Shown in their history.', kick: 'Removes the player from the server now. They can rejoin.',
  tempban: 'Bans the player for a set time (moderators: up to 7 days). Recorded in the audit log.', ban: 'Bans the player. Set minutes to 0 for a permanent ban. Recorded.',
  unban: 'Lifts an existing ban by its ban ID.', addmoney: 'Adds money to the chosen account. Recorded with your reason.', removemoney: 'Takes money from the chosen account. Recorded with your reason.',
  setjob: 'Gives the player a job and grade (for example taxi, grade 0).', giveitem: 'Puts an item in the player\'s inventory.', removeitem: 'Takes an item from the player\'s inventory.',
  clearinventory: 'Empties the player\'s entire inventory. Cannot be undone.', setstaffrank: 'Gives or removes a staff rank. You cannot assign a rank at or above your own.',
  spawnvehicle: 'Creates a vehicle next to you (or the selected player). Use the model name, for example adder.', deletevehicle: 'Removes the vehicle you are in or next to.',
  repairvehicle: 'Fixes the vehicle you are in or next to.', cleanvehicle: 'Washes the vehicle you are in or next to.', flipvehicle: 'Turns a tipped-over vehicle back upright.',
  noclip: 'Lets you fly through walls. Press again to turn it off.', god: 'You cannot be damaged while on.', invisible: 'Other players cannot see you while on.',
  nametags: 'Shows player names and IDs above heads nearby.', tpwaypoint: 'Teleports you to the waypoint on your map.', tpcoords: 'Teleports you to exact coordinates.',
  staffduty: 'Starts or ends your staff shift. Used for logging and when duty is required.', announce: 'Sends a message to every player on the server.',
  weather: 'Changes the weather for everyone.', time: 'Sets the in-game clock for everyone.', freezetime: 'Stops or resumes the in-game clock.',
  maintenance: 'When on, only staff can join. Players already in the server stay in.', restartresource: 'Stops and starts one Nexoro resource. Use after a config change.',
  vimpound: 'Seizes the vehicle into an impound with a fee and reason.', vrelease: 'Takes a vehicle out of impound without a fee.', vrepair: 'Restores the vehicle to full condition.',
  vtransfer: 'Moves ownership of the vehicle to another Citizen ID. Recorded.', vdelete: 'Scraps the vehicle permanently. Cannot be undone.',
};
const TAB_HINTS = {
  Dashboard: 'Live server status: players, staff, uptime and resources. Read-only.',
  Players: 'Choose a player on the left. Their details and actions appear on the right. Actions mostly need a reason, which is logged.',
  Self: 'Your own tools. Toggles stay on until you turn them off.',
  Vehicles: 'Vehicle tools. They act on the vehicle you are in or next to, or on the selected player.',
  World: 'Server-wide tools: announcements, weather, time and maintenance. Everything here affects every player.',
  Economy: 'Money in circulation and large transactions. Use it to spot duplication or exploits.',
  Bans: 'Active bans. Lifting a ban is logged.',
  Registry: 'Search the vehicle registry by plate, owner, Citizen ID or model. Actions are logged.',
  Logs: 'The audit trail. Staff actions show previous and new values.',
};
const PLAYER_GROUPS = { Teleport: ['goto', 'bring', 'return', 'spectate', 'stopspectate'], State: ['freeze', 'unfreeze', 'heal', 'revive', 'armour'],
  Moderation: ['message', 'mute', 'unmute', 'warn', 'kick', 'tempban', 'ban'], Economy: ['addmoney', 'removemoney'], 'Jobs and items': ['setjob', 'giveitem', 'removeitem', 'clearinventory'], Staff: ['setstaffrank'] };
const RESOURCES = ['nexoro_character', 'nexoro_banking', 'nexoro_inventory', 'nexoro_chat', 'nexoro_notifications', 'nexoro_ui', 'nexoro_phone', 'nexoro_hud', 'nexoro_menu', 'nexoro_admin', 'nexoro_identity', 'nexoro_core'];

const S = { menu: null, tab: 'Dashboard', players: [], selected: null, search: '' };
const allowed = (a) => S.menu.allowed.includes(a);

let toastTimer;
function toast(msg, ok) { const t = $('toast'); t.textContent = msg; t.className = ok ? 'ok' : ''; clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.add('hidden'), 5000); }

function runAction(name, extra) {
  const def = ACTIONS[name];
  const base = Object.assign({}, extra || {});
  if (!def.fields && !def.sensitive) return send(name, base);
  const form = $('dialog'); form.replaceChildren(el('h2', { text: def.label }));
  const inputs = {};
  (def.fields || []).forEach((f) => {
    let input;
    if (f.type === 'select') {
      const opts = f.options === 'RANKS' ? ['none', ...S.menu.ranks.map((r) => r.name)] : f.options === 'WEATHERS' ? S.menu.weathers : f.options === 'RESOURCES' ? RESOURCES : f.options;
      input = el('select', {}, opts.map((o) => el('option', { value: o, text: o })));
    } else input = el('input', { type: f.type, step: f.step || '1', autocomplete: 'off', value: f.value ?? '' });
    inputs[f.name] = input;
    form.append(el('div', { class: 'f' }, el('label', { text: f.label }), input));
  });
  let confirm;
  if (def.sensitive) { confirm = el('input', { type: 'checkbox', style: 'width:auto' }); form.append(el('label', { class: 'warn' }, confirm, ' I understand this is logged and may be hard to undo.')); }
  form.append(el('div', { class: 'row' },
    el('button', { type: 'button', class: 'ghost', onclick: () => $('modal').classList.add('hidden') }, 'Cancel'),
    el('button', { type: 'submit', class: def.danger ? 'danger' : 'primary' }, 'Confirm')));
  form.onsubmit = (e) => {
    e.preventDefault();
    const payload = Object.assign({}, base);
    for (const f of def.fields || []) { const v = inputs[f.name].value; if (f.type === 'number') payload[f.name] = v === '' ? undefined : Number(v); else if (!(f.optional && v === '')) payload[f.name] = v; }
    if (def.sensitive) payload.confirm = confirm.checked;
    $('modal').classList.add('hidden');
    send(name, payload);
  };
  $('modal').classList.remove('hidden');
  const first = form.querySelector('input,select'); if (first) first.focus();
}

async function send(name, payload) {
  const res = await post('api', { endpoint: 'action', name, payload });
  if (!res.ok) return toast(errText(res.error));
  toast(`${ACTIONS[name].label}: done.`, true);
  if (S.tab === 'Players') refreshPlayers(true);
  if (S.tab === 'Bans') render();
}

const btn = (name, extra, cls) => allowed(name) ? el('button', { class: cls || (ACTIONS[name].danger ? 'danger' : ''), type: 'button', title: HINTS[name] || ACTIONS[name].label, onclick: () => runAction(name, extra) }, ACTIONS[name].label) : null;
const table = (head, rows) => el('table', {}, el('thead', {}, el('tr', {}, head.map((h) => el('th', { text: h })))), el('tbody', {}, rows.map((r) => el('tr', {}, r.map((c) => el('td', { text: c ?? '' }))))));
const fmtUptime = (s) => `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;

/* ---------- Tabs ---------- */
async function viewDashboard(v) {
  const res = await api('dashboard'); if (!res.ok) return v.append(el('p', { class: 'bad', text: errText(res.error) }));
  const d = res.data;
  v.append(el('h2', { text: 'Dashboard' }), el('div', { class: 'cards' },
    ...[['Players online', `${d.online} / ${d.maxClients}`], ['Staff online', d.staffOnline], ['Staff on duty', d.staffOnDuty], ['Emergency on duty', d.emergencyOnDuty], ['Uptime', fmtUptime(d.uptimeSeconds)], ['Script memory', `${d.memoryMb} MB`], ['Maintenance', d.maintenance ? 'ON' : 'off'], ['Game time', `${String(d.world.hour).padStart(2, '0')}:${String(d.world.minute).padStart(2, '0')} ${d.world.weather}`]]
      .map(([k, val]) => el('div', { class: 'card' }, el('b', { text: String(val) }), el('span', { text: k })))),
    el('h3', { text: 'Resources' }), table(['Resource', 'State'], d.resources.map((r) => [r.name, r.state])),
    el('p', { class: 'muted', text: 'Active reports and dispatch incidents will appear here once those systems are installed.' }));
}

async function refreshPlayers(keep) {
  const res = await api('players'); if (!res.ok) return;
  S.players = res.data; if (!keep) S.selected = null; renderPlayersList();
  if (S.selected) loadDetails(S.selected);
}
function renderPlayersList() {
  const list = $('plist'); if (!list) return; list.replaceChildren();
  const q = S.search.toLowerCase();
  S.players.filter((p) => !q || `${p.id} ${p.name} ${p.characterName || ''} ${p.citizenId || ''}`.toLowerCase().includes(q)).forEach((p) =>
    list.append(el('div', { class: 'p' + (S.selected === p.id ? ' sel' : ''), onclick: () => { S.selected = p.id; renderPlayersList(); loadDetails(p.id); } },
      `[${p.id}] ${p.characterName || p.name}`, el('small', { text: `${p.job || 'no character'}${p.staffRank ? ' · ' + p.staffRank : ''} · ${p.ping}ms` }))));
}
async function loadDetails(id) {
  const box = $('details'); if (!box) return;
  const res = await api('player', { id }); box.replaceChildren();
  if (!res.ok) return box.append(el('p', { class: 'bad', text: errText(res.error) }));
  const d = res.data, c = d.character;
  box.append(el('h2', { text: c ? c.name : d.name }), el('p', { class: 'muted', text: `Server ID ${d.id} · ${d.name}${d.staffRank ? ' · Staff: ' + d.staffRank : ''}` }));
  if (c) box.append(table(['Citizen ID', 'Born', 'Job', 'Cash', 'Bank'], [[c.citizenId, c.dob, c.job, c.cash, c.bank]]));
  Object.entries(PLAYER_GROUPS).forEach(([group, names]) => { const bs = names.map((n) => btn(n, { target: id })).filter(Boolean); if (bs.length) box.append(el('h3', { text: group }), el('div', { class: 'row' }, bs)); });
  box.append(el('h3', { text: 'Identifiers' }), table(['Type', 'Value'], d.identifiers.map((i) => [i.kind, i.value])));
  if (d.inventory) box.append(el('h3', { text: `Inventory (${(d.inventory.weight / 1000).toFixed(1)} / ${(d.inventory.maxWeight / 1000).toFixed(1)} kg)` }), table(['Item', 'Amount'], d.inventory.items.map((i) => [i.label, i.amount])));
  if (d.transactions && d.transactions.length) box.append(el('h3', { text: 'Recent bank activity' }), table(['Date', 'Type', 'Amount', 'With'], d.transactions.map((t) => [t.date, t.type, t.amount, t.counterparty])));
  box.append(el('h3', { text: `Warnings (${d.warnings.length}) · Previous bans: ${d.bans}` }), table(['Date', 'Reason', 'By'], d.warnings.map((w) => [w.date, w.reason, w.issued_by])));
  if (d.notes.length) box.append(el('h3', { text: 'Staff actions on this player' }), table(['Date', 'Action', 'By', 'Reason'], d.notes.map((n) => [n.date, n.action, n.staff_name, n.reason])));
}
async function viewPlayers(v) {
  const search = el('input', { type: 'text', placeholder: 'Search by name, ID or citizen ID', value: S.search });
  search.addEventListener('input', () => { S.search = search.value; renderPlayersList(); });
  v.append(el('div', { class: 'split' }, el('div', {}, el('h2', { text: 'Players' }), search, el('div', { id: 'plist', class: 'plist' }), el('div', { class: 'row', style: 'margin-top:8px' }, el('button', { type: 'button', onclick: () => refreshPlayers(true) }, 'Refresh'))), el('div', { id: 'details' }, el('p', { class: 'muted', text: 'Select a player.' }))));
  await refreshPlayers(true);
}
function viewSelf(v) {
  v.append(el('h2', { text: 'Self' }), el('div', { class: 'row' }, ['noclip', 'god', 'invisible', 'nametags', 'tpwaypoint', 'tpcoords', 'staffduty'].map((n) => btn(n)).filter(Boolean)),
    el('h3', { text: 'Quick' }), el('div', { class: 'row' }, ['heal', 'armour', 'revive'].map((n) => btn(n, {})).filter(Boolean)),
    el('p', { class: 'muted', text: 'Noclip: W A S D to move, Space up, Ctrl down, Shift fast, Alt slow.' }));
}
function viewVehicles(v) {
  const target = S.selected ? { target: S.selected } : {};
  v.append(el('h2', { text: 'Vehicles' }), el('p', { class: 'muted', text: S.selected ? `Actions apply to player ${S.selected} (selected in Players).` : 'Actions apply to you. Select a player in the Players tab to target them.' }),
    el('h3', { text: 'Quick spawn' }), el('div', { class: 'row' }, S.menu.quickVehicles.map((m) => allowed('spawnvehicle') ? el('button', { type: 'button', onclick: () => send('spawnvehicle', Object.assign({ model: m }, target)) }, m) : null).filter(Boolean)),
    el('h3', { text: 'Spawn by model' }), el('div', { class: 'row' }, btn('spawnvehicle', target, 'primary')),
    el('h3', { text: 'Current vehicle' }), el('div', { class: 'row' }, ['repairvehicle', 'cleanvehicle', 'flipvehicle', 'deletevehicle'].map((n) => btn(n, target)).filter(Boolean)));
}
function viewWorld(v) {
  v.append(el('h2', { text: 'World and server' }), el('div', { class: 'row' }, ['announce', 'weather', 'time', 'freezetime', 'maintenance', 'restartresource'].map((n) => btn(n)).filter(Boolean)));
}
async function viewEconomy(v) {
  const res = await api('economy'); if (!res.ok) return v.append(el('p', { class: 'bad', text: errText(res.error) }));
  const d = res.data;
  v.append(el('h2', { text: 'Economy' }), el('div', { class: 'cards' }, [['Characters', d.characters], ['Cash in circulation', d.cash], ['Bank balances', d.bank], ['Total', d.total]].map(([k, val]) => el('div', { class: 'card' }, el('b', { text: String(val) }), el('span', { text: k })))),
    el('h3', { text: `Large transactions (${d.thresholdText} or more)` }), table(['Date', 'Citizen ID', 'Type', 'Amount', 'With'], d.suspicious.map((t) => [t.date, t.citizen_id, t.type, t.amount, t.counterparty])),
    el('h3', { text: 'Richest characters' }), table(['Citizen ID', 'Name', 'Cash', 'Bank'], d.richest.map((r) => [r.citizen_id, `${r.first_name} ${r.last_name}`, r.cash, r.bank])));
}
async function viewBans(v) {
  const res = await api('bans'); if (!res.ok) return v.append(el('p', { class: 'bad', text: errText(res.error) }));
  v.append(el('h2', { text: 'Active bans' }), el('table', {}, el('thead', {}, el('tr', {}, ['ID', 'Player', 'Reason', 'By', 'Date', 'Expires', ''].map((h) => el('th', { text: h })))),
    el('tbody', {}, res.data.map((b) => el('tr', {}, [b.id, b.player_name, b.reason, b.banned_by, b.date, b.expires || 'never'].map((c) => el('td', { text: String(c) })).concat([el('td', {}, btn('unban', { banId: b.id }) || '')]))))));
}
async function viewRegistry(v) {
  const q = el('input', { type: 'text', placeholder: 'Search plate, owner, Citizen ID or model', maxlength: 12 }), out = el('div', {});
  const load = async () => {
    const r = await api('vehicles', { search: q.value }); out.replaceChildren();
    if (!r.ok) return out.append(el('p', { class: 'bad', text: errText(r.error) }));
    out.append(el('table', {}, el('thead', {}, el('tr', {}, ['Plate', 'Model', 'Status', 'Garage', 'Owner', 'Actions'].map((h) => el('th', { text: h })))),
      el('tbody', {}, r.data.map((c) => el('tr', {}, [c.plate, c.model, c.status, c.garage, `${c.owner} (${c.citizenId})`].map((t) => el('td', { text: t })).concat([el('td', {}, el('div', { class: 'row' }, ['vimpound', 'vrelease', 'vrepair', 'vtransfer', 'vdelete'].map((n) => btn(n, { plate: c.plate })).filter(Boolean)))]))))));
  };
  q.addEventListener('keydown', (e) => { if (e.key === 'Enter') load(); });
  v.append(el('h2', { text: 'Vehicle registry' }), q, el('button', { type: 'button', class: 'primary', style: 'margin-top:8px', onclick: load }, 'Search'), out);
}
async function viewLogs(v) {
  const kind = el('select', {}, ['admin', 'economy', 'banking', 'inventory', 'character', 'security', 'chat', 'permissions', 'jobs'].map((k) => el('option', { value: k, text: k === 'admin' ? 'Staff actions (with previous and new values)' : k })));
  const out = el('div', {});
  const load = async () => {
    const res = await api('logs', kind.value === 'admin' ? { kind: 'admin' } : { category: kind.value }); out.replaceChildren();
    if (!res.ok) return out.append(el('p', { class: 'bad', text: errText(res.error) }));
    out.append(kind.value === 'admin' ? table(['Date', 'Staff', 'Action', 'Target', 'Previous', 'New', 'Reason'], res.data.map((l) => [l.date, `${l.staff_name} (${l.staff_rank})`, l.action, l.target_name, l.previous_value, l.new_value, l.reason]))
      : table(['Date', 'Category', 'Action', 'Licence', 'Data'], res.data.map((l) => [l.date, l.category, l.action, l.license, l.data])));
  };
  kind.addEventListener('change', load);
  v.append(el('h2', { text: 'Logs' }), kind, out); await load();
}

const TABS = [['Dashboard', viewDashboard, () => S.menu.canSeeDashboard], ['Players', viewPlayers, () => S.menu.canSeePlayers], ['Self', viewSelf, () => true], ['Vehicles', viewVehicles, () => allowed('spawnvehicle')],
  ['World', viewWorld, () => allowed('announce') || allowed('maintenance')], ['Economy', viewEconomy, () => S.menu.canSeeEconomy], ['Bans', viewBans, () => S.menu.canSeeBans], ['Registry', viewRegistry, () => S.menu.canSeeRegistry], ['Logs', viewLogs, () => S.menu.canSeeLogs]];

async function render() {
  const tabs = TABS.filter(([, , ok]) => ok());
  if (!tabs.find(([n]) => n === S.tab)) S.tab = tabs[0][0];
  $('tabs').replaceChildren(...tabs.map(([n]) => el('button', { type: 'button', class: n === S.tab ? 'active' : '', onclick: () => { S.tab = n; render(); } }, n)));
  const v = $('view'); v.replaceChildren();
  if (TAB_HINTS[S.tab]) v.append(el('p', { class: 'muted', style: 'margin:0 0 12px', text: TAB_HINTS[S.tab] }));
  await tabs.find(([n]) => n === S.tab)[1](v);
}

$('close').addEventListener('click', () => post('close'));
window.addEventListener('keydown', (e) => { if (e.key === 'Escape') { if (!$('modal').classList.contains('hidden')) $('modal').classList.add('hidden'); else post('close'); } });
window.addEventListener('message', (e) => {
  if (e.data.action === 'open') { S.menu = e.data.menu; S.selected = null; $('app').classList.remove('hidden'); render(); }
  else if (e.data.action === 'close') { $('app').classList.add('hidden'); $('modal').classList.add('hidden'); }
});
