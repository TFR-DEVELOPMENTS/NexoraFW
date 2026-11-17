'use strict';
const post = (n, d) => fetch(`https://${GetParentResourceName()}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d || {}) }).then((r) => r.json()).catch(() => ({ ok: false, error: 'nui_error' }));
const $ = (id) => document.getElementById(id);
const ERRORS = { rate_limited: 'Slow down a little.', not_usable: 'That item cannot be used.', stack_full: 'That stack is full.', invalid_move: 'Those items cannot be swapped like that.', too_heavy: 'You are carrying too much.', no_space: 'No space left.', busy: 'Try again in a moment.', cancelled: 'You cannot use that right now.' };
let inv = null, dragFrom = null, filter = '';

function toast(text) { const m = $('msg'); m.textContent = text; m.classList.remove('hidden'); clearTimeout(toast.t); toast.t = setTimeout(() => m.classList.add('hidden'), 2500); }
const kg = (g) => (g / 1000).toFixed(1);

function render() {
  if (!inv) return;
  $('weight').textContent = `${kg(inv.weight)} / ${kg(inv.maxWeight)} kg`;
  $('bar-fill').style.width = `${Math.min(100, (inv.weight / inv.maxWeight) * 100)}%`;
  const bySlot = new Map(inv.items.map((i) => [i.slot, i]));
  const grid = $('grid');
  grid.replaceChildren();
  for (let s = 1; s <= inv.slots; s++) {
    const item = bySlot.get(s);
    const el = document.createElement('div');
    el.className = 'slot';
    el.dataset.slot = s;
    if (s <= 5) { const n = document.createElement('span'); n.className = 'num'; n.textContent = s; el.append(n); }
    if (item) {
      el.draggable = true;
      const tile = document.createElement('div'); tile.className = 'tile';
      const img = document.createElement('img'); img.src = `img/${item.item}.png`; img.alt = '';
      img.onerror = () => { img.remove(); tile.textContent = item.label.slice(0, 2).toUpperCase(); };
      tile.append(img); el.append(tile);
      if (item.amount > 1) { const a = document.createElement('span'); a.className = 'amt'; a.textContent = item.amount; el.append(a); }
      const name = document.createElement('span'); name.className = 'name'; name.textContent = item.label; el.append(name);
      if (filter && !item.label.toLowerCase().includes(filter)) el.classList.add('dim');
      el.addEventListener('dragstart', (e) => { dragFrom = s; e.dataTransfer.effectAllowed = 'move'; });
      el.addEventListener('dblclick', () => use(s));
      el.addEventListener('contextmenu', (e) => { e.preventDefault(); use(s); });
      el.addEventListener('mousemove', (e) => showTip(e, item));
      el.addEventListener('mouseleave', hideTip);
    }
    el.addEventListener('dragover', (e) => { e.preventDefault(); el.classList.add('over'); });
    el.addEventListener('dragleave', () => el.classList.remove('over'));
    el.addEventListener('drop', async (e) => {
      e.preventDefault(); el.classList.remove('over');
      if (dragFrom == null || dragFrom === s) return;
      const from = dragFrom; dragFrom = null;
      const res = await post('move', { from, to: s, amount: e.shiftKey ? 1 : undefined });
      if (!res.ok) toast(ERRORS[res.error] || 'That move is not possible.');
    });
    grid.append(el);
  }
}

async function use(slot) { const res = await post('use', { slot }); if (!res.ok) toast(ERRORS[res.error] || 'You cannot use that.'); }

function showTip(e, item) {
  const t = $('tip');
  t.replaceChildren();
  const b = document.createElement('b'); b.textContent = item.label;
  const d = document.createElement('div'); d.textContent = item.description || '';
  const w = document.createElement('div'); w.className = 'muted'; w.textContent = `${kg(item.weight * item.amount)} kg total`;
  t.append(b, d, w);
  t.style.left = `${Math.min(e.clientX + 16, innerWidth - 260)}px`; t.style.top = `${e.clientY + 16}px`;
  t.classList.remove('hidden');
}
function hideTip() { $('tip').classList.add('hidden'); }

$('search').addEventListener('input', (e) => { filter = e.target.value.trim().toLowerCase(); render(); });
window.addEventListener('keydown', (e) => { if (e.key === 'Escape') post('close'); });
window.addEventListener('message', (e) => {
  const m = e.data;
  if (m.action === 'open') { $('inv').classList.remove('hidden'); }
  else if (m.action === 'close') { $('inv').classList.add('hidden'); hideTip(); }
  else if (m.action === 'update') { inv = m.inventory; render(); }
});
