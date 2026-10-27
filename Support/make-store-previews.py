from pathlib import Path
import sys,json,subprocess,re,shutil
import argparse
parser=argparse.ArgumentParser(description="Rebuild music-backed store previews from a Word Trails media pack.")
parser.add_argument("media_pack",type=Path,help="Folder containing iPhone, iPad, Music.wav and Captions-timing.json")
parser.add_argument("--ffmpeg",default=shutil.which("ffmpeg"),help="FFmpeg executable; defaults to the version on PATH")
args=parser.parse_args()
if not args.ffmpeg:parser.error("Install FFmpeg or supply --ffmpeg /path/to/ffmpeg")
ffmpeg=args.ffmpeg
root=args.media_pack.resolve()
segments=json.loads((root/'Captions-timing.json').read_text(encoding='utf-8'))
def stamp(t,ass=False):
 h=int(t//3600);m=int(t%3600//60);s=t%60
 return f'{h}:{m:02}:{s:05.2f}' if ass else f'{h:02}:{m:02}:{s:06.3f}'.replace('.',',')
srt='\n'.join(f"{i+1}\n{stamp(s['start'])} --> {stamp(s['end'])}\n{s['text']}\n" for i,s in enumerate(segments))
(root/'Captions.srt').write_text(srt,encoding='utf-8')
for device,w,h in [('iPhone',886,1920),('iPad',1200,1600)]:
 folder=root/device;raw=folder/'Gameplay-original.mp4'
 if not raw.exists():continue
 meta=subprocess.run([ffmpeg,'-i',str(raw)],capture_output=True,text=True).stderr
 match=re.search(r'Duration: (\d+):(\d+):([\d.]+)',meta);assert match,meta
 duration=int(match[1])*3600+int(match[2])*60+float(match[3])
 ass=f'''[Script Info]
ScriptType: v4.00+
PlayResX: {w}
PlayResY: {h}
WrapStyle: 0
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,{34 if device=='iPhone' else 38},&H00F1F5F8,&H00FFFFFF,&H00244321,&H80244321,0,0,0,0,100,100,0,0,3,8,0,2,36,36,26,1
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''
 for s in segments:ass+=f"Dialogue: 0,{stamp(s['start'],True)},{stamp(s['end'],True)},Default,,0,0,0,,{s['text']}\n"
 (folder/'Captions.ass').write_text(ass,encoding='utf-8')
 command=[ffmpeg,'-y','-i',raw.name,'-i','../Music.wav','-vf',f'setpts={24/duration}*(PTS-STARTPTS),fps=30,tpad=stop_mode=clone:stop_duration=5,scale={w}:{h-120}:force_original_aspect_ratio=decrease,pad={w}:{h}:(ow-iw)/2:0:color=0xf9f7ef,setsar=1,subtitles=Captions.ass','-af','apad','-t','28','-r','30','-c:v','libx264','-profile:v','high','-level:v','4.0','-pix_fmt','yuv420p','-b:v','10M','-maxrate','12M','-bufsize','24M','-c:a','aac','-b:a','256k','-ar','48000','-ac','2','-movflags','+faststart','App-Preview-Music.mp4']
 result=subprocess.run(command,cwd=folder,capture_output=True,text=True)
 (folder/'Encoding.log').write_text(result.stderr,encoding='utf-8')
 assert result.returncode==0,result.stderr[-2500:]
 check=subprocess.run([ffmpeg,'-i',str(folder/'App-Preview-Music.mp4')],capture_output=True,text=True).stderr
 (folder/'Video-verification.txt').write_text(check,encoding='utf-8')
 print(device,check[check.find('Duration:'):check.find('At least one output')])
