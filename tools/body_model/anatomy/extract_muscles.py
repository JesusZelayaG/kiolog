import bpy,sys
out=sys.argv[sys.argv.index('--')+1]
col=bpy.data.collections['4: Muscular system']
objs=[o for o in col.all_objects if o.type=='MESH' and o.name.rsplit('.',1)[-1] not in('g','j')]
print('TOP',[(o.name,len(o.data.vertices)) for o in sorted(objs,key=lambda o:-len(o.data.vertices))[:30]])
def isf(n):
    n=n.lower(); return any(w in n for w in('fascia','aponeuros','linea alba','tendon','retinacul','sheath','ligament','septum','galea','membrane'))
print('FASC',[o.name for o in objs if isf(o.name)][:60])
def isw(n):
    n=n.lower(); return any(w in n for w in('linea alba','iliotibial','epicranial aponeurosis','thoracolumbar','calcaneal tendon'))
dg=bpy.context.evaluated_depsgraph_get()
res={}
for key,sel in (('muscle',[o for o in objs if not isf(o.name) and not isw(o.name)]),('fascia',[o for o in objs if isf(o.name)]),('white',[o for o in objs if isw(o.name)])):
    V=[];F=[];n=0
    for o in sel:
        e=o.evaluated_get(dg); m=e.to_mesh(); w=o.matrix_world
        V+=[tuple(w@v.co) for v in m.vertices]; F+=[tuple(i+n for i in p.vertices) for p in m.polygons]; n=len(V); e.to_mesh_clear()
    me=bpy.data.meshes.new(key); me.from_pydata(V,[],F); me.update(); res[key]=me; print('RES',key,len(sel),len(V))
sc=bpy.data.scenes.new('out')
for k,me in res.items():
    sc.collection.objects.link(bpy.data.objects.new(k,me))
for s in list(bpy.data.scenes):
    if s is not sc: bpy.data.scenes.remove(s)
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=out,compress=True)
