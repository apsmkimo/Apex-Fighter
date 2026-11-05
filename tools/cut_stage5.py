# 第五關（SPORE HIVE 孢子母巢）素材去背與切割
import sys, numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0,'/workspace/work/tools')
from cut_magenta import key, components, save
U='/workspace/projects/f7bb02bf-dc2c-4067-96c4-7dc4b1fc6c8c/files/uploads/'
R='/workspace/work/raiden-godot/assets/sprites/'
def bbox(a,minsize=20000,merge=20):
    bx=components(a,merge=merge,minsize=minsize)
    return (min(b[0] for b in bx),min(b[1] for b in bx),max(b[2] for b in bx),max(b[3] for b in bx))
def single(src,out,size,rot=0,minsize=20000):
    rgb,a=key(U+src)
    return save(rgb,a,bbox(a,minsize),R+out,size,rot)
# 小兵（黑底）：從邊界灌水去背
def black(src,out,size,rot=0,th=28):
    im=np.array(Image.open(U+src).convert('RGB'))
    dark=im.max(axis=2)<th
    lab,n=ndimage.label(dark)
    border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    bg=ndimage.binary_opening(np.isin(lab,list(border)),iterations=1)
    a8=(ndimage.gaussian_filter((~bg).astype(float),0.8)*255).astype(np.uint8)
    return save(im,a8,bbox(a8,50000,10),R+out,size,rot)
black('1000027265-47c08c327705.png','enemies/spore_pod.png',92)
single('1000027256-b35d7a2c872f.png','enemies/spore_cross.png',130)
single('1000027257-7d02a0c8a2c5.png','enemies/spore_bastion.png',190)
# 地面：砲台1、飛彈台、砲台2、炸毀坑
single('1000027258-8ad402f5c925.png','enemies/spore_turret.png',130)
single('1000027260-8bb92759b99c.png','enemies/spore_launcher.png',150)
single('1000027259-4d99e925ea81.png','enemies/spore_cannon.png',150)
single('1000027262-388bd3f2e2a1.png','terrain/spore_crater.png',150)
# Boss
single('1000027274-f0509936ccd7.png','enemies/boss_spore_hive.png',380)
single('1000027277-7f42c03a27e2.png','enemies/boss_brood_mother.png',560)
single('1000027283-981cdc3fe3bb.png','enemies/boss_brood_mother_open.png',560)
# 特效
single('1000027284-011a0436d791.png','fx/brood_vortex.png',900)
single('1000027279-57217c05cc0d.png','fx/spore_fireball.png',300)
single('1000027280-164e5d5c6711.png','hazards/spore_missile.png',76,rot=-90)   # 彈頭朝右（飛彈用 rotation = 速度角度）
single('1000027281-167a295744f7.png','fx/spore_burst.png',260)
single('1000027268-a8d68b105036.png','fx/boss_blast_0.png',512)
single('1000027269-f6cd8b2b4798.png','fx/boss_blast_1.png',512)
# 通用爆炸三格（小→大）
rgb,a=key(U+'1000027272-0d0546080174.png')
bx=sorted(components(a,merge=25,minsize=3000),key=lambda b:b[1])
print('explosion parts',len(bx))
for i,b in enumerate(bx[:3]): save(rgb,a,b,R+f'fx/explosion_{i}.png',[96,200,220][i])
# 黑底能量特效表：亮度當透明度（光效素材）
def glow_cells(src,cols,rows_,names,sizes):
    im=np.array(Image.open(U+src).convert('RGB')).astype(float)
    for ri,(y0,y1) in enumerate(rows_):
        for ci,(x0,x1) in enumerate(cols):
            n=names[ri][ci]
            if not n: continue
            c=im[y0:y1,x0:x1]
            L=c.max(axis=2)
            a=np.clip((L-14)/150,0,1)
            ys,xs=np.where(a>0.08)
            c=c[ys.min():ys.max()+1,xs.min():xs.max()+1]; a=a[ys.min():ys.max()+1,xs.min():xs.max()+1]
            rgb=np.clip(c/np.maximum(a[...,None],1e-3),0,255)
            img=Image.fromarray(np.dstack([rgb,a*255]).astype(np.uint8),'RGBA')
            s=sizes[ri]/max(img.size); img=img.resize((max(1,round(img.width*s)),max(1,round(img.height*s))),Image.LANCZOS)
            img.save(R+f'bullets/{n}.png'); print(n,img.size)
glow_cells('1000027267-1d615001895d.jpg',[(107,533),(533,906),(906,1333)],[(40,560),(570,1045),(1050,1415),(1420,1840)],
    [['fx_laser_red','fx_laser_blue','fx_laser_green'],['fx_laser_orange','fx_laser_violet','fx_laser_cyan'],
     ['fx_orb_gold','fx_orb_pink','fx_orb_ice'],['fx_burst_orange','fx_burst_blue','fx_burst_lime']],[64,64,40,40])
# 戰場背景：橫圖轉直，上下鏡像接成無縫循環（遊戲內以 50% 透明顯示）
img=Image.open(U+'1000027264-1b21e1a61eb3.png').convert('RGB').rotate(90,expand=True)
w=540; img=img.resize((w,round(img.height*w/img.width)),Image.LANCZOS)
A=np.array(img); S=np.concatenate([A,A[::-1]])
Image.fromarray(S).save(R+'terrain/spore_field.jpg',quality=86); print('terrain',S.shape)
# 特效圖邊緣殘留的洋紅色：再去一次
for f in ['fx/brood_vortex','fx/spore_burst','fx/spore_fireball','fx/boss_blast_0','fx/boss_blast_1']:
    a=np.array(Image.open(R+f+'.png').convert('RGBA')).astype(float)
    pink=np.clip((np.minimum(a[...,0],a[...,2])-a[...,1]-20)/40,0,1)
    a[...,3]*=1-pink*ndimage.binary_dilation(a[...,3]<250,iterations=6)
    Image.fromarray(a.astype(np.uint8)).save(R+f+'.png')
