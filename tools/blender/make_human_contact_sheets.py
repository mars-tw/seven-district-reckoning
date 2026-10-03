"""Compose rendered validation views with labels; no geometry is fabricated."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2];QA=ROOT/'qa/art/v03-human'
rows=json.loads((QA/'manifest.json').read_text(encoding='utf-8'))['characters']
rows=sorted(rows,key=lambda r:['hero_human','guard_human','civilian_human','mei_human','yuan_human','zhou_human'].index(r['name']))
try:font=ImageFont.truetype('C:/Windows/Fonts/msjh.ttc',18)
except OSError:font=ImageFont.load_default()

def paste_view(canvas,path,xy,size):
 im=Image.open(path).convert('RGBA');im.thumbnail(size)
 x,y=xy;canvas.paste(im,(x+(size[0]-im.width)//2,y),im)

lineup=Image.new('RGB',(1920,480),'white');draw=ImageDraw.Draw(lineup)
for i,row in enumerate(rows):
 paste_view(lineup,QA/(row['name']+'_front.png'),(320*i,12),(310,405))
 draw.text((320*i+12,425),row['label'].split('｜')[0],fill='#1c2630',font=font)
 draw.text((320*i+12,450),f"{row['height_m']:.2f}m / {row['triangles']:,} tris",fill='#455565',font=font)
lineup.save(QA/'character-lineup.png')

turn=Image.new('RGB',(1200,6*360),'white');draw=ImageDraw.Draw(turn)
for row_index,row in enumerate(rows):
 for col,view in enumerate(['front','side','back','face']):
  x=300*col;y=360*row_index;paste_view(turn,QA/(row['name']+'_'+view+'.png'),(x,y),(290,322))
  draw.text((x+6,y+330),row['name']+' / '+view,fill='#26323d',font=font)
turn.save(QA/'human-turnarounds.png')

clips=['idle','walk','run','attack','hit','drive','pedal','knockdown']
actions=Image.new('RGB',(1280,900),'white');draw=ImageDraw.Draw(actions)
for i,clip in enumerate(clips):
 path=QA/('hero_human_'+('front' if clip=='idle' else clip)+'.png');x=i%4*320;y=i//4*450
 paste_view(actions,path,(x,y),(310,405));draw.text((x+18,y+421),clip,fill='#26323d',font=font)
actions.save(QA/'hero-actions.png')
print('CONTACT_SHEETS',3)
