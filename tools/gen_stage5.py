# 產生第 5 關（SPORE HIVE 孢子母巢）的敵人、彈幕、Boss 與 StageData
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
pat('p5_spore_shot','AimedPattern',AP,'fx_orb_spore',320.0,8.0,2,0.16,[('count',1),('spread_deg',0.0)])
pat('p5_green_fan3','AimedPattern',AP,'fx_laser_green',420.0,6.0,1,0.12,[('count',3),('spread_deg',28.0)])
pat('p5_twin_red','AimedPattern',AP,'fx_laser_red',450.0,6.0,3,0.11,[('count',2),('spread_deg',10.0)])
pat('p5_turret3','AimedPattern',AP,'fx_laser_red',400.0,6.0,1,0.1,[('count',3),('spread_deg',14.0)])
pat('p5_cannon','AimedPattern',AP,'fx_burst_orange',300.0,11.0,3,0.16,[('count',1),('spread_deg',0.0)])
pat('p5_spore_ring8','RingPattern',RP,'fx_orb_spore',200.0,8.0,1,0.12,[('count',8),('rotation_per_shot_deg',22.0)])
pat('p5_spore_ring16','RingPattern',RP,'fx_orb_spore',220.0,8.0,1,0.12,[('count',16),('rotation_per_shot_deg',11.0)])
pat('p5_spore_spiral','RingPattern',RP,'fx_burst_spore',240.0,8.0,6,0.1,[('count',5),('rotation_per_shot_deg',13.0)])
pat('p5_red_aim5','AimedPattern',AP,'fx_laser_red',470.0,6.0,3,0.1,[('count',5),('spread_deg',42.0)])
pat('p5_violet_rain','RingPattern',RP,'fx_laser_violet',260.0,6.0,2,0.14,[('count',3),('random_rotation','true')])
# ---------- 移動 ----------
res('data/patterns/move_hive_hover.tres','MoveHover',MH,[('stop_distance',420.0),('enter_time',3.0),('amplitude',150.0),('period',7.0),('y_amplitude',50.0),('y_speed',0.8)])
res('data/patterns/move_brood_hover.tres','MoveHover',MH,[('stop_distance',500.0),('enter_time',3.0),('amplitude',80.0),('period',9.0),('y_amplitude',26.0),('y_speed',0.6)])

ITEMS=[('Script','res://src/entities/items/item_data.gd','itm'),('Resource','res://data/items/missile.tres','i_mis'),('Resource','res://data/items/shield.tres','i_sh'),
       ('Resource','res://data/items/special.tres','i_sp'),('Resource','res://data/items/power.tres','i_pw'),('Resource','res://data/items/weapon_plasma.tres','i_wp')]
POOL='Array[ExtResource("itm")]([ExtResource("i_mis"), ExtResource("i_sh"), ExtResource("i_sp"), ExtResource("i_wp")])'
def enemy(name,tex,props,ext=(),items=False):
    ext=[('Texture2D',S+tex,'tex'),*ext]+(ITEMS if items else [])
    p=[('id',f'&"{name}"'),('texture',E('tex')),*props]
    if items: p+=[('drop_item',E('i_pw')),('bonus_pool',POOL)]
    res(f'data/enemies/{name}.tres','EnemyData',ED,p,ext)
PT=lambda n:('Resource',f'res://data/patterns/{n}.tres','pat')
MV=lambda n:('Resource',f'res://data/patterns/{n}.tres','mv')
GREENC='Color(0.4, 1, 0.45, 1)'
MSL=('Resource','res://data/enemies/spore_missile.tres','dh')
CRATER=[('Texture2D',S+'terrain/spore_crater.png','crt')]
DEC=('death_decals','Array[Texture2D]([ExtResource("crt")])')
# ---------- 孢子飛彈（中 Boss、大兵、飛彈台、大 Boss 共用） ----------
enemy('spore_missile','hazards/spore_missile.png',[('max_hp',3),('hit_radius',22.0),('score',60),('explosion_scale',0.9),('hazard_kind','&"missile"'),
    ('blast_radius',95.0),('blast_damage',2),('blast_enemy_damage',10),('home_speed',240.0),('home_turn',1.9),('home_life',6.0),
    ('hazard_color',GREENC),('death_fx',E('fx')),('death_fx_size',190.0),('bullet_damage',0),('contact_damage',0)],
    [('Texture2D',S+'fx/spore_burst.png','fx')])
# ---------- 敵機 ----------
enemy('spore_pod','enemies/spore_pod.png',[('max_hp',3),('hit_radius',30.0),('score',130),('explosion_scale',0.8),('movement',E('mv')),('spin',1.0),
    ('bullet_pattern',E('pat')),('fire_interval',1.9),('first_fire_delay',0.6)],[MV('move_sine'),PT('p5_spore_shot')])
enemy('spore_cross','enemies/spore_cross.png',[('max_hp',7),('hit_radius',40.0),('score',220),('explosion_scale',1.1),('movement',E('mv')),
    ('bullet_pattern',E('pat')),('fire_interval',2.0),('first_fire_delay',0.7)],[MV('move_diagonal'),PT('p5_green_fan3')])
enemy('spore_bastion','enemies/spore_bastion.png',[('max_hp',32),('hit_radius',78.0),('score',850),('explosion_scale',1.9),('movement',E('mv')),
    ('bullet_pattern',E('pat')),('fire_interval',2.2),('first_fire_delay',1.0),('drop_hazard',E('dh')),('drop_hazard_interval',4.2),('drop_hazard_first',2.0),
    ('bullet_damage',2),('contact_damage',3),('drop_chance',0.25),('bonus_chance',0.35)],[MV('move_stop_and_go'),PT('p5_twin_red'),MSL],True)
# ---------- 地面：砲台1（三管）、砲台2（重砲）、飛彈台；砲口在圖上朝右上，用 aim_offset_deg 對齊 ----------
enemy('spore_turret','enemies/spore_turret.png',[('ground','true'),('aim_offset_deg',50.0),('max_hp',20),('hit_radius',48.0),('score',420),('explosion_scale',1.5),
    ('bullet_pattern',E('pat')),('fire_interval',1.5),('first_fire_delay',1.0),('contact_damage',0),DEC,('drop_chance',0.12),('bonus_chance',0.15)],[PT('p5_turret3'),*CRATER],True)
enemy('spore_cannon','enemies/spore_cannon.png',[('ground','true'),('aim_offset_deg',47.0),('max_hp',34),('hit_radius',54.0),('score',700),('explosion_scale',1.8),
    ('bullet_pattern',E('pat')),('fire_interval',2.1),('first_fire_delay',1.3),('contact_damage',0),DEC,('drop_chance',0.2),('bonus_chance',0.2)],[PT('p5_cannon'),*CRATER],True)
enemy('spore_launcher','enemies/spore_launcher.png',[('ground','true'),('aim_offset_deg',46.0),('max_hp',40),('hit_radius',58.0),('score',1100),('explosion_scale',2.2),
    ('bullet_pattern',E('pat')),('fire_interval',3.4),('first_fire_delay',1.8),('drop_hazard',E('dh')),('drop_hazard_interval',3.6),('drop_hazard_first',1.4),
    ('contact_damage',0),DEC,('drop_chance',0.3),('bonus_chance',0.3)],[PT('p5_spore_ring8'),MSL,*CRATER],True)
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
# 中 Boss：SPORE HIVE，只有中央綠核受傷；絕招＝6 座紅色孢子砲台同時往 6 個方向噴射大量綠色光球；會放孢子飛彈
HIVE_PTS='PackedVector2Array(-2, -132, 110, -75, 116, 62, 0, 126, -109, 61, -111, -69)'
boss('boss_spore_hive','boss_spore_hive','SPORE HIVE','mid_boss','move_hive_hover',
    [(0.6,['p5_green_fan3','p5_spore_ring8'],[1.3,1.6]),(0.25,['p5_spore_spiral','p5_spore_shot'],[0.9,1.1]),(0.0,['p5_spore_ring16','p5_green_fan3','p5_violet_rain'],[1.0,1.2,1.0])],
    [('ult_kinds','Array[StringName]([&"spore_ring"])'),('ult_first_delay',5.0),('ult_interval',9.0),('ult_damage',3),('ult_color',GREENC),('ult_origin','Vector2(0, 0)'),
     ('ult_feather_points',HIVE_PTS),('ult_feather_time',2.6),('ult_feather_rate',0.09),('ult_feather_speed',250.0),('ult_feather_charge',1.6),('ult_feather_texture',E('orb')),
     ('drop_hazard',E('dh')),('drop_hazard_interval',4.5),('drop_hazard_first',4.0),BLASTS,('death_blast_size',420.0),
     ('weak_color',GREENC),('max_hp',900),('hit_radius',170.0),('weak_offset','Vector2(0, 0)'),('weak_radius',44.0),('score',32000),('explosion_scale',3.8),
     ('bullet_damage',2),('contact_damage',3)],[('Texture2D',S+'bullets/fx_orb_spore.png','orb'),MSL,*BLAST])
# 最終 Boss：BROOD MOTHER 母巢，綠色腦核受傷
#  絕招 1（eye_laser）：右下天線碟充能 → 超寬紅色孢子光柱橫掃全場，同時射出 4 枚追蹤孢子飛彈
#  絕招 2（devour）：全場變暗 → 張開腹部巨口 → 旋渦吸入場上所有東西 → 壓縮吐出超巨型孢子火球
DEBRIS=[('Texture2D',S+f'hazards/satellite_small_{i}.png',f'db{i}') for i in range(4)]+[('Texture2D',S+'enemies/spore_pod.png','db4')]
boss('boss_brood_mother','boss_brood_mother','BROOD MOTHER','boss','move_brood_hover',
    [(0.65,['p5_red_aim5','p5_spore_ring8'],[1.4,1.5]),(0.3,['p5_spore_spiral','p5_twin_red','p5_violet_rain'],[0.8,1.6,1.1]),(0.0,['p5_spore_ring16','p5_red_aim5','p5_spore_spiral','p5_green_fan3'],[0.9,1.2,0.9,1.4])],
    [('ult_kinds','Array[StringName]([&"eye_laser", &"devour"])'),('ult_first_delay',5.5),('ult_interval',8.0),('ult_damage',4),('ult_color','Color(1, 0.18, 0.15, 1)'),
     ('ult_eye_offset','Vector2(205, 185)'),('ult_eye_width',150.0),('ult_eye_sweep_deg',110.0),('ult_eye_charge',2.2),('ult_eye_fire',2.4),
     ('ult_eye_missiles',4),('ult_missile_data',E('dh')),('ult_missile_points','PackedVector2Array(-150, 190, 150, 190, -90, 230, 90, 230)'),
     ('ult_devour_texture',E('open')),('ult_vortex_texture',E('vtx')),('ult_fireball_texture',E('fb')),('ult_fireball_burst',E('fbx')),
     ('ult_devour_debris','Array[Texture2D]([%s])'%', '.join(E(f'db{i}') for i in range(5))),('ult_mouth','Vector2(2, 25)'),
     ('ult_devour_charge',1.8),('ult_devour_time',3.6),('ult_devour_pull',130.0),('ult_vortex_size',780.0),('ult_fireball_size',250.0),('ult_fireball_speed',230.0),('ult_fireball_ring',18),
     ('ult_feather_texture',E('orb')),BLASTS,('death_blast_size',700.0),
     ('weak_color',GREENC),('max_hp',1500),('hit_radius',260.0),('weak_offset','Vector2(-3, 22)'),('weak_radius',58.0),('score',55000),('explosion_scale',5.5),
     ('bullet_damage',3),('contact_damage',3)],
    [('Texture2D',S+'enemies/boss_brood_mother_open.png','open'),('Texture2D',S+'fx/brood_vortex.png','vtx'),('Texture2D',S+'fx/spore_fireball.png','fb'),
     ('Texture2D',S+'fx/spore_burst.png','fbx'),('Texture2D',S+'bullets/fx_orb_spore.png','orb'),MSL,*BLAST,*DEBRIS])

# ---------- 關卡 ----------
K={'pod':'spore_pod','cross':'spore_cross','bast':'spore_bastion','pow':'dart_power','tur':'spore_turret','can':'spore_cannon','lau':'spore_launcher'}
W=[]
def w(t,k,x=0.5,n=1,iv=0.0,st=0.0,mir=False,lst=None,hold=False): (lst if lst is not None else W).append((t,k,n,iv,x,st,mir,hold))
# 主段（約 60 秒）
for t,x in [(1.5,0.1),(8,0.6),(16,0.1),(24,0.6),(31,0.1),(40,0.6),(48,0.1),(56,0.6)]: w(t,'pod',x,5,0.3,0.07,True)
for t,x in [(4.5,0.3),(12,0.7),(20,0.3),(29,0.7),(37,0.3),(45,0.7),(53,0.3)]: w(t,'cross',x,3,0.4,0.12)
for t,x in [(18,0.3),(34,0.7),(43,0.3),(51,0.7)]: w(t,'bast',x)
# 經過的地面砲台
for t,x,k in [(3,0.18,'tur'),(3,0.82,'tur'),(10,0.5,'can'),(22,0.2,'tur'),(26,0.78,'can'),(38,0.5,'tur'),(47,0.2,'can'),(47,0.8,'tur')]: w(t,k,x)
# 砲台封鎖：全部打掉才繼續捲動
for t,gate in [(14,[('tur',0.25),('tur',0.75)]),(32,[('can',0.3),('can',0.7),('tur',0.5)]),(54,[('lau',0.5),('tur',0.18),('tur',0.82)])]:
    for k,x in gate: w(t,k,x,hold=True)
w(11,'pow'); w(28,'pow'); w(46,'pow')
# 中 Boss 之後的增援（約 30 秒）
A=[]
for t,x in [(1.5,0.1),(9,0.6),(18,0.1),(26,0.6)]: w(t,'pod',x,5,0.3,0.07,True,lst=A)
for t,x in [(4,0.3),(13,0.7),(22,0.3)]: w(t,'cross',x,3,0.4,0.12,lst=A)
for t,x in [(8,0.7),(17,0.3),(25,0.5)]: w(t,'bast',x,lst=A)
for t,x,k in [(2,0.2,'can'),(6,0.8,'tur'),(20,0.5,'can')]: w(t,k,x,lst=A)
for k,x in [('lau',0.3),('lau',0.7),('can',0.5)]: w(12,k,x,lst=A,hold=True)
w(15,'pow',lst=A)
W.sort(key=lambda v:v[0]); A.sort(key=lambda v:v[0])
used=sorted({v[1] for v in W+A})
ext=[('Script','res://src/stages/wave_data.gd','w_wave')]+[('Resource',f'res://data/enemies/{K[k]}.tres',f'e_{k}') for k in used]
ext+=[('Resource','res://data/enemies/boss_spore_hive.tres','b_mid'),('Resource','res://data/enemies/boss_brood_mother.tres','b_final'),('Texture2D',S+'terrain/spore_field.jpg','t_ter')]
subs=''
def mk(p,ws):
    global subs; ids=[]
    for i,(t,k,n,iv,x,st,mir,hold) in enumerate(ws):
        ids.append(f'{p}{i}')
        subs+=f'[sub_resource type="Resource" id="{p}{i}"]\nscript = ExtResource("w_wave")\ntime = {t}\nenemy = ExtResource("e_{k}")\ncount = {n}\ninterval = {iv}\nstart_x = {x}\nstep_x = {st}\nmirror = {"true" if mir else "false"}\n'+('hold = true\n' if hold else '')+'\n'
    return ', '.join(f'SubResource("{i}")' for i in ids)
wl=mk('W',W); al=mk('A',A)
res('data/stages/stage_05.tres','StageData','res://src/stages/stage_data.gd',[('id','&"stage_05"'),('display_name','"STAGE 5"'),('sort_order',4),('scroll_speed',170.0),
    ('bg_top_color','Color(0.02, 0.06, 0.03, 1)'),('bg_bottom_color','Color(0.05, 0.12, 0.06, 1)'),('terrain',E('t_ter')),('terrain_tint','Color(1, 1, 1, 0.5)'),
    ('hp_mult',1.25),('waves',f'Array[ExtResource("w_wave")]([{wl}])'),('mid_boss',E('b_mid')),
    ('waves_after_mid',f'Array[ExtResource("w_wave")]([{al}])'),('after_mid_hp_mult',1.0),('boss',E('b_final')),('boss_warning_time',2.5)],ext,subs)
print('stage 5:',len(W),'main waves,',len(A),'after-mid waves')
