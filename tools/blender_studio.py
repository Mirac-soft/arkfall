# ARKFALL — BLENDER STÜDYOSU
# Oyuncu uçaklarını ve Vahar gemilerini Blender'da kurar, Cycles ile ışın izlemeli render alır,
# 7 yatış açısını yan yana art/3d/<ad>.png şeridine kaydeder (Godot stüdyosuyla aynı format).
# Çalıştır:  blender -b -P tools/blender_studio.py -- [--only=kartal] [--samples=64]
# Ölçek: 1 birim = SVG'de 1 piksel, çıktı 2x çözünürlük. Burun +Y yönünde, yukarıdan bakış.
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OPT = dict(a[2:].split('=', 1) if '=' in a else (a[2:], '1') for a in ARGS)
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
OUT = os.path.join(ROOT, 'art', '3d')
TMP = os.path.join(OUT, '_tmp.png')
ROLLS, MAX_ROLL = 7, 55.0

def hexc(h):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)  # sRGB -> doğrusal

# ---------------- sahne ----------------
def reset(units):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = int(OPT.get('samples', 48)); sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.exposure = 0.0
    sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGBA'
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.32, 0.38, 0.48, 1); bg.inputs[1].default_value = 0.32
    def sun(name, energy, col, rot):
        l = bpy.data.lights.new(name, 'SUN'); l.energy = energy; l.color = col; l.angle = math.radians(4)
        o = bpy.data.objects.new(name, l); o.rotation_euler = [math.radians(a) for a in rot]; sc.collection.objects.link(o)
    sun('key', 5.6, (1.0, 0.96, 0.9), (35, -28, -35))
    sun('fill', 1.1, (0.6, 0.75, 1.0), (-40, 30, 140))
    sun('rim', 2.2, (1.0, 0.85, 0.7), (75, 0, 180))
    cam = bpy.data.cameras.new('cam'); cam.type = 'ORTHO'; cam.ortho_scale = units; cam.clip_end = 1000
    co = bpy.data.objects.new('cam', cam); co.location = (0, 0, 300); sc.collection.objects.link(co); sc.camera = co
    root = bpy.data.objects.new('root', None); sc.collection.objects.link(root)
    return root

# ---------------- malzemeler ----------------
def principled(name):
    m = bpy.data.materials.new(name); m.use_nodes = True
    return m, m.node_tree.nodes['Principled BSDF'], m.node_tree
def metal(col, rough=0.4, met=0.6, panels=False):
    m, b, t = principled('metal')
    b.inputs['Base Color'].default_value = (*col, 1); b.inputs['Metallic'].default_value = met; b.inputs['Roughness'].default_value = rough
    if panels: _panels(t, b)
    return m
def _panels(t, b, scale=0.07):
    # panel derzleri: Voronoi kenar uzaklığı -> ince oluk (bump) + hafif koyulaşma
    tc = t.nodes.new('ShaderNodeTexCoord'); vo = t.nodes.new('ShaderNodeTexVoronoi'); vo.feature = 'DISTANCE_TO_EDGE'; vo.inputs['Scale'].default_value = scale
    t.links.new(tc.outputs['Object'], vo.inputs['Vector'])
    cr = t.nodes.new('ShaderNodeValToRGB'); cr.color_ramp.elements[0].position = 0.0; cr.color_ramp.elements[1].position = 0.035
    t.links.new(vo.outputs['Distance'], cr.inputs['Fac'])
    bump = t.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.35
    t.links.new(cr.outputs['Color'], bump.inputs['Height']); t.links.new(bump.outputs['Normal'], b.inputs['Normal'])
def camo(c1, c2):
    m, b, t = principled('camo')
    tc = t.nodes.new('ShaderNodeTexCoord'); n = t.nodes.new('ShaderNodeTexNoise'); n.inputs['Scale'].default_value = 0.05; n.inputs['Detail'].default_value = 3
    t.links.new(tc.outputs['Object'], n.inputs['Vector'])
    cr = t.nodes.new('ShaderNodeValToRGB'); cr.color_ramp.interpolation = 'CONSTANT'
    cr.color_ramp.elements[0].color = (*[min(1.0, v * 1.25) for v in c1], 1); cr.color_ramp.elements[1].position = 0.52; cr.color_ramp.elements[1].color = (*c2, 1)
    t.links.new(n.outputs['Fac'], cr.inputs['Fac']); t.links.new(cr.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Metallic'].default_value = 0.45; b.inputs['Roughness'].default_value = 0.5
    _panels(t, b)
    return m
def emit(col, strength=8.0):
    m, b, t = principled('glow')
    b.inputs['Base Color'].default_value = (*col, 1); b.inputs['Emission Color'].default_value = (*col, 1); b.inputs['Emission Strength'].default_value = strength
    return m
def glass():
    m, b, t = principled('glass')
    b.inputs['Base Color'].default_value = (0.01, 0.04, 0.09, 1); b.inputs['Metallic'].default_value = 0.2; b.inputs['Roughness'].default_value = 0.03
    b.inputs['Coat Weight'].default_value = 1.0; b.inputs['Emission Color'].default_value = (0.05, 0.25, 0.4, 1); b.inputs['Emission Strength'].default_value = 0.4
    return m
def hull(col=(0.045, 0.055, 0.05)):  # Vahar: koyu namlu çeliği, cilalı (ışıklar asit yeşili, mermiler pembe: karışmasın)
    m, b, t = principled('hull')
    b.inputs['Base Color'].default_value = (*col, 1); b.inputs['Metallic'].default_value = 0.6; b.inputs['Roughness'].default_value = 0.28
    b.inputs['Coat Weight'].default_value = 0.8; b.inputs['Coat Roughness'].default_value = 0.1
    _panels(t, b, 0.09)
    return m

# ---------------- geometri ----------------
def obj(name, bm, mat, root, smooth=True, bevel=0.0, subsurf=0):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o); o.parent = root
    me.materials.append(mat)
    for p in me.polygons: p.use_smooth = smooth
    if bevel > 0:
        md = o.modifiers.new('bev', 'BEVEL'); md.width = bevel; md.segments = 2; md.limit_method = 'ANGLE'
    if subsurf:
        md = o.modifiers.new('sub', 'SUBSURF'); md.levels = subsurf; md.render_levels = subsurf
    return o
def lathe(root, prof, k, mat, flat=0.55, z=0.0, seg=24, samples=26):
    # prof: [[yarıçap, y2d]] burun -y2d. Kesitler arası doğrusal ara değer, eliptik halkalar
    pts = [(p[0] * k, -p[1] * k) for p in prof]
    ys = [pts[0][1] + (pts[-1][1] - pts[0][1]) * i / (samples - 1) for i in range(samples)]
    def rad_at(y):
        for (r0, y0), (r1, y1) in zip(pts, pts[1:]):
            if (y0 >= y >= y1) or (y1 >= y >= y0):
                f = 0 if y1 == y0 else (y - y0) / (y1 - y0)
                return r0 + (r1 - r0) * f
        return 0.0
    bm = bmesh.new(); rings = []
    for y in ys:
        r = max(rad_at(y), 0.05)
        rings.append([bm.verts.new((math.cos(a) * r, y, z + math.sin(a) * r * flat)) for a in [i * 2 * math.pi / seg for i in range(seg)]])
    for a, b in zip(rings, rings[1:]):
        for i in range(seg): bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
    bm.faces.new(rings[0][::-1]); bm.faces.new(rings[-1])
    return obj('body', bm, mat, root, True, 0, 1)
def plate(root, poly, k, mat, thick=1.4, z=0.0, flip=False, bevel=0.35):
    bm = bmesh.new()
    vs = [bm.verts.new(((-p[0] if flip else p[0]) * k, -p[1] * k, z)) for p in poly]
    f = bm.faces.new(vs if not flip else vs[::-1])
    if f.normal.z < 0: f.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, verts=[e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)], vec=(0, 0, -thick))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj('plate', bm, mat, root, False, bevel)
def fin(root, x, y0, y1, h, mat, thick=0.9):
    bm = bmesh.new()
    vs = [bm.verts.new((x, -y, zz)) for y, zz in [(y1, 0), (y0, 0), (y1 - 1.0, h), (y1, h)]]
    f = bm.faces.new(vs); ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, verts=[e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)], vec=(thick, 0, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj('fin', bm, mat, root, False, 0.3)
def cyl(root, loc, r, depth, mat, axis='Y', seg=20, r2=None):
    bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    rot = {'Y': (math.pi / 2, 0, 0), 'Z': (0, 0, 0), 'X': (0, math.pi / 2, 0)}[axis]
    o = obj('cyl', bm, mat, root, True, 0.15 if depth > 1 else 0); o.rotation_euler = rot; o.location = loc
    return o
def sphere(root, loc, r, mat, sc=(1, 1, 1)):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=r)
    o = obj('sph', bm, mat, root, True); o.location = loc; o.scale = sc
    return o
def bar(root, a, b, w, h, mat):
    a, b = Vector(a), Vector(b); d = b - a
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    o = obj('bar', bm, mat, root, False, 0.1); o.scale = (w, d.length, h); o.location = (a + b) / 2
    o.rotation_euler = (0, 0, math.atan2(-d.x, d.y))
    return o
def star(root, loc, r, mat):
    bm = bmesh.new()
    vs = [bm.verts.new((loc[0] + math.cos(-math.pi / 2 + i * math.pi / 5) * (r if i % 2 == 0 else r * 0.42), loc[1] - math.sin(-math.pi / 2 + i * math.pi / 5) * (r if i % 2 == 0 else r * 0.42), loc[2])) for i in range(10)]
    bm.faces.new(vs)
    return obj('star', bm, mat, root, False)

# ---------------- oyuncu uçakları ----------------
P = {
    'serce': dict(main='8fa3b5', camo='6c7f92', acc='4fd8ff', k=1.75, fins=1, body=[[0, -26], [4, -16], [5.5, 4], [4.5, 15], [0, 19]], wing=[[4.5, -5], [24, 8], [24, 13], [4.5, 11]],
        extra=[[[3.5, 11], [11, 18], [11, 21], [3.5, 18]]], cockpit=[0, -12, 2.8, 6.5], eng=[[0, 20, 3.4]]),
    'dogan': dict(main='7d8f6a', camo='56653f', acc='57ff9a', k=1.65, fins=1, body=[[0, -30], [4.5, -19], [6.5, 2], [5.5, 17], [0, 21]], wing=[[5.5, 2], [27, -9], [29, -4], [6.5, 14]],
        extra=[[[3.5, -16], [11, -13], [11, -10], [3.5, -10]], [[4.5, 13], [13, 21], [13, 24], [4.5, 21]]], cockpit=[0, -15, 3, 6.5], eng=[[0, 22, 4]]),
    'simsek': dict(main='c8c2a8', camo='9e9474', acc='ffe14f', k=1.55, fins=2, body=[[0, -38], [3.4, -23], [4.5, 8], [3.4, 23], [0, 26]], wing=[[3.4, -3], [22, 14], [22, 18], [4.5, 13]],
        extra=[[[2.4, -20], [9, -12], [2.4, -12]], [[3.4, 15], [11, 26], [9, 28], [3.4, 24]]], cockpit=[0, -19, 2.4, 7.5], eng=[[-2.6, 27, 2.6], [2.6, 27, 2.6]]),
    'kartal': dict(main='7a6e62', camo='544a42', acc='ff9a3c', k=1.6, fins=2, body=[[0, -29], [6.5, -19], [8.5, 8], [7.5, 21], [0, 24]], wing=[[7.5, -8], [34, 9], [34, 15], [19, 15], [8.5, 13]],
        extra=[[[6.5, 14], [18, 22], [18, 27], [6.5, 23]], [[22, -3], [26, -3], [26, 15], [22, 15]]], cockpit=[0, -16, 3.6, 7.5], eng=[[-4.8, 25, 3.6], [4.8, 25, 3.6]]),
    'anka': dict(main='3e2a4a', camo='2a1d33', acc='ff4fd8', k=1.55, fins=2, gold=True, body=[[0, -33], [5.5, -21], [6.5, 6], [4.5, 19], [0, 25]],
        wing=[[5.5, -10], [21, -6], [38, 6], [32, 9], [39, 14], [28, 14], [32, 20], [19, 16], [6.5, 12]], extra=[[[4.5, 15], [14, 28], [7.5, 26], [3.4, 23]]], cockpit=[0, -18, 3.2, 7.5], eng=[[-3.2, 26, 3.4], [3.2, 26, 3.4]]),
}
def build_plane(root, d):
    k = d['k']; main, cm, acc = hexc(d['main']), hexc(d['camo']), hexc(d['acc'])
    mb = metal(tuple(v * 0.9 for v in main), 0.45, 0.55, panels=True); mc = camo(main, cm); dark = metal((0.03, 0.035, 0.04), 0.45, 0.8)
    white, navy, red = metal((0.85, 0.85, 0.85), 0.5, 0.0), metal((0.02, 0.05, 0.16), 0.5, 0.0), emit((1.0, 0.1, 0.12), 3)
    lathe(root, d['body'], k, mb, 0.5)
    for flip in (False, True):
        sx = -1 if flip else 1
        plate(root, d['wing'], k, mc, 1.6, 0.6, flip)
        for e in d['extra']: plate(root, e, k, mc, 1.1, 0.4, flip)
        w = d['wing']
        bar(root, (w[0][0] * k * sx, -w[0][1] * k, 0.75), (w[1][0] * k * sx, -w[1][1] * k, 0.75), 0.9, 0.5, emit(acc, 4))
        cx = sum(p[0] for p in w[:3]) / 3 * k * sx; cy = -sum(p[1] for p in w[:3]) / 3 * k
        cyl(root, (cx, cy, -1.4), 1.3, 15, metal((0.85, 0.87, 0.9), 0.3, 0.3)); sphere(root, (cx, cy + 7.5, -1.4), 1.3, red)
        rx, ry = cx + sx * 4.0, cy - 1.0  # nişan: beyaz halka, lacivert disk, beyaz yıldız
        cyl(root, (rx, ry, 0.68), 4.4, 0.08, white, 'Z', 32); cyl(root, (rx, ry, 0.72), 3.6, 0.08, navy, 'Z', 32); star(root, (rx, ry, 0.78), 2.6, white)
        tip = max(w, key=lambda p: p[0])
        sphere(root, (tip[0] * k * sx, -tip[1] * k, 0.6), 0.9, emit((1, 0.15, 0.15) if flip else (0.15, 1, 0.25), 10))
    tail = d['body'][3][1] * k
    if d['fins'] == 1: fin(root, -0.45, tail - 14, tail + 2, 9, mb)
    else:
        for sx in (-1, 1): fin(root, sx * 4.5 * k / 1.6 - 0.45, tail - 12, tail + 3, 8, mb)
    c = d['cockpit']
    body_r = max(p[0] for p in d['body'] if abs(p[1] - c[1]) < 12) * k  # kokpit gövdenin üst yüzeyine oturur
    sphere(root, (0, -c[1] * k, body_r * 0.5 * 0.85), c[2] * k * 0.85, glass(), (1.0, c[3] / c[2], 0.75))
    for e in d['eng']:
        cyl(root, (e[0] * k, -(e[1] * k + 1.5), 0), e[2] * k, 5, dark)
        cyl(root, (e[0] * k, -(e[1] * k + 4.1), 0), e[2] * k * 0.62, 0.4, emit((1.0, 0.45, 0.12), 12))
    if d.get('gold'):
        g = metal((0.95, 0.68, 0.2), 0.2, 1.0)
        bar(root, (0, -(d['body'][0][1] * k + 6), 2.6), (0, -tail, 2.6), 1.2, 0.6, g)

# ---------------- Vahar gemileri ----------------
def build_drone(root):
    h, d, g = hull(), metal((0.05, 0.04, 0.05), 0.4, 0.7), emit((0.42, 1.0, 0.08), 10)
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=13)
    o = obj('hull', bm, h, root, True); o.scale = (1, 1, 0.42)
    for i in range(3):
        a = -math.pi / 2 + i * 2 * math.pi / 3; tip = (math.cos(a) * 21, -math.sin(a) * 21, 0)
        bar(root, (0, 0, 0), tip, 3, 2, d); sphere(root, tip, 5, h, (1, 1, 0.45)); sphere(root, (tip[0], tip[1], 1.6), 2.2, g)
    sphere(root, (0, 0, 4), 5, g, (1, 0.8, 0.6))
def build_avci(root):
    h, g = hull(), emit((0.42, 1.0, 0.08), 9)
    lathe(root, [[0, -36], [4, -20], [6.5, 10], [0, 24]], 1, h, 0.6)
    for f in (False, True):
        sx = -1 if f else 1
        plate(root, [[6, -8], [26, -4], [36, 10], [30, 26], [22, 16], [14, 14], [7, 16]], 1, h, 1.4, 0.4, f)
        bar(root, (10 * sx, 4, 0.9), (30 * sx, -18, 0.9), 1.0, 0.5, g)
    sphere(root, (0, 12, 2.5), 3.2, g, (1, 2.4, 0.6))
    for sx in (-4, 4): sphere(root, (sx, -22, 0), 2.6, emit((0.42, 1.0, 0.08), 10))
def build_kamikaze(root):
    h, y = hull(), emit((0.42, 1.0, 0.08), 9)
    lathe(root, [[0, -36], [7, -8], [5.5, 22], [0, 17]], 1, h, 0.8)
    for f in (False, True): plate(root, [[5, 2], [17, 28], [5, 19]], 1, h, 1.0, 0.0, f)
    for yy in (14, 4, -6): cyl(root, (0, yy, 0), 6.0, 1.6, y)
    sphere(root, (0, 30, 0), 3, y); sphere(root, (0, -18, 0), 3.2, emit((0.42, 1.0, 0.08), 12))
def build_topcu(root):
    h, g, d = hull(), emit((0.42, 1.0, 0.08), 9), metal((0.05, 0.04, 0.05), 0.4, 0.7)
    cyl(root, (0, 0, 0), 30, 9, h, 'Z', 6); cyl(root, (0, 0, 3), 21, 5, d, 'Z', 6)
    for sx in (-11, 11): cyl(root, (sx, 30, 3), 3, 28, metal((0.2, 0.18, 0.2), 0.3, 0.7)); sphere(root, (sx, 44, 3), 2.6, g)
    for i in range(6):
        a = math.pi / 6 + i * math.pi / 3; sphere(root, (math.cos(a) * 25, -math.sin(a) * 25, 4.5), 2, g)
    sphere(root, (0, 0, 6), 7, g, (1, 1, 0.6))
def build_girdap(root):
    h, g = hull(), emit((0.42, 1.0, 0.08), 9)
    for i in range(3):
        a = i * 2 * math.pi / 3; ca, sa = math.cos(a), math.sin(a)
        poly = [[6, -8], [20, -24], [36, -22], [44, -10], [40, 12], [30, 0], [18, -4], [8, 6]]
        plate(root, [[x * ca - y * sa, x * sa + y * ca] for x, y in poly], 1, h, 2.0, 1.0)
    sphere(root, (0, 0, 0), 14, h, (1, 1, 0.6)); sphere(root, (0, 0, 6), 8, g, (1, 1, 0.5))
def build_bomber(root):
    h, o, d = hull(), emit((0.42, 1.0, 0.08), 9), metal((0.05, 0.04, 0.05), 0.4, 0.6)
    for f in (False, True):
        sx = -1 if f else 1
        plate(root, [[0, -52], [30, -44], [60, -10], [74, 14], [60, 20], [44, 14], [30, 24], [18, 30], [0, 26]], 1, h, 2.0, 0.0, f)
        plate(root, [[10, -36], [30, -30], [48, -8], [40, 8], [24, 10], [10, 14]], 1, d, 0.6, 0.5, f)
        bar(root, (16 * sx, 40, 1.0), (70 * sx, -12, 1.0), 1.4, 0.8, o)
        for x in (28, 48): sphere(root, (x * sx, -14, 1), 6.5, d, (1, 1.3, 0.6)); sphere(root, (x * sx, -16, 3), 3.5, o)
    lathe(root, [[0, -42], [10, -26], [13, 14], [0, 20]], 1, h, 0.6, 2.0)
    sphere(root, (0, 16, 7), 5, emit((0.42, 1.0, 0.08), 10), (1, 1.8, 0.5))

# v0.9: her bölgeye yeni Vahar türü
G9 = (0.42, 1.0, 0.08)
def build_kalkanli(root):  # önde enerji kalkanı taşıyan ağır savaşçı
    h, d = hull(), metal((0.05, 0.04, 0.05), 0.4, 0.7)
    lathe(root, [[0, -20], [9, -12], [11, 10], [0, 22]], 1, h, 0.7)
    for f in (False, True): plate(root, [[8, -2], [22, 6], [20, 20], [8, 16]], 1, d, 1.4, 0.3, f)
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=10, radius=26)
    o = obj('shield', bm, emit((0.35, 0.75, 1.0), 5), root, True); o.scale = (1.0, 0.22, 0.35); o.location = (0, 24, 0)
    sphere(root, (0, -2, 5), 4, emit(G9, 10), (1, 1.4, 0.6))
def build_bolunen(root):  # üç parçalı, birleşik gövde (ölünce ayrılır)
    h, g = hull(), emit((1.0, 0.55, 0.12), 9)
    for i in range(3):
        a = -math.pi / 2 + i * 2 * math.pi / 3; c = (math.cos(a) * 10, -math.sin(a) * 10, 0)
        sphere(root, c, 10, h, (1, 1, 0.5)); sphere(root, (c[0], c[1], 3.5), 3.2, g)
    for i in range(3):
        a = -math.pi / 6 + i * 2 * math.pi / 3; bar(root, (0, 0, 1), (math.cos(a) * 14, -math.sin(a) * 14, 1), 1.2, 0.6, g)
def build_kivilcim(root):  # bölünenin küçük parçası
    h, g = hull(), emit((1.0, 0.55, 0.12), 10)
    sphere(root, (0, 0, 0), 9, h, (1, 1.2, 0.5))
    for sx in (-1, 1): plate(root, [[4, -4], [14, 4], [6, 8]], 1, h, 0.8, 0.0, sx < 0)
    sphere(root, (0, 0, 3.5), 3.2, g)
def build_hayalet(root):  # ince, keskin, gizlenen avcı
    h, g = hull((0.06, 0.06, 0.08)), emit((0.8, 0.78, 0.95), 6)
    lathe(root, [[0, -34], [3, -18], [4.5, 12], [0, 26]], 1, h, 0.45)
    for f in (False, True): plate(root, [[3, -6], [26, 14], [28, 20], [4, 12]], 1, h, 0.8, 0.0, f)
    for sx in (-1, 1): bar(root, (4 * sx, -2, 0.6), (26 * sx, 16, 0.6), 0.6, 0.3, g)
    sphere(root, (0, -14, 2), 2.4, g, (1, 2.0, 0.6))
def build_isinlanan(root):  # halka çekirdekli ışınlanıcı
    h, g = hull(), emit((0.45, 0.5, 1.0), 10)
    bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=24, radius2=24, depth=4)
    o = obj('ring', bm, h, root, True); o.scale = (1, 1, 1)
    cyl(root, (0, 0, 2.5), 17, 3, metal((0.02, 0.02, 0.04), 0.3, 0.8), 'Z', 32)
    sphere(root, (0, 0, 4), 9, g, (1, 1, 0.8))
    for i in range(4):
        a = i * math.pi / 2; sphere(root, (math.cos(a) * 24, math.sin(a) * 24, 1), 3.5, g)
def build_keskin(root):  # uzun namlulu nişancı
    h, d, r = hull(), metal((0.05, 0.04, 0.05), 0.4, 0.7), emit((1.0, 0.12, 0.2), 12)
    lathe(root, [[0, -16], [8, -8], [9, 12], [0, 18]], 1, h, 0.7)
    cyl(root, (0, -30, 1.5), 2.2, 34, d); sphere(root, (0, -47, 1.5), 2.4, r)
    for f in (False, True): plate(root, [[8, 0], [24, 10], [22, 16], [8, 14]], 1, h, 1.0, 0.0, f)
    sphere(root, (0, -4, 6), 3.4, r, (1, 1.4, 0.6))
def build_mayinci(root):  # sırtında mayın hazneleri taşıyan geniş gemi
    h, d, o = hull(), metal((0.05, 0.04, 0.05), 0.4, 0.7), emit((1.0, 0.45, 0.12), 9)
    for f in (False, True): plate(root, [[0, -26], [24, -18], [32, 6], [22, 26], [0, 22]], 1, h, 2.0, 0.0, f)
    for x, y in [(-12, -6), (12, -6), (-12, 10), (12, 10)]: sphere(root, (x, y, 3), 5.5, d, (1, 1, 0.7)); sphere(root, (x, y, 6), 2.2, o)
    sphere(root, (0, -18, 3), 3, emit(G9, 10))
def build_tamirci(root):  # onarım kollarıyla destek gemisi
    h, g, d = hull(), emit((0.3, 1.0, 0.45), 10), metal((0.05, 0.04, 0.05), 0.4, 0.7)
    sphere(root, (0, 0, 0), 14, h, (1, 1.15, 0.55))
    for sx in (-1, 1):
        bar(root, (6 * sx, 0, 0), (26 * sx, -10, 0), 2.4, 1.6, d); sphere(root, (27 * sx, -12, 0), 4.5, g)
    poly = [[-3, -9], [3, -9], [3, -3], [9, -3], [9, 3], [3, 3], [3, 9], [-3, 9], [-3, 3], [-9, 3], [-9, -3], [-3, -3]]
    plate(root, poly, 0.9, g, 0.5, 7.5)
def build_ana(root):  # kovan: dron üreten ağır taşıyıcı
    h, g, d = hull(), emit((0.85, 0.4, 1.0), 9), metal((0.05, 0.04, 0.05), 0.4, 0.7)
    cyl(root, (0, 0, 0), 40, 12, h, 'Z', 8); cyl(root, (0, 0, 5), 28, 6, d, 'Z', 8)
    for i in range(8):
        a = math.pi / 8 + i * math.pi / 4; c = (math.cos(a) * 30, math.sin(a) * 30, 6.5)
        cyl(root, c, 5, 2, metal((0.02, 0.02, 0.03), 0.3, 0.8), 'Z', 12); sphere(root, (c[0], c[1], 7.5), 2.6, g)
    sphere(root, (0, 0, 9), 10, g, (1, 1, 0.5))
def build_zirhli(root):  # kalın plakalı, yavaş tank
    h, d, o = hull((0.07, 0.07, 0.075)), metal((0.12, 0.12, 0.13), 0.35, 0.85, panels=True), emit((1.0, 0.25, 0.15), 8)
    for f in (False, True): plate(root, [[0, -36], [26, -30], [36, -6], [34, 24], [20, 34], [0, 32]], 1, h, 3.0, 0.0, f)
    for f in (False, True): plate(root, [[6, -26], [22, -22], [28, 0], [26, 20], [6, 22]], 1, d, 1.0, 1.2, f)
    cyl(root, (0, -2, 4), 12, 5, d, 'Z', 8); cyl(root, (0, -22, 4), 3.2, 22, metal((0.2, 0.18, 0.2), 0.3, 0.7))
    sphere(root, (0, -2, 7), 4, o, (1, 1, 0.6))
def build_orak(root):  # hilal kanatlı, hızlı dalış gemisi
    h, g = hull(), emit((1.0, 0.16, 0.55), 10)
    lathe(root, [[0, -22], [5, -10], [6, 10], [0, 18]], 1, h, 0.6)
    for f in (False, True):
        sx = -1 if f else 1
        plate(root, [[5, 4], [16, -4], [28, -20], [34, -36], [30, -14], [22, 8], [6, 14]], 1, h, 1.2, 0.2, f)
        bar(root, (8 * sx, -4, 0.8), (30 * sx, 26, 0.8), 0.8, 0.4, g)
    sphere(root, (0, -6, 3), 3, g, (1, 1.8, 0.6))

def build_pod(root):
    # Vahar ikmal kapsülü: sade, küçük. Koyu çelik hap gövde, tek altın kuşak, iki kehribar ışık
    body, gold = metal((0.06, 0.065, 0.07), 0.35, 0.75, panels=True), metal((0.95, 0.66, 0.18), 0.22, 1.0)
    amber = emit((1.0, 0.5, 0.1), 12)
    lathe(root, [[0, -21], [6, -19], [9, -12], [9.5, 0], [9, 12], [6, 19], [0, 21]], 1, body, 0.8, 0.0, 28, 30)
    cyl(root, (0, 0, 0), 10.2, 5.0, gold, 'Y', 28)
    for y in (-12.5, 12.5): cyl(root, (0, y, 0), 9.3, 1.2, gold, 'Y', 28)
    for y in (-6.5, 6.5): sphere(root, (0, y, 6.6), 1.7, amber, (1, 1.6, 0.6))

# ---------------- çekim ----------------
def render(name, build, w, h, rolls=ROLLS):
    root = reset(max(w, h) / 2.0)
    sc = bpy.context.scene; sc.render.resolution_x = w; sc.render.resolution_y = h; sc.render.resolution_percentage = 100
    build(root)
    sheet = np.zeros((h, w * rolls, 4), dtype=np.float32)
    for i in range(rolls):
        root.rotation_euler = (math.radians(-30) if rolls == 1 else 0, 0 if rolls == 1 else math.radians((i - 3) / 3.0 * MAX_ROLL), 0)  # tek kare: hafif eğik; pozitif yatış = sağ kanat aşağı
        sc.render.filepath = TMP; bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(TMP, check_existing=False)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
        sheet[:, i * w:(i + 1) * w, :] = px
        bpy.data.images.remove(img)
    out = bpy.data.images.new(name, w * rolls, h, alpha=True)
    out.pixels = sheet.ravel()
    out.filepath_raw = os.path.join(OUT, name + '.png'); out.file_format = 'PNG'; out.save()
    print('BLENDER', name, flush=True)

JOBS = [('plane_' + k, (lambda d: lambda r: build_plane(r, d))(v), 256, 256) for k, v in P.items()] + [
    ('e_drone', build_drone, 128, 128), ('e_avci', build_avci, 160, 160), ('e_kamikaze', build_kamikaze, 144, 144),
    ('e_topcu', build_topcu, 192, 192), ('e_girdap', build_girdap, 192, 192), ('e_bombardiman', build_bomber, 320, 256),
    ('e_kalkanli', build_kalkanli, 176, 176), ('e_bolunen', build_bolunen, 160, 160), ('e_kivilcim', build_kivilcim, 96, 96),
    ('e_hayalet', build_hayalet, 160, 160), ('e_isinlanan', build_isinlanan, 160, 160), ('e_keskin', build_keskin, 176, 176),
    ('e_mayinci', build_mayinci, 192, 192), ('e_tamirci', build_tamirci, 176, 176), ('e_ana', build_ana, 256, 256),
    ('e_zirhli', build_zirhli, 256, 256), ('e_orak', build_orak, 192, 192)]
SINGLE = [('pod', build_pod, 96, 96)]  # yatış karesi olmayan tek görseller
if __name__ == "__main__":  # blender_base.py yardımcıları içe aktarırken çekim yapılmasın
    os.makedirs(OUT, exist_ok=True)
    for name, fn, w, h in JOBS:
        if OPT.get('only') and not any(o in name for o in OPT['only'].split(',')): continue  # --only=a,b
        render(name, fn, w, h)
    for name, fn, w, h in SINGLE:
        if OPT.get("only") and OPT["only"] not in name: continue
        render(name, fn, w, h, 1)
    if os.path.exists(TMP): os.remove(TMP)
