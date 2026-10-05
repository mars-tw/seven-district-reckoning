"""Verify and package an exported Windows game; never export, publish or copy source trees."""
import argparse
import ctypes
import hashlib
import importlib.util
import json
import re
import shutil
import struct
import subprocess
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / 'deliverables/windows'
SOURCE = 'https://github.com/mars-tw/seven-district-reckoning/blob/main/'
PACK_READER = 'https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/file_access_pack.cpp'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inspect_pe(data):
    if data[:2] != b'MZ': raise ValueError('Not a Windows executable')
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    if data[pe:pe+4] != b'PE\0\0': raise ValueError('PE header is missing')
    machine, sections = struct.unpack_from('<HH', data, pe+4)
    optional_size = struct.unpack_from('<H', data, pe+20)[0]
    optional = pe+24
    if machine != 0x8664 or struct.unpack_from('<H', data, optional)[0] != 0x20B:
        raise ValueError('Expected an x86_64 PE32+ executable')
    entries=[]
    for index in range(sections):
        position=optional+optional_size+index*40
        virtual_size, virtual_address, raw_size, raw_offset=struct.unpack_from('<IIII',data,position+8)
        entries.append((virtual_address,max(virtual_size,raw_size),raw_offset))
    def offset(rva):
        for address,size,raw in entries:
            if address<=rva<address+size: return raw+rva-address
        raise ValueError('PE import address is outside the image')
    imports=[]
    import_rva=struct.unpack_from('<I',data,optional+112+8)[0]
    if import_rva:
        position=offset(import_rva)
        for _ in range(256):
            descriptor=struct.unpack_from('<IIIII',data,position)
            if not any(descriptor): break
            name=offset(descriptor[3]); end=data.index(b'\0',name)
            imports.append(data[name:end].decode('ascii'))
            position+=20
        else: raise ValueError('PE import table is not terminated')
    return {'architecture':'x86_64','imported_dlls':sorted(set(imports))}


def inspect_pack(data):
    # Uses the official Godot 4.7.2 footer and V2/V3/V4 directory format.
    if data[-4:] != b'GDPC': raise ValueError('Embedded PCK footer is missing')
    size=struct.unpack_from('<Q',data,len(data)-12)[0]
    start=len(data)-12-size
    if start<0 or data[start:start+4] != b'GDPC': raise ValueError('Embedded PCK offset is invalid')
    version,major,minor,patch,flags=struct.unpack_from('<IIIII',data,start+4)
    if version not in (2,3,4) or flags&1: raise ValueError('Unsupported or encrypted PCK directory')
    file_base=struct.unpack_from('<Q',data,start+24)[0]
    if version in (3,4) or flags&2: file_base+=start
    position=start+100 if version==2 else start+struct.unpack_from('<Q',data,start+32)[0]
    count=struct.unpack_from('<I',data,position)[0]; position+=4
    if not 1<=count<=100000: raise ValueError('Invalid PCK resource count')
    files={}
    for _ in range(count):
        length=struct.unpack_from('<I',data,position)[0]; position+=4
        if not 1<=length<=16384: raise ValueError('Invalid PCK resource path length')
        name=data[position:position+length].rstrip(b'\0').decode('utf-8').removeprefix('res://'); position+=length
        relative,length=struct.unpack_from('<QQ',data,position); md5=data[position+16:position+32]
        file_flags=struct.unpack_from('<I',data,position+32)[0]; position+=36
        if file_flags: raise ValueError('Expected ordinary unencrypted resources')
        begin=file_base+relative; end=begin+length
        if name in files or not start<=begin<=end<=len(data)-12: raise ValueError('Duplicate or out-of-range PCK resource')
        payload=data[begin:end]
        if hashlib.md5(payload).digest()!=md5: raise ValueError('PCK resource checksum failed: '+name)
        files[name]=payload
    return {'format':version,'engine_version':f'{major}.{minor}.{patch}','bytes':size,'offset':start,'resource_count':count},files


def pe_versions(executable):
    if sys.platform!='win32': raise RuntimeError('PE version verification requires the Windows release host')
    api=ctypes.windll.version
    api.GetFileVersionInfoSizeW.argtypes=[ctypes.c_wchar_p,ctypes.POINTER(ctypes.c_uint)]
    api.GetFileVersionInfoSizeW.restype=ctypes.c_uint
    api.GetFileVersionInfoW.argtypes=[ctypes.c_wchar_p,ctypes.c_uint,ctypes.c_uint,ctypes.c_void_p]
    api.VerQueryValueW.argtypes=[ctypes.c_void_p,ctypes.c_wchar_p,ctypes.POINTER(ctypes.c_void_p),ctypes.POINTER(ctypes.c_uint)]
    size=api.GetFileVersionInfoSizeW(str(executable),None)
    if not size: raise ValueError('Windows version resources are missing')
    buffer=ctypes.create_string_buffer(size)
    if not api.GetFileVersionInfoW(str(executable),0,size,buffer): raise ValueError('Cannot read Windows version resources')
    pointer=ctypes.c_void_p(); length=ctypes.c_uint()
    if not api.VerQueryValueW(buffer,'\\',ctypes.byref(pointer),ctypes.byref(length)): raise ValueError('Fixed file version is missing')
    values=ctypes.cast(pointer,ctypes.POINTER(ctypes.c_uint32))
    if values[0]!=0xFEEF04BD: raise ValueError('Invalid Windows version signature')
    def version(ms,ls): return f'{ms>>16}.{ms&65535}.{ls>>16}.{ls&65535}'
    return {'file_version':version(values[2],values[3]),'product_version':version(values[4],values[5])}


def notice_files():
    result={name:ROOT/name for name in ['LICENSE','CREDITS.md','LICENSE-ASSETS.md']}
    for source in sorted((ROOT/'assets/provenance').glob('*.txt')):
        result['licenses/'+source.name]=source
    result['licenses/NotoSansTC-OFL.txt']=ROOT/'godot/assets/fonts/OFL.txt'
    result['licenses/MakeHuman-ASSETS-CC0.txt']=ROOT/'assets/source/makehuman/LICENSE.ASSETS.md'
    result['licenses/MakeHuman-source-notice.md']=ROOT/'assets/provenance/v03-human-assets.md'
    for name,source in result.items():
        if any(value in name.lower() for value in ('credential','.env','.pem','.key')): raise ValueError('Private filename cannot be packaged')
        text=source.read_text(encoding='utf-8-sig')
        if re.search(r'-----BEGIN [A-Z ]*PRIVATE KEY-----|\bgithub_pat_[A-Za-z0-9_]{20,}|\bghp_[A-Za-z0-9]{30,}',text):
            raise ValueError('Potential credential in a notice; refusing to package '+name)
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version',help='Must equal the current project version')
    args=parser.parse_args()
    version=re.search(r'^config/version="([^"]+)"', (ROOT/'godot/project.godot').read_text(encoding='utf-8'),re.M)[1]
    if args.version and args.version!=version: raise ValueError('Requested and actual project versions differ')
    if not re.fullmatch(r'\d+\.\d+\.\d+',version): raise ValueError('Only a numbered release can be packaged')
    executable=DIRECTORY/'SevenDistrict.exe'
    data=executable.read_bytes()
    pe=inspect_pe(data); versions=pe_versions(executable)
    if set(versions.values())!={version+'.0'}: raise ValueError('PE metadata does not match the actual project version')
    pack,resources=inspect_pack(data)
    if pack['engine_version']!='4.7.2': raise ValueError('Expected the official Godot 4.7.2 pack format')
    if list(DIRECTORY.glob('*.pck')): raise ValueError('Embedded PCK release must not include a second external PCK')
    forbidden=[name for name in resources if name.startswith('_checks/') or 'notosanstc-regular' in name.lower()]
    if forbidden: raise ValueError('Fixture/full-source-font resources remain in the release')
    needed=['project.binary','data/taiwan_life.json','data/taiwan_expansion.json','data/device_profiles.json','data/taiwan_activities.json','data/taiwan_asset_manifest.json','data/taiwan_people_manifest.json']
    if any(name not in resources for name in needed): raise ValueError('Current 0.4 resources are missing')
    for name in needed[1:]:
        if resources[name]!=(ROOT/'godot'/name).read_bytes(): raise ValueError('Pack source mismatch: '+name)
    if version.encode() not in resources['project.binary']: raise ValueError('Embedded project config version is missing')
    if b'res://scenes/main.tscn' not in resources['project.binary']: raise ValueError('Original main scene is not configured')
    model_ids=json.loads(resources['data/taiwan_people_manifest.json'])['characters']
    if not all(any(item['name'] in name for name in resources) for item in model_ids): raise ValueError('A Taiwan character was not packaged')
    runtime=subprocess.run([str(executable),'--version'],cwd=DIRECTORY,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=15,
                           creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    runtime_version=runtime.stdout.strip()
    if runtime.returncode or not runtime_version.startswith('4.7.2.stable.official.'):
        raise ValueError('The exported runtime is not official Godot 4.7.2 stable')
    run=[str(executable),'--headless','--quiet','--language','en','--quit-after','5']
    startup=subprocess.run(run,cwd=DIRECTORY,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90,
                           creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    output=startup.stdout+startup.stderr
    local=ROOT/'qa/local'; local.mkdir(parents=True,exist_ok=True)
    (local/'v04-windows-startup.log').write_text(output,encoding='utf-8')
    if startup.returncode or re.search(r'SCRIPT ERROR:|ERROR:|Failed loading resource|Parse Error',output,re.I):
        raise ValueError('Quiet original-title startup failed; inspect the ignored startup log')
    sources=notice_files()
    paths=['SevenDistrict.exe']
    for runtime in sorted(DIRECTORY.glob('*.dll'))+sorted(DIRECTORY.glob('*.console.exe')):
        paths.append(runtime.name)
    mapping={source.relative_to(ROOT).as_posix():name for name,source in sources.items()}
    def rewrite(match):
        target=match[1]
        if re.match(r'^(?:https?://|#|mailto:)',target): return match[0]
        return ']('+mapping.get(target,SOURCE+target.removeprefix('./'))+')'
    for name,source in sources.items():
        target=DIRECTORY/name; target.parent.mkdir(parents=True,exist_ok=True)
        if source.suffix=='.md': target.write_text(re.sub(r'\]\(([^)]+)\)',rewrite,source.read_text(encoding='utf-8-sig')),encoding='utf-8')
        else: shutil.copy2(source,target)
        paths.append(name)
    (DIRECTORY/'PLAY.txt').write_text(
        f'Seven District: Break the Chain - Alpha {version}\nRun SevenDistrict.exe. Godot and Blender are not required.\n'
        'WASD move; Shift sprint; mouse look; left-click attack; E interact; F mount/dismount;\n'
        'Q tool; Space jump/brake; R recover vehicle; Tab missions; M map; J life jobs; Esc pause; F5/F9 save/load.\n'
        'Single player, fictional 800 x 800 m neighbourhood; no real account, order or payment connection.\n'
        'This unsigned alpha has arcade vehicles and incomplete full campaign features.\n'
        'Source: https://github.com/mars-tw/seven-district-reckoning\n',encoding='utf-8')
    (DIRECTORY/'runtime-notices.txt').write_text(
        f'Alpha {version} runtime and asset notices\n'
        'Godot 4.7.2 runtime: MIT; licenses/Godot-LICENSE.txt and licenses/Godot-COPYRIGHT.txt.\n'
        'Original code/docs: LICENSE (MIT). Assets retain individual rights in CREDITS.md and LICENSE-ASSETS.md.\n'
        'Kenney/original street and character adaptations: CC0; complete retained notices are in licenses/.\n'
        'MakeHuman CC0 body/rig source: licenses/MakeHuman-ASSETS-CC0.txt and MakeHuman-source-notice.md.\n'
        'Poly by Google bicycle: CC BY 3.0; licenses/CC-BY-3.0.txt, attribution/modification details in CREDITS.md.\n'
        'Seven District Sans TC derived font: SIL OFL 1.1; licenses/NotoSansTC-OFL.txt.\n'
        'Original synthesized audio by Seven District contributors: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/.\n'
        'No source archives, private reports, credentials, full source font or test fixtures are redistributed in this binary package.\n',encoding='utf-8')
    paths+=['PLAY.txt','runtime-notices.txt']
    spec=importlib.util.spec_from_file_location('release_source_audit',ROOT/'tools/test_game.py')
    source_audit=importlib.util.module_from_spec(spec); spec.loader.exec_module(source_audit)
    report={'version':version,'status':'VERIFIED','scope':'native x64 embedded-pack integrity, quiet 5-frame original-title headless startup and redistribution package; no rendering/full-playthrough claim',
            'verified_at':datetime.now(timezone.utc).isoformat(),'exe_bytes':len(data),'exe_sha256':digest(data),**pe,**versions,'runtime_version':runtime_version,'pack':pack,
            'source_fingerprint':source_audit.source_fingerprint(ROOT/'godot'),
            'excluded_checks_and_source_font':True,'startup':{'frames':5,'headless':True,'returncode':startup.returncode,'output_bytes':len(output.encode()),'custom_scene_or_script':False,'play_or_save_command':False},
            'runtime_files':[name for name in paths if name.lower().endswith(('.exe','.dll'))],'license_files':sorted(sources),'pack_reader_reference':PACK_READER}
    archive=ROOT/'deliverables'/f'SevenDistrict-{version}-Windows-x64.zip'
    folder=f'SevenDistrict-{version}-Windows-x64'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as package:
        for name in sorted(paths):
            info=zipfile.ZipInfo(folder+'/'+name,date_time=(2026,1,1,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED; info.external_attr=0o100644<<16
            package.writestr(info,(DIRECTORY/name).read_bytes())
    with zipfile.ZipFile(archive) as package:
        if package.testzip() is not None: raise ValueError('Archive CRC failed')
        if any('credential' in name.lower() or '/_checks/' in name or name.endswith('.pck') for name in package.namelist()): raise ValueError('Unexpected private or duplicate payload entry')
        if package.read(folder+'/SevenDistrict.exe')!=data: raise ValueError('Archived executable differs from verified binary')
    report.update(archive=archive.relative_to(ROOT).as_posix(),archive_bytes=archive.stat().st_size,archive_sha256=digest(archive.read_bytes()),archive_files=len(paths))
    (local/'v04-windows-package.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    (archive.with_suffix('.zip.sha256')).write_text(report['archive_sha256']+'  '+archive.name+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__': main()
