"""Draws the card pictures that have no hand-made image: vault, worm, siphon, cover, express.

Same style as the existing schematic art: one flat colour on the dark field, cut-outs in the field
colour; attack cards are free-standing icons, defence cards a shield (the exact outline of
cdn/patch/response/sca.png) with a cut-out symbol. Drawn at 3x and downsampled for smooth edges.

    python3 assets/cards/schematic/make_art.py      (needs Pillow)
then let Godot import the new PNGs (open the editor, or `godot --headless --path . --import`).
"""
import math
import os
from PIL import Image, ImageDraw

SIZE = 1254
S = 3                                    # supersampling factor
FIELD = (13, 15, 22)                     # the dark background every card picture shares
HERE = os.path.dirname(os.path.abspath(__file__))


def canvas():
    im = Image.new("RGB", (SIZE * S, SIZE * S), FIELD)
    return im, ImageDraw.Draw(im)


def p(*xy):                              # 1254-space coordinates -> supersampled pixels
    return [v * S for v in xy]


def line(d, a, b, col, w):               # a stroke with round caps
    d.line(p(*a, *b), fill=col, width=int(w * S))
    for c in (a, b):
        r = w / 2
        d.ellipse(p(c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill=col)


def poly_line(d, pts, col, w):           # joined strokes with round joins
    for k in range(len(pts) - 1):
        line(d, pts[k], pts[k + 1], col, w)


def disc(d, c, r, col):
    d.ellipse(p(c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill=col)


def ring(d, c, r, col, w):
    d.ellipse(p(c[0] - r, c[1] - r, c[0] + r, c[1] + r), outline=col, width=int(w * S))


def shield(d, col):                      # the defence shield every DEFENCE card wears
    d.polygon(p(320, 284, 934, 284, 934, 636, 627, 949, 320, 636), fill=col)


def save(im, name):
    im.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(HERE, name + ".png"), optimize=True)
    print("wrote", name + ".png")


def vault():                             # Vault raid: a safe with a wheel dial (gold: it takes Crypto)
    gold = (255, 208, 80)
    im, d = canvas()
    d.rectangle(p(296, 420, 336, 490), fill=gold); d.rectangle(p(296, 710, 336, 780), fill=gold)   # hinges
    d.rounded_rectangle(p(330, 300, 924, 896), radius=48 * S, fill=gold)                          # body
    d.rounded_rectangle(p(386, 356, 868, 840), radius=30 * S, outline=FIELD, width=24 * S)        # door seam
    d.rectangle(p(382, 896, 476, 950), fill=gold); d.rectangle(p(778, 896, 872, 950), fill=gold)  # feet
    centre = (627, 598)
    ring(d, centre, 150, FIELD, 30)
    for k in range(4):                   # the wheel's spokes
        a = math.radians(45 + 90 * k)
        line(d, centre, (centre[0] + 150 * math.cos(a), centre[1] + 150 * math.sin(a)), FIELD, 26)
    disc(d, centre, 46, FIELD)
    disc(d, centre, 18, gold)
    save(im, "vault")


def worm():                              # Worm: one tapered, segmented body winding to a raised head
    green = (126, 222, 96)
    im, d = canvas()
    n = 700
    pts = [(286 + 574 * k / (n - 1), 610 - 130 * math.sin(2 * math.pi * 1.25 * k / (n - 1))) for k in range(n)]
    total = [0.0]
    for k in range(1, n):
        total.append(total[-1] + math.dist(pts[k - 1], pts[k]))

    def radius(k):                       # thin tail, full body
        return 30 + 40 * k / (n - 1)

    for k in range(n):                   # the body: discs along the path, a continuous tapered stroke
        disc(d, pts[k], radius(k), green)
    s_at = 70.0
    for k in range(1, n - 1):            # segment grooves across the body, every 70 px of its length
        if total[k] < s_at:
            continue
        s_at += 70.0
        if total[-1] - total[k] < 40:
            break
        tx, ty = pts[k + 1][0] - pts[k - 1][0], pts[k + 1][1] - pts[k - 1][1]
        m = math.hypot(tx, ty); nx, ny = -ty / m, tx / m
        r = radius(k) + 8
        line(d, (pts[k][0] - nx * r, pts[k][1] - ny * r), (pts[k][0] + nx * r, pts[k][1] + ny * r), FIELD, 12)
    hx, hy = pts[-1][0] + 70, pts[-1][1]  # the head, level at the last crest
    disc(d, (hx, hy), 98, green)
    line(d, (hx - 84, hy - 70), (hx - 84, hy + 70), FIELD, 12)   # neck groove
    disc(d, (hx + 26, hy - 30), 20, FIELD)                        # the eye
    save(im, "worm")


def siphon():                            # Packet siphon: a packet stream with a branch pulling one away
    teal = (64, 214, 168)
    im, d = canvas()
    line(d, (270, 400), (984, 400), teal, 48)          # the stream
    for x in (392, 862):                               # packets riding it
        d.rectangle(p(x - 82, 318, x + 82, 482), fill=FIELD)
        d.rectangle(p(x - 66, 334, x + 66, 466), fill=teal)
    line(d, (627, 400), (627, 790), teal, 48)          # the siphon branch
    d.rectangle(p(545, 530, 709, 694), fill=FIELD)     # the packet it took
    d.rectangle(p(561, 546, 693, 678), fill=teal)
    d.polygon(p(507, 780, 747, 780, 627, 960), fill=teal)   # heading to your main node
    disc(d, (627, 400), 72, teal)                      # the junction
    disc(d, (627, 400), 30, FIELD)
    save(im, "siphon")


def cover():                             # Courier cover: a shield sheltering cargo under an umbrella
    amber = (255, 184, 92)
    im, d = canvas()
    shield(d, amber)
    cx, top = 627, 560
    d.pieslice(p(cx - 220, top - 220, cx + 220, top + 220), 180, 360, fill=FIELD)   # the canopy
    for k in range(4):                   # its scalloped rim
        x = cx - 165 + 110 * k
        disc(d, (x, top), 56, amber)
    line(d, (cx, top - 236), (cx, top - 200), FIELD, 26)   # the tip
    line(d, (cx, top), (cx, 770), FIELD, 30)               # the handle
    d.arc(p(cx - 92, 704, cx, 796), 0, 180, fill=FIELD, width=30 * S)   # its hook
    disc(d, (cx - 92 + 15, 750), 15, FIELD)
    save(im, "cover")


def express():                           # Express route: a shield with a fast-forward double chevron
    orchid = (232, 124, 232)
    im, d = canvas()
    shield(d, orchid)
    for x in (468, 628):
        poly_line(d, [(x, 392), (x + 140, 532), (x, 672)], FIELD, 62)
    save(im, "express")


if __name__ == "__main__":
    vault(); worm(); siphon(); cover(); express()
