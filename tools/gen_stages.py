# 產生第 3–9 關的 StageData（data/stages/stage_0N.tres）
E={'dart':'dart','shade':'shade','beetle':'beetle','raptor':'raptor','rhino':'rhino','pow':'dart_power',
   'jugg':'juggernaut','spider':'spider','carrier':'bomb_carrier','gun':'gun_turret','twin':'twin_turret','silo':'missile_silo'}
SMALLV=[(5,0.35,0.2,0,'sine',True),(6,0.3,0.1,0.16,None,False),(6,0.3,0.15,0,'diag',True),(8,0.25,0.1,0.11,None,False)]
GATES=[[('gun',0.25),('gun',0.75)],[('twin',0.3),('twin',0.7),('gun',0.5)],[('silo',0.5),('twin',0.18),('twin',0.82)]]
STAGES={
 3:dict(name='STAGE 3',small=['beetle'],med=['rhino'],big=['spider'],mid='boss_scythe_mantis',fin='boss_ember_citadel',hp=1.0,terrain='moss',tint=(0.85,0.9,0.85),top=(0.02,0.08,0.06),bot=(0.05,0.17,0.12),speed=190),

 # 第 5 關改由 repo tools/gen_stage5.py 產生
# 6:dict(name='STAGE 6',small=['dart','beetle'],med=['raptor','rhino'],big=['jugg'],mid='boss_scythe_mantis',fin='boss_crimson_widow',hp=1.35,terrain='ice',tint=(0.78,0.82,0.9),top=(0.02,0.06,0.12),bot=(0.05,0.12,0.22),speed=190),
 7:dict(name='STAGE 7',small=['shade'],med=['rhino'],big=['spider','jugg'],mid='boss_violet_fortress',fin='boss_ember_citadel',hp=1.45,top=(0.12,0.02,0.03),bot=(0.22,0.05,0.06),speed=195),
 8:dict(name='STAGE 8',small=['dart','beetle'],med=['raptor','rhino'],big=['carrier','spider'],mid='boss_abyss_crab',fin='boss_inferno_seraph',hp=1.55,top=(0.02,0.05,0.14),bot=(0.04,0.1,0.26),speed=200),
 9:dict(name='STAGE 9',small=['beetle','shade','dart'],med=['rhino','raptor'],big=['spider','jugg','carrier'],mid='boss_scythe_mantis',fin='boss_ember_citadel',hp=1.7,terrain='lava',tint=(0.85,0.8,0.78),top=(0.1,0.03,0.02),bot=(0.2,0.06,0.03),speed=195),
}
MAIN=['S',2,'S',5,'S',8,'P',11,'S',12,'M',16,'M',18,'S',21,'M2',24,'B',29,'S',33,'M',36,'B',40,'B',42,'S',46,'P',49,'M2',51,'S',55]
AFTER=['S',1.5,'S',4,'M2',7,'S',11,'B',14,'M',18,'P',20,'B',23,'B',25,'S',29]
def build(n,c):
    planet='terrain' in c
    waves=[];after=[]
    cnt={'S':0,'M':0,'B':0}
    def add(lst,kind,t):
        if kind=='P': lst.append((t,'pow',1,0,0.5,0,None,False,False)); return
        if kind=='S':
            k=c['small'][cnt['S']%len(c['small'])]; v=SMALLV[cnt['S']%4]; cnt['S']+=1
            lst.append((t,k)+v+(False,)); return
        if kind in('M','M2'):
            k=c['med'][cnt['M']%len(c['med'])]; cnt['M']+=1
            if kind=='M2': lst.append((t,k,2,0.8,0.25,0.5,None,False,False))
            else: lst.append((t,k,1,0,0.3 if cnt['M']%2 else 0.7,0,None,cnt['M']%3==0,False))
            return
        k=c['big'][cnt['B']%len(c['big'])]; cnt['B']+=1
        lst.append((t,k,1,0,0.3 if cnt['B']%2 else 0.7,0,None,False,False))
    for i in range(0,len(MAIN),2): add(waves,MAIN[i],MAIN[i+1])
    for i in range(0,len(AFTER),2): add(after,AFTER[i],AFTER[i+1])
    if planet:
        # 經過的地面砲台＋砲台封鎖
        for t,x in [(6.5,0.15),(6.5,0.85),(38,0.5)]: waves.append((t,'gun',1,0,x,0,None,False,False))
        for gi,t in enumerate([14,27,44]):
            for k,x in GATES[gi]: waves.append((t,k,1,0,x,0,None,False,True))
        for k,x in GATES[2 if n==9 else 1]: after.append((16,k,1,0,x,0,None,False,True))
        if n==9:
            for k,x in GATES[2]: waves.append((52,k,1,0,x,0,None,False,True))
    waves.sort(key=lambda w:w[0]); after.sort(key=lambda w:w[0])
    used=sorted({w[1] for w in waves+after})
    ext=[('Script','res://src/stages/stage_data.gd','s_stage'),('Script','res://src/stages/wave_data.gd','w_wave')]
    ext+=[('Resource',f'res://data/enemies/{E[k]}.tres',f'e_{k}') for k in used]
    ext+=[('Resource','res://data/patterns/move_sine.tres','m_sine'),('Resource','res://data/patterns/move_diagonal.tres','m_diag'),
          ('Resource',f'res://data/enemies/{c["mid"]}.tres','b_mid'),('Resource',f'res://data/enemies/{c["fin"]}.tres','b_final')]
    if planet: ext.append(('Texture2D',f'res://assets/sprites/terrain/{c["terrain"]}.jpg','t_ter'))
    subs='';
    def mk(p,ws):
        nonlocal subs; ids=[]
        for i,(t,k,cn,iv,x,st,mv,mir,hold) in enumerate(ws):
            sid=f'{p}{i}'; ids.append(sid)
            subs+=f'[sub_resource type="Resource" id="{sid}"]\nscript = ExtResource("w_wave")\ntime = {t}\nenemy = ExtResource("e_{k}")\ncount = {cn}\ninterval = {iv}\nstart_x = {x}\nstep_x = {st}\n'+(f'movement_override = ExtResource("m_{mv}")\n' if mv else '')+f'mirror = {"true" if mir else "false"}\n'+('hold = true\n' if hold else '')+'\n'
        return ', '.join(f'SubResource("{i}")' for i in ids)
    w=mk('W',waves); a=mk('A',after)
    col=lambda v:f'Color({v[0]}, {v[1]}, {v[2]}, 1)'
    out=f'[gd_resource type="Resource" script_class="StageData" load_steps={len(ext)+len(waves)+len(after)+1} format=3]\n\n'
    out+=''.join(f'[ext_resource type="{t}" path="{p}" id="{i}"]\n' for t,p,i in ext)+'\n'+subs
    out+=f'''[resource]
script = ExtResource("s_stage")
id = &"stage_0{n}"
display_name = "{c['name']}"
sort_order = {n-1}
scroll_speed = {c['speed']}.0
bg_top_color = {col(c['top'])}
bg_bottom_color = {col(c['bot'])}
'''+(f'terrain = ExtResource("t_ter")\nterrain_tint = {col(c["tint"])}\n' if planet else '')+f'''hp_mult = {c['hp']}
waves = Array[ExtResource("w_wave")]([{w}])
mid_boss = ExtResource("b_mid")
waves_after_mid = Array[ExtResource("w_wave")]([{a}])
after_mid_hp_mult = 1.0
boss = ExtResource("b_final")
boss_warning_time = 2.5
'''
    open(f'/workspace/work/raiden-godot/data/stages/stage_0{n}.tres','w').write(out)
    print(n,len(waves),len(after))
for n,c in STAGES.items(): build(n,c)
