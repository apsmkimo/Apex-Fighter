# 產生第 4 關（SATELLITE GRAVEYARD 報廢衛星墳場）的敵人、彈幕、Boss 與 StageData
ROOT='/workspace/work/raiden-godot/'
S='res://assets/sprites/'

def res(path, cls, script, props, ext=None, subs=''):
    ext=ext or []
    lines=[f'[gd_resource type="Resource" script_class="{cls}" load_steps={len(ext)+2+subs.count("[sub_resource")} format=3]\n']
    lines.append(f'[ext_resource type="Script" path="{script}" id="scr"]')
    for t,p,i in ext: lines.append(f'[ext_resource type="{t}" path="{p}" id="{i}"]')
    out='\n'.join(lines)+'\n\n'+subs+'[resource]\nscript = ExtResource("scr")\n'
    for k,v in props: out+=f'{k} = {v}\n'
    open(ROOT+path,'w').write(out)

E=lambda i:f'ExtResource("{i}")'
ED='res://src/entities/enemies/enemy_data.gd'
AP='res://src/patterns/bullet/aimed_pattern.gd'; RP='res://src/patterns/bullet/ring_pattern.gd'
MS='res://src/patterns/movement/move_straight.gd'; MH='res://src/patterns/movement/move_hover.gd'
def pat(name,cls,script,tex,speed,radius,burst=1,biv=0.12,extra=()):
    res(f'data/patterns/{name}.tres',cls,script,[*extra,('bullet_texture',E('tex')),('bullet_speed',speed),('bullet_radius',radius),('damage',1),('burst_count',burst),('burst_interval',biv)],
        [('Texture2D',S+f'bullets/{tex}.png','tex')])
# ---------- 彈幕 ----------
pat('p4_needle','AimedPattern',AP,'enemy_needle',360.0,6.0,2,0.14,[('count',1),('spread_deg',0.0)])
pat('p4_lance3','AimedPattern',AP,'enemy_lance',430.0,7.0,1,0.12,[('count',3),('spread_deg',24.0)])
pat('p4_rocket_fan','AimedPattern',AP,'enemy_rocket',220.0,13.0,2,0.45,[('count',3),('spread_deg',36.0)])
# 報廢衛星亂射雷射：兩道反向、每次隨機角度
pat('p4_sat_laser','RingPattern',RP,'enemy_laser_red',300.0,6.0,3,0.09,[('count',2),('random_rotation','true')])
pat('p4_sat_laser3','RingPattern',RP,'enemy_laser_red',280.0,6.0,2,0.12,[('count',3),('random_rotation','true')])
pat('p4_red_ring','RingPattern',RP,'enemy_laser_red',230.0,6.0,1,0.12,[('count',16),('rotation_per_shot_deg',11.0)])
pat('p4_red_aim','AimedPattern',AP,'enemy_laser_red',480.0,6.0,3,0.1,[('count',5),('spread_deg',40.0)])
# ---------- 移動 ----------
res('data/patterns/move_sat_drift.tres','MoveStraight',MS,[('velocity','Vector2(22, 105)')])
res('data/patterns/move_sat_drift_slow.tres','MoveStraight',MS,[('velocity','Vector2(-12, 80)')])
res('data/patterns/move_sat_fall.tres','MoveStraight',MS,[('velocity','Vector2(70, 430)')])
res('data/patterns/move_sat_fall_fast.tres','MoveStraight',MS,[('velocity','Vector2(-40, 520)')])
res('data/patterns/move_titan_hover.tres','MoveHover',MH,[('stop_distance',530.0),('enter_time',3.0),('amplitude',85.0),('period',8.0),('y_amplitude',30.0),('y_speed',0.7)])
res('data/patterns/move_reaper_hover.tres','MoveHover',MH,[('stop_distance',420.0),('enter_time',3.0),('amplitude',160.0),('period',6.0),('y_amplitude',60.0),('y_speed',0.9)])

ITEMS=[('Script','res://src/entities/items/item_data.gd','itm'),('Resource','res://data/items/missile.tres','i_mis'),('Resource','res://data/items/shield.tres','i_sh'),
       ('Resource','res://data/items/special.tres','i_sp'),('Resource','res://data/items/power.tres','i_pw'),('Resource','res://data/items/weapon_laser.tres','i_wl')]
POOL='Array[ExtResource("itm")]([ExtResource("i_mis"), ExtResource("i_sh"), ExtResource("i_sp"), ExtResource("i_wl")])'
def enemy(name,tex,props,ext=(),items=False):
    ext=[('Texture2D',S+tex,'tex'),*ext]+(ITEMS if items else [])
    p=[('id',f'&"{name}"'),('texture',E('tex')),*props]
    if items: p+=[('drop_item',E('i_pw')),('bonus_pool',POOL)]
    res(f'data/enemies/{name}.tres','EnemyData',ED,p,ext)
PT=lambda n:('Resource',f'res://data/patterns/{n}.tres','pat')
MV=lambda n:('Resource',f'res://data/patterns/{n}.tres','mv')
# ---------- 敵機 ----------
# 小兵：X 型無人機（旋翼慢慢轉）
enemy('junk_drone','enemies/junk_drone.png',[('max_hp',3),('hit_radius',28.0),('score',120),('explosion_scale',0.8),('movement',E('mv')),('spin',1.2),
    ('bullet_pattern',E('pat')),('fire_interval',1.9),('first_fire_delay',0.6)],[MV('move_sine'),PT('p4_needle')])
# 中兵：箭形戰機，尖頭朝下
enemy('junk_arrow','enemies/junk_arrow.png',[('max_hp',6),('hit_radius',34.0),('score',200),('explosion_scale',1.0),('movement',E('mv')),
    ('bullet_pattern',E('pat')),('fire_interval',2.0),('first_fire_delay',0.7),
    ('thruster_offsets','PackedVector2Array(-14, -46, 14, -46)'),('thruster_color','Color(0.4, 1, 0.45, 1)'),('thruster_width',9.0),('thruster_length',20.0)],
    [MV('move_diagonal'),PT('p4_lance3')])
# 大兵：履帶重裝，發射火箭＋投放追蹤飛彈
enemy('junk_hauler','enemies/junk_hauler.png',[('max_hp',30),('hit_radius',72.0),('score',800),('explosion_scale',1.8),('movement',E('mv')),
    ('bullet_pattern',E('pat')),('fire_interval',2.3),('first_fire_delay',1.0),('drop_hazard',E('dh')),('drop_hazard_interval',3.8),('drop_hazard_first',1.8),
    ('bullet_damage',2),('contact_damage',3),('drop_chance',0.25),('bonus_chance',0.35)],
    [MV('move_stop_and_go'),PT('p4_rocket_fan'),('Resource','res://data/enemies/bio_missile.tres','dh')],True)
# 報廢衛星：大的慢慢漂、輕微自轉，0、2 號會亂射雷射
for i in range(4):
    laser=i in (0,2)
    pr=[('max_hp',9),('hit_radius',44.0),('score',250),('explosion_scale',1.2),('movement',E('mv')),('spin',0.35 if i%2==0 else -0.28),
        ('bullet_damage',2),('contact_damage',2),('drop_chance',0.06)]
    ext=[MV('move_sat_drift' if i%2==0 else 'move_sat_drift_slow'),('Resource','res://data/items/power.tres','pw')]
    if laser:
        pr+=[('bullet_pattern',E('pat')),('fire_interval',1.7 if i==0 else 2.1),('first_fire_delay',0.8+0.4*i)]
        ext.append(PT('p4_sat_laser' if i==0 else 'p4_sat_laser3'))
    enemy(f'satellite_big_{i}',f'hazards/satellite_big_{i}.png',pr,ext)
    p=ROOT+f'data/enemies/satellite_big_{i}.tres'; s=open(p).read().replace('drop_chance = 0.06','drop_item = ExtResource("pw")\ndrop_chance = 0.06'); open(p,'w').write(s)
# 小衛星：漂浮用＋衛星雨（快速落下）
for i in range(4):
    enemy(f'satellite_small_{i}',f'hazards/satellite_small_{i}.png',[('max_hp',3),('hit_radius',26.0),('score',80),('explosion_scale',0.8),('movement',E('mv')),
        ('spin',0.6 if i%2 else -0.5),('bullet_damage',0),('contact_damage',2)],[MV('move_sat_drift')])
    enemy(f'satellite_rain_{i}',f'hazards/satellite_{"small" if i<3 else "big"}_{i}.png',[('max_hp',5),('hit_radius',24.0 if i<3 else 40.0),('score',40),('explosion_scale',0.8),('movement',E('mv')),
        ('spin',3.0 if i%2 else -2.4),('bullet_damage',0),('contact_damage',2)],[MV('move_sat_fall' if i%2 else 'move_sat_fall_fast')])

# ---------- Boss ----------
BD='res://src/entities/bosses/boss_data.gd'; PH='res://src/entities/bosses/boss_phase.gd'; BP='res://src/patterns/bullet/bullet_pattern.gd'
def boss(name,tex,title,bgm,mv,phases,props,ext2=()):
    pats=sorted({p for ph in phases for p in ph[1]})
    ext=[('Texture2D',S+f'enemies/{tex}.png','tex'),('Script',PH,'ph'),('Script',BP,'bp'),('Resource',f'res://data/patterns/{mv}.tres','mv'),
         ('AudioStream',f'res://assets/audio/bgm/{bgm}.wav','bgm'),*ext2]
    ext+=[('Resource',f'res://data/patterns/{p}.tres',f'p_{p}') for p in pats]
    subs=''
    for i,(end,ps,iv) in enumerate(phases):
        subs+=f'[sub_resource type="Resource" id="ph{i}"]\nscript = ExtResource("ph")\nhp_ratio_end = {end}\npatterns = Array[ExtResource("bp")]([{", ".join(E("p_"+p) for p in ps)}])\nintervals = PackedFloat32Array({", ".join(map(str,iv))})\n\n'
    res(f'data/enemies/{name}.tres','BossData',BD,[('boss_name',f'"{title}"'),('bgm',E('bgm')),('entry_time',3.0),
        ('phases','Array[ExtResource("ph")]([%s])'%', '.join(f'SubResource("ph{i}")' for i in range(len(phases)))),
        ('id',f'&"{name}"'),('texture',E('tex')),('movement',E('mv')),*props],ext,subs)
GREEN='Color(0.35, 1, 0.45, 1)'
# 中 Boss：JUNK REAPER，只有中間綠色核心受傷；絕招＝高速旋轉碾壓
boss('boss_junk_reaper','boss_junk_reaper','JUNK REAPER','mid_boss','move_reaper_hover',
    [(0.6,['p4_lance3','p4_sat_laser3'],[1.2,1.0]),(0.25,['spiral_6','p4_needle'],[0.22,1.0]),(0.0,['p4_red_ring','p4_lance3','p4_sat_laser'],[0.8,1.1,0.9])],
    [('ult_kinds','Array[StringName]([&"ram"])'),('ult_first_delay',6.0),('ult_interval',9.0),('ult_damage',3),('ult_color',GREEN),('ult_origin','Vector2(0, 0)'),
     ('ult_ram_time',5.0),('ult_ram_speed',540.0),('ult_ram_spin',13.0),('ult_ram_radius',125.0),('ult_ram_charge',1.6),
     ('max_hp',800),('hit_radius',150.0),('weak_offset','Vector2(-2, 2)'),('weak_radius',40.0),('score',30000),('explosion_scale',3.8),
     ('bullet_damage',2),('contact_damage',3)])
# 最終 Boss：SCRAP TITAN，大型；絕招＝前方紅色砲台雷射、報廢衛星雨
RAIN=[('Script',ED,'eds')]+[('Resource',f'res://data/enemies/satellite_rain_{i}.tres',f'r{i}') for i in range(4)]
boss('boss_scrap_titan','boss_scrap_titan','SCRAP TITAN','boss','move_titan_hover',
    [(0.65,['p4_red_aim','p4_sat_laser3'],[1.4,0.9]),(0.3,['spiral_6','p4_rocket_fan','p4_lance3'],[0.2,2.2,1.2]),(0.0,['p4_red_ring','p4_red_aim','p4_sat_laser','p4_rocket_fan'],[0.7,1.1,0.8,2.4])],
    [('ult_kinds','Array[StringName]([&"beam", &"debris"])'),('ult_first_delay',6.0),('ult_interval',9.0),('ult_damage',4),('ult_color','Color(1, 0.2, 0.2, 1)'),
     ('ult_origin','Vector2(0, 280)'),('ult_width',190.0),('ult_charge_time',2.4),('ult_fire_time',1.8),
     ('ult_debris','Array[ExtResource("eds")]([%s])'%', '.join(E(f'r{i}') for i in range(4))),('ult_debris_count',24),('ult_debris_time',3.6),('ult_debris_charge',1.8),
     ('weak_color',GREEN),('max_hp',1200),('hit_radius',260.0),('weak_offset','Vector2(-2, -41)'),('weak_radius',46.0),('score',50000),('explosion_scale',5.5),
     ('bullet_damage',3),('contact_damage',3)],RAIN)

# ---------- 關卡 ----------
K={'drone':'junk_drone','arrow':'junk_arrow','haul':'junk_hauler','pow':'dart_power',
   **{f'sb{i}':f'satellite_big_{i}' for i in range(4)},**{f'ss{i}':f'satellite_small_{i}' for i in range(4)}}
W=[]
def w(t,k,x=0.5,n=1,iv=0.0,st=0.0,mir=False,lst=None): (lst if lst is not None else W).append((t,k,n,iv,x,st,mir))
# 主段（約 60 秒）：小兵、中兵波次，大兵壓陣，報廢衛星一路漂過
for t,x in [(1.5,0.1),(9,0.6),(17,0.1),(25,0.6),(33,0.1),(42,0.6),(50,0.1),(57,0.6)]: w(t,'drone',x,5,0.3,0.07,True)
for t,x in [(5,0.3),(13,0.7),(21,0.3),(30,0.7),(38,0.3),(46,0.7),(54,0.3)]: w(t,'arrow',x,3,0.4,0.12)
for t,x in [(19,0.3),(35,0.7),(44,0.3),(52,0.7)]: w(t,'haul',x)
SAT=[(2.5,0.2,'sb0'),(4,0.75,'ss1'),(7,0.55,'sb1'),(10,0.15,'ss0'),(12,0.8,'sb2'),(15,0.4,'ss2'),(18,0.85,'sb3'),(22,0.2,'sb0'),(24,0.6,'ss3'),
     (27,0.35,'sb2'),(29,0.8,'ss1'),(32,0.55,'sb1'),(36,0.15,'sb0'),(39,0.7,'ss0'),(41,0.45,'sb2'),(45,0.85,'ss2'),(48,0.2,'sb3'),(51,0.5,'sb0'),(55,0.8,'sb2'),(58,0.3,'ss3')]
for t,x,k in SAT: w(t,k,x)
w(11,'pow'); w(28,'pow'); w(47,'pow')
# 中 Boss 之後的增援（約 30 秒）
A=[]
for t,x in [(1.5,0.1),(10,0.6),(19,0.1),(27,0.6)]: w(t,'drone',x,5,0.3,0.07,True,lst=A)
for t,x in [(4,0.3),(13,0.7),(22,0.3)]: w(t,'arrow',x,3,0.4,0.12,lst=A)
for t,x in [(8,0.7),(17,0.3),(25,0.5)]: w(t,'haul',x,lst=A)
for t,x,k in [(2,0.5,'sb2'),(6,0.2,'sb0'),(9,0.85,'ss1'),(12,0.4,'sb1'),(15,0.75,'sb2'),(20,0.25,'ss0'),(23,0.65,'sb0'),(28,0.35,'sb3')]: w(t,k,x,lst=A)
w(14,'pow',lst=A)
W.sort(key=lambda v:v[0]); A.sort(key=lambda v:v[0])
used=sorted({v[1] for v in W+A})
ext=[('Script','res://src/stages/wave_data.gd','w_wave')]+[('Resource',f'res://data/enemies/{K[k]}.tres',f'e_{k}') for k in used]
ext+=[('Resource','res://data/enemies/boss_junk_reaper.tres','b_mid'),('Resource','res://data/enemies/boss_scrap_titan.tres','b_final'),('Texture2D',S+'terrain/scrapyard.jpg','t_ter')]
ext+=[('Texture2D',S+f'hazards/satellite_small_{i}.png',f'd{i}') for i in range(4)]
subs=''
def mk(p,ws):
    global subs; ids=[]
    for i,(t,k,n,iv,x,st,mir) in enumerate(ws):
        ids.append(f'{p}{i}')
        subs+=f'[sub_resource type="Resource" id="{p}{i}"]\nscript = ExtResource("w_wave")\ntime = {t}\nenemy = ExtResource("e_{k}")\ncount = {n}\ninterval = {iv}\nstart_x = {x}\nstep_x = {st}\nmirror = {"true" if mir else "false"}\n\n'
    return ', '.join(f'SubResource("{i}")' for i in ids)
wl=mk('W',W); al=mk('A',A)
decor='Array[Texture2D]([%s])'%', '.join(E(f'd{i}') for i in range(4))
res('data/stages/stage_04.tres','StageData','res://src/stages/stage_data.gd',[('id','&"stage_04"'),('display_name','"STAGE 4"'),('sort_order',3),('scroll_speed',150.0),
    ('bg_top_color','Color(0.12, 0.1, 0.06, 1)'),('bg_bottom_color','Color(0.2, 0.16, 0.1, 1)'),('terrain',E('t_ter')),('terrain_tint','Color(0.46, 0.45, 0.43, 1)'),
    ('float_decor',decor),('hp_mult',1.15),('waves',f'Array[ExtResource("w_wave")]([{wl}])'),('mid_boss',E('b_mid')),
    ('waves_after_mid',f'Array[ExtResource("w_wave")]([{al}])'),('after_mid_hp_mult',1.0),('boss',E('b_final')),('boss_warning_time',2.5)],ext,subs)
print('stage 4:',len(W),'main waves,',len(A),'after-mid waves')
