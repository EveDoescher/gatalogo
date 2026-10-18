"""Small native tools whose pouring lip is the shared origin (0, 0, 0)."""
import numpy as np
from quintal_model_authoring import Model, lathe, box, ellipsoid, beam, transform, rgba, WOOD, WOOD_LIGHT, WOOD_DARK, STRAW


def pipe(a, b, r1, r2, color):
    a=np.asarray(a,dtype=float);b=np.asarray(b,dtype=float)
    up=b-a;length=np.linalg.norm(up);up/=length
    side=np.cross(up,[0,0,1] if abs(up[2])<.9 else [1,0,0]);side/=np.linalg.norm(side)
    rotation=np.column_stack([side,up,np.cross(side,up)])
    mesh=lathe([(0,0),(r1,0),(r2,length),(0,length)],color,10)
    mesh.positions=mesh.positions@rotation.T+a
    mesh.normals=mesh.normals@rotation.T
    return mesh


def watering_can():
    m=Model();metal=rgba('7eaaa3');edge=rgba('577c76')
    m.add('vessel',lathe([(0,-.17),(.22,-.17),(.25,.19),(.22,.25),(.17,.25),(.18,.19),(.17,-.12),(0,-.12)],metal,12,at=(.65,.15,0)))
    m.add('spout',pipe((.52,.08,0),(.12,.025,0),.085,.045,metal))
    m.add('rose-neck',pipe((.12,.025,0),(.025,0,0),.045,.08,edge))
    m.add('rose',pipe((.025,0,0),(0,0,0),.09,.10,metal))
    for y,z in [(-.035,-.035),(-.035,.035),(.035,-.035),(.035,.035),(0,0)]:
        m.add('rose-hole',ellipsoid((.008,.013,.013),edge,at=(-.003,y,z),segments=5,rings=3))
    handle=[(.80,.33,0),(1.02,.37,0),(1.10,.20,0),(1.02,-.02,0),(.84,-.01,0)]
    for a,b in zip(handle,handle[1:]):m.add('handle',beam(a,b,.043,edge))
    m.add('top-grip',beam((.50,.42,0),(.77,.42,0),.043,WOOD_DARK))
    for x in (.50,.77):m.add('grip-support',beam((x,.35,0),(x,.42,0),.027,edge))
    return m


def feed_scoop():
    m=Model()
    m.add('floor',box((.46,.035,.31),WOOD_LIGHT,at=(.23,.015,0)))
    for z in (-.155,.155):m.add('side',box((.46,.13,.028),WOOD,at=(.23,.065,z)))
    m.add('back',box((.035,.17,.33),WOOD,at=(.46,.085,0)))
    m.add('handle',beam((.46,.075,0),(.87,.12,0),.065,WOOD_DARK))
    for i in range(12):
        x=.08+(i%4)*.095;z=(i//4-1)*.087
        m.add('grain',ellipsoid((.075,.045,.055),rgba('bd985b'),at=(x,.06,z),segments=6,rings=3))
    return m


def hay_fork():
    m=Model();iron=rgba('788078')
    m.add('handle',beam((.30,.06,0),(1.08,.21,0),.045,WOOD_DARK))
    m.add('fork-shoulder',beam((.33,.045,-.14),(.33,.045,.14),.023,iron))
    for z in (-.14,0,.14):m.add('tine',beam((.33,.045,z),(0,0,z),.023,iron))
    for i in range(14):
        z=(i%7-3)*.043;y=.07+(i//7)*.036
        m.add('hay',beam((.025,y,z),(.36,y+.04+(i%3)*.009,z+.015),.025,STRAW if i%2 else rgba('d8c486')))
    return m


def action_tool(kind,stage):
    source={'watering-can':watering_can,'feed-scoop':feed_scoop,'hay-fork':hay_fork}[kind]()
    # Tilt the real geometry around its lip, preserving the stream attachment.
    angle=-35+stage*12
    model=Model()
    for name,mesh in source.parts:model.add(name,transform(mesh,angles=(0,0,angle)))
    return model
