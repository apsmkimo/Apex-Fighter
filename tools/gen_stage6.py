# 產生第 6 關（BLACK GOLD 黑金機甲）的敵人、彈幕、Boss 與 StageData
# 先跑 tools/cut_stage6.py 產生素材
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
V=lambda pts:'PackedVector2Array(%s)'%', '.join(f'{x}, {y}' for x,y in pts)
ED='res://src/entities/enemies/enemy_data.gd'
AP='res://src/patterns/bullet/aimed_pattern.gd'; RP='res://src/patterns/bullet/ring_pattern.gd'; MP='res://src/patterns/bullet/muzzle_pattern.gd'
MSN='res://src/patterns/movement/move_sine.gd'; MH='res://src/patterns/movement/move_hover.gd'; MSG='res://src/patterns/movement/move_stop_and_go.gd'
def pat(name,cls,script,tex,speed,radius,burst=1,biv=0.12,extra=()):
    res(f'data/patterns/{name}.tres',cls,script,[*extra,('bullet_texture',E('tex')),('bullet_speed',speed),('bullet_radius',radius),('damage',1),('burst_count',burst),('burst_interval',biv)],
        [('Texture2D',S+f'bullets/{tex}.png','tex')])

# 小 Boss 十門砲（相對機身中心，左 5 右 5）
MID_L=[(-161,-150),(-186,-85),(-206,4),(-176,102),(-118,208)]
MID=MID_L+[(-x,y) for x,y in MID_L]
DREAD_SIDE=[(-93,5),(94,5)]
# ---------- 彈幕 ----------
pat('p6_swarm2','AimedPattern',AP,'fx_laser_red',470.0,5.0,1,0.1,[('count',2),('spread_deg',6.0)])
pat('p6_side_twin','MuzzlePattern',MP,'fx_laser_red',400.0,5.0,2,0.14,[('muzzles',V(DREAD_SIDE)),('aim','true')])
pat('p6_sat3','AimedPattern',AP,'fx_orb_red',270.0,8.0,1,0.1,[('count',3),('spread_deg',40.0)])
pat('p6_drone','AimedPattern',AP,'fx_laser_red',420.0,5.0,2,0.12,[('count',1),('spread_deg',0.0)])
pat('p6_mid_volley','MuzzlePattern',MP,'fx_laser_red',340.0,5.0,3,0.14,[('muzzles',V(MID)),('aim','false')])
pat('p6_mid_sweep','MuzzlePattern',MP,'fx_orb_red',250.0,8.0,8,0.11,[('muzzles',V(MID)),('aim','false'),('sweep_deg',46.0),('sweep_step',0.42)])
pat('p6_mid_aim','MuzzlePattern',MP,'fx_laser_red',390.0,5.0,2,0.15,[('muzzles',V(MID[3:5]+MID[8:10])),('aim','true')])
pat('p6_super','AimedPattern',AP,'fx_orb_red',170.0,20.0,1,0.1,[('count',3),('spread_deg',30.0)])
pat('p6_fort_ring','RingPattern',RP,'fx_laser_red',230.0,5.0,1,0.1,[('count',16),('rotation_per_shot_deg',11.0)])
pat('p6_fort_spiral','RingPattern',RP,'fx_orb_red',220.0,8.0,8,0.1,[('count',4),('rotation_per_shot_deg',14.0)])
# ---------- 移動 ----------
res('data/patterns/move_swarm.tres','MoveSine',MSN,[('speed',300.0),('amplitude',70.0),('frequency',0.9)])
res('data/patterns/move_blade.tres','MoveStopAndGo',MSG,[('stop_distance',270.0),('enter_time',1.0),('wait_time',6.0),('exit_velocity','Vector2(0, 220)')])
res('data/patterns/move_dread.tres','MoveSine',MSN,[('speed',58.0),('amplitude',90.0),('frequency',0.2)])
res('data/patterns/move_warship_hover.tres','MoveHover',MH,[('stop_distance',540.0),('enter_time',3.0),('amplitude',120.0),('period',8.0),('y_amplitude',30.0),('y_speed',0.7)])
res('data/patterns/move_fortress_hover.tres','MoveHover',MH,[('stop_distance',620.0),('enter_time',3.0),('amplitude',70.0),('period',10.0),('y_amplitude',20.0),('y_speed',0.5)])

ITEMS=[('Script','res://src/entities/items/item_data.gd','itm'),('Resource','res://data/items/missile.tres','i_mis'),('Resource','res://data/items/shield.tres','i_sh'),
       ('Resource','res://data/items/special.tres','i_sp'),('Resource','res://data/items/power.tres','i_pw'),('Resource','res://data/items/weapon_plasma.tres','i_wp')]
POOL='Array[ExtResource("itm")]([ExtResource("i_mis"), ExtResource("i_sh"), ExtResource("i_sp"), ExtResource("i_wp")])'
RED='Color(1, 0.18, 0.15, 1)'
SHIELD=[('Texture2D',S+'fx/bg_shield.png','shd')]
PIT=[('Texture2D',S+'terrain/bg_lava_pit.png','pit')]
def enemy(name,tex,props,ext=(),items=False,shield=0.5):
    ext=[('Texture2D',S+tex,'tex'),*ext]+(ITEMS if items else [])+(SHIELD if shield else [])
    p=[('id',f'&"{name}"'),('texture',E('tex')),*props]
    if shield: p+=[('shield_texture',E('shd')),('shield_ratio',shield)]
    if items: p+=[('drop_item',E('i_pw')),('bonus_pool',POOL)]
    res(f'data/enemies/{name}.tres','EnemyData',ED,p,ext)
PT=lambda n:('Resource',f'res://data/patterns/{n}.tres','pat')
MV=lambda n:('Resource',f'res://data/patterns/{n}.tres','mv')
LASER=('Texture2D',S+'bullets/fx_laser_red.png','btx')
ORB=('Texture2D',S+'bullets/fx_orb_red.png','btx')
B=lambda kind,extra=():[('behavior',f'&"{kind}"'),('behavior_color',RED),*extra]

# ---------- 紅光飛彈（13）：垂直飛彈巢用；命中爆炸留小岩漿坑＋紅光衝擊波 ----------
enemy('bg_missile','hazards/bg_missile.png',[('max_hp',3),('hit_radius',20.0),('score',60),('explosion_scale',0.9),('hazard_kind','&"missile"'),
    ('blast_radius',80.0),('blast_damage',2),('blast_enemy_damage',10),('home_speed',250.0),('home_turn',2.3),('home_life',5.5),
    ('hazard_color',RED),('death_pit',E('pit')),('death_pit_size',80.0),('bullet_damage',0),('contact_damage',0)],PIT,shield=0)
# ---------- 敵機 ----------
# 01 小兵 蜂群無人機：三架一組突進，正面 2 發點射，低血加速自爆
enemy('bg_swarm','enemies/bg_swarm.png',[('max_hp',5),('hit_radius',30.0),('score',140),('explosion_scale',0.8),('movement',E('mv')),
    ('bullet_pattern',E('pat')),('fire_interval',1.8),('first_fire_delay',0.5),*B('kamikaze',[('kamikaze_ratio',0.3),('kamikaze_speed',470.0)]),('contact_damage',2)],
    [MV('move_swarm'),PT('p6_swarm2')])
# 02 中兵 重劍戰機：蓄力劍氣（穿透）→ 重劍突刺留紅光殘影
enemy('bg_blade','enemies/bg_blade.png',[('max_hp',12),('hit_radius',28.0),('score',320),('explosion_scale',1.1),('movement',E('mv')),
    ('first_fire_delay',0.8),*B('sword',[('behavior_points',V([(0,72)])),('behavior_texture',E('btx'))]),('contact_damage',3)],
    [MV('move_blade'),LASER])
# 03 大兵 重砲戰艦：4 門重砲輪流齊射（落點岩漿坑）＋側舷副砲
enemy('bg_dreadnought','enemies/bg_dreadnought.png',[('max_hp',45),('hit_radius',85.0),('score',950),('explosion_scale',2.0),('movement',E('mv')),
    ('bullet_pattern',E('pat')),('fire_interval',2.4),('first_fire_delay',1.2),
    *B('artillery',[('behavior_points',V([(-20,-95),(19,-95),(-31,-80),(30,-80)])),('behavior_texture',E('btx')),('behavior_interval',3.4),('behavior_count',4),
       ('behavior_damage',2),('behavior_pit_size',120.0),('death_pit',E('pit'))]),
    ('bullet_damage',2),('contact_damage',3),('drop_chance',0.3),('bonus_chance',0.35)],[MV('move_dread'),PT('p6_side_twin'),ORB,*PIT],True)
# 06 砲台 1 加特林：預判速射，過熱紅光膨脹後連射
GROUND=[('ground','true'),('aim_rotate','false'),('ground_spin',0.0),('contact_damage',0)]
enemy('bg_gatling','enemies/bg_gatling.png',[*GROUND,('max_hp',26),('hit_radius',50.0),('score',480),('explosion_scale',1.6),('first_fire_delay',1.0),
    *B('gatling',[('behavior_points',V([(0,-58)])),('behavior_texture',E('btx'))]),('bullet_damage',1),('drop_chance',0.12),('bonus_chance',0.15)],[LASER],True)
# 07 砲台 2 雷射聚焦砲：聚焦環蓄力 1 秒 → 2 秒紅光雷射旋轉掃場，地板燒痕
enemy('bg_focus','enemies/bg_focus.png',[*GROUND,('ground_spin',0.25),('max_hp',30),('hit_radius',52.0),('score',620),('explosion_scale',1.7),('first_fire_delay',1.4),
    *B('focus_laser',[('behavior_interval',4.6),('behavior_damage',3)]),('drop_chance',0.15),('bonus_chance',0.2)],[],True)
# 08 飛彈台 垂直飛彈巢：冒紅光蒸氣 → 同時升空 6 枚紅光飛彈
HEX=[(0,-34),(30,-17),(30,17),(0,34),(-30,17),(-30,-17)]
enemy('bg_hive','enemies/bg_hive.png',[*GROUND,('max_hp',36),('hit_radius',56.0),('score',900),('explosion_scale',2.0),('first_fire_delay',1.5),
    *B('vlauncher',[('behavior_points',V(HEX)),('behavior_missile',E('msl')),('behavior_count',6),('behavior_interval',6.0)]),('drop_chance',0.25),('bonus_chance',0.3)],
    [('Resource','res://data/enemies/bg_missile.tres','msl')],True)
# 10 被支配的小衛星：繞場旋轉、紅光脈衝環、間歇 3 向散射；擊破必掉補給但爆出小岩漿坑
enemy('bg_satellite','enemies/bg_satellite.png',[('max_hp',14),('hit_radius',46.0),('score',500),('explosion_scale',1.3),('spin',0.6),
    ('bullet_pattern',E('pat')),('fire_interval',2.2),('first_fire_delay',1.6),*B('orbit'),('death_pit',E('pit')),('death_pit_size',90.0),
    ('drop_chance',1.0),('bonus_chance',0.25),('contact_damage',2)],[PT('p6_sat3'),*PIT],True)
# 大 Boss 的浮游砲
enemy('bg_float_cannon','enemies/bg_float_cannon.png',[('max_hp',50),('hit_radius',34.0),('score',600),('explosion_scale',1.4),
    ('bullet_pattern',E('pat')),('fire_interval',1.7),('first_fire_delay',1.0),('bullet_damage',2),('contact_damage',2)],[PT('p6_drone')],shield=0.3)

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

BLAST=[('Texture2D',S+'fx/boss_blast_0.png','bl0'),('Texture2D',S+'fx/boss_blast_1.png','bl1')]
BLASTS=('death_blasts','Array[Texture2D]([ExtResource("bl0"), ExtResource("bl1")])')
# 小 Boss：黑金機甲戰艦（10 門砲）。第二階段（50%）裝甲炸開才露出核心；絕招＝全砲口聚能 → 地面巨大 X
boss('boss_bg_warship','boss_bg_warship','BLACK GOLD WARSHIP','mid_boss','move_warship_hover',
    [(0.6,['p6_mid_volley','p6_mid_sweep'],[1.7,2.3]),(0.3,['p6_mid_sweep','p6_mid_aim'],[1.7,1.9]),(0.0,['p6_mid_volley','p6_mid_aim','p6_mid_sweep'],[1.5,1.7,2.0])],
    [('ult_kinds','Array[StringName]([&"x_strike"])'),('ult_first_delay',5.0),('ult_interval',8.0),('ult_damage',3),('ult_color',RED),
     ('ult_feather_points',V(MID)),('ult_x_texture',E('xt')),('ult_x_size',640.0),('ult_pit_texture',E('pit')),
     ('core_reveal_ratio',0.5),('armor_damage_mult',0.6),BLASTS,('death_blast_size',460.0),
     ('weak_color',RED),('max_hp',900),('hit_radius',190.0),('weak_offset','Vector2(0, 2)'),('weak_radius',44.0),('score',34000),('explosion_scale',4.0),
     ('bullet_damage',2),('contact_damage',3)],[('Texture2D',S+'fx/bg_x_strike.png','xt'),*PIT,*BLAST])
# 大 Boss：黑金機甲飛天堡壘。本體超重砲＋六片浮游砲；絕招一＝浮游砲圓環聚焦紅光球，絕招二＝核心黑洞湮滅光柱
SLOTS=[(-205,-198),(-140,-256),(-61,-287),(61,-287),(140,-256),(206,-198)]
COVER=[('Texture2D',S+f'hazards/asteroid_big_{i}.png',f'cv{i}') for i in (0,1,2)]
boss('boss_bg_fortress','boss_bg_fortress','BLACK GOLD FORTRESS','boss','move_fortress_hover',
    [(0.65,['p6_super','p6_fort_ring'],[1.8,2.1]),(0.3,['p6_super','p6_fort_spiral'],[1.5,1.3]),(0.0,['p6_super','p6_fort_ring','p6_fort_spiral'],[1.3,1.7,1.2])],
    [('ult_kinds','Array[StringName]([&"focus_ring", &"annihilate"])'),('ult_first_delay',6.0),('ult_interval',7.5),('ult_damage',4),('ult_color',RED),
     ('ult_orb_texture',E('orb')),('ult_pit_texture',E('pit')),('ult_focus_radius',210.0),
     ('ult_beam_texture',E('beam')),('ult_hole_texture',E('hole')),('ult_cover_textures','Array[Texture2D]([%s])'%', '.join(E(f'cv{i}') for i in (0,1,2))),
     ('ult_annihilate_width',300.0),('ult_annihilate_sweep_deg',64.0),('ult_annihilate_time',5.0),
     ('float_cannon',E('fc')),('float_slots',V(SLOTS)),BLASTS,('death_blast_size',760.0),
     ('weak_color',RED),('max_hp',1600),('hit_radius',240.0),('weak_offset','Vector2(0, -53)'),('weak_radius',54.0),('score',60000),('explosion_scale',5.5),
     ('bullet_damage',3),('contact_damage',3)],
    [('Texture2D',S+'fx/bg_focus_orb.png','orb'),('Texture2D',S+'fx/bg_annihilation_beam.png','beam'),('Texture2D',S+'fx/bg_blackhole.png','hole'),
     ('Resource','res://data/enemies/bg_float_cannon.tres','fc'),*PIT,*BLAST,*COVER])

# ---------- 關卡 ----------
K={'sw':'bg_swarm','bl':'bg_blade','dr':'bg_dreadnought','sat':'bg_satellite','pow':'dart_power','gat':'bg_gatling','foc':'bg_focus','hiv':'bg_hive'}
W=[]
def w(t,k,x=0.5,n=1,iv=0.0,st=0.0,mir=False,lst=None,hold=False): (lst if lst is not None else W).append((t,k,n,iv,x,st,mir,hold))
# 主段（約 60 秒）：蜂群三架一組
for t,x in [(1.5,0.15),(5,0.65),(9,0.2),(17,0.6),(21,0.15),(27,0.7),(36,0.2),(40,0.65),(45,0.15),(50,0.6),(57,0.2)]: w(t,'sw',x,3,0.22,0.06)
for t,x in [(6.5,0.3),(19,0.7),(29,0.3),(38,0.75),(48,0.3),(55,0.7)]: w(t,'bl',x,2,0.6,0.3)
for t,x in [(11,0.3),(24,0.7),(42,0.35),(52,0.65)]: w(t,'dr',x)
for t,x in [(13,0.3),(31,0.7),(46,0.3)]: w(t,'sat',x)
# 經過的地面砲台
for t,x,k in [(3,0.18,'gat'),(3,0.82,'gat'),(8,0.5,'foc'),(20,0.2,'hiv'),(25,0.8,'gat'),(37,0.5,'foc'),(43,0.15,'gat'),(49,0.82,'hiv')]: w(t,k,x)
# 砲台封鎖：全部打掉才繼續捲動
for t,gate in [(15,[('gat',0.25),('gat',0.75)]),(33,[('foc',0.3),('foc',0.7),('gat',0.5)]),(54,[('hiv',0.5),('gat',0.18),('gat',0.82)])]:
    for k,x in gate: w(t,k,x,hold=True)
w(12,'pow'); w(30,'pow'); w(47,'pow')
# 小 Boss 之後的增援（約 30 秒）
A=[]
for t,x in [(1.5,0.15),(8,0.65),(16,0.2),(24,0.6)]: w(t,'sw',x,3,0.22,0.06,lst=A)
for t,x in [(4,0.3),(14,0.7),(22,0.3)]: w(t,'bl',x,2,0.6,0.3,lst=A)
for t,x in [(7,0.7),(19,0.3),(26,0.5)]: w(t,'dr',x,lst=A)
for t,x in [(10,0.3),(21,0.7)]: w(t,'sat',x,lst=A)
for t,x,k in [(2,0.2,'foc'),(6,0.8,'gat'),(20,0.5,'hiv')]: w(t,k,x,lst=A)
for k,x in [('hiv',0.3),('hiv',0.7),('foc',0.5)]: w(12,k,x,lst=A,hold=True)
w(15,'pow',lst=A)
W.sort(key=lambda v:v[0]); A.sort(key=lambda v:v[0])
used=sorted({v[1] for v in W+A})
ext=[('Script','res://src/stages/wave_data.gd','w_wave')]+[('Resource',f'res://data/enemies/{K[k]}.tres',f'e_{k}') for k in used]
ext+=[('Resource','res://data/enemies/boss_bg_warship.tres','b_mid'),('Resource','res://data/enemies/boss_bg_fortress.tres','b_final'),
      ('Texture2D',S+'terrain/bg_redsea.jpg','t_ter'),('Texture2D',S+'terrain/bg_redsea_far.jpg','t_far')]
subs=''
def mk(p,ws):
    global subs; ids=[]
    for i,(t,k,n,iv,x,st,mir,hold) in enumerate(ws):
        ids.append(f'{p}{i}')
        subs+=f'[sub_resource type="Resource" id="{p}{i}"]\nscript = ExtResource("w_wave")\ntime = {t}\nenemy = ExtResource("e_{k}")\ncount = {n}\ninterval = {iv}\nstart_x = {x}\nstep_x = {st}\nmirror = {"true" if mir else "false"}\n'+('hold = true\n' if hold else '')+'\n'
    return ', '.join(f'SubResource("{i}")' for i in ids)
wl=mk('W',W); al=mk('A',A)
res('data/stages/stage_06.tres','StageData','res://src/stages/stage_data.gd',[('id','&"stage_06"'),('display_name','"STAGE 6"'),('sort_order',5),('scroll_speed',180.0),
    ('bg_top_color','Color(0.08, 0.01, 0.02, 1)'),('bg_bottom_color','Color(0.12, 0.02, 0.03, 1)'),('terrain',E('t_ter')),('terrain_tint','Color(0.8, 0.74, 0.72, 0.62)'),
    ('terrain_far',E('t_far')),('terrain_far_tint','Color(0.5, 0.46, 0.46, 1)'),('terrain_far_speed',0.4),
    ('hp_mult',1.35),('waves',f'Array[ExtResource("w_wave")]([{wl}])'),('mid_boss',E('b_mid')),
    ('waves_after_mid',f'Array[ExtResource("w_wave")]([{al}])'),('after_mid_hp_mult',1.0),('boss',E('b_final')),('boss_warning_time',2.5)],ext,subs)
print('stage 6:',len(W),'main waves,',len(A),'after-mid waves')
