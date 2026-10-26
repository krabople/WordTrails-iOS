"""Record only the running UI test's gameplay, never Simulator startup."""
import subprocess, os, time
from pathlib import Path
sim=os.environ['SIMULATOR_ID']
command=['xcodebuild','test-without-building','-project','WordTrails.xcodeproj','-scheme','WordTrails','-destination',f'platform=iOS Simulator,id={sim}','-derivedDataPath','.build/DerivedData','-parallel-testing-enabled','NO','-only-testing:WordTrailsUITests/StoreMediaTests/testRecordGameplay','-resultBundlePath','.build/Recording.xcresult','CODE_SIGNING_ALLOWED=NO']
def docs():
 r=subprocess.run(['xcrun','simctl','get_app_container',sim,'com.krabople.wordtrails.uitests.xctrunner','data'],capture_output=True,text=True)
 return Path(r.stdout.strip())/'Documents' if r.returncode==0 else None
d=docs()
if d:
 for name in ['ready','started','done']:(d/('store-video-'+name)).unlink(missing_ok=True)
with open('.build/recording-test.log','w') as log:
 test=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT)
 deadline=time.monotonic()+480
 while time.monotonic()<deadline:
  d=docs()
  if d and (d/'store-video-ready').exists():break
  if test.poll() is not None:raise SystemExit('Recording UI test exited before ready')
  time.sleep(1)
 else:raise SystemExit('Recording UI test did not become ready')
 output=Path('.build/store-media');output.mkdir(parents=True,exist_ok=True)
 recorder=subprocess.Popen(['xcrun','simctl','io',sim,'recordVideo','--codec=h264',str(output/'Gameplay-original.mp4')])
 try:
  time.sleep(1)
  (d/'store-video-started').touch()
  deadline=time.monotonic()+180
  while not (d/'store-video-done').exists() and time.monotonic()<deadline:
   if test.poll() is not None:break
   time.sleep(.5)
 finally:
  recorder.send_signal(2);recorder.wait(timeout=30)
 result=test.wait(timeout=180)
 if result:raise SystemExit(result)
 if not (d/'store-video-done').exists():raise SystemExit('Gameplay recording incomplete')
