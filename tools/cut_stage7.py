# 第七關（BLACK GOLD 黑金機甲）素材去背與切割
import sys, numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0,'/workspace/work/tools')
from cut_magenta import components, save
U='/workspace/projects/f7bb02bf-dc2c-4067-96c4-7dc4b1fc6c8c/files/uploads/'
R='/workspace/work/raiden-godot/assets/sprites/'
# 綠幕去背：綠色明顯高於紅藍的像素當背景，邊緣柔化並去綠溢色
def key_green(src):
    im=np.array(Image.open(U+src).convert('RGB')).astype(float)
    r,g,b=im[...,0],im[...,1],im[...,2]
    gd=g-np.maximum(r,b)
    a=1-np.clip((gd-35)/45,0,1)
    a=ndimage.gaussian_filter(a,0.6)
    sp=np.clip(g-np.maximum(r,b)*1.05,0,None)*(a<0.999)+np.clip(g-np.maximum(r,b)-8,0,None)*(a>=0.999)
    out=im.copy(); out[...,1]-=sp
    return np.clip(out,0,255).astype(np.uint8),(np.clip(a,0,1)*255).astype(np.uint8)
# 黑底去背：從邊界灌水
def key_black(src,th=26):
    im=np.array(Image.open(U+src).convert('RGB'))
    dark=im.max(axis=2)<th
    lab,n=ndimage.label(dark)
    border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    bg=ndimage.binary_opening(np.isin(lab,list(border)),iterations=1)
    return im,(ndimage.gaussian_filter((~bg).astype(float),0.8)*255).astype(np.uint8)
def bbox(a,minsize=20000,merge=20):
    bx=components(a,merge=merge,minsize=minsize)
    return (min(b[0] for b in bx),min(b[1] for b in bx),max(b[2] for b in bx),max(b[3] for b in bx))
def cut(src,out,size,rot=0,black=False,minsize=20000):
    rgb,a=key_black(src) if black else key_green(src)
    return save(rgb,a,bbox(a,minsize),R+out,size,rot)
if __name__=='__main__':
    cut('1000027316-b2e64e71ecdd.png','enemies/bg_swarm.png',88,black=True)
    cut('1000027317-0ace39498aa4.png','enemies/bg_blade.png',150,black=True)
    cut('1000027318-40623905559c.png','enemies/bg_dreadnought.png',220,black=True)
    cut('1000027303-45555c25c04a.png','enemies/bg_gatling.png',130)
    cut('1000027304-eb3861102a0e.png','enemies/bg_focus.png',140)
    cut('1000027305-c117cf6fd349.png','enemies/bg_hive.png',140)
    cut('1000027307-22affd2a52ee.png','enemies/bg_satellite.png',130)
    cut('1000027306-2a67abe34e14.png','terrain/bg_lava_pit.png',256)
    cut('1000027309-6b796806c7e2.png','fx/bg_shield.png',256)
    cut('1000027311-56b3babaa349.png','fx/bg_x_strike.png',720)
    # 紅光飛彈：透明底、彈頭朝下 → 轉成彈頭朝右（飛彈 rotation = 速度角度）
    im=Image.open(U+'1000027320-39a0f463e65c.png').convert('RGBA'); A=np.array(im).astype(float)
    r,g,b=A[...,0],A[...,1],A[...,2]
    gr=np.clip(g-np.maximum(r,b)-10,0,None); A[...,1]-=gr      # 鰭邊綠色去掉
    al=A[...,3]>40; ys,xs=np.where(al)
    Image.fromarray(np.clip(A,0,255).astype(np.uint8)).crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1)).rotate(90,expand=True,resample=Image.BICUBIC).save('/tmp/m.png')
    m=Image.open('/tmp/m.png'); s=84/max(m.size); m.resize((round(m.width*s),round(m.height*s)),Image.LANCZOS).save(R+'hazards/bg_missile.png'); print('missile',m.size)
    # 小 Boss
    cut('1000027319-bdb40afc698f.png','enemies/boss_bg_warship.png',440,black=True)
    # 大 Boss：本體與六片浮游砲分開
    rgb,a=key_green('1000027302-ed268a5febfe.png')
    bx=components(a,merge=6,minsize=3000)
    bx=sorted(bx,key=lambda b:-(b[2]-b[0])*(b[3]-b[1]))
    for b in bx: print('fortress part',b)
    np.save('/workspace/work/s6/fort_alpha.npy',a)
    Image.fromarray(np.dstack([rgb,a]),'RGBA').save('/workspace/work/s6/fort_keyed.png')
    # 大 Boss 本體：去掉上方六片浮游砲（各自的框）與細雷射線
    DR=[(107,302,382,533),(293,124,551,400),(542,18,729,338),(871,18,1058,338),(1049,124,1307,400),(1218,302,1493,533)]   # x0,y0,x1,y1
    body=a.copy()
    for x0,y0,x1,y1 in DR: body[max(0,y0-6):y1+6,max(0,x0-6):x1+6]=0
    top=body[:600]>100; top=ndimage.binary_opening(top,iterations=4)
    body[:600]=np.where(top,body[:600],0)
    lab,n=ndimage.label(body>60); sizes=ndimage.sum(np.ones_like(lab),lab,range(1,n+1)); keep=np.argmax(sizes)+1
    body=np.where(ndimage.binary_dilation(lab==keep,iterations=2),body,0).astype(np.uint8)
    ys,xs=np.where(body>60); y0,y1,x0,x1=ys.min(),ys.max(),xs.min(),xs.max()
    print('body bbox',x0,y0,x1,y1,'core rel to bbox center',800-(x0+x1)/2,809-(y0+y1)/2)
    img=save(rgb,body,(y0,x0,y1+1,x1+1),R+'enemies/boss_bg_fortress.png',560)
    sc=560/max(x1-x0+9,y1-y0+9); cx,cy=(x0+x1)/2,(y0+y1)/2
    print('scale',sc,'core',((800-cx)*sc,(809-cy)*sc))
    for i,(x0_,y0_,x1_,y1_) in enumerate(DR): print('drone',i,'slot',(((x0_+x1_)/2-cx)*sc,((y0_+y1_)/2-cy)*sc))
    # 浮游砲：取最上面那片（右上方向朝內），轉成砲口朝下
    x0_,y0_,x1_,y1_=DR[2]; sub=a[y0_:y1_,x0_:x1_].copy()
    lab,n=ndimage.label(sub>100); sizes=ndimage.sum(np.ones_like(lab),lab,range(1,n+1)); sub=np.where(ndimage.binary_dilation(lab==np.argmax(sizes)+1,iterations=2),sub,0).astype(np.uint8)
    d=Image.fromarray(np.dstack([rgb[y0_:y1_,x0_:x1_],sub]),'RGBA')
    # 這片砲口朝右下（約 62° 向下偏右），轉到正下方
    d=d.rotate(-28,expand=True,resample=Image.BICUBIC); bb=d.getbbox(); d=d.crop(bb); s=96/max(d.size)
    d.resize((round(d.width*s),round(d.height*s)),Image.LANCZOS).save(R+'enemies/bg_float_cannon.png'); print('drone',d.size)
    # 絕招一：中央紅光球（圓形裁切、邊緣淡出）
    rgb15,a15=key_green('1000027313-9cdd6400787b.png')
    cx,cy,r=800,800,240; yy,xx=np.mgrid[cy-r:cy+r,cx-r:cx+r]; rr=np.hypot(xx-cx,yy-cy)
    fade=np.clip((r-rr)/70,0,1); al=(a15[cy-r:cy+r,cx-r:cx+r]*fade).astype(np.uint8)
    Image.fromarray(np.dstack([rgb15[cy-r:cy+r,cx-r:cx+r],al]),'RGBA').resize((360,360),Image.LANCZOS).save(R+'fx/bg_focus_orb.png')
    # 最終絕招：黑洞核心（圓形裁切）、光柱一段（轉成直的，可上下平鋪）
    rgb16,a16=key_green('1000027312-ced7df21b26b.png')
    cx,cy,r=1110,555,170; yy,xx=np.mgrid[cy-r:cy+r,cx-r:cx+r]; rr=np.hypot(xx-cx,yy-cy)
    fade=np.clip((r-rr)/60,0,1); al=(a16[cy-r:cy+r,cx-r:cx+r]*fade).astype(np.uint8)
    Image.fromarray(np.dstack([rgb16[cy-r:cy+r,cx-r:cx+r],al]),'RGBA').resize((300,300),Image.LANCZOS).save(R+'fx/bg_blackhole.png')
    def seam(A,k):
        # 無縫：輸出 = A[:h-k]，最上面 k 列由 A[h-k:] 漸變到 A[:k]（循環時底接頂剛好連續）
        h=A.shape[0]; t=np.linspace(0,1,k).reshape((k,)+(1,)*(A.ndim-1))
        out=A[:h-k].copy(); out[:k]=A[h-k:]*(1-t)+A[:k]*t
        return out
    strip=np.dstack([rgb16[430:680,10:270],a16[430:680,10:270]]).astype(float)
    rr,gg,bb=strip[...,0],strip[...,1],strip[...,2]
    keep=np.maximum(np.clip((rr-gg-30)/70,0,1),np.clip((np.minimum(np.minimum(rr,gg),bb)-200)/40,0,1))
    strip[...,3]*=keep; strip=strip.astype(np.uint8)
    S=np.array(Image.fromarray(strip,'RGBA').rotate(90,expand=True)).astype(float)
    S=seam(S,60); Image.fromarray(np.clip(S,0,255).astype(np.uint8),'RGBA').save(R+'fx/bg_annihilation_beam.png'); print('beam strip',S.shape)
    # 背景：主背景（粒子加強版）＋遠景
    def tile(src,out,w=720):
        img=Image.open(U+src).convert('RGB'); img=img.resize((w,round(img.height*w/img.width)),Image.LANCZOS)
        A=seam(np.array(img).astype(float),90)
        Image.fromarray(np.clip(A,0,255).astype(np.uint8)).save(R+out,quality=88); print(out,A.shape)
    tile('1000027321-875a08e082ac.webp','terrain/bg_redsea.jpg')
    tile('1000027314-8dcf9aa44fab.webp','terrain/bg_redsea_far.jpg')
    # 紅色大光球（由粉紅光球轉色）：大 Boss 超重砲、大兵重砲用
    o=np.array(Image.open(R+'bullets/fx_orb_pink.png').convert('RGBA')).astype(float)
    L=o[...,:3].max(axis=2); o[...,0]=np.clip(L*1.05,0,255); o[...,1]=np.clip(L*0.28,0,255); o[...,2]=np.clip(L*0.22,0,255)
    core=np.clip((L-200)/55,0,1); o[...,1]+=core*150; o[...,2]+=core*120
    Image.fromarray(np.clip(o,0,255).astype(np.uint8),'RGBA').save(R+'bullets/fx_orb_red.png')
