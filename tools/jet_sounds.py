# Gerçek jet kayıtlarını (tools/audio_src, kaynak ve lisans: CREDITS.md) keser, yumuşatır, seviyeler -> audio/engine, afterburner, sonicboom
# Çalıştır: blender -b --python tools/jet_sounds.py -- tools/audio_src audio
import aud, numpy as np, sys, os
src, out = sys.argv[-2], sys.argv[-1]
JOBS = [  # çıktı, kaynak, başlangıç, bitiş, giriş, çıkış, hedef tepe
    ("engine", "WWS_SaabJ35DDrakenstartengineandtaxiing.ogg", 9.0, 14.5, 0.25, 1.0, 0.7),
    ("afterburner", "WWS_SaabJ35DDraken8211passingtwotimes.ogg", 10.5, 16.5, 0.6, 1.4, 0.85),
    ("sonicboom", "Sonic-boom-massive-sound.ogg", 0.0, 6.6, 0.0, 1.5, 0.9),
]
for name, f, a, b, fi, fo, peak in JOBS:
    s = aud.Sound(os.path.join(src, f)).rechannel(1).limit(a, b)
    s = s.fadein(0, fi).fadeout((b - a) - fo, fo)
    d = s.data(); pk = float(np.abs(d).max())
    s = s.volume(peak / max(pk, 1e-6))
    s.write(os.path.join(out, name + ".wav"), rate=44100, channels=aud.CHANNELS_MONO, format=aud.FORMAT_S16, container=aud.CONTAINER_WAV, codec=aud.CODEC_PCM)
    print("CUT", name, "%.1fs" % (b - a), "peak %.2f" % pk)
