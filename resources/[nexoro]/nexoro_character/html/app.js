'use strict';

const post = (name, data) =>
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}),
  }).then((r) => r.json()).catch(() => ({ ok: false, error: 'nui_error' }));

const $ = (id) => document.getElementById(id);

function el(tag, props, ...kids) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props || {})) {
    if (key === 'class') node.className = value;
    else if (key === 'text') node.textContent = value;
    else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
    else node.setAttribute(key, value);
  }
  kids.flat().forEach((kid) => node.append(kid));
  return node;
}

const MODELS = { masculine: 'mp_m_freemode_01', feminine: 'mp_f_freemode_01' };
const FACE_FEATURES = ['Nose width', 'Nose peak height', 'Nose peak length', 'Nose bone height', 'Nose peak lowering',
  'Nose bone twist', 'Eyebrow height', 'Eyebrow depth', 'Cheekbone height', 'Cheekbone width', 'Cheek width',
  'Eye opening', 'Lip thickness', 'Jaw width', 'Jaw length', 'Chin height', 'Chin length', 'Chin width',
  'Chin hole size', 'Neck thickness'];
const OVERLAYS = ['Blemishes', 'Facial hair', 'Eyebrows', 'Ageing', 'Makeup', 'Blush', 'Complexion', 'Sun damage',
  'Lipstick', 'Moles and freckles', 'Chest hair', 'Body blemishes', 'Extra body blemishes'];
const COLOURED_OVERLAYS = new Set([1, 2, 4, 5, 8, 10]);
const CLOTHING = [[1, 'Masks'], [3, 'Torso and arms'], [4, 'Legs'], [5, 'Bags'], [6, 'Shoes'], [7, 'Accessories'],
  [8, 'Undershirt'], [9, 'Body armour'], [10, 'Decals'], [11, 'Tops']];
const PROPS = ['Hats', 'Glasses', 'Earwear', 'Watches', 'Bracelets'];

const ERRORS = {
  rate_limited: 'You are doing that too quickly. Wait a few seconds and try again.',
  timeout: 'The server took too long to answer. Try again.',
  no_free_slot: 'All of your character slots are in use.',
  slot_taken: 'That slot was just taken. Try again.',
  confirmation_mismatch: 'The Citizen ID you typed does not match.',
  not_found: 'That character no longer exists.',
  already_loaded: 'You already have a character loaded.',
  name_taken: 'You already have an outfit with that name.',
  invalid_name: 'Outfit names can use letters, numbers, spaces, hyphens and apostrophes (30 characters max).',
  outfit_limit: 'You have reached the outfit limit. Delete one to save a new one.',
  nui_error: 'The interface could not reach the game. Close and reopen it.',
};
const errorText = (error) => (error && error.message) || ERRORS[error] || 'Something went wrong. Please try again.';

const state = { mode: 'select', options: null, limits: null, characters: [], slots: 3, tab: 'Identity', app: null, outfits: [], identity: null, errorField: null };

function defaultApp(model) {
  return {
    model, headBlend: { shapeFirst: 0, shapeSecond: 0, skinFirst: 0, skinSecond: 0, shapeMix: 0.5, skinMix: 0.5 },
    faceFeatures: Array(20).fill(0),
    headOverlays: Array.from({ length: 13 }, () => ({ style: -1, opacity: 1, color: 0 })),
    hair: { style: 0, color: 0, highlight: 0 }, eyeColor: 0,
    components: Array.from({ length: 12 }, () => ({ drawable: 0, texture: 0 })),
    props: Array.from({ length: 5 }, () => ({ drawable: -1, texture: 0 })),
  };
}

let toastTimer;
function toast(message, ok) {
  const t = $('toast');
  t.textContent = message;
  t.className = ok ? 'ok' : '';
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.add('hidden'), 5000);
}

let previewTimer;
function preview() {
  clearTimeout(previewTimer);
  previewTimer = setTimeout(async () => {
    const res = await post('preview', { appearance: state.app });
    if (res.limits) state.limits = res.limits;
  }, 60);
}

function range(label, min, max, step, value, onChange, format) {
  const out = el('output', { text: format ? format(value) : String(value) });
  const input = el('input', { type: 'range', min, max, step, value });
  input.addEventListener('input', () => {
    const v = Number(input.value);
    out.textContent = format ? format(v) : String(v);
    onChange(v);
  });
  return el('label', { class: 'field' }, el('span', { class: 'lbl' }, label, out), input);
}

/* ---------- Selection ---------- */

function showScreen(name) {
  $('screen-select').classList.toggle('hidden', name !== 'select');
  $('screen-create').classList.toggle('hidden', name === 'select');
  $('rotate').classList.toggle('hidden', name === 'select' && !state.characters.length);
  state.mode = name;
}

function renderSlots() {
  const box = $('slots');
  box.replaceChildren();
  for (let slot = 1; slot <= state.slots; slot++) {
    const c = state.characters.find((x) => x.slot === slot);
    if (!c) {
      box.append(el('div', { class: 'card empty', tabindex: 0, onclick: () => startCreate() }, `Slot ${slot} is empty. Create a character`));
      continue;
    }
    const card = el('div', { class: 'card', onclick: () => { if (c.appearance) post('preview', { appearance: c.appearance }); } },
      el('div', { class: 'name', text: `${c.firstName} ${c.lastName}` }),
      el('div', { class: 'meta' },
        `Citizen ID ${c.citizenId}`, el('br'),
        `Born ${c.dob} · ${c.nationality} · ${c.height} cm`, el('br'),
        `${c.job}${c.lastPlayed ? ' · Last played ' + c.lastPlayed : ''}`),
      el('div', { class: 'row' },
        el('button', { class: 'primary small', type: 'button', onclick: (e) => { e.stopPropagation(); play(c); } }, 'Play'),
        el('button', { class: 'ghost small', type: 'button', onclick: (e) => { e.stopPropagation(); askDelete(c); } }, 'Delete')));
    box.append(card);
  }
  const first = state.characters[0];
  if (first && first.appearance) post('preview', { appearance: first.appearance });
}

async function play(c) {
  const res = await post('select', { id: c.id });
  if (!res.ok) toast(errorText(res.error));
}

function askDelete(c) {
  $('modal-text').textContent = `This permanently deletes ${c.firstName} ${c.lastName}, including money and belongings. Type ${c.citizenId} to confirm.`;
  const input = $('modal-input');
  const confirm = $('modal-confirm');
  input.value = '';
  confirm.disabled = true;
  input.oninput = () => { confirm.disabled = input.value.trim() !== c.citizenId; };
  $('modal-cancel').onclick = () => $('modal').classList.add('hidden');
  confirm.onclick = async () => {
    const res = await post('delete', { id: c.id, citizenId: input.value.trim() });
    $('modal').classList.add('hidden');
    if (!res.ok) return toast(errorText(res.error));
    state.characters = res.characters;
    state.slots = res.slots;
    renderSlots();
    toast('Character deleted.', true);
  };
  $('modal').classList.remove('hidden');
  input.focus();
}

/* ---------- Creator ---------- */

function startCreate() {
  state.identity = { firstName: '', lastName: '', dob: '', gender: state.options.genders[0], nationality: state.options.nationalities[0], height: 175, biography: '' };
  state.app = defaultApp(MODELS.masculine);
  state.tab = 'Identity';
  state.errorField = null;
  $('create-title').textContent = 'Create your character';
  $('btn-submit').textContent = 'Create character';
  $('btn-back').textContent = 'Back';
  showScreen('create');
  $('rotate').classList.remove('hidden');
  renderTabs(['Identity', 'Heritage', 'Face', 'Hair and colour', 'Clothing']);
  preview();
}

function openWardrobe(appearance, limits) {
  state.app = JSON.parse(JSON.stringify(appearance));
  state.limits = limits;
  state.tab = 'Clothing';
  $('create-title').textContent = 'Wardrobe';
  $('btn-submit').textContent = 'Save appearance';
  $('btn-back').textContent = 'Close';
  showScreen('wardrobe');
  $('rotate').classList.add('hidden');
  loadOutfits();
  renderTabs(['Clothing', 'Outfits']);
}

let tabNames = [];
function renderTabs(names) {
  tabNames = names;
  const nav = $('tabs');
  nav.replaceChildren(...names.map((name) =>
    el('button', { type: 'button', role: 'tab', class: name === state.tab ? 'active' : '', onclick: () => { state.tab = name; renderTabs(tabNames); } }, name)));
  renderTab();
}

function field(labelText, control, key) {
  const wrap = el('label', { class: 'field' + (state.errorField === key ? ' error' : '') }, el('span', { class: 'lbl' }, labelText), control);
  return wrap;
}

function select(options, value, onChange) {
  const s = el('select', {}, options.map((o) => el('option', { value: o, text: o })));
  s.value = value;
  s.addEventListener('change', () => onChange(s.value));
  return s;
}

function renderTab() {
  const body = $('tab-body');
  body.replaceChildren();
  const tabs = { Identity: tabIdentity, Heritage: tabHeritage, Face: tabFace, 'Hair and colour': tabHair, Clothing: tabClothing, Outfits: tabOutfits };
  body.append(...tabs[state.tab]());
}

function tabIdentity() {
  const id = state.identity;
  const text = (key, max) => { const i = el('input', { type: 'text', maxlength: max, value: id[key], autocomplete: 'off' }); i.addEventListener('input', () => { id[key] = i.value; }); return i; };
  const dob = el('input', { type: 'date', value: id.dob });
  dob.addEventListener('input', () => { id.dob = dob.value; });
  const bio = el('textarea', { maxlength: state.options.maxBiography });
  bio.value = id.biography;
  bio.addEventListener('input', () => { id.biography = bio.value; });
  const model = select(['masculine', 'feminine'], state.app.model === MODELS.feminine ? 'feminine' : 'masculine', (v) => {
    state.app = Object.assign(defaultApp(MODELS[v]), { model: MODELS[v] });
    preview();
  });
  return [
    el('div', { class: 'two' }, field('First name', text('firstName', state.options.maxNameLength), 'firstName'), field('Last name', text('lastName', state.options.maxNameLength), 'lastName')),
    field(`Date of birth (${state.options.minAge} to ${state.options.maxAge} years old)`, dob, 'dob'),
    el('div', { class: 'two' },
      field('Gender', select(state.options.genders, id.gender, (v) => { id.gender = v; }), 'gender'),
      field('Nationality', select(state.options.nationalities, id.nationality, (v) => { id.nationality = v; }), 'nationality')),
    range('Height', state.options.minHeight, state.options.maxHeight, 1, id.height, (v) => { id.height = v; }, (v) => `${v} cm`),
    field('Character model', model, 'model'),
    field('Biography (optional)', bio, 'biography'),
  ];
}

function tabHeritage() {
  const hb = state.app.headBlend;
  const r = (label, key, max, step) => range(label, 0, max, step, hb[key], (v) => { hb[key] = v; preview(); });
  return [
    r('Shape: first parent', 'shapeFirst', 45, 1), r('Shape: second parent', 'shapeSecond', 45, 1),
    r('Shape mix', 'shapeMix', 1, 0.01), r('Skin tone: first parent', 'skinFirst', 45, 1),
    r('Skin tone: second parent', 'skinSecond', 45, 1), r('Skin mix', 'skinMix', 1, 0.01),
  ];
}

function tabFace() {
  return FACE_FEATURES.map((name, i) =>
    range(name, -1, 1, 0.05, state.app.faceFeatures[i], (v) => { state.app.faceFeatures[i] = v; preview(); }));
}

function tabHair() {
  const l = state.limits || { overlays: [], hairColours: 64, makeupColours: 64 };
  const a = state.app;
  const out = [
    range('Hair colour', 0, Math.max((l.hairColours || 64) - 1, 0), 1, a.hair.color, (v) => { a.hair.color = v; preview(); }),
    range('Hair highlights', 0, Math.max((l.hairColours || 64) - 1, 0), 1, a.hair.highlight, (v) => { a.hair.highlight = v; preview(); }),
    range('Eye colour', 0, 31, 1, a.eyeColor, (v) => { a.eyeColor = v; preview(); }),
    el('div', { class: 'group', text: 'Face details' }),
  ];
  OVERLAYS.forEach((name, i) => {
    const max = Math.max((l.overlays[i] || 1) - 1, -1);
    out.push(range(name, -1, max, 1, a.headOverlays[i].style, (v) => { a.headOverlays[i].style = v; preview(); }, (v) => (v < 0 ? 'None' : String(v))));
    if (COLOURED_OVERLAYS.has(i)) {
      out.push(range(`${name} colour`, 0, 63, 1, a.headOverlays[i].color, (v) => { a.headOverlays[i].color = v; preview(); }));
    }
  });
  const hairStyle = el('p', { class: 'hint', text: 'Hair style is part of the Clothing tab under "Hair style".' });
  out.push(hairStyle);
  return out;
}

function tabClothing() {
  const l = state.limits || { components: [], props: [] };
  const a = state.app;
  const out = [range('Hair style', 0, Math.max((l.components[2] || 1) - 1, 0), 1, a.hair.style, (v) => { a.hair.style = v; preview(); })];
  CLOTHING.forEach(([component, name]) => {
    const i = component; // index into a.components is component number (0-based)
    const c = a.components[i];
    const max = Math.max((l.components[i] || 1) - 1, 0);
    out.push(el('div', { class: 'group', text: name }));
    out.push(range('Style', 0, max, 1, c.drawable, async (v) => {
      c.drawable = v; c.texture = 0; preview();
      renderTextureSlider(i, 'component', component, v);
    }));
    out.push(el('div', { id: `tex-c-${i}` }, range('Variation', 0, 20, 1, c.texture, (v) => { c.texture = v; preview(); })));
  });
  PROPS.forEach((name, i) => {
    const p = a.props[i];
    const max = Math.max((l.props[i] || 0) - 1, -1);
    out.push(el('div', { class: 'group', text: name }));
    out.push(range('Style', -1, max, 1, p.drawable, (v) => { p.drawable = v; p.texture = 0; preview(); }, (v) => (v < 0 ? 'None' : String(v))));
    out.push(range('Variation', 0, 20, 1, p.texture, (v) => { p.texture = v; preview(); }));
  });
  return out;
}

async function renderTextureSlider(index, kind, id, drawable) {
  const res = await post('textureCount', { kind, id, drawable });
  const host = $(`tex-c-${index}`);
  if (!host || !res.ok) return;
  host.replaceChildren(range('Variation', 0, Math.max(res.count - 1, 0), 1, 0, (v) => { state.app.components[index].texture = v; preview(); }));
}

function tabOutfits() {
  const nameInput = el('input', { type: 'text', maxlength: 30, placeholder: 'Outfit name' });
  const save = el('button', { class: 'primary small', type: 'button', onclick: async () => {
    const res = await post('saveOutfit', { name: nameInput.value, appearance: state.app });
    if (!res.ok) return toast(errorText(res.error));
    state.outfits = res.outfits;
    nameInput.value = '';
    toast('Outfit saved.', true);
    renderTab();
  } }, 'Save current outfit');
  const list = state.outfits.length
    ? state.outfits.map((o) => el('div', { class: 'outfit' }, el('span', { text: o.name }), el('div', { class: 'row' },
        el('button', { class: 'ghost small', type: 'button', onclick: () => { state.app.components = o.components; state.app.props = o.props; preview(); toast('Outfit worn. Save appearance to keep it.', true); } }, 'Wear'),
        el('button', { class: 'ghost small', type: 'button', onclick: async () => {
          const res = await post('deleteOutfit', { id: o.id });
          if (res.ok) { state.outfits = res.outfits; renderTab(); } else toast(errorText(res.error));
        } }, 'Delete'))))
    : [el('p', { class: 'hint', text: 'No saved outfits yet. Choose your clothes, name them, then save.' })];
  return [el('div', { class: 'two' }, nameInput, save), el('div', { class: 'group', text: 'Saved outfits' }), ...list];
}

async function loadOutfits() {
  const res = await post('listOutfits');
  state.outfits = res.ok ? res.outfits : [];
  if (state.tab === 'Outfits') renderTab();
}

$('btn-back').addEventListener('click', async () => {
  if (state.mode === 'wardrobe') return post('closeWardrobe');
  showScreen('select');
  renderSlots();
});

$('btn-submit').addEventListener('click', async () => {
  const button = $('btn-submit');
  button.disabled = true;
  try {
    if (state.mode === 'wardrobe') {
      const res = await post('saveAppearance', { appearance: state.app });
      if (!res.ok) return toast(errorText(res.error));
      toast('Appearance saved.', true);
      return;
    }
    const res = await post('create', { identity: state.identity, appearance: state.app });
    if (!res.ok) {
      state.errorField = res.error && res.error.field;
      if (state.errorField) { state.tab = 'Identity'; renderTabs(tabNames); }
      toast(errorText(res.error));
    }
  } finally {
    button.disabled = false;
  }
});

$('rot').addEventListener('input', (e) => post('rotate', { degrees: Number(e.target.value) }));

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && state.mode === 'wardrobe') post('closeWardrobe');
});

window.addEventListener('message', (event) => {
  const m = event.data;
  if (m.action === 'close') { $('app').classList.add('hidden'); return; }
  if (m.action !== 'open') return;
  $('app').classList.remove('hidden');
  if (m.screen === 'select') {
    state.options = m.options;
    state.characters = m.characters || [];
    state.slots = m.slots;
    showScreen('select');
    renderSlots();
  } else {
    openWardrobe(m.appearance, m.limits);
  }
});
