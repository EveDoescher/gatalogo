"""Hand-authored, modular farm props matching Quintal's simple faceted animals.

The references inform silhouettes (gambrel barn, raised coop, canvas counter).
Small bevels, layered joinery and restrained colour variation supply detail
without textures with baked shadows or realistic high-frequency noise.
"""
import math
import numpy as np
from quintal_model_authoring import (Model, bevel_box as block, box, beam, lathe,
    ellipsoid, transform, mesh_faces, rgba, CREAM, WATER)

TIMBER=rgba('a5734c'); LIGHT=rgba('cdab76'); DARK=rgba('694c38')
IVORY=rgba('efdab0'); RED=rgba('b85f4e'); SAGE=rgba('79956d')
IRON=rgba('555a50'); HAY=rgba('c8ad67')


def shade(color,value):
    return color*np.array([value,value,value,1])


def add_parts(m,other,prefix='',at=(0,0,0),angles=(0,0,0)):
    for name,mesh in other.parts:m.add(prefix+name,transform(mesh,at=at,angles=angles))
    return m


def pegs(m,x,y,z):
    for dx in (-.065,.065):m.add('iron-peg',block((.024,.024,.015),IRON,at=(x+dx,y,z),bevel=.004))


def plank_wall(m,w,h,at,color,axis='front',vertical=True,opening=None):
    count=max(3,round(w/.18))
    for i in range(count):
        p=-w/2+(i+.5)*w/count
        if opening and abs(p)<opening/2:continue
        c=shade(color,[1,.96,1.035,.985][i%4])
        dims=(w/count-.012,h,.065)
        pos=(at[0]+p,at[1]+h/2,at[2])
        if axis=='side':dims=(.065,h,w/count-.012);pos=(at[0],at[1]+h/2,at[2]+p)
        m.add('siding',block(dims,c,at=pos,bevel=.008))


def roof(m,w,d,y,barn=False,state='ready'):
    color=rgba('676256') if barn else rgba('778e60')
    profile=[(-w/2,y),(-w*.30,y+.51),(0,y+.74),(w*.30,y+.51),(w/2,y)] if barn else [(-w/2,y),(0,y+.54),(w/2,y)]
    for slope,(a,b) in enumerate(zip(profile,profile[1:])):
        for z in (-d/2,d/2):m.add('barge-board',beam((a[0],a[1],z),(b[0],b[1],z),.08,DARK))
        length=math.dist(a,b);angle=math.degrees(math.atan2(b[1]-a[1],b[0]-a[0]))
        if state=='building':
            for z in (-d/4,0,d/4):m.add('bare-rafter',beam((a[0],a[1],z),(b[0],b[1],z),.055,TIMBER))
            continue
        rows=3 if barn else 4
        for row in range(rows):
            for col in range(4):
                if state=='abandoned' and (row+col+slope)%3==0:continue
                t=(row+.5)/rows
                panel=block((length/rows+.02,.060,d/4-.008),shade(color,[1,.95,1.04,1.01][(row+col)%4]),bevel=.012)
                m.add('roof-tile',transform(panel,at=(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t+.035,-d/2+(col+.5)*d/4),angles=(0,0,angle)))
    for side in (-1,1):m.add('eave-fascia',block((.09,.11,d+.03),LIGHT,at=(side*w/2,y-.015,0)))
    m.add('ridge-cap',block((.12,.10,d+.14),DARK,at=(0,max(p[1] for p in profile)+.05,0)))
    return profile


def door(m,w,h,at,angle=0):
    d=Model()
    plank_wall(d,w,h,(0,0,0),RED)
    for side in (-1,1):d.add('door-edge',block((.045,h,.045),IVORY,at=(side*(w/2-.024),h/2,.048)))
    for y in (.035,h-.035):d.add('door-rail',block((w,.07,.06),IVORY,at=(0,y,.05)))
    for side in (-1,1):d.add('door-brace',beam((-w*.42,.08,.057),(w*.42,h-.08,.057),.048,IVORY) if side==1 else beam((w*.42,.08,.057),(-w*.42,h-.08,.057),.048,IVORY))
    for y in (.14,h-.14):d.add('strap-hinge',block((.12,.035,.02),IRON,at=(-w*.32,y,.087),bevel=.006))
    d.add('latch',block((.035,.09,.035),IRON,at=(w*.30,h*.52,.08)))
    return add_parts(m,d,'door-',at,angles=(0,angle,0))


def shelter(kind,level,state):
    barn=kind=='barn';w=(2.0 if barn else 1.50)+(level-1)*.60
    d=1.40 if barn else 1.12+(level-1)*1.08
    floor=.10 if barn else .31;wall=1.12 if barn else .90;top=floor+wall
    if state=='upgrading':
        m=shelter(kind,1,'ready')
        x=1.30 if barn else -.97
        for z in (-.52,.40):m.add('scaffold-post',block((.075,1.40,.075),TIMBER,at=(x,.70,z)))
        m.add('scaffold-brace',beam((x,.12,-.52),(x,1.22,.40),.055,LIGHT))
        m.add('scaffold-platform',block((.25,.07,1.02),LIGHT,at=(x,.70,-.06)))
        for i in range(3):m.add('extension-planks',block((.28,.06,.70),LIGHT,at=(x,.08+i*.064,-.07)))
        return m
    m=Model();body=RED if barn else TIMBER
    for x in (-w/2+.05,w/2-.05):
        for z in (-d/2+.06,d/2-.06):
            m.add('stone-foot',block((.19,.12,.19),rgba('a5a08b'),at=(x,.06,z),bevel=.035))
            if not barn:m.add('raised-foot',block((.11,floor,.11),DARK,at=(x,floor/2,z)))
    m.add('floor',block((w+.07,.10,d+.08),DARK,at=(0,floor,0)))
    if state=='abandoned':
        for x in (-w/2,w/2):
            m.add('broken-upright',transform(block((.11,wall*.65,.11),LIGHT),at=(x,floor+wall*.32,-d/2),angles=(0,0,7 if x>0 else -9)))
        plank_wall(m,w,wall*.50,(0,floor,-d/2),body)
        plank_wall(m,d*.62,wall*.36,(w/2,floor,-d*.18),body,axis='side')
        fallen=Model();roof(fallen,w*.80,d*.68,.16,barn,'abandoned')
        add_parts(m,fallen,'fallen-',(.03,.02,.08),(0,-14,9))
        for i in range(3):m.add('fallen-siding',transform(block((.16,.055,.58),body),at=(-w*.35+i*.25,.09,d*.52),angles=(0,i*19-15,0)))
        from build_quintal_compositions import part
        m.add('overgrowth',part('grass',(.60,.42,.50),at=(-w*.28,0,.08)))
        m.add('corner-shrub',part('plant_bushSmall',(.50,.55,.45),at=(w*.40,0,-d*.3)))
        return m
    for x in (-w/2,w/2):
        for z in (-d/2,d/2):m.add('corner-post',block((.095,wall,.095),IVORY if barn else LIGHT,at=(x,floor+wall/2,z)))
    profile=roof(m,w+.24,d+.26,top+.02,barn,state)
    if state=='building':
        plank_wall(m,w,wall*.32,(0,floor,-d/2),body)
        for x in (-w/2,w/2):m.add('frame-brace',beam((x,floor,-d/2),(x,top,d/2),.055,LIGHT))
        for i in range(4):m.add('building-plank-stack',block((.75,.065,.22),LIGHT,at=(.1,.10+i*.066,d/2+.18)))
        return m
    plank_wall(m,w,wall,(0,floor,-d/2),body)
    plank_wall(m,d,wall,(-w/2,floor,0),body,axis='side')
    if barn:
        plank_wall(m,d,wall,(w/2,floor,0),body,axis='side')
    else:
        # Side ventilator: dark recess, frame and wire, inset into timber cladding.
        plank_wall(m,d,wall*.28,(w/2,floor,0),body,axis='side')
        plank_wall(m,d,.16,(w/2,top-.16,0),body,axis='side')
        m.add('vent-dark-interior',box((.018,wall*.51,d-.12),DARK,at=(w/2-.025,floor+wall*.54,0)))
        for z in np.linspace(-d/2+.08,d/2-.08,6):m.add('vent-wire',beam((w/2+.018,floor+.29,z),(w/2+.018,top-.17,z),.012,rgba('a9a890')))
        for y in (floor+.34,floor+.47,floor+.60):m.add('vent-wire',beam((w/2+.02,y,-d/2+.08),(w/2+.02,y,d/2-.08),.012,rgba('a9a890')))
    for z in (-d/2,d/2):
        vertices=[(-w/2,top,z),(w/2,top,z)]+[(x,y,z) for x,y in profile[-2:0:-1]]
        m.add('gable',mesh_faces(vertices,[tuple(range(len(vertices)))],body))
        m.add('header',block((w+.10,.105,.105),IVORY if barn else LIGHT,at=(0,top-.01,z+.025)))
    gap=1.15 if barn else .56
    for side in (-1,1):
        pw=(w-gap)/2
        plank_wall(m,pw,wall,(side*(w+gap)/4,floor,d/2),body)
        m.add('door-frame',block((.07,wall,.10),IVORY if barn else LIGHT,at=(side*(gap/2+.01),floor+wall/2,d/2+.025)))
    m.add('door-top',block((gap+.15,.10,.11),IVORY if barn else LIGHT,at=(0,top-.07,d/2+.025)))
    # Deep loft window, split shutters and trim reproduce the references' character.
    wy=top+(.27 if barn else .17)
    m.add('loft-recess',block((.34,.28,.03),DARK,at=(0,wy,d/2+.025)))
    for x in (-.205,.205):
        m.add('loft-shutter',block((.115,.28,.055),LIGHT,at=(x,wy,d/2+.045)))
        m.add('shutter-strap',block((.115,.025,.02),DARK,at=(x,wy-.075,d/2+.078)))
    m.add('window-mullion',block((.027,.28,.055),IVORY,at=(0,wy,d/2+.045)))
    m.add('window-sill',block((.56,.045,.13),IVORY,at=(0,wy-.155,d/2+.065)))
    if barn:
        for side in (-1,1):door(m,.54,.80,(side*.70,floor+.05,d/2+.25),side*58)
        m.add('hay-floor',block((w-.20,.025,d-.20),shade(HAY,.88),at=(0,floor+.063,0),bevel=.01))
        # Side window and crossed trim break up the broad solid wall.
        m.add('side-window-dark',block((.04,.38,.48),DARK,at=(w/2+.04,.77,-.14)))
        for y in (.55,.99):m.add('side-window-sill',block((.08,.06,.61),IVORY,at=(w/2+.065,y,-.14)))
        for z in (-.41,.13):m.add('side-window-jamb',block((.07,.42,.06),IVORY,at=(w/2+.065,.77,z)))
        for end in (-1,1):m.add('side-window-cross',beam((w/2+.10,.60,-.14-end*.22),(w/2+.10,.94,-.14+end*.22),.035,IVORY))
        # Small ridge finial belongs to the roof, without a floating decoration.
        ry=max(p[1] for p in profile)
        m.add('finial-post',block((.045,.24,.045),IRON,at=(0,ry+.18,-d*.18)))
        m.add('finial-arrow',beam((-.18,ry+.25,-d*.18),(.18,ry+.25,-d*.18),.025,IRON))
        m.add('weather-arrowhead',mesh_faces([(.25,ry+.25,-d*.18),(.13,ry+.30,-d*.18),(.13,ry+.20,-d*.18)],[(0,1,2)],IRON))
    else:
        ramp=Model()
        for i in range(4):ramp.add('ramp-board',block((.12,.055,.76),shade(LIGHT,1-i*.025),at=((i-1.5)*.12,0,0)))
        for i in range(5):ramp.add('ramp-cleat',block((.49,.025,.036),DARK,at=(0,.035,-.31+i*.15)))
        add_parts(m,ramp,'',(0,.17,d/2+.35),(24,0,0))
        # The open nest compartment holds the separate per-hen egg modules.
        m.add('nest-floor',block((.57,.065,d),DARK,at=(w/2+.24,.43,0)))
        for z in (-d/2,d/2):m.add('nest-cheek',block((.57,.38,.05),TIMBER,at=(w/2+.24,.64,z)))
        for i in range(max(4,round(d/.18))):
            z=-d/2+(i+.5)*d/max(4,round(d/.18))
            m.add('nest-lid-board',transform(block((.64,.055,d/max(4,round(d/.18))-.007),shade(LIGHT,1-(i%2)*.055)),at=(w/2+.24,.87,z),angles=(0,0,-12)))
        for z in (-d*.28,d*.28):m.add('nest-hinge',block((.12,.02,.055),IRON,at=(w/2+.06,.934,z)))
        m.add('egg-sign',block((.20,.16,.045),LIGHT,at=(-gap/2-.22,.90,d/2+.058)))
        m.add('egg-relief',ellipsoid((.070,.10,.025),IVORY,at=(-gap/2-.22,.90,d/2+.09)))
    return m


def food_fill(m,amount,rx,rz,base,top,grain=False):
    """One container, different physical fill heights; clustered solids, never soup."""
    y=base+(top-base)*(1 if amount==2 else .27)
    color=HAY if grain else rgba('a97a49')
    # Dense lower volume is covered by broad faceted granules at its top.
    m.add('ration-volume',lathe([(0,base),(.98,base),(.98,y-.012),(.90,y+.005),(0,y+.018)],shade(color,.84),16,(rx,rz)))
    rng=np.random.default_rng(104)
    for i in range(46):
        a=i*2.39996;r=math.sqrt((i+.5)/46)
        yy=y+.012+.014*(1-r*r)
        dims=(.050,.035,.044) if grain else (.069,.045,.060)
        m.add('ration-granule',transform(ellipsoid(dims,shade(color,float(rng.uniform(.88,1.13))),segments=6,rings=3),at=(math.cos(a)*r*rx,yy,math.sin(a)*r*rz),angles=(0,i*29,0)))


def trough(kind,amount):
    m=Model();water=kind=='water'
    # Tapered timber trough on trestles, with rounded corners and a real inner basin.
    for x in (-.52,.52):
        for side in (-1,1):m.add('splayed-leg',transform(block((.12,.24,.12),DARK),at=(x,.12,side*.24),angles=(side*14,0,0)))
        m.add('trestle',block((.17,.10,.72),LIGHT,at=(x,.22,0)))
    m.add('inner-floor',block((1.36,.065,.41),shade(TIMBER,.85),at=(0,.265,0)))
    for side in (-1,1):
        m.add('long-stave',transform(block((1.48,.28,.085),TIMBER),at=(0,.39,side*.267),angles=(side*12,0,0)))
        m.add('rim-long',block((1.54,.065,.09),LIGHT,at=(0,.535,side*.303)))
    for side in (-1,1):
        m.add('end-stave',transform(block((.085,.28,.53),TIMBER),at=(side*.712,.39,0),angles=(0,0,-side*9)))
        m.add('rim-end',block((.095,.065,.57),LIGHT,at=(side*.753,.535,0)))
    for x in (-.53,.53):
        for z in (-.313,.313):
            m.add('iron-band',block((.045,.215,.018),IRON,at=(x,.41,z)))
            m.add('band-rivet',ellipsoid((.022,.022,.017),LIGHT,at=(x,.47,z+(.012 if z>0 else -.012)),segments=6,rings=3))
    if amount:
        y=.325 if amount==1 else .475
        if water:
            m.add('water',block((1.34,.012,.43 if amount==1 else .49),WATER,at=(0,y,0),bevel=.015))
            for x,z in [(-.35,.08),(.20,-.08)]:m.add('water-glint',block((.24,.001,.020),rgba('c3ddd1'),at=(x,y+.008,z)))
        else:
            # Fine hay stems, not a pile of broad rectangular cardboard pieces.
            fill_height=y-.285
            m.add('hay-volume',block((1.28,fill_height,.43),shade(HAY,.93),at=(0,.285+fill_height/2,0),bevel=.025))
            rng=np.random.default_rng(39)
            for i in range(54):
                x=float(rng.uniform(-.52,.52));z=float(rng.uniform(-.16,.16))
                h=y+.003
                a=float(rng.uniform(-1.2,1.2));l=float(rng.uniform(.07,.16))
                dx=math.cos(a)*l/2;dz=math.sin(a)*l*.225
                m.add('hay-stem',beam((x-dx,h,z-dz),(x+dx,h+.01,z+dz),.012,shade(HAY,float(rng.uniform(.86,1.13)))))
    return m


def bowl(kind,amount,color=CREAM,long=False):
    if long:return trough(kind,amount)
    m=Model();profile=[(0,.028),(.25,.028),(.33,.09),(.38,.235),(.377,.270),(.345,.280),(.317,.257),(.29,.120),(.245,.074),(0,.074)]
    m.add('ceramic-bowl',lathe(profile,color,16))
    m.add('foot-ring',lathe([(.245,.015),(.265,.025),(.27,.045),(.25,.052),(.245,.015)],shade(color,.65),16))
    m.add('glazed-rim',lathe([(.345,.280),(.377,.270),(.38,.25),(.370,.252),(.340,.273),(.345,.280)],shade(color,1.07),16))
    # A little embossed paw is part of the ceramic, not a hovering UI icon.
    m.add('paw-pad',ellipsoid((.09,.065,.015),IVORY,at=(0,.16,.348),segments=7,rings=3))
    for x,y in [(-.055,.199),(0,.221),(.055,.199)]:m.add('paw-toe',ellipsoid((.038,.04,.014),IVORY,at=(x,y,.357),segments=6,rings=3))
    if amount:
        if kind=='water':
            y=.12 if amount==1 else .23;r=.288 if amount==1 else .31
            m.add('water-level',lathe([(r,y),(0,y)],WATER,16))
            for x,z,w in [(-.09,.08,.14),(.09,-.08,.075)]:m.add('water-glint',block((w,.001,.014),rgba('c6ddd4'),at=(x,y+.002,z)))
        else:food_fill(m,amount,.246 if amount==1 else .273,.246 if amount==1 else .273,.085,.222,kind=='grain')
    return m


def kitchen(level,state):
    if state=='upgrading':
        m=kitchen(1,'ready')
        for x in (.05,1.02):m.add('shelf-frame',block((.065,.50,.065),LIGHT,at=(x,1.10,-.39)))
        for i in range(3):m.add('spare-shelf',block((.67,.04,.16),TIMBER,at=(.52,.34+i*.045,0)))
        return m
    m=Model();brick=rgba('bf8464');stone=rgba('d4c6a4');w=2.24
    # Stone feet and a low brick hearth, not a large brown plinth.
    m.add('hearth',block((1.02,.09,.92),shade(stone,.80),at=(-.64,.05,0),bevel=.025))
    rows=5 if state!='building' else 2
    for row in range(rows):
        for side in (-1,1):
            if state=='abandoned' and (row+side)%3==0:continue
            for z in range(3):m.add('firebox-brick',block((.16,.13,.24),shade(brick,[1,.95,1.045][(z+row)%3]),at=(-.64+side*.36,.17+row*.135,-.27+z*.27),bevel=.018))
        for col in range(3):m.add('rear-brick',block((.24,.13,.13),shade(brick,.94),at=(-.91+col*.27,.17+row*.135,-.38),bevel=.016))
    if state!='ready':
        m.add('fallen-counter',transform(block((1.10,.085,.65),TIMBER),at=(.52,.20,.06),angles=(0,12,18 if state=='abandoned' else 0)))
        for i in range(3):m.add('loose-brick',transform(block((.23,.12,.13),brick),at=(-.10+i*.27,.085,.42),angles=(0,i*26,0)))
        if state=='abandoned':
            from build_quintal_compositions import part
            m.add('grass',part('grass',(.55,.40,.42),at=(.55,0,-.30)))
            m.add('discarded-pot',part('pot',(.35,.30,.35),pack='food-kit',at=(.78,.07,.24),tilt=(0,65)))
        return m
    m.add('firebox-dark-back',box((.52,.48,.015),DARK,at=(-.64,.38,-.32)))
    # Keystone arch and iron grate make the opening read as an oven.
    for i in range(7):
        a=math.pi*i/6
        m.add('arch-stone',transform(block((.14,.17,.12),shade(stone,1-(i%2)*.055)),at=(-.64+math.cos(a)*.265,.43+math.sin(a)*.235,.414),angles=(0,0,math.degrees(a)-90)))
    for x in (-.84,-.71,-.58,-.45):m.add('grate-bar',block((.025,.18,.025),IRON,at=(x,.27,.408)))
    m.add('grate-bottom',block((.46,.035,.04),IRON,at=(-.64,.18,.41)))
    m.add('stove-top',block((.99,.105,.89),stone,at=(-.64,.827,0),bevel=.035))
    # Chimney sits behind the pan and terminates in a broad terracotta cap.
    for row in range(5):m.add('chimney-course',block((.24,.145,.24),shade(brick,1-(row%2)*.05),at=(-.92,.94+row*.145,-.31),bevel=.017))
    m.add('chimney-cap',block((.32,.075,.32),stone,at=(-.92,1.62,-.31)))
    m.add('chimney-opening',block((.17,.003,.17),IRON,at=(-.92,1.66,-.31)))
    for x in (.04,1.04):
        for z in (-.38,.38):m.add('table-leg',block((.10,.73,.10),TIMBER,at=(x,.385,z)))
    m.add('shelf',block((1.08,.065,.80),TIMBER,at=(.54,.27,0)))
    for i in range(5):m.add('worktop-plank',block((1.20,.09,.18),shade(LIGHT,[1,.96,1.02][i%3]),at=(.54,.825,-.36+i*.18),bevel=.012))
    m.add('apron',block((1.02,.15,.055),TIMBER,at=(.54,.69,.38)))
    m.add('drawer-front',block((.47,.12,.035),SAGE,at=(.70,.70,.426)))
    m.add('drawer-handle',block((.14,.025,.04),DARK,at=(.70,.70,.456)))
    # Folded dish towel drapes over the counter edge, attached along its top.
    m.add('towel-top',block((.21,.012,.21),IVORY,at=(.12,.880,.34),bevel=.004))
    m.add('towel-drop',block((.21,.25,.02),IVORY,at=(.12,.75,.45),bevel=.008))
    for y in (.66,.69):m.add('towel-stripe',box((.21,.018,.004),SAGE,at=(.12,y,.463)))
    # Shelving remains behind the serving area and never claims collectible stock.
    if level==2:
        for x in (.03,1.02):m.add('shelf-upright',block((.07,.59,.07),TIMBER,at=(x,1.1,-.38)))
        m.add('upper-shelf',block((1.16,.06,.26),LIGHT,at=(.52,1.36,-.35)))
        for i in range(3):
            m.add('spice-jar',lathe([(0,0),(.064,0),(.07,.12),(.05,.16),(0,.16)],shade(SAGE,1+i*.06),10,at=(.22+i*.29,1.39,-.35)))
            m.add('jar-lid',block((.13,.035,.13),LIGHT,at=(.22+i*.29,1.565,-.35),bevel=.018))
    return m


def portions(count):
    # A single serving casserole; multiple portions change its content level.
    m=Model();color=rgba('e2c58f')
    m.add('serving-dish',lathe([(0,.02),(.24,.02),(.34,.06),(.37,.19),(.34,.22),(.30,.19),(.265,.065),(0,.065)],color,12,(1,.69)))
    for side in (-1,1):m.add('dish-handle',block((.12,.055,.11),color,at=(side*.38,.155,0),bevel=.025))
    if count:food_fill(m,1 if count==1 else 2,.27,.17,.078,.18)
    return m


def linen(width, depth, height, drop=.06, drape_start=.90):
    """Folded fabric with a green woven border and a short front overhang."""
    m=Model();columns=12;rows=12;vertices=[]
    for j in range(rows+1):
        t=j/rows
        for i in range(columns+1):
            x=(i/columns-.5)*width
            y=height+.009*math.cos(i*.85+j*.55)-drop*max(0,(t-drape_start)/(1-drape_start))
            vertices.append((x,y,(t-.5)*depth))
    for j in range(rows):
        for i in range(columns):
            a=j*(columns+1)+i
            c=rgba('789568') if j==9 or i in (1,10) else IVORY
            m.add('linen-border' if j==9 or i in (1,10) else 'linen-fold',mesh_faces(vertices,[(a,a+columns+1,a+columns+2,a+1)],c))
    return m


def produce_crate(covered=False):
    """Open slatted crate, with real gaps/handholds and an optional linen cover."""
    m=Model();w=.48;d=.40
    m.add('crate-floor',block((w,.035,d),TIMBER,at=(0,.023,0),bevel=.009))
    for x in (-1,1):
        for z in (-1,1):m.add('crate-corner',block((.042,.285,.042),LIGHT,at=(x*.228,.15,z*.188),bevel=.01))
    for y in (.075,.155):
        for z in (-1,1):m.add('crate-plank',block((.44,.065,.029),TIMBER,at=(0,y,z*.19),bevel=.008))
        for x in (-1,1):m.add('crate-side',block((.029,.065,.35),TIMBER,at=(x*.23,y,0),bevel=.008))
    # An actual gap under the top rail forms the handhold on each short side.
    for x in (-1,1):
        m.add('crate-handle-rail',block((.033,.036,.35),LIGHT,at=(x*.23,.267,0),bevel=.009))
        for z in (-1,1):m.add('crate-handle-end',block((.033,.068,.095),TIMBER,at=(x*.23,.231,z*.127),bevel=.009))
    for z in (-1,1):m.add('crate-rim',block((.44,.073,.033),LIGHT,at=(0,.24,z*.19),bevel=.008))
    if covered:
        for name,mesh in linen(.43,.47,.273,.10).parts:m.add(name,mesh)
    return m


def post(state):
    m=Model();sage=rgba('83a181');w=2.10
    for x in (-.93,.93):
        for z in (-.49,.49):
            if state=='abandoned' and x<0 and z>0:continue
            m.add('post-foot',block((.17,.10,.17),DARK,at=(x,.05,z),bevel=.025))
            m.add('post',block((.095,1.68,.095),LIGHT,at=(x,.91,z),bevel=.016))
    if state!='ready':
        for i in range(3):m.add('counter-boards',transform(block((1.15,.075,.20),TIMBER),at=(.08,.13+i*.078,.12),angles=(0,i*8,0)))
        if state=='abandoned':
            for i in (0,1,4,5):m.add('torn-canvas',transform(block((.32,.03,.65),sage if i%2==0 else IVORY),at=(-.9+i*.36,1.62,-.22),angles=(18,0,i*3)))
            m.add('fallen-sign',transform(block((.65,.28,.05),IVORY),at=(-.37,.13,.47),angles=(72,0,-15)))
            from build_quintal_compositions import part
            m.add('shrub',part('plant_bushSmall',(.54,.48,.45),at=(.6,0,-.12)))
        else:m.add('canopy-rail',block((2.04,.09,.09),TIMBER,at=(0,1.74,.49)))
        return m
    for z in (-.49,.49):m.add('canopy-rail',block((2.08,.09,.09),TIMBER,at=(0,1.72,z)))
    # Bent fabric strips and scalloped hems make a canopy rather than a flat roof.
    for i in range(6):
        x=-.9+i*.36;c=sage if i%2==0 else IVORY
        points=[(-.67,1.90),(-.20,1.88),(.29,1.79),(.80,1.65)]
        for (za,ya),(zb,yb) in zip(points,points[1:]):
            angle=-math.degrees(math.atan2(yb-ya,zb-za))
            m.add('canvas-band',transform(block((.356,.035,math.hypot(zb-za,yb-ya)+.014),c,bevel=.006),at=(x,(ya+yb)/2,(za+zb)/2),angles=(angle,0,0)))
        vertices=[(x-.178,1.67,.80),(x+.178,1.67,.80)]+[(x+.178*math.cos(a),1.54-.10*math.sin(a),.80) for a in np.linspace(0,math.pi,7)]
        m.add('canvas-scallop',mesh_faces(vertices,[tuple(range(len(vertices)))],c))
    # Painted counter with separate rails, inset panels and bevelled timber top.
    for i in range(8):m.add('counter-siding',block((.22,.57,.06),shade(sage,[1,.95,1.035][i%3]),at=(-.84+i*.24,.43,.51)))
    for x in (-.95,0,.95):m.add('counter-stile',block((.06,.60,.09),LIGHT,at=(x,.43,.55)))
    for y in (.15,.69):m.add('counter-rail',block((1.98,.06,.09),LIGHT,at=(0,y,.55)))
    m.add('countertop',block((2.04,.085,.78),LIGHT,at=(0,.775,.31),bevel=.023))
    m.add('back-shelf',block((1.89,.07,.29),TIMBER,at=(0,.44,-.35)))
    for x in (-.9,0,.9):m.add('cubby-divider',block((.045,.34,.29),sage,at=(x,.245,-.35)))
    # Permanent produce display stays left; the right-hand cloth is the pickup area.
    from build_quintal_compositions import part
    for index,x in enumerate((-.68,-.24)):
        for name,mesh in produce_crate().parts:
            m.add('display-'+name,transform(mesh,scale=(.78,.72,.76),at=(x,.818,.53)))
        for i,(dx,dz) in enumerate([(-.085,-.065),(.065,-.065),(-.08,.065),(.065,.065),(0,0)]):
            fruit=part('apple',(.115,.13,.115),pack='food-kit',at=(x+dx,.965+(i==4)*.07,.53+dz),angle=i*57)
            for mesh in fruit:
                # Preserve the fruit's stem material; tint its larger body only.
                if np.ptp(mesh.positions[:,0])>.06:mesh.texture=None;mesh.color=rgba('be7459' if index==0 else 'a3b86a')
            m.add('display-fruit',fruit)
    for name,mesh in linen(.76,.95,.834,.17,drape_start=.80).parts:
        m.add('counter-'+name,transform(mesh,at=(.39,0,.415)))
    m.add('bell-base',lathe([(0,0),(.092,0),(.10,.025),(0,.025)],DARK,12,at=(.72,.82,.30)))
    m.add('counter-bell',lathe([(0,0),(.078,0),(.065,.05),(.025,.074),(0,.075)],rgba('bd995a'),12,at=(.72,.845,.30)))
    m.add('bell-button',block((.025,.025,.025),IRON,at=(.72,.935,.30),bevel=.005))
    return m
