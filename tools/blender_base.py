# ARKFALL — HAVA ÜSSÜ (kalkış sahnesi). Yukarıdan bakış, 1 birim = oyunda 1 piksel.
# Oyun koordinatı (x, y) -> Blender (x, -y). Pist x=-100..100, eşik y=230; sığınak x=-95..95, y=380..600 (kapı yukarı bakar).
# Çıktılar: art/3d/base.png (zemin, oyun x -800..800, y -2700..800) ve art/3d/base_roof.png (sığınak çatısı, uçağın üstünde çizilir)
# Çalıştır: blender -b -P tools/blender_base.py -- [--samples=32]
import bpy, bmesh, math, os, random, importlib.util
from mathutils import Vector

spec = importlib.util.spec_from_file_location('bs', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'blender_studio.py'))
bs = importlib.util.module_from_spec(spec); spec.loader.exec_module(bs)  # malzeme ve geometri yardımcıları
random.seed(41)
X0, X1, Y0, Y1 = -800, 800, -2700, 800

def W(x, y, z=0.0): return (x, -y, z)  # oyun -> Blender

def scene(w, h, cx, cy, ortho):
    root = bs.reset(ortho)
    sc = bpy.context.scene
    sc.render.resolution_x = w; sc.render.resolution_y = h; sc.render.resolution_percentage = 100
    sc.cycles.samples = int(bs.OPT.get('samples', 32))
    cam = sc.camera; cam.location = (cx, -cy, 1500); cam.data.clip_end = 4000
    for o in list(sc.collection.objects):  # stüdyo ışıkları yerine alçak, sıcak gün batımı güneşi: uzun gölgeler
        if o.type == 'LIGHT': bpy.data.objects.remove(o)
    def sun(e, col, rot):
        l = bpy.data.lights.new('s', 'SUN'); l.energy = e; l.color = col; l.angle = math.radians(2)
        o = bpy.data.objects.new('s', l); o.rotation_euler = [math.radians(a) for a in rot]; sc.collection.objects.link(o)
    sun(5.0, (1.0, 0.84, 0.66), (50, 0, -40))
    sun(0.9, (0.55, 0.65, 0.9), (-30, 0, 150))
    return root

def mat_tex(name, c1, c2, scale, rough=0.85, kind='noise'):
    m, b, t = bs.principled(name)
    tc = t.nodes.new('ShaderNodeTexCoord')
    n = t.nodes.new('ShaderNodeTexNoise'); n.inputs['Scale'].default_value = scale; n.inputs['Detail'].default_value = 6
    t.links.new(tc.outputs['Object'], n.inputs['Vector'])
    cr = t.nodes.new('ShaderNodeValToRGB'); cr.color_ramp.elements[0].color = (*c1, 1); cr.color_ramp.elements[1].color = (*c2, 1)
    t.links.new(n.outputs['Fac'], cr.inputs['Fac']); t.links.new(cr.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = rough
    return m

def slabs(name, col, scale):  # beton plakalar: tuğla dokusu derzleri
    m, b, t = bs.principled(name)
    tc = t.nodes.new('ShaderNodeTexCoord'); br = t.nodes.new('ShaderNodeTexBrick')
    br.inputs['Scale'].default_value = scale; br.inputs['Mortar Size'].default_value = 0.012; br.offset = 0.0
    br.inputs['Color1'].default_value = (*col, 1); br.inputs['Color2'].default_value = (*[v * 0.92 for v in col], 1); br.inputs['Mortar'].default_value = (*[v * 0.55 for v in col], 1)
    t.links.new(tc.outputs['Object'], br.inputs['Vector']); t.links.new(br.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.9
    return m

def box(root, x0, y0, x1, y1, z0, z1, mat, bevel=0.0):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(abs(x1 - x0), abs(y1 - y0), max(z1 - z0, 0.05)), verts=bm.verts)  # pah gerçek ölçüde olsun
    o = bs.obj('box', bm, mat, root, False, bevel)
    o.location = W((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    return o

def shelter_roof(root, cx, cy, mat, rim):
    # sertleştirilmiş uçak sığınağı: y boyunca uzanan beton kemer
    bm = bmesh.new(); seg = 16; L = 220.0; R = 95.0
    rings = []
    for yy in (cy - L / 2, cy + L / 2):
        rings.append([bm.verts.new((cx + math.cos(math.pi * i / seg) * R, -yy, math.sin(math.pi * i / seg) * 62.0)) for i in range(seg + 1)])
    for i in range(seg): bm.faces.new((rings[0][i], rings[0][i + 1], rings[1][i + 1], rings[1][i]))
    bm.faces.new(rings[1][::-1])  # arka duvar kapalı
    bs.obj('roof', bm, mat, root, True)
    box(root, cx - R - 4, cy - L / 2 - 6, cx + R + 4, cy - L / 2 + 4, 0, 64, rim, 1.0)  # ön alın kirişi

def base(root):
    grass = mat_tex('grass', (0.045, 0.065, 0.03), (0.12, 0.125, 0.065), 0.02)
    dirt = mat_tex('dirt', (0.1, 0.085, 0.06), (0.16, 0.13, 0.09), 0.03)
    asph = mat_tex('asph', (0.035, 0.035, 0.04), (0.07, 0.07, 0.075), 0.08, 0.95)
    conc = slabs('conc', (0.26, 0.26, 0.25), 0.012)
    dark = slabs('floor', (0.13, 0.13, 0.13), 0.02)
    white = bs.metal((0.8, 0.8, 0.78), 0.8, 0.0); yellow = bs.metal((0.85, 0.62, 0.06), 0.7, 0.0)
    wall = bs.metal((0.22, 0.22, 0.21), 0.9, 0.0); olive = bs.metal((0.16, 0.18, 0.1), 0.6, 0.3)
    box(root, X0, Y0, X1, Y1, -2, 0, grass)
    for i in range(14):  # bombalanmış toprak lekeleri: savaş havası
        x, y = random.choice([-1, 1]) * random.uniform(180, 700), random.uniform(Y0, Y1)
        o = bs.sphere(root, W(x, y, -6), random.uniform(20, 46), dirt, (1, random.uniform(0.7, 1.3), 0.15))
    # pist
    box(root, -100, Y0, 100, 232, 0, 0.6, asph)
    for sx in (-1, 1): box(root, sx * 92 - 2, Y0, sx * 92 + 2, 232, 0.6, 0.8, white)
    for y in range(Y0 + 40, 150, 80): box(root, -3, y, 3, y + 40, 0.6, 0.8, white)
    for k in range(8):
        x = -70 + k * 16 + (12 if k >= 4 else 0); box(root, x, 160, x + 9, 214, 0.6, 0.8, white)
    bpy.ops.object.text_add(location=W(0, 110, 0.9)); tx = bpy.context.object; tx.data.body = '27'; tx.data.size = 54; tx.data.align_x = 'CENTER'; tx.data.align_y = 'CENTER'
    tx.rotation_euler = (0, 0, 0); tx.data.materials.append(white); tx.parent = root
    amber, green = bs.emit((1.0, 0.7, 0.3), 9), bs.emit((0.3, 1.0, 0.4), 9)
    for y in range(Y0, 232, 60):
        for sx in (-1, 1): bs.sphere(root, W(sx * 108, y, 1.5), 2.6, amber)
    for x in range(-96, 100, 16): bs.sphere(root, W(x, 228, 1.5), 2.4, green)
    # pist kenarı biçilmiş açık şerit, paralel taksi yolu ve bağlantıları
    mown = mat_tex('mown', (0.09, 0.11, 0.05), (0.13, 0.14, 0.07), 0.02)
    for sx in (-1, 1): box(root, sx * 100, Y0, sx * 150, 232, -0.5, 0.1, mown)
    box(root, -262, Y0 + 200, -202, 232, 0, 0.5, asph)
    for y in (-2300, -1200, -60):
        box(root, -202, y, -100, y + 60, 0, 0.5, asph); box(root, -233, y + 28, -100, y + 32, 0.5, 0.7, yellow)
    box(root, -233, Y0 + 200, -229, 232, 0.5, 0.7, yellow)
    # servis yolu ve bina sıraları (kışla, depo, atölye): düz çatılar, çatı üstü cihazlar
    box(root, 590, Y0, 640, Y1, 0, 0.4, asph)
    roofc = mat_tex('rooftop', (0.13, 0.13, 0.135), (0.2, 0.2, 0.2), 0.05, 0.9); unit = bs.metal((0.45, 0.46, 0.46), 0.5, 0.4)
    y = -2550
    while y < -150:
        h = random.uniform(70, 150); w = random.uniform(120, 230); x0 = random.uniform(270, 560 - w)
        box(root, x0, y, x0 + w, y + h, 0, random.uniform(14, 30), roofc, 1.0)
        for i in range(random.randint(1, 4)):
            ux, uy = x0 + random.uniform(8, w - 24), y + random.uniform(8, h - 24); box(root, ux, uy, ux + 14, uy + 14, 30, 36, unit)
        y += h + random.uniform(40, 120)
    for i in range(10):  # yan taraftaki depo hangarları
        yy = -2450 + i * 230 + random.uniform(-30, 30)
        if -560 < yy < -480: continue
        box(root, -500, yy, -330, yy + 110, 0, 26, roofc, 1.0)
    # apron ve sığınaklar arası yollar
    box(root, -260, 232, 260, 640, 0, 0.5, conc)
    for sx in (-1, 1): box(root, sx * 260, 400, sx * 520, 460, 0, 0.45, conc)
    box(root, -2, 250, 2, 560, 0.5, 0.7, yellow)            # sığınaktan piste sarı rehber çizgisi
    for dy in (246, 254): box(root, -96, dy - 1.5, 96, dy + 1.5, 0.5, 0.7, yellow)  # bekleme çizgisi
    # oyuncunun sığınağı: iç zemin + yan duvarlar (çatı ayrı katmanda)
    box(root, -95, 380, 95, 600, 0, 0.55, dark)
    box(root, -1.5, 390, 1.5, 590, 0.55, 0.7, yellow)
    for sx in (-1, 1): box(root, sx * 95 - 8, 380, sx * 95 + 8, 606, 0, 40, wall, 1.5)
    box(root, -103, 598, 103, 612, 0, 40, wall, 1.5)
    # diğer sığınaklar (kapılar kapalı, çatılar tabanda)
    roofm = bs.camo((0.3, 0.3, 0.27), (0.2, 0.21, 0.17))
    for sx in (-1, 1):
        shelter_roof(root, sx * 430, 450, roofm, wall)
        box(root, sx * 430 - 95, 338, sx * 430 + 95, 342, 0, 60, bs.metal((0.2, 0.21, 0.2), 0.5, 0.6))
    # park halindeki uçaklar (oyuncunun filosu)
    for (x, y, rot, key) in [(-185, 520, 0, 'dogan'), (185, 520, 0, 'kartal')]:
        e = bpy.data.objects.new('p', None); bpy.context.scene.collection.objects.link(e); e.parent = root
        e.location = W(x, y, 4); e.rotation_euler = (0, 0, math.radians(rot)); bs.build_plane(e, bs.P[key])
    # kule, yakıt tankları, radar, kamyonlar, uçaksavar
    box(root, 300, 60, 360, 120, 0, 70, wall, 2.0); box(root, 304, 64, 356, 116, 70, 84, bs.glass()); box(root, 308, 68, 352, 112, 84, 88, wall, 1.0)
    bs.cyl(root, W(330, 90, 96), 1.2, 22, white, 'Z')
    tank = bs.metal((0.62, 0.62, 0.6), 0.4, 0.5)
    for (x, y) in [(-470, -180), (-470, -270), (-395, -225)]: bs.cyl(root, W(x, y, 18), 32, 36, tank, 'Z', 32); bs.cyl(root, W(x, y, 37), 22, 2, wall, 'Z', 32)
    bs.cyl(root, W(480, -520, 10), 16, 20, wall, 'Z'); bs.sphere(root, W(480, -520, 34), 30, bs.metal((0.7, 0.72, 0.7), 0.3, 0.6), (1, 0.35, 0.8))
    for (x, y, r) in [(220, 300, 10), (240, 335, -6), (-230, 300, 4), (-330, -60, 80), (410, 160, 90)]:
        t = box(root, x - 9, y - 22, x + 9, y + 22, 0, 16, olive, 1.0); t.rotation_euler[2] = math.radians(r)
    sand = bs.metal((0.35, 0.3, 0.2), 0.95, 0.0)
    for (x, y) in [(-300, -700), (300, -1300), (-300, -1900)]:  # kum torbalı uçaksavar mevzileri
        for i in range(10):
            a = i * math.tau / 10; bs.sphere(root, W(x + math.cos(a) * 26, y + math.sin(a) * 26, 4), 9, sand, (1, 1, 0.6))
        bs.cyl(root, W(x, y, 10), 8, 12, olive, 'Z'); bs.bar(root, W(x, y, 18), W(x + 22, y - 22, 26), 2.2, 2.2, wall)
    # çevre: ağaç kümeleri ve tel çit
    leaf = mat_tex('leaf', (0.03, 0.06, 0.025), (0.07, 0.1, 0.04), 0.2)
    for i in range(170):
        x = random.choice([-1, 1]) * random.uniform(560, 790); y = random.uniform(Y0, Y1)
        if abs(x) < 640 and -560 < y < -480: continue
        bs.sphere(root, W(x, y, 8), random.uniform(12, 26), leaf, (1, 1, 0.8))
    for sx in (-1, 1): box(root, sx * 545 - 1, Y0, sx * 545 + 1, Y1, 0, 6, wall)

def roof(root):
    roofm = bs.camo((0.3, 0.3, 0.27), (0.2, 0.21, 0.17)); wall = bs.metal((0.22, 0.22, 0.21), 0.9, 0.0)
    shelter_roof(root, 0, 490, roofm, wall)
    bs.sphere(root, W(0, 395, 66), 3, bs.emit((1.0, 0.2, 0.15), 14))  # kapı üstü uyarı lambası

def shoot(name, build, w, h, cx, cy, ortho, transparent):
    root = scene(w, h, cx, cy, ortho); build(root)
    sc = bpy.context.scene; sc.render.film_transparent = transparent
    sc.render.filepath = os.path.join(bs.OUT, name + '.png'); bpy.ops.render.render(write_still=True)
    print('BLENDER', name, flush=True)

os.makedirs(bs.OUT, exist_ok=True)
if bs.OPT.get('only', 'base') in ('base', 'all'): shoot('base', base, 1600, 3500, 0, (Y0 + Y1) / 2, 3500, False)
if bs.OPT.get('only', 'roof') in ('roof', 'all'): shoot('base_roof', roof, 240, 256, 0, 490, 256, True)
