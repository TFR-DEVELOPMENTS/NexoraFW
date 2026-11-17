'use strict';
const LABELS = { success: 'Success', error: 'Error', warning: 'Warning', info: 'Information', emergency: 'Emergency', job: 'Job', banking: 'Bank', inventory: 'Inventory', staff: 'Staff' };
window.addEventListener('message', (e) => {
  const m = e.data;
  if (m.action !== 'notify') return;
  const stack = document.getElementById('stack');
  const n = document.createElement('div'); n.className = `n ${m.kind}`;
  const t = document.createElement('div'); t.className = 't'; t.textContent = m.title || LABELS[m.kind];
  const body = document.createElement('div'); body.className = 'm'; body.textContent = m.message;
  n.append(t, body); stack.prepend(n);
  while (stack.children.length > 6) stack.lastChild.remove();
  setTimeout(() => { n.classList.add('out'); setTimeout(() => n.remove(), 250); }, m.duration);
});
