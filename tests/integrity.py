"""Static checks across every Nexoro resource: manifests, dependencies, exports, callbacks, server.cfg order."""
import os, re, glob, sys
ROOT = 'resources/[nexoro]'
problems = []
resources = sorted(d for d in os.listdir(ROOT) if os.path.isdir(os.path.join(ROOT, d)))

def read(p):
    with open(p, encoding='utf-8', errors='replace') as f:
        return f.read()

manifests = {}
for r in resources:
    mf = os.path.join(ROOT, r, 'fxmanifest.lua')
    if not os.path.exists(mf):
        problems.append(f'{r}: no fxmanifest.lua'); continue
    manifests[r] = read(mf)

# 1. every file named in a manifest exists
for r, m in manifests.items():
    base = os.path.join(ROOT, r)
    def check(path, optional_glob=False):
        if path.startswith('@'):
            ref = path[1:]
            res, _, rest = ref.partition('/')
            if res.startswith('nexoro_') and res in manifests:
                if not os.path.exists(os.path.join(ROOT, res, rest)):
                    problems.append(f'{r}: refers to {path} which does not exist')
            return
        if '*' in path:
            if not glob.glob(os.path.join(glob.escape(base), path)) and not optional_glob:
                problems.append(f'{r}: no files match {path}')
            return
        if not os.path.exists(os.path.join(base, path)):
            problems.append(f'{r}: missing file {path}')
    for key in ['shared_script', 'server_script', 'client_script', 'ui_page', 'loadscreen']:
        for path in re.findall(rf"{key}\s+'([^']+)'", m):
            check(path)
    for block in re.findall(r"(?:shared_scripts|server_scripts|client_scripts|files)\s*\{([^}]*)\}", m, re.S):
        for path in re.findall(r"'([^']+)'", block):
            check(path, optional_glob=True)

# 2. every dependency is a resource that exists
for r, m in manifests.items():
    for block in re.findall(r"dependenc(?:y|ies)\s*\{?([^\n}]*)", m):
        for dep in re.findall(r"'([^']+)'", block):
            if dep.startswith('nexoro_') and dep not in manifests:
                problems.append(f'{r}: depends on missing resource {dep}')

# 3. every nexoro export called from another resource is defined by that resource
defined = {}
for r in manifests:
    src = ''
    for f in glob.glob(os.path.join(glob.escape(ROOT), r, '**', '*.lua'), recursive=True):
        src += read(f)
    defined[r] = set(re.findall(r"exports\('([^']+)'", src))
core_api_names = set(re.findall(r"API\.(\w+)\s*=", read(os.path.join(ROOT, 'nexoro_core/server/api.lua'))))
core_api_names |= set(re.findall(r"^function API\.(\w+)", read(os.path.join(ROOT, 'nexoro_core/server/api.lua')), re.M))
core_api_names |= set(re.findall(r"for name, fn in pairs\(API\)", ''))  # loop-exported names are covered by API.*
for r in manifests:
    for f in glob.glob(os.path.join(glob.escape(ROOT), r, '**', '*.lua'), recursive=True):
        for res, name in re.findall(r"exports\.(nexoro_\w+):(\w+)\(", read(f)):
            if res == 'nexoro_core':
                if name not in core_api_names and name not in ('GetCore', 'IsReady', 'RegisterKeybind', 'TriggerCallback', 'GetCharacterData', 'IsCharacterLoaded', 'GetStatus'):
                    # core API functions are exported by name in api.lua, plus those defined in other core files
                    if name not in defined.get('nexoro_core', set()):
                        problems.append(f'{os.path.relpath(f, ROOT)}: calls exports.nexoro_core:{name} which is not defined')
                continue
            if res not in defined:
                problems.append(f'{os.path.relpath(f, ROOT)}: calls exports.{res}:{name} but {res} is not a resource')
            elif name not in defined[res]:
                problems.append(f'{os.path.relpath(f, ROOT)}: calls exports.{res}:{name} which {res} does not define')

# 4. every client callback name is registered by some server resource.
# Callbacks are requests with a reply (NexoroCore.Callback, or a local helper that wraps it).
# Events (TriggerServerEvent, RegisterNetEvent, TriggerEvent, TriggerClientEvent) are not callbacks and are skipped.
CALLBACK_CALL = re.compile(r"(?:NexoroCore\.Callback|\bcall|\bact|\brequest|\bdoCallback)\(\s*'([a-zA-Z_:]+)'")
registered = set()
for r in manifests:
    for f in glob.glob(os.path.join(glob.escape(ROOT), r, '**', '*.lua'), recursive=True):
        t = read(f)
        prefixes = re.findall(r"'(nexoro_[a-z_]+:)'\s*\.\.\s*name", t)
        for name in re.findall(r"RegisterCallback\(\s*'([^']+)'", t):
            registered.add(name)
        for name in re.findall(r"\bcb\(\s*'([^']+)'", t):
            if '..' in name: continue
            if name.startswith('nexoro_'):
                registered.add(name)
            for pre in prefixes:
                registered.add(pre + name)
            # helpers that add a module prefix when they register
            if not prefixes:
                registered.add(name)
called = {}
for r in manifests:
    for f in glob.glob(os.path.join(glob.escape(ROOT), r, '**', '*.lua'), recursive=True):
        if '/client/' not in f.replace(os.sep, '/'):
            continue
        t = read(f)
        cprefixes = re.findall(r"'(nexoro_[a-z_]+:)'\s*\.\.", t)   # client helpers that add a module prefix
        for name in CALLBACK_CALL.findall(t):
            if name.endswith(':'):
                continue  # built at runtime (admin endpoints), checked by admin's own table
            full = name if name.startswith('nexoro_') or not cprefixes else cprefixes[0] + name
            called.setdefault(full, []).append(os.path.relpath(f, ROOT))
for name, where in sorted(called.items()):
    if name not in registered:
        for w in sorted(set(where)):
            problems.append(f'{w}: client calls callback {name} which no server registers')

# 5. start order in the server.cfg template: each resource starts after its dependencies
cfg = read('dev/server.cfg.template')
order = [m for m in re.findall(r"^ensure (\S+)", cfg, re.M)]
for r in order:
    if r not in manifests and r not in ('oxmysql', 'mapmanager', 'sessionmanager'):
        problems.append(f'server.cfg: ensures {r} but no such resource exists')
pos = {r: i for i, r in enumerate(order)}
for r in order:
    if r in manifests:
        for block in re.findall(r"dependenc(?:y|ies)\s*\{?([^\n}]*)", manifests[r]):
            for dep in re.findall(r"'([^']+)'", block):
                if dep in pos and pos[dep] > pos[r]:
                    problems.append(f'server.cfg: {r} starts before its dependency {dep}')
for r in manifests:
    if r not in pos:
        problems.append(f'server.cfg: {r} is never started')

print(f'checked {len(manifests)} resources, {len(called)} client callbacks, {len(order)} ensure lines')
for p in problems:
    print('PROBLEM', p)
print(f'{len(problems)} problem(s)')

# 6. the txAdmin recipe and the server.cfg template must start the same resources
import yaml
recipe_path = 'recipe.yaml'
if os.path.exists(recipe_path):
    recipe = yaml.safe_load(read(recipe_path))
    body = next(t['data'] for t in recipe['tasks'] if t.get('action') == 'write_file')
    from_recipe = re.findall(r'^\s*ensure (\S+)', body, re.M)
    from_template = re.findall(r'^ensure (\S+)', read('dev/server.cfg.template'), re.M)
    dup = sorted({x for x in from_recipe if from_recipe.count(x) > 1})
    if dup:
        print('PROBLEM recipe.yaml starts these twice:', ', '.join(dup)); problems.append('dup'); sys.exit(1)
    if set(from_recipe) != set(from_template):
        diff = sorted(set(from_recipe) ^ set(from_template))
        print('PROBLEM recipe.yaml and server.cfg.template start different resources:', ', '.join(diff)); sys.exit(1)
    print(f'recipe and template match: {len(set(from_recipe))} resources')

sys.exit(1 if problems else 0)
