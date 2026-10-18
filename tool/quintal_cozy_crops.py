"""Four hand-authored growth stages per crop, rooted at the soil origin.

Shared folded leaves and faceted fruit keep the crops in the same visual family
as Quintal's animals. Stages change topology and maturation, not just scale.
"""
import math
import numpy as np
from quintal_model_authoring import Model,mesh_faces,beam,ellipsoid,lathe,transform,rgba,bevel_box

LEAF=rgba('71944b'); LIGHT=rgba('91ad61'); DARK=rgba('567a40')
STEM=rgba('7e9e51'); GOLD=rgba('d9b45f'); PALE=rgba('ebcf87')


def blade(start,end,width,color=LEAF,arch=.04,lobed=False):
    """Folded curved blade with a ridge and tapered tip, not a flat diamond."""
    a,b=np.array(start,dtype=float),np.array(end,dtype=float)
    direction=b-a;side=np.array([-direction[2],0,direction[0]])
    if np.linalg.norm(side)<1e-8:side=np.array([1.,0,0])
    side/=np.linalg.norm(side)
    steps=6 if lobed else 4;vertices=[]
    for i in range(steps+1):
        t=i/steps;center=a+direction*t
        center[1]+=arch*math.sin(math.pi*t)
        breadth=width*math.sin(math.pi*t)**.7
        if lobed:breadth*=1.10 if i%2==0 else .78
        ridge=center+np.array([0,width*.16*math.sin(math.pi*t),0])
        vertices.extend([center-side*breadth,ridge,center+side*breadth])
    faces=[]
    for i in range(steps):
        a=i*3;b=(i+1)*3
        faces.extend([(a,a+1,b+1,b),(a+1,a+2,b+2,b+1)])
    return mesh_faces(vertices,faces,color)


def stem_path(m,name,points,thickness,color=STEM):
    for i,(a,b) in enumerate(zip(points,points[1:])):
        m.add(f'{name}-{i}',beam(a,b,thickness,color))


def wheat(stage):
    m=Model();count=[3,5,7,9][stage]
    for i in range(count):
        angle=i*2.39996;r=[.085,.12,.16,.18][stage]*math.sqrt((i+.5)/count)
        x,z=math.cos(angle)*r,math.sin(angle)*r
        h=[.12,.34,.57,.69][stage]*(.91+(i%3)*.09)
        lean=np.array([math.cos(angle)*.045,0,math.sin(angle)*.045])
        p=np.array([x,0,z]);tip=p+[0,h,0]+lean
        color=STEM if stage<3 else GOLD
        stem_path(m,f'stalk-{i}',[p,p+[0,h*.55,0]+lean*.3,tip],.014 if stage<2 else .019,color)
        for j in range(2 if stage==0 else 3):
            a=angle+j*2.4;start=p+[0,h*(.18+j*.18),0]
            length=[.09,.17,.23,.23][stage]
            end=start+[math.cos(a)*length,.04 if stage==0 else .055,math.sin(a)*length]
            m.add('blade',blade(start,end,.024 if stage==0 else .032,LIGHT if stage<3 else rgba('c0ad61'),arch=.04))
        if stage<2:continue
        ear=Model();rows=4 if stage==2 else 5
        ear.add('rachis',beam((0,0,0),(0,.25,0),.015,color))
        for row in range(rows):
            for side in (-1,1):
                yy=.025+row*.039
                grain=ellipsoid((.047,.085,.045),LIGHT if stage==2 else (PALE if (row+i)%2 else GOLD),segments=6,rings=4)
                ear.add('kernel',transform(grain,at=(side*.021,yy+.023,0),angles=(0,0,-side*23)))
                # A few short awns give the ear its wheat silhouette without noise.
                if row in (1,3):ear.add('awn',beam((side*.025,yy+.045,0),(side*.053,yy+.10,0),.0045,LIGHT if stage==2 else PALE))
        ear.add('ear-tip',ellipsoid((.035,.080,.034),LIGHT if stage==2 else PALE,at=(0,.235,0),segments=6,rings=4))
        for name,mesh in ear.parts:
            m.add(f'ear-{i}-{name}',transform(mesh,at=tip,angles=(math.cos(angle)*-9,math.degrees(angle),math.sin(angle)*12)))
    return m


def corn_ear():
    """A tapered cob with close-fitting kernels and a partly opened husk."""
    m=Model()
    profile=[(0,.008),(.025,.008),(.047,.025),(.060,.075),(.059,.17),(.047,.235),(.027,.268),(0,.28)]
    m.add('golden-cob',lathe(profile,rgba('d7a94c'),14))
    # Sixteen columns cover the entire circumference, including the back.
    # Broad bevelled kernels read as corn rather than isolated yellow pebbles.
    for row in range(10):
        y=.036+row*.026
        radius=float(np.interp(y,[.025,.075,.17,.235,.268],[.047,.060,.059,.047,.027]))
        for col in range(16):
            a=col*math.tau/16
            width=radius*(math.tau/16)*.96
            color=rgba(['e4bc63','e9c775','e6c16b'][(row+col)%3])
            grain=bevel_box((width,.025,.021),color,bevel=.006)
            m.add('kernel',transform(grain,at=(math.sin(a)*(radius+.003),y,math.cos(a)*(radius+.003)),angles=(0,math.degrees(a),0)))
    # Open side leaves and a short basal sheath expose the kernels on both sides.
    for side in (-1,1):
        m.add('husk-fold',blade((side*.012,.005,-.004),(side*.094,.20,-.021),.035,LEAF,arch=.037))
        m.add('husk-tip',blade((side*.050,.10,-.032),(side*.091,.24,-.050),.023,LIGHT,arch=.021))
    # A shaped half-shell follows the rear of the cob; it must not sit inside it.
    vertices=[];columns=8;levels=4
    for level in range(levels+1):
        t=level/levels
        for col in range(columns+1):
            a=math.pi/2+col*math.pi/columns
            y=.008+t*(.050+.025*math.cos(a-math.pi))
            r=float(np.interp(y,[.008,.025,.075,.17,.235,.268],[.025,.047,.060,.059,.047,.027]))+.005
            vertices.append((math.sin(a)*r,y,math.cos(a)*r))
    faces=[]
    for level in range(levels):
        for col in range(columns):
            a=level*(columns+1)+col;b=a+columns+1
            faces.append((a,b,b+1,a+1))
    m.add('back-husk',mesh_faces(vertices,faces,LEAF))
    for i in (-1,0,1):
        stem_path(m,'silk',[(i*.009,.27,0),(i*.014,.292,.005),(i*.019,.298,.025)],.0045,rgba('b58b50'))
    return m


def corn(stage):
    m=Model();height=[.14,.39,.77,1.03][stage]
    stem_path(m,'stalk',[(0,0,0),(.012,height*.52,0),(0,height,.018)],.018 if stage<2 else .035)
    count=[3,5,7,9][stage]
    for i in range(count):
        angle=i*2.40+.4
        y=height*(.10+.72*i/count)
        length=[.12,.24,.33,.36][stage]*(1-abs(i/count-.45)*.40)
        start=(.006,y,.008)
        end=(math.cos(angle)*length,y+.06,math.sin(angle)*length)
        m.add(f'corn-leaf-{i}',blade(start,end,[.025,.048,.067,.076][stage],LIGHT if i%3==0 else LEAF,arch=length*.35))
    if stage>=2:
        for i,angle in enumerate((.45,3.6)):
            y=height*(.44+i*.19);anchor=(math.cos(angle)*.07,y,math.sin(angle)*.07)
            if stage==3:
                ear=corn_ear()
            else:
                ear=Model();ear.add('husk-core',ellipsoid((.12,.29,.12),LIGHT,at=(0,.12,0),segments=8,rings=5))
                for side in (-1,1):ear.add('husk-leaf',blade((side*.025,0,0),(side*.115,.19,-.015),.035,LEAF,arch=.06))
            for name,mesh in ear.parts:m.add(f'corn-ear-{i}-{name}',transform(mesh,at=anchor,angles=(0,math.degrees(angle),-14 if i==0 else 14)))
    if stage==3:
        for a in (-1,0,1):
            stem_path(m,'tassel',[(0,height,.018),(a*.055,height+.085,.018),(a*.09,height+.16,.025)],.011,GOLD)
            for j in range(3):m.add('tassel-seed',ellipsoid((.027,.045,.026),PALE,at=(a*.04,height+.045+j*.033,.02),segments=5,rings=3))
    return m


def roots(kind,stage):
    m=Model();carrot=kind=='carrot'
    base=.01
    if stage==3:
        # Only the shoulder emerges; the harvested root is never displayed on top.
        profile=[(0,0),(.13,0),(.125,.035),(.08,.075),(0,.083)] if carrot else [(0,0),(.165,0),(.17,.04),(.125,.10),(.05,.125),(0,.125)]
        m.add('root-shoulder',lathe(profile,rgba('d99548') if carrot else rgba('d9bdc6'),12))
        base=.074 if carrot else .11
        if not carrot:m.add('root-crown',lathe([(.095,.113),(.06,.132),(0,.132)],rgba('e5d8b7'),12))
    if stage==0:
        for i in range(3):
            a=i*math.tau/3
            m.add('cotyledon',blade((0,base,0),(math.cos(a)*.10,.095,math.sin(a)*.10),.028 if carrot else .047,LIGHT,arch=.025))
        return m
    count=[0,5,7,9][stage] if carrot else [0,4,6,7][stage]
    for i in range(count):
        a=i*2.39996
        reach=[0,.17,.25,.29][stage]*(.80+(i%3)*.10)
        h=[0,.19,.27,.32][stage]+base
        end=np.array([math.cos(a)*reach,h,math.sin(a)*reach]);start=np.array([0,base,0])
        if carrot:
            stem_path(m,'frond-stem',[start,end*.60+start*.40,end],.009,DARK)
            lateral=np.array([-math.sin(a),0,math.cos(a)])
            for j in range(2+stage):
                t=.25+j*.13;p=start+(end-start)*t
                length=(.082-stage*.003)*(1-t*.60)
                for side in (-1,1):
                    q=p+lateral*side*length+np.array([math.cos(a)*.025,.02,math.sin(a)*.025])
                    m.add('carrot-leaflet',blade(p,q,.017+stage*.002,LIGHT if i%3==0 else LEAF,arch=.018))
            m.add('frond-tip',blade(start+(end-start)*.77,end,.025,LEAF,arch=.015))
        else:
            petiole=start+(end-start)*.26
            m.add('leaf-stalk',beam(start,petiole,.014,STEM))
            m.add('turnip-leaf',blade(petiole,end,.071+stage*.007,LIGHT if i%3==0 else LEAF,arch=.06,lobed=True))
            m.add('leaf-vein',beam(petiole,petiole+(end-petiole)*.7,.006,LIGHT))
    return m


def harvested_root(kind):
    """Same crown/leaves; the underground body is revealed only during harvest."""
    m=roots(kind,3)
    carrot=kind=='carrot'
    profile=([(0,-.53),(.025,-.47),(.065,-.31),(.105,-.13),(.13,0),(0,0)]
             if carrot else [(0,-.37),(.025,-.28),(.12,-.20),(.18,-.09),(.165,0),(0,0)])
    m.add('underground-root',lathe(profile,rgba('d99548') if carrot else rgba('e5d8b7'),12))
    return m


def fruit_mesh(kind,mature):
    # The original nature-kit pumpkin is the requested ripe silhouette.
    # Keep its broad bevels and lobes; the melon uses the matching pack geometry.
    from build_quintal_compositions import part
    pumpkin=kind=='pumpkin';m=Model()
    dims=(.48,.31,.48) if pumpkin else (.43,.33,.38)
    if not mature:dims=tuple(d*.48 for d in dims)
    meshes=part('crop_pumpkin' if pumpkin else 'crop_melon',dims)
    for i,mesh in enumerate(meshes):
        stem=i==(1 if pumpkin else 2)
        if stem:mesh.color=DARK.copy()
        elif not mature:mesh.color=rgba('95ad62' if i==0 else '71934e')
        elif not pumpkin:mesh.color=rgba('c6ce85' if i==0 else '96ad66')
        m.add('fruit-stem' if stem else 'fruit-skin',mesh)
    return m


def vine(kind,stage):
    m=Model();length=[.10,.22,.32,.38][stage]
    count=[2,3,4,5][stage]
    for i in range(count):
        a=i*2.39996+.7
        origin=np.array([-.075,.008,-.04]);end=origin+np.array([math.cos(a)*length,.009,math.sin(a)*length])
        bend=origin+(end-origin)*.55+np.array([math.sin(a)*.035,0,-math.cos(a)*.035])
        stem_path(m,'vine',[origin,bend,end],.011+stage*.003,DARK)
        petiole=end+np.array([math.cos(a)*.018,.045,math.sin(a)*.018])
        m.add('leaf-petiole',beam(end,petiole,.010,STEM))
        leaf_end=petiole+np.array([math.cos(a)*.12,.04,math.sin(a)*.12])
        m.add('vine-leaf',blade(petiole,leaf_end,.038+stage*.018,LIGHT if i%2 else LEAF,arch=.045,lobed=True))
    if stage>=2:
        # Fruit rests directly on the soil; a short vine joins its stem.
        fruit=fruit_mesh(kind,stage==3);at=(.105,.002,.075)
        for name,mesh in fruit.parts:m.add(name,transform(mesh,at=at,angles=(0,-18,0)))
        h=(.31 if kind=='pumpkin' else .33)*(1 if stage==3 else .48)
        stem_path(m,'fruit-attachment',[(-.075,.01,-.04),(-.16,.012,.02),(-.12,h*.50,.075),(.105,h*.90,.075)],.014,DARK)
    elif stage==1:
        # A small bud hints at future fruit without pretending it is harvestable.
        m.add('flower-bud',ellipsoid((.046,.05,.046),rgba('d6b96a'),at=(.06,.036,.02),segments=6,rings=3))
    return m


def crop(kind,stage):
    if stage not in range(4):raise ValueError('Crop stage must be 0..3')
    if kind=='wheat':return wheat(stage)
    if kind=='corn':return corn(stage)
    if kind in ('carrot','turnip'):return roots(kind,stage)
    if kind in ('pumpkin','melon'):return vine(kind,stage)
    raise ValueError(f'Unknown crop: {kind}')
