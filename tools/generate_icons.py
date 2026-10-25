"""Deterministic density export; requires Pillow. Does not regenerate artwork."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
RES=ROOT/'android/app/src/main/res'
OUT=ROOT/'assets/images'
im=Image.open(OUT/'diraasa_symbol_source.png').convert('RGBA')
# Ignore fully transparent margins, preserve all visible pixels and alpha.
box=im.getchannel('A').getbbox()
symbol=im.crop(box)
def fitted(size,fraction):
    result=Image.new('RGBA',(size,size))
    icon=symbol.copy()
    icon.thumbnail((round(size*fraction),round(size*fraction)),Image.Resampling.LANCZOS)
    result.alpha_composite(icon,((size-icon.width)//2,(size-icon.height)//2))
    return result
def opaque(image,color):
    bg=Image.new('RGBA',image.size,color)
    bg.alpha_composite(image)
    return bg.convert('RGB')
fitted(1024,.90).save(OUT/'diraasa_internal.png')
opaque(fitted(1024,.76),'#F5F0E5').save(OUT/'diraasa_launcher.png')
fitted(1152,.68).save(OUT/'diraasa_splash.png')
for density,scale in [('mdpi',1),('hdpi',1.5),('xhdpi',2),('xxhdpi',3),('xxxhdpi',4)]:
    mip=RES/('mipmap-'+density);mip.mkdir(exist_ok=True)
    opaque(fitted(round(48*scale),.76),'#F5F0E5').save(mip/'ic_launcher.png')
    opaque(fitted(round(48*scale),.66),'#F5F0E5').save(mip/'ic_launcher_round.png')
    draw=RES/('drawable-'+density);draw.mkdir(exist_ok=True)
    fg=fitted(round(108*scale),.58)
    fg.save(draw/'ic_launcher_foreground.png')
    mono=Image.new('RGBA',fg.size,'white')
    mono.putalpha(fg.getchannel('A'))
    mono.save(draw/'ic_launcher_monochrome.png')
    fitted(round(192*scale),.68).save(draw/'launch_image.png')
# Internal QA only, white and black backgrounds.
preview=Image.new('RGB',(800,400))
for x,color in [(0,'white'),(400,'black')]:
    preview.paste(opaque(fitted(400,.68),color),(x,0))
preview.save(ROOT.parent/'icon_qa.png')
print('Exported launcher, adaptive foreground, internal and padded splash in 5 densities.')
