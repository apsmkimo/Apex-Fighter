# 產生第 10 關（ASTEROID BELT）的敵人、彈幕、Boss 與 StageData
import os
ROOT='/workspace/work/raiden-godot/'
S='res://assets/sprites/'

def res(path, cls, script, props, ext=None, subs=''):
    """props: list of (key, value 字串)。值裡用 E:id 參照 ext。"""
    ext=ext or []
    lines=[f'[gd_resource type="Resource" script_class="{cls}" load_steps={len(ext)+2+subs.count("[sub_resource")} format=3]\n']
    lines.append(f'[ext_resource type="Script" path="{script}" id="scr"]')
    for t,p,i in ext: lines.append(f'[ext_resource type="{t}" path="{p}" id="{i}"]')
    out='\n'.join(lines)+'\n\n'+subs+'[resource]\nscript = ExtResource("scr")\n'
    for k,v in props: out+=f'{k} = {v}\n'
    open(ROOT+path,'w').write(out)

E=lambda i:f'ExtResource("{i}")'
ED='res://src/entities/enemies/enemy_data.gd'
# ---------- 彈幕 ----------
AP='res://src/patterns/bullet/aimed_pattern.gd'; RP='res://src/patterns/bullet/ring_pattern.gd'; SP='res://src/patterns/bullet/split_pattern.gd'
def pat(name,cls,script,tex,speed,radius,burst=1,biv=0.12,extra=(),ext2=()):
    res(f'data/patterns/{name}.tres',cls,script,[*extra,('bullet_texture',E('tex')),('bullet_speed',speed),('bullet_radius',radius),('damage',1),('burst_count',burst),('burst_interval',biv)],
        [('Texture2D',S+f'bullets/{tex}.png','tex'),*ext2])
pat('p10_needle','AimedPattern',AP,'enemy_needle',400.0,6.0,3,0.1,[('count',3),('spread_deg',26.0)])
pat('p10_needle_single','AimedPattern',AP,'enemy_needle',380.0,6.0,2,0.15,[('count',1),('spread_deg',0.0)])
pat('p10_lance','AimedPattern',AP,'enemy_lance',520.0,7.0,2,0.18,[('count',3),('spread_deg',20.0)])
pat('p10_rocket','AimedPattern',AP,'enemy_rocket',230.0,13.0,1,0.12,[('count',1),('spread_deg',0.0)])
pat('p10_rocket_fan','AimedPattern',AP,'enemy_rocket',210.0,13.0,2,0.4,[('count',3),('spread_deg',40.0)])
pat('p10_split','SplitPattern',SP,'enemy_split_missile',260.0,10.0,1,0.12,
    [('count',1),('spread_deg',0.0),('split_time',0.8),('split_count',6),('split_spread',80.0),('split_texture',E('ntex'))],
    [('Texture2D',S+'bullets/enemy_needle.png','ntex')])
pat('p10_ring_lance','RingPattern',RP,'enemy_lance',220.0,7.0,1,0.12,[('count',14),('rotation_per_shot_deg',12.0)])
# ---------- 移動 ----------
MS='res://src/patterns/movement/move_straight.gd'
res('data/patterns/move_asteroid_drift.tres','MoveStraight',MS,[('velocity','Vector2(25, 150)')])
res('data/patterns/move_asteroid_shard.tres','MoveStraight',MS,[('velocity','Vector2(120, 230)')])

ITEMS=[('Script','res://src/entities/items/item_data.gd','itm'),('Resource','res://data/items/missile.tres','i_mis'),('Resource','res://data/items/shield.tres','i_sh'),
       ('Resource','res://data/items/special.tres','i_sp'),('Resource','res://data/items/power.tres','i_pw'),('Resource','res://data/items/weapon_laser.tres','i_wl'),('Resource','res://data/items/bomb.tres','i_bm')]
POOL='Array[ExtResource("itm")]([ExtResource("i_mis"), ExtResource("i_sh"), ExtResource("i_sp"), ExtResource("i_wl")])'
def enemy(name,tex,props,ext=(),items=False):
    ext=[('Texture2D',S+tex,'tex'),*ext]+(ITEMS if items else [])
    p=[('id',f'&"{name}"'),('texture',E('tex')),*props]
    if items: p+= [('drop_item',E('i_pw')),('bonus_pool',POOL)]
    res(f'data/enemies/{name}.tres','EnemyData',ED,p,ext)
PT=lambda n:('Resource',f'res://data/patterns/{n}.tres','pat')
MV=lambda n:('Resource',f'res://data/patterns/{n}.tres','mv')
# 危險物
enemy('spike_mine','hazards/spike_mine.png',[('max_hp',5),('hit_radius',30.0),('score',100),('explosion_scale',1.3),('weak_radius',16.0),('hazard_kind','&"mine"'),
    ('blast_radius',100.0),('blast_damage',3),('blast_enemy_damage',20),('trigger_radius',76.0),('blast_ring',10),('bullet_damage',2),('contact_damage',0)])
enemy('bio_missile','hazards/bio_missile.png',[('max_hp',3),('hit_radius',20.0),('score',60),('explosion_scale',1.0),('weak_offset','Vector2(10, 0)'),('weak_radius',14.0),
    ('hazard_kind','&"missile"'),('blast_radius',72.0),('blast_damage',3),('blast_enemy_damage',10),('home_speed',230.0),('home_turn',2.0),('home_life',6.0),('bullet_damage',0),('contact_damage',0)])
enemy('boss_spike_missile','hazards/boss_spike_missile.png',[('max_hp',4),('hit_radius',24.0),('score',80),('explosion_scale',1.2),('weak_offset','Vector2(12, 0)'),('weak_radius',16.0),
    ('hazard_kind','&"missile"'),('blast_radius',80.0),('blast_damage',4),('blast_enemy_damage',10),('home_speed',260.0),('home_turn',1.7),('home_life',6.5),('bullet_damage',0),('contact_damage',0)])
# 隕石（小的先寫，大的碎成小的）
for i in (0,1):
    enemy(f'asteroid_small_{i}',f'hazards/asteroid_small_{i*2}.png',[('max_hp',3),('hit_radius',24.0),('score',60),('explosion_scale',0.8),
        ('movement',E('mv')),('spin',2.2),('bullet_damage',0),('contact_damage',2)],[MV('move_asteroid_shard')])
    enemy(f'asteroid_big_{i}',f'hazards/asteroid_big_{i*2}.png',[('max_hp',16),('hit_radius',56.0),('score',200),('explosion_scale',1.4),
        ('movement',E('mv')),('spin',0.7),('bullet_damage',0),('contact_damage',3),('death_spawn',E('sm')),('death_spawn_count',3),('drop_chance',0.08)],
        [MV('move_asteroid_drift'),('Resource',f'res://data/enemies/asteroid_small_{i}.tres','sm'),('Resource','res://data/items/power.tres','pw')])
    # 補上掉寶參照
    p=ROOT+f'data/enemies/asteroid_big_{i}.tres'; s=open(p).read().replace('drop_chance = 0.08','drop_item = ExtResource("pw")\ndrop_chance = 0.08'); open(p,'w').write(s)
# 飛行敵機
enemy('rock_dart','enemies/rock_dart.png',[('max_hp',3),('hit_radius',18.0),('score',120),('explosion_scale',0.8),('movement',E('mv')),('bullet_pattern',E('pat')),
    ('fire_interval',1.8),('first_fire_delay',0.6),('thruster_offsets','PackedVector2Array(0, -36)'),('thruster_color','Color(0.4, 1, 0.4, 1)'),('thruster_width',8.0),('thruster_length',18.0)],
    [MV('move_sine'),PT('p10_needle_single')])
enemy('rock_arrow','enemies/rock_arrow.png',[('max_hp',4),('hit_radius',22.0),('score',140),('explosion_scale',0.9),('movement',E('mv')),('bullet_pattern',E('pat')),
    ('fire_interval',2.0),('first_fire_delay',0.7),('thruster_offsets','PackedVector2Array(-8, -36, 8, -36)'),('thruster_color','Color(0.4, 1, 0.4, 1)'),('thruster_width',7.0),('thruster_length',16.0)],
    [MV('move_diagonal'),PT('p10_lance')])
enemy('rock_bulk','enemies/rock_bulk.png',[('max_hp',22),('hit_radius',44.0),('score',500),('explosion_scale',1.4),('movement',E('mv')),('bullet_pattern',E('pat')),
    ('fire_interval',2.2),('first_fire_delay',1.0),('drop_hazard',E('dh')),('drop_hazard_interval',4.0),('drop_hazard_first',2.0),('drop_chance',0.15),('bonus_chance',0.25)],
    [MV('move_stop_and_go'),PT('p10_rocket'),('Resource','res://data/enemies/spike_mine.tres','dh')],True)
enemy('rock_spider','enemies/rock_spider.png',[('max_hp',24),('hit_radius',44.0),('score',550),('explosion_scale',1.4),('movement',E('mv')),('bullet_pattern',E('pat')),
    ('fire_interval',2.4),('first_fire_delay',1.0),('drop_chance',0.15),('bonus_chance',0.25)],
    [MV('move_slow_sway'),PT('p10_split')],True)
enemy('rock_shield','enemies/rock_shield.png',[('max_hp',60),('hit_radius',72.0),('score',1200),('explosion_scale',2.2),('movement',E('mv')),('bullet_pattern',E('pat')),
    ('fire_interval',1.9),('first_fire_delay',1.2),('drop_hazard',E('dh')),('drop_hazard_interval',4.5),('drop_hazard_first',2.5),('bullet_damage',2),('contact_damage',3),('drop_chance',0.3),('bonus_chance',0.4)],
    [MV('move_slow_sway'),PT('p10_ring_lance'),('Resource','res://data/enemies/bio_missile.tres','dh')],True)
enemy('rock_wing','enemies/rock_wing.png',[('max_hp',70),('hit_radius',80.0),('score',1400),('explosion_scale',2.4),('movement',E('mv')),('bullet_pattern',E('pat')),
    ('fire_interval',2.0),('first_fire_delay',1.0),('bullet_damage',2),('contact_damage',3),('drop_chance',0.3),('bonus_chance',0.4),
    ('thruster_offsets','PackedVector2Array(-22, -92, 0, -96, 22, -92)'),('thruster_color','Color(0.4, 1, 0.4, 1)'),('thruster_width',12.0),('thruster_length',24.0)],
    [MV('move_slow_sway'),PT('p10_rocket_fan')],True)
# 地面砲台（打爆留下坑洞）
CR=[('Texture2D',S+f'decals/crater_{i}.png',f'cr{i}') for i in range(5)]
DEC=('death_decals','Array[Texture2D]([%s])'%', '.join(f'ExtResource("cr{i}")' for i in range(5)))
enemy('quad_cannon','enemies/quad_cannon.png',[('ground','true'),('aim_offset_deg',45.0),('max_hp',22),('hit_radius',50.0),('score',500),('explosion_scale',1.5),
    ('bullet_pattern',E('pat')),('fire_interval',1.7),('first_fire_delay',1.0),('contact_damage',0),DEC,('drop_chance',0.12),('bonus_chance',0.15)],[PT('p10_needle'),*CR],True)
enemy('heavy_cannon','enemies/heavy_cannon.png',[('ground','true'),('aim_offset_deg',45.0),('max_hp',34),('hit_radius',54.0),('score',700),('explosion_scale',1.7),
    ('bullet_pattern',E('pat')),('fire_interval',2.2),('first_fire_delay',1.2),('contact_damage',0),DEC,('drop_chance',0.15),('bonus_chance',0.2)],[PT('p10_split'),*CR],True)
enemy('crater_fortress','enemies/crater_fortress.png',[('ground','true'),('aim_rotate','false'),('ground_spin',0.0),('max_hp',170),('hit_radius',150.0),('score',5000),('explosion_scale',3.0),
    ('weak_offset','Vector2(-2, -17)'),('weak_radius',36.0),('extra_weak_offsets','PackedVector2Array(0, 128)'),
    ('bullet_pattern',E('pat')),('fire_interval',1.5),('first_fire_delay',1.5),('drop_hazard',E('dh')),('drop_hazard_interval',3.5),('drop_hazard_first',2.0),
    ('bullet_damage',2),('contact_damage',0),DEC,('drop_chance',1.0),('bonus_chance',1.0)],[PT('p10_ring_lance'),('Resource','res://data/enemies/bio_missile.tres','dh'),*CR],True)
p=ROOT+'data/enemies/crater_fortress.tres'; s=open(p).read().replace('[resource]','[resource]',1); open(p,'w').write(s)

# ---------- Boss ----------
BD='res://src/entities/bosses/boss_data.gd'; PH='res://src/entities/bosses/boss_phase.gd'; BP='res://src/patterns/bullet/bullet_pattern.gd'
def boss(name,tex,title,bgm,phases,props):
    pats=sorted({p for ph in phases for p in ph[1]})
    ext=[('Texture2D',S+f'enemies/{tex}.png','tex'),('Script',PH,'ph'),('Script',BP,'bp'),('Resource','res://data/patterns/move_boss_hover.tres','mv'),
         ('AudioStream',f'res://assets/audio/bgm/{bgm}.wav','bgm'),('Resource','res://data/enemies/boss_spike_missile.tres','msl'),('Texture2D',S+'bullets/enemy_orb.png','orb')]
    ext+=[('Resource',f'res://data/patterns/{p}.tres',f'p_{p}') for p in pats]
    subs=''
    for i,(end,ps,iv) in enumerate(phases):
        subs+=f'[sub_resource type="Resource" id="ph{i}"]\nscript = ExtResource("ph")\nhp_ratio_end = {end}\npatterns = Array[ExtResource("bp")]([{", ".join(E("p_"+p) for p in ps)}])\nintervals = PackedFloat32Array({", ".join(map(str,iv))})\n\n'
    res(f'data/enemies/{name}.tres','BossData',BD,[('boss_name',f'"{title}"'),('bgm',E('bgm')),('entry_time',3.0),
        ('phases','Array[ExtResource("ph")]([%s])'%', '.join(f'SubResource("ph{i}")' for i in range(len(phases)))),
        ('id',f'&"{name}"'),('texture',E('tex')),('movement',E('mv')),('ult_feather_texture',E('orb')),('ult_missile_data',E('msl')),*props],ext,subs)
boss('boss_rock_bastion','boss_rock_bastion','ROCK BASTION','mid_boss',
    [(0.6,['p10_needle','p10_rocket'],[1.1,1.8]),(0.25,['p10_split','spiral_6'],[1.6,0.2]),(0.0,['p10_ring_lance','p10_lance','p10_rocket_fan'],[0.8,1.2,2.0])],
    [('ult_kinds','Array[StringName]([&"missile", &"nova"])'),('ult_first_delay',7.0),('ult_interval',10.0),('ult_damage',4),('ult_color','Color(1, 0.3, 0.25, 1)'),
     ('ult_origin','Vector2(0, -7)'),('ult_missile_points','PackedVector2Array(-78, 117, 79, 117, -104, -9, 105, -9)'),('ult_missile_count',6),
     ('bank_amount',0.3),('thruster_offsets','PackedVector2Array(0, -172, 52, -173, -51, -173)'),('thruster_color','Color(0.4, 1, 0.4, 1)'),('thruster_width',20.0),('thruster_length',34.0),('flight_ref_speed',110.0),
     ('max_hp',900),('hit_radius',170.0),('weak_offset','Vector2(0, -7)'),('weak_radius',28.0),
     ('extra_weak_offsets','PackedVector2Array(-78, 117, 79, 117, 105, -9, -104, -9, 75, -68, -73, -69)'),('score',30000),('explosion_scale',4.0),
     ('bullet_damage',3),('contact_damage',3)])
boss('boss_rune_core','boss_rune_core','RUNE CORE','boss',
    [(0.65,['p10_ring_lance','p10_split'],[1.0,1.8]),(0.3,['spiral_6','p10_rocket_fan','p10_needle'],[0.18,2.0,1.3]),(0.0,['ring_20','p10_lance','p10_split','p10_rocket'],[0.7,1.0,1.6,2.2])],
    [('ult_kinds','Array[StringName]([&"eye_laser", &"timebomb", &"missile"])'),('ult_first_delay',6.0),('ult_interval',9.0),('ult_damage',4),('ult_color','Color(0.4, 1, 0.35, 1)'),
     ('ult_origin','Vector2(0, -3)'),('ult_eye_offset','Vector2(0, -3)'),('ult_eye_width',50.0),('ult_eye_sweep_deg',40.0),
     ('ult_missile_points','PackedVector2Array(-158, 35, 160, 35, -145, -68, 146, -68)'),('ult_missile_count',6),('ult_bomb_count',3),
     ('bank_amount',0.25),('thruster_offsets','PackedVector2Array(-40, -215, 40, -215)'),('thruster_color','Color(0.4, 0.9, 1, 1)'),('thruster_width',22.0),('thruster_length',36.0),('flight_ref_speed',110.0),
     ('max_hp',1400),('hit_radius',200.0),('weak_offset','Vector2(0, -3)'),('weak_radius',32.0),
     ('extra_weak_offsets','PackedVector2Array(160, 35, -158, 35, 146, -68, -145, -68)'),('score',50000),('explosion_scale',5.0),
     ('bullet_damage',3),('contact_damage',3)])

# ---------- 關卡 ----------
K={'ab0':'asteroid_big_0','ab1':'asteroid_big_1','as0':'asteroid_small_0','dart':'rock_dart','arrow':'rock_arrow','bulk':'rock_bulk','spider':'rock_spider',
   'shield':'rock_shield','wing':'rock_wing','quad':'quad_cannon','heavy':'heavy_cannon','fort':'crater_fortress','pow':'dart_power','mine':'spike_mine'}
W=[]  # (time,key,count,interval,x,step,mirror,hold)
def w(t,k,x=0.5,n=1,iv=0.0,st=0.0,mir=False,hold=False,lst=None): (lst if lst is not None else W).append((t,k,n,iv,x,st,mir,hold))
# 第一段：隕石群（0–40 秒）
for t,x,k in [(1,0.2,'ab0'),(2.5,0.7,'ab1'),(5,0.45,'ab0'),(9,0.15,'ab1'),(10,0.85,'ab0'),(14,0.5,'ab1'),(18,0.3,'ab0'),(19,0.75,'ab1'),(24,0.55,'ab0'),(28,0.2,'ab1'),(29,0.8,'ab0'),(34,0.4,'ab1'),(37,0.65,'ab0')]: w(t,k,x)
for t,x in [(3,0.1),(12,0.6),(21,0.1),(31,0.6)]: w(t,'dart',x,5,0.3,0.06,True)
for t,x in [(7,0.3),(16,0.7),(26,0.3),(36,0.7)]: w(t,'arrow',x,4,0.35,0.1)
w(11,'pow',0.5); w(22,'bulk',0.3); w(33,'spider',0.7); w(38,'shield',0.5)
# 第二段：隕石地表（40–100 秒），經過的砲台＋兩次封鎖
for t,x,k in [(42,0.15,'quad'),(42,0.85,'quad'),(48,0.5,'heavy'),(66,0.2,'quad'),(66,0.8,'heavy'),(84,0.5,'quad'),(90,0.25,'heavy'),(90,0.75,'quad')]: w(t,k,x)
for k,x in [('quad',0.25),('quad',0.75),('heavy',0.5)]: w(56,k,x,hold=True)
for k,x in [('heavy',0.2),('heavy',0.8),('quad',0.5)]: w(78,k,x,hold=True)
for t,x in [(44,0.1),(52,0.6),(62,0.1),(72,0.6),(86,0.1),(96,0.6)]: w(t,'dart',x,5,0.3,0.06,True)
for t,x in [(46,0.7),(60,0.3),(70,0.7),(88,0.3)]: w(t,'arrow',x,4,0.35,0.1)
for t,x,k in [(50,0.3,'bulk'),(58,0.7,'spider'),(64,0.5,'mine'),(68,0.3,'spider'),(74,0.7,'bulk'),(82,0.5,'wing'),(92,0.3,'bulk'),(94,0.7,'spider')]: w(t,k,x)
for t,x,k in [(45,0.8,'ab0'),(54,0.2,'ab1'),(63,0.85,'ab0'),(76,0.15,'ab1'),(87,0.6,'ab0'),(97,0.35,'ab1')]: w(t,k,x)
w(61,'pow',0.5); w(85,'pow',0.5)
# 第三段：巨型隕石坑要塞封鎖
w(104,'fort',0.5,hold=True); w(104,'quad',0.12,hold=True); w(104,'quad',0.88,hold=True)
w(107,'dart',0.1,5,0.3,0.06,True)
# 第四段：中 Boss 之後的增援（約 40 秒）
A=[]
for t,x in [(1.5,0.1),(9,0.6),(18,0.1),(28,0.6),(36,0.1)]: w(t,'dart',x,5,0.3,0.06,True,lst=A)
for t,x in [(4,0.3),(13,0.7),(24,0.3),(33,0.7)]: w(t,'arrow',x,4,0.35,0.1,lst=A)
for t,x,k in [(2,0.5,'ab0'),(6,0.2,'ab1'),(11,0.8,'ab0'),(16,0.35,'bulk'),(20,0.65,'spider'),(22,0.5,'wing'),(26,0.2,'ab1'),(30,0.5,'shield'),(34,0.8,'ab0'),(38,0.4,'spider')]: w(t,k,x,lst=A)
for k,x in [('heavy',0.25),('heavy',0.75),('quad',0.5)]: w(14,k,x,hold=True,lst=A)
w(19,'pow',0.5,lst=A)
W.sort(key=lambda v:v[0]); A.sort(key=lambda v:v[0])
used=sorted({v[1] for v in W+A})
ext=[('Script','res://src/stages/wave_data.gd','w_wave')]+[('Resource',f'res://data/enemies/{K[k]}.tres',f'e_{k}') for k in used]
ext+=[('Resource','res://data/enemies/boss_rock_bastion.tres','b_mid'),('Resource','res://data/enemies/boss_rune_core.tres','b_final'),('Texture2D',S+'terrain/rock.jpg','t_ter')]
ext+=[('Texture2D',S+f'hazards/asteroid_{s}_{i}.png',f'd_{s}{i}') for s in ('big','small') for i in range(4)]
subs=''
def mk(p,ws):
    global subs; ids=[]
    for i,(t,k,n,iv,x,st,mir,hold) in enumerate(ws):
        ids.append(f'{p}{i}')
        subs+=f'[sub_resource type="Resource" id="{p}{i}"]\nscript = ExtResource("w_wave")\ntime = {t}\nenemy = ExtResource("e_{k}")\ncount = {n}\ninterval = {iv}\nstart_x = {x}\nstep_x = {st}\nmirror = {"true" if mir else "false"}\n'+('hold = true\n' if hold else '')+'\n'
    return ', '.join(f'SubResource("{i}")' for i in ids)
wl=mk('W',W); al=mk('A',A)
decor='Array[Texture2D]([%s])'%', '.join(f'ExtResource("d_{s}{i}")' for s in ('big','small') for i in range(4))
res('data/stages/stage_10.tres','StageData','res://src/stages/stage_data.gd',[('id','&"stage_10"'),('display_name','"STAGE 10"'),('sort_order',9),('scroll_speed',170.0),
    ('bg_top_color','Color(0.06, 0.05, 0.03, 1)'),('bg_bottom_color','Color(0.12, 0.09, 0.05, 1)'),('terrain',E('t_ter')),('terrain_tint','Color(0.78, 0.76, 0.72, 1)'),
    ('float_decor',decor),('hp_mult',1.8),('waves',f'Array[ExtResource("w_wave")]([{wl}])'),('mid_boss',E('b_mid')),
    ('waves_after_mid',f'Array[ExtResource("w_wave")]([{al}])'),('after_mid_hp_mult',1.0),('boss',E('b_final')),('boss_warning_time',2.5)],ext,subs)
print('stage 10:',len(W),'main waves,',len(A),'after-mid waves')
