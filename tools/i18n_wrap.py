"""Arayüz betiklerindeki ekrana giden Türkçe metinleri Data.L("...") ile sarar ve lang/keys.json'a
çevrilecek tüm kaynak metinleri (data.gd değerleri dahil) toplar.
Kullanım: python tools/i18n_wrap.py [--apply]   (bayraksız: sadece rapor)"""
import re, sys, json, glob, os

ROOT = os.path.join(os.path.dirname(__file__), '..')
UI_FILES = ['game', 'menu', 'stages', 'records', 'hangar', 'tree', 'codex', 'cine', 'ui', 'main']
LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
SKIP_CALLS = ('Color(', 'load(', 'preload(', 'tex(', 'sheet(', 'play(', 'play_music(', 'has(', 'get(', 'set_shader_parameter(',
              'is_action_pressed(', 'is_action_just_pressed(', 'get_vector(', 'name_to_tag(', 'get_meta(', 'set_meta(',
              'tween_property(', 'tween_method(', '_line(', 'has_node(', 'get_node(', 'begins_with(', 'trim_prefix(', 'split(',
              'connect(', 'Data.L(', 'make_enemy(', 'add_weapon(', 'theme_', 'override(', 'set_lang(')
TEXTY = re.compile(r'[ ÇĞİÖŞÜçğıöşü•▶★☆→✔☠%!?]|[A-ZÇĞİÖŞÜ]{2}')


def texty(t):
    return bool(re.search(r'[A-Za-zÇĞİÖŞÜçğıöşü]', t)) and bool(TEXTY.search(t)) and not t.startswith('res://')


def wrap_file(path, apply):
    s = open(path, encoding='utf-8').read()
    out, keys = [], set()
    for line in s.split('\n'):
        code = line.split(' # ')[0] if ' # ' in line else line
        if 'print(' in line or line.lstrip().startswith('#') or line.lstrip().startswith('##'):
            out.append(line); continue
        res, last = [], 0
        for m in LIT.finditer(code):
            t = m.group(1)
            before = code[:m.start()]
            after = code[m.end():]
            is_key = re.match(r'\s*:(?!=)', after) is not None
            call = re.search(r'([A-Za-z_\.]+\()\s*$', before)
            in_skip = call is not None and call.group(1).endswith(SKIP_CALLS)
            if texty(t) and not is_key and not in_skip and not before.rstrip().endswith('Data.L('):
                keys.add(t)
                res.append(line[last:m.start()] + 'Data.L("' + t + '")'); last = m.end()
        res.append(line[last:])
        out.append(''.join(res))
    if apply: open(path, 'w', encoding='utf-8').write('\n'.join(out))
    return keys


def data_keys():
    """data.gd'deki ekrana giden değerler (sözlük anahtarları ve kimlikler hariç)."""
    s = open(os.path.join(ROOT, 'scripts', 'data.gd'), encoding='utf-8').read()
    keys = set()
    for line in s.split('\n'):
        if line.lstrip().startswith('#'): continue
        for m in LIT.finditer(line):
            t = m.group(1)
            if re.match(r'\s*:(?!=)', line[m.end():]): continue
            before = line[:m.start()]
            if re.search(r'(Color|load|tex|sheet|name_to_tag)\(\s*$', before): continue
            if re.fullmatch(r'[a-z0-9_:/\.\-]*', t): continue
            if t.startswith('res://') or t.startswith('%'): continue
            if re.search(r'[A-Za-zÇĞİÖŞÜçğıöşü]', t): keys.add(t)
    return keys


if __name__ == '__main__':
    apply = '--apply' in sys.argv
    allk = set()
    for f in UI_FILES:
        k = wrap_file(os.path.join(ROOT, 'scripts', f + '.gd'), apply)
        allk |= k
        print(f, len(k))
    dk = data_keys(); print('data', len(dk))
    allk |= dk
    os.makedirs(os.path.join(ROOT, 'lang'), exist_ok=True)
    json.dump(sorted(allk), open(os.path.join(ROOT, 'lang', 'keys.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    print('toplam', len(allk), sum(map(len, allk)))
