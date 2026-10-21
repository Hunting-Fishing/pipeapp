"""Original Oil & Gas Tycoon geometry, authored for the project.

Run inside Blender after clearing the scene. build(kind) creates only meshes.
The shared renderer supplies its camera, lighting, output, and normalization.
No downloaded geometry or textures are used by this module.
"""
import math
import bpy
from mathutils import Vector


COLORS = {
    'navy': (0.055, 0.13, 0.17, 1),
    'teal': (0.08, 0.37, 0.34, 1),
    'copper': (0.88, 0.37, 0.13, 1),
    'cream': (0.78, 0.79, 0.70, 1),
    'steel': (0.36, 0.45, 0.46, 1),
    'concrete': (0.51, 0.57, 0.51, 1),
    'rubber': (0.025, 0.040, 0.045, 1),
    'glass': (0.10, 0.26, 0.32, 1),
}


def material(name):
    key = 'Tycoon_' + name
    mat = bpy.data.materials.get(key)
    if mat is None:
        mat = bpy.data.materials.new(key)
        mat.diffuse_color = COLORS[name]
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = COLORS[name]
        shader.inputs['Roughness'].default_value = 0.65
        shader.inputs['Metallic'].default_value = 0.25 if name == 'steel' else 0.05
    return mat


def finish(obj, name, color, bevel=0.025):
    obj.name = name
    obj.data.materials.append(material(color))
    if bevel:
        modifier = obj.modifiers.new('Machined edges', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 2
    return obj


def box(name, location, size, color, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, color, bevel)


def cylinder(name, location, radius, depth, color, axis='Z', vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    if axis == 'X':
        obj.rotation_euler[1] = math.pi / 2
    elif axis == 'Y':
        obj.rotation_euler[0] = math.pi / 2
    return finish(obj, name, color, 0.018)


def beam(name, start, end, width, color):
    start, end = Vector(start), Vector(end)
    obj = box(name, (start + end) / 2, (width, width, (end - start).length), color, 0.012)
    obj.rotation_euler = (end - start).to_track_quat('Z', 'Y').to_euler()
    return obj


def slab(x, y):
    box('Concrete foundation', (0, 0, 0.10), (x, y, .20), 'concrete', .06)


def pumpjack(large=False):
    slab(4.9, 2.6)
    box('Main skid', (0, 0, .31), (4.35, 1.8, .20), 'navy')
    for y in [-.60, .60]:
        beam('Sampson post front', (-.95, y, .44), (-.28, y, 2.60), .18, 'teal')
        beam('Sampson post rear', (.45, y, .44), (-.28, y, 2.60), .18, 'teal')
        beam('A frame brace', (-.68, y, 1.18), (.18, y, 1.18), .14, 'cream')
    cylinder('Saddle bearing', (-.28, 0, 2.60), .23, 1.6, 'steel', 'Y')
    beam('Walking beam', (-2.0, 0, 2.89), (1.72, 0, 2.31), .28, 'copper')
    # Extruded curved horsehead profile, with a rounded outer working edge.
    profile = [(1.55, 2.57), (1.98, 2.52), (2.19, 2.28), (2.25, 1.99), (2.16, 1.76), (1.85, 1.78), (1.73, 2.04)]
    vertices = [(x, y, z) for y in [-.23, .23] for x, z in profile]
    count = len(profile)
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    mesh = bpy.data.meshes.new('Horsehead profile')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new('Horsehead', mesh)
    bpy.context.collection.objects.link(obj)
    finish(obj, 'Horsehead', 'copper', .035)
    for y in [-.49, .49]:
        cylinder('Crank wheel', (-1.11, y, 1.12), .59, .14, 'navy', 'Y')
        cylinder('Crank hub', (-1.11, y * 1.16, 1.12), .16, .16, 'cream', 'Y')
        box('Counterweight', (-1.4, y * 1.1, .85), (.62, .24, .34), 'copper')
        beam('Pitman arm', (-.78, y, 1.52), (-1.55, y, 2.80), .12, 'steel')
    box('Gearbox', (-1.13, 0, .73), (.80, .68, .50), 'teal')
    cylinder('Drive motor', (-1.9, 0, .69), .27, .58, 'steel', 'Y')
    beam('Polished rod', (2.15, 0, .43), (2.15, 0, 2.17), .045, 'steel')
    cylinder('Wellhead', (2.12, 0, .40), .24, .37, 'teal')
    cylinder('Wellhead flange', (2.12, 0, .59), .30, .10, 'copper')
    beam('Flow line', (2.12, 0, .43), (2.12, -.99, .43), .11, 'steel')
    box('Control cabinet', (.6, .93, .68), (.52, .30, .80), 'cream')
    box('Cabinet panel', (.6, .76, .82), (.30, .04, .24), 'glass', .01)
    if large:
        for obj in list(bpy.context.scene.objects):
            if obj.type == 'MESH':
                obj.scale *= 1.2
                obj.location *= 1.2
        box('Heavy-duty motor shelter', (-1.65, .96, .88), (1.4, .80, 1.1), 'navy')
        for x in [-2.10, -1.88, -1.66, -1.44]:
            box('Motor cooling fins', (x, .53, .92), (.08, .05, .65), 'cream', .008)


def drilling_rig():
    slab(4.8, 3.0)
    box('Rig deck', (0, 0, .40), (4.15, 2.45, .40), 'navy')
    box('Generator housing', (-1.26, 0, 1.08), (1.45, 1.65, 1.0), 'teal')
    box('Generator roof', (-1.26, 0, 1.62), (1.65, 1.85, .14), 'cream')
    for x in [-1.77, -1.52, -1.27, -1.02, -.77]:
        box('Housing vents', (x, -.84, 1.11), (.07, .06, .49), 'navy', .005)
    corners = [(0.1, -.63), (1.46, -.63), (1.46, .63), (.1, .63)]
    tops = [(.48, -.33), (1.08, -.33), (1.08, .33), (.48, .33)]
    for (x, y), (tx, ty) in zip(corners, tops):
        beam('Mast leg', (x, y, .64), (tx, ty, 5.3), .13, 'copper')
    for level in range(6):
        z1, z2 = .72 + level * .72, .72 + (level + 1) * .72
        frac1, frac2 = (z1-.64)/4.66, (z2-.64)/4.66
        points1 = [(x+(tx-x)*frac1, y+(ty-y)*frac1, z1) for (x,y),(tx,ty) in zip(corners,tops)]
        points2 = [(x+(tx-x)*frac2, y+(ty-y)*frac2, z2) for (x,y),(tx,ty) in zip(corners,tops)]
        for i in range(4):
            nxt = (i + 1) % 4
            beam('Mast horizontal', points1[i], points1[nxt], .065, 'cream')
            beam('Mast diagonal', points1[i], points2[nxt], .065, 'cream')
    cylinder('Drill string', (.78, 0, 2.9), .065, 4.7, 'steel')
    box('Crown assembly', (.78, 0, 5.35), (.9, .85, .25), 'navy')
    cylinder('Travelling block', (.78, 0, 4.45), .18, .38, 'navy')
    for y in [-1.07, 1.07]:
        beam('Deck safety rail', (-1.95,y,1.05),(1.95,y,1.05),.055,'cream')
        for x in [-1.95,-.65,.65,1.95]:
            beam('Rail post',(x,y,.64),(x,y,1.05),.055,'cream')
    for i in range(3):
        box('Access stair', (2.18 + i*.17,-.54,.50-i*.12),(.35,.80,.18),'steel')


def gas_skid():
    slab(4.6, 3.0)
    box('Gathering skid', (0,0,.30),(4.16,2.5,.24),'navy')
    for y in [-.77, 0, .77]:
        cylinder('Separator vessel',(0,y,1.06),.33,2.9,'cream','X')
        for x in [-1.09,1.09]:
            box('Vessel support',(x,y,.63),(.18,.62,.42),'teal')
            cylinder('Vessel flange',(x*1.27,y,1.06),.37,.12,'steel','X')
        cylinder('Separator inlet',(-1.76,y,1.06),.11,.60,'copper','X')
    beam('Inlet manifold',(-1.99,-1.06,1.06),(-1.99,1.06,1.06),.16,'copper')
    box('Compressor housing',(1.64,0,.90),(.55,1.85,.98),'teal')
    for y in [-.65,0,.65]:
        cylinder('Control valve',(-1.98,y,1.40),.20,.04,'navy')
        beam('Valve stem',(-1.98,y,1.06),(-1.98,y,1.4),.06,'steel')
    box('Control instrument',(1.65,-1.10,1.23),(.45,.13,.42),'cream')
    box('Instrument display',(1.65,-1.18,1.27),(.28,.025,.17),'glass',.005)


def tanker(heavy=False):
    length = 8.5 if heavy else 6.5
    back = -length / 2
    front = length / 2
    box('Heavy steel chassis', (0,0,.70),(length,1.95,.30),'navy')
    box('Cab lower body',(front-.85,0,1.16),(1.65,2.04,.66),'teal',.08)
    box('Cab upper body',(front-1.02,0,1.94),(1.35,1.96,1.0),'cream',.09)
    box('Windshield',(front-.32,0,2.03),(.035,1.62,.58),'glass',.025)
    for y in [-1.0,1.0]:
        box('Cab side window',(front-.96,y,2.03),(.85,.03,.57),'glass',.025)
        box('Door handle',(front-1.04,y*1.025,1.54),(.24,.025,.055),'steel',.005)
        box('Side step',(front-1.05,y*1.15,.86),(1.25,.32,.14),'steel')
        beam('Mirror arm',(front-.37,y*1.04,1.94),(front-.37,y*1.30,1.94),.045,'steel')
        box('Mirror',(front-.37,y*1.31,2.02),(.17,.10,.30),'navy',.025)
    box('Front bumper',(front+.01,0,.86),(.14,2.22,.19),'steel')
    box('Front grille',(front+.005,0,1.17),(.04,.92,.26),'navy')
    for y in [-.77,.77]:
        box('Headlamp',(front+.028,y,1.22),(.045,.32,.18),'cream',.03)
    tank_length = length-2.25
    tank_x = back+tank_length/2+.06
    cylinder('Tank body',(tank_x,0,1.71),.92,tank_length,'cream','X',48)
    for x in [tank_x-tank_length*.32,tank_x+tank_length*.32]:
        cylinder('Tank retention band',(x,0,1.71),.94,.13,'steel','X',48)
    cylinder('Rear tank dome',(back+.03,0,1.71),.81,.14,'steel','X',48)
    for x in [tank_x-.60,tank_x+.60]:
        cylinder('Top fill hatch',(x,0,2.65),.23,.12,'copper')
    for y in [-.65,.65]:
        beam('Tank top rail',(back+.30,y,2.76),(front-2.36,y,2.76),.035,'steel')
    axles = [front-.89,back+1.10,back+2.04] if heavy else [front-.89,back+1.05]
    for x in axles:
        cylinder('Axle',(x,0,.56),.10,2.20,'steel','Y')
        for y in [-1.03,1.03]:
            cylinder('Tyre',(x,y,.56),.54,.35,'rubber','Y',32)
            cylinder('Wheel hub',(x,y*1.19,.56),.30,.05,'steel','Y',24)
            cylinder('Hub cap',(x,y*1.22,.56),.12,.055,'navy','Y')
    box('Rear bumper',(back-.12,0,.76),(.14,2.08,.16),'steel')
    for y in [-.85,.85]:
        box('Rear lamp',(back-.20,y,.98),(.06,.19,.15),'copper')
    beam('Delivery pipe',(back-.13,-.26,.90),(back-.13,.61,.90),.12,'teal')
    for z in [1.02,1.34,1.66,1.98,2.30]:
        beam('Rear ladder rung',(back-.23,-.34,z),(back-.23,.34,z),.055,'steel')
    for y in [-.38,.38]:
        beam('Rear ladder rail',(back-.24,y,.90),(back-.24,y,2.50),.055,'steel')


def build(kind):
    if kind == 'pumpjack':
        pumpjack()
    elif kind == 'heavy_pumpjack':
        pumpjack(True)
    elif kind == 'drilling_rig':
        drilling_rig()
    elif kind == 'gas_skid':
        gas_skid()
    elif kind == 'field_tanker':
        tanker()
    elif kind == 'heavy_tanker':
        tanker(True)
    else:
        raise ValueError(kind)
