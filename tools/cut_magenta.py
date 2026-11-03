# 洋紅色背景去背＋自動切割素材表
import numpy as np
from PIL import Image
from scipy import ndimage
def key(src):
    im=np.array(Image.open(src).convert('RGB')).astype(float)
    r,g,b=im[...,0],im[...,1],im[...,2]
    mag=np.minimum(r,b)-g          # 洋紅程度
    bg=(mag>90)&(r>110)&(b>90)
    soft=np.clip((mag-60)/50,0,1)*(r>90)*(b>70)
    alpha=1-np.maximum(bg*1.0,soft)
    # 去洋紅溢色
    sp=np.clip(np.minimum(r,b)-g-25,0,None)*(alpha<1)
    out=im.copy(); out[...,0]-=sp*0.6; out[...,2]-=sp*0.6
    out=np.clip(out,0,255)
    return out.astype(np.uint8),(alpha*255).astype(np.uint8)
def components(alpha,merge=15,minsize=4000):
    m=alpha>128
    md=ndimage.binary_dilation(m,iterations=merge)
    lab,n=ndimage.label(md)
    boxes=[]
    for i,sl in enumerate(ndimage.find_objects(lab)):
        if (lab[sl]==i+1).sum()<minsize: continue
        boxes.append((sl[0].start,sl[1].start,sl[0].stop,sl[1].stop))
    return boxes
def rows(boxes,tol=200):
    boxes=sorted(boxes,key=lambda b:(b[0]+b[2])/2)
    out=[];cur=[]
    for b in boxes:
        if cur and (b[0]+b[2])/2-(cur[0][0]+cur[0][2])/2>tol: out.append(sorted(cur,key=lambda b:b[1]));cur=[]
        cur.append(b)
    if cur: out.append(sorted(cur,key=lambda b:b[1]))
    return out
def save(rgb,alpha,box,out,maxsz,rot=0,pad=4):
    y0,x0,y1,x1=box
    y0=max(0,y0-pad);x0=max(0,x0-pad);y1=min(rgb.shape[0],y1+pad);x1=min(rgb.shape[1],x1+pad)
    img=Image.fromarray(np.dstack([rgb[y0:y1,x0:x1],alpha[y0:y1,x0:x1]]),'RGBA')
    if rot: img=img.rotate(rot,expand=True,resample=Image.BICUBIC)
    w,h=img.size;s=maxsz/max(w,h)
    img=img.resize((max(1,round(w*s)),max(1,round(h*s))),Image.LANCZOS); img.save(out); print(out,img.size); return img
