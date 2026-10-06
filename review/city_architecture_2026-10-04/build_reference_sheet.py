"""Generate an original SVG architecture study; this does not run or change RIM.

Run from any directory with Python. The SVG has no external dependencies/assets.
Optional PNG preview: render the SVG with a browser at its intrinsic dimensions.
"""

from pathlib import Path
from html import escape

OUT = Path(__file__).resolve().parent
W, H = 1460, 1270
parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-labelledby="title desc">',
         '<title id="title">RIM architecture: nine building and street patterns</title>',
         '<desc id="desc">Original schematic isometric studies of housing, mixed-use streets, apartments, civic buildings and work sites. Proposed design direction, not game screenshots.</desc>',
         '<rect width="1460" height="1270" fill="#0f1722"/>']


def text(x, y, value, size=15, color='#aebcce', weight='400'):
    parts.append(f'<text x="{x}" y="{y}" fill="{color}" font-family="Segoe UI,Arial,sans-serif" font-size="{size}" font-weight="{weight}">{escape(value)}</text>')


def poly(points, color, stroke=None, sw=1):
    p = ' '.join(f'{x:.2f},{y:.2f}' for x, y in points)
    parts.append(f'<polygon points="{p}" fill="{color}" stroke="{stroke or color}" stroke-width="{sw}" stroke-linejoin="round"/>')


def line(a, b, color, width=1):
    parts.append(f'<path d="M{a[0]:.2f},{a[1]:.2f} L{b[0]:.2f},{b[1]:.2f}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round"/>')


def iso(x, y, z=0):
    return (222 + (x-y)*24, 140 + (x+y)*12-z)


def ground(x, y, w, d, col):
    poly([iso(x,y),iso(x+w,y),iso(x+w,y+d),iso(x,y+d)],col)


def shade(col, factor):
    rgb = [int(col[i:i+2],16) for i in (1,3,5)]
    return '#' + ''.join(f'{min(255,round(v*factor)):02x}' for v in rgb)


def wall_rect(x, y, u, v, bottom, height, face, color, frame=False):
    # u = start, v = width along the wall, measured in world-plan units.
    if face == 'south':
        pts=[iso(x+u,y,bottom),iso(x+u+v,y,bottom),iso(x+u+v,y,bottom+height),iso(x+u,y,bottom+height)]
    else:
        pts=[iso(x,y+u,bottom),iso(x,y+u+v,bottom),iso(x,y+u+v,bottom+height),iso(x,y+u,bottom+height)]
    poly(pts,color,'#e4dfcd' if frame else None,.7)


def building(x,y,w,d,h,wall='#ad7960',roof='gable_y',roof_col='#605663',rise=16, floors=2, shop=False,side=True,door=True):
    A,B,C,D=[iso(*q,h) for q in [(x,y),(x+w,y),(x+w,y+d),(x,y+d)]]
    poly([iso(x,y+d),iso(x+w,y+d),C,D],wall)
    poly([iso(x+w,y),iso(x+w,y+d),C,B],shade(wall,.76))
    line(iso(x,y+d),iso(x+w,y+d),'#635e59',2)
    line(iso(x+w,y),iso(x+w,y+d),'#535659',1.5)
    bays=max(1,round(w/.62))
    for level in range(floors):
        if shop and level == 0:
            continue
        bottom=8+level*(h-10)/max(1,floors)
        for col in range(bays):
            center=w*(col+.5)/bays
            wall_rect(x,y+d,center-.115,.23,bottom,7,'south','#384e5a',True)
        if side:
            for j in range(max(1,round(d/1.0))):
                pos=d*(j+.5)/max(1,round(d/1.0))
                wall_rect(x+w,y,pos-.11,.22,bottom,7,'east','#34434e',True)
    if shop:
        wall_rect(x,y+d,.09,w-.18,1,12,'south','#547b83',True)
        wall_rect(x,y+d,.08,w-.16,14,4,'south','#438e8c')
        wall_rect(x,y+d,w*.66,w*.18,0,12,'south','#273b46')
        poly([iso(x,y+d,13),iso(x+w,y+d,13),iso(x+w,y+d+.25,11),iso(x,y+d+.25,11)],'#caa47c')
    elif door:
        wall_rect(x,y+d,w*.17,w*.18,0,12,'south','#415b59',True)
    if roof == 'flat':
        poly([A,B,C,D],roof_col)
        line(D,C,shade(wall,1.18),2)
        line(B,C,shade(wall,.94),2)
    elif roof == 'gable_y':
        R1,R2=iso(x+w/2,y,h+rise),iso(x+w/2,y+d,h+rise)
        poly([D,C,R2],shade(wall,1.05))
        poly([A,D,R2,R1],shade(roof_col,.82))
        poly([B,C,R2,R1],roof_col)
        line(R1,R2,shade(roof_col,1.3),1.1)
        line(D,R2,'#d2be9e',1.2)
        line(R2,C,'#d2be9e',1.2)
    elif roof == 'gable_x':
        R1,R2=iso(x,y+d/2,h+rise),iso(x+w,y+d/2,h+rise)
        poly([B,C,R2],shade(wall,.82))
        poly([A,B,R2,R1],shade(roof_col,.76))
        poly([D,C,R2,R1],roof_col)
        line(R1,R2,shade(roof_col,1.32),1.0)
    elif roof == 'hip':
        cut=min(w*.28,d*.3)
        R1,R2=iso(x+cut,y+d/2,h+rise),iso(x+w-cut,y+d/2,h+rise)
        poly([A,B,R2,R1],shade(roof_col,.75))
        poly([A,D,R1],shade(roof_col,.86))
        poly([D,C,R2,R1],roof_col)
        poly([B,C,R2],shade(roof_col,.72))
        line(R1,R2,shade(roof_col,1.35),1)


def tree(x,y,sz=10):
    a=iso(x,y)
    line(a,(a[0],a[1]-sz),'#77725f',3)
    parts.append(f'<circle cx="{a[0]:.1f}" cy="{a[1]-sz-4:.1f}" r="{sz}" fill="#659079"/>')
    parts.append(f'<circle cx="{a[0]-sz*.2:.1f}" cy="{a[1]-sz-7:.1f}" r="{sz*.7}" fill="#88ab86"/>')


def base():
    ground(0,0,5.8,5.5,'#acae9e')
    ground(0,4.3,5.8,.48,'#d1cbb8')
    ground(0,4.8,5.8,.7,'#48545e')
    line(iso(0,4.78),iso(5.8,4.78),'#e1d7bf',1.4)


def panel(n,title,kicker,caption,draw):
    col,row=(n-1)%3,(n-1)//3
    x,y=36+col*468,142+row*356
    parts.append(f'<g transform="translate({x},{y})">')
    parts.append('<rect width="450" height="338" rx="16" fill="#1b2735" stroke="#344252"/>')
    text(20,31,f'{n:02d}  {title}',19,'#f1eee5','600')
    text(20,53,kicker,13,'#8fbdba')
    base()
    draw()
    text(20,317,caption,13,'#c4cdd6')
    parts.append('</g>')


text(36,49,'RIM / ARCHITECTURE THAT MAKES A TOWN',31,'#f3efe4','700')
text(36,81,'Choose a neighbourhood family. Align buildings to streets. Preserve room for everyday life.',18)
text(36,111,'Original schematic design studies • Proposed direction, not game captures • Materials and proportions are illustrative.',13,'#7da39f')


def dutch():
    for i in range(4):
        ground(.5+i*1.16,.2,1.1,1.1,'#829376')
    for i in range(4):
        building(.5+i*1.16,1.45,1.14,2.6,40+(i%2)*7,wall=['#98644f','#b17a58','#98765e','#b88969'][i],roof_col='#6b5b55',rise=16,floors=3,side=i==3)


def terrace():
    for i in range(5):
        ground(.35+i*1.0,.3,.94,1.12,'#7f977b')
    for i in range(5):
        building(.35+i*1.,1.55,1.,2.,34,wall='#a77863',roof='gable_x',roof_col='#535a65',rise=12,side=i==4)
    for i in (0,2,4):
        building(.9+i,2.2,.15,.18,52,wall='#9c715e',roof='flat',roof_col='#585656',floors=0,door=False,side=False)
    ground(.35,3.6,5,.55,'#c7b99c')


def stone():
    for i in range(3):
        building(.55+i*1.48,1.7,1.46,2.3,44+(i%2)*3,wall=['#d3c9ac','#c4b797','#d6ceb8'][i],roof='hip',roof_col='#4f5f6b',rise=15,floors=3,side=i==2)
    tree(5.2,4.05,8)


def garden():
    ground(.7,.5,4.4,3.7,'#839779')
    tree(.7,1.1,11)
    for i in range(2):
        building(1.25+i*1.45,1.25,1.45,1.9,33,wall='#c4b698',roof='gable_x',roof_col='#866859',rise=15,side=i==1)
        ground(1.46+i*1.45,3.18,.22,1.12,'#d3c3a6')
    line(iso(.7,4.1),iso(2.6,4.1),'#466e58',5)
    line(iso(3.05,4.1),iso(5.1,4.1),'#466e58',5)
    tree(4.9,3.4,9)


def highstreet():
    for i in range(3):
        building(.4+i*1.62,1.75,1.6,2.35,53,wall=['#c5b095','#aa8068','#d0c0a7'][i],roof='gable_x',roof_col='#636675',rise=13,floors=3,shop=True,side=i==2)


def courtyard():
    ground(.7,.7,4.5,3.6,'#c0b7a4')
    ground(2.15,2.,1.65,1.7,'#81a084')
    building(.7,.7,4.5,.95,46,wall='#b5927a',roof='flat',roof_col='#687273',floors=3)
    building(.7,1.65,1.1,2.65,46,wall='#b5927a',roof='flat',roof_col='#687273',floors=3)
    tree(2.8,2.8,8)
    building(4.1,1.65,1.1,2.65,46,wall='#b5927a',roof='flat',roof_col='#687273',floors=3)
    ground(2.75,3.55,.42,.76,'#ddd0b6')


def civic():
    ground(.3,.7,5.15,3.65,'#c7c4b5')
    building(1.15,1.35,3.5,2.4,36,wall='#c2b291',roof='hip',roof_col='#6b6562',rise=15,floors=2)
    building(3.65,1.42,.73,.78,72,wall='#c2b291',roof='hip',roof_col='#4e6c6b',rise=16,floors=0,door=False)
    cx,cy=iso(3.65+.365,1.42+.78,61)
    parts.append(f'<circle cx="{cx}" cy="{cy}" r="4.4" fill="#eee5c8"/>')
    line((cx,cy),(cx,cy-3),'#48555e',1)
    line((cx,cy),(cx+2,cy+1),'#48555e',1)
    wall_rect(1.15,3.75,1.43,.66,0,20,'south','#586264',True)
    ground(2.38,3.77,1.05,.38,'#ded5bf')
    tree(.6,3.7,9)
    tree(5.1,3.7,9)


def works():
    ground(.5,.7,4.9,3.65,'#aba999')
    building(.7,1.25,.33,.38,65,wall='#a17059',roof='flat',roof_col='#574e46',floors=0,door=False)
    for i in range(3):
        building(.9+i*1.35,1.6,1.34,2.1,28,wall='#a8876c',roof='gable_y',roof_col='#829399',rise=10,floors=1,door=False,side=i==2)
        wall_rect(.9+i*1.35,3.7,.18,.98,0,19,'south','#58666d',True)
    ground(1.2,3.95,1.1,.25,'#d8c09b')
    building(4.8,3.6,.3,.4,8,wall='#a6926f',roof='flat',roof_col='#d0b58b',floors=0,door=False)


def retail():
    ground(.6,1.,4.7,3.3,'#b8b7aa')
    building(.85,1.5,3.65,2.2,28,wall='#b7b4a7',roof='flat',roof_col='#6b797d',floors=1,shop=True,side=False)
    building(3.6,.9,1.15,.6,20,wall='#999d96',roof='flat',roof_col='#707b78',floors=0,door=False,side=False)
    ground(4.6,2.2,.7,1.8,'#7d827b')
    for i in range(3):
        line(iso(4.68,2.5+i*.48),iso(5.22,2.5+i*.48),'#d6d0b6',1)
    tree(.6,4.,8)
    tree(5.3,4.,8)


panel(1,'Historic brick frontage','Dutch-town reference • selected gabled fronts','Narrow plots; related roofs; small differences.',dutch)
panel(2,'Terraced housing','British-town reference • shared roof rhythm','Aligned homes; party walls; gardens behind.',terrace)
panel(3,'Stone town frontage','Saumur / Bessin references • regional palette','Light masonry; dark roofs; vertical openings.',stone)
panel(4,'Garden housing','Paired homes • shared composition','Front paths, hedges and real domestic grounds.',garden)
panel(5,'Shops with homes above','Mixed high street • distinct ground floor','Shopfronts below; residential rhythm above.',highstreet)
panel(6,'Courtyard apartments','Several wings • shared inner space','Street edges, entrances and a usable courtyard.',courtyard)
panel(7,'Civic hall and square','Local landmark • deliberate silhouette','A focal entrance and public space at its base.',civic)
panel(8,'Workshop / reused works','Employment compound • service frontage','Broad doors, repeated sheds and a working yard.',works)
panel(9,'Local shopping destination','Contemporary everyday architecture','A complete site, canopy, glazing and service space.',retail)
text(36,1244,'IMPLEMENTATION ORDER   street orientation → footprint / mass → roof → facade rhythm → grounds → materials → selective neon',14,'#a0c8bf','600')
parts.append('</svg>')
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'architecture_reference.svg').write_text('\n'.join(parts),encoding='utf-8')
print(OUT/'architecture_reference.svg')
