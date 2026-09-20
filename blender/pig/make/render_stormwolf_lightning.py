"""Render unique lightning states, then encode the 30 fps flicker as MP4."""
from pathlib import Path
import bpy,json,shutil,sys
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT.parents[1]/'assets/skins/animal/legendary/stormwolf'
sys.path.insert(0,str(Path(__file__).parent))
from stormwolf_lightning import values
bpy.ops.wm.open_mainfile(filepath=str(OUT/'stormwolf-complete.blend'))
scene=bpy.context.scene;scene.render.resolution_x=600;scene.render.resolution_y=600
coat=bpy.data.objects['Body'].data.materials[0]
pulse=next(n for n in coat.node_tree.nodes if n.label=='Painted lightning pulse')
mask=next(n.image for n in coat.node_tree.nodes if n.label=='Body lightning emission mask')
assert mask.packed_file and tuple(mask.size)==(1024,1024)
body_strengths=[]
for frame in range(1,61):
    scene.frame_set(frame)
    actual=pulse.outputs[0].default_value
    assert abs(actual-(.35+4.65*max(values(frame))))<1e-5,(frame,actual)
    body_strengths.append(actual)
scene.render.resolution_percentage=100;scene.cycles.samples=8
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.20
for ob in scene.objects:
    if ob.type=='LIGHT':ob.data.energy*=.30
frames=OUT/'lightning-frames';frames.mkdir(exist_ok=True)
cache={};timeline=[]
for frame in range(1,61):
    state=tuple(values(frame));path=frames/f'frame-{frame:03d}.png'
    if '--encode-only' in sys.argv:
        assert path.exists(),path;cache.setdefault(state,path)
    elif state not in cache:
        scene.frame_set(frame);scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        cache[state]=path
    else:shutil.copy2(cache[state],path)
    timeline.append(path)
shutil.copy2(timeline[10],OUT/'stormwolf-lightning-on.png')
shutil.copy2(timeline[0],OUT/'stormwolf-lightning-off.png')
video=bpy.data.scenes.new('StormWolf_LightningVideo');bpy.context.window.scene=video
video.render.resolution_x=600;video.render.resolution_y=600;video.render.resolution_percentage=100
video.render.fps=30;video.frame_start=1;video.frame_end=120
video.view_settings.view_transform='Standard'
if hasattr(video.render.image_settings,'media_type'):video.render.image_settings.media_type='VIDEO'
video.render.image_settings.file_format='FFMPEG';video.render.ffmpeg.format='MPEG4';video.render.ffmpeg.codec='H264'
video.render.ffmpeg.constant_rate_factor='HIGH';video.render.filepath=str(OUT/'stormwolf-lightning.mp4')
video.render.use_sequencer=True;video.render.use_compositing=False
editor=video.sequence_editor_create();strips=editor.strips if hasattr(editor,'strips') else editor.sequences
strip=strips.new_image('Lightning frames',str(timeline[0]),channel=1,frame_start=1)
for path in (timeline+timeline)[1:]:strip.elements.append(path.name)
strip.frame_final_duration=120
bpy.ops.render.render(animation=True)
assert (OUT/'stormwolf-lightning.mp4').stat().st_size>10000
strip.mute=True
movie=strips.new_movie('Encoded preview check',str(OUT/'stormwolf-lightning.mp4'),channel=2,frame_start=1)
assert movie.frame_duration==120,movie.frame_duration
if hasattr(video.render.image_settings,'media_type'):video.render.image_settings.media_type='IMAGE'
video.render.image_settings.file_format='PNG';video.frame_set(11)
video.render.filepath=str(OUT/'lightning-video-check.png');bpy.ops.render.render(write_still=True)
report=dict(fps=30,frames=120,seconds=4,loopSeconds=2,uniqueRenderedStates=len(cache),
    bodyGlow=dict(maskPacked=True,framesVerified=60,idleStrength=min(body_strengths),peakStrength=max(body_strengths)),
    longestFlashFrames=max(max(sum(1 for _ in run) for active,run in __import__('itertools').groupby([values(f)[i]>0 for f in range(1,61)]) if active) for i in range(6)),
    offFrames=[f for f in range(1,61) if not any(values(f))],fullStrikeFrame=11)
assert report['longestFlashFrames']<=2 and report['offFrames']
(OUT/'lightning-preview-checks.json').write_text(json.dumps(report,indent=2))
print('LIGHTNING_VIDEO_READY',json.dumps(report),flush=True)
