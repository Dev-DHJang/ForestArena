extends SceneTree
const Fixture := preload("res://_workspace/motion-naturalness-v1/qa/lan-launch-release-visual-r02/client-fixture.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok: bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func image_for(values:Array[int])->Image:
 var im:=Image.create(140,12,false,Image.FORMAT_RGBA8)
 im.fill(Color(0.2,0.2,0.2,1))
 for k:int in 64:
  var on:bool=(values[k/8]&(1<<(k%8)))!=0
  for x:int in range(4+k*2,6+k*2):
   for y:int in range(4,8):im.set_pixel(x,y,Color.WHITE if on else Color.BLACK)
 return im
func _initialize()->void:
 for stamp:int in [0,1,255,256,32767,65535,65536,65537]:
  for frame:int in [0,4,12,13,14,15,255]:
   for slot:int in [0,1]:
    for motion:String in ["launch","jump","idle"]:
     for flipped:bool in [false,true]:
      var b:Array[int]=Fixture.marker_bytes(stamp,frame,slot,motion,flipped)
      var mc:int={"launch":1,"jump":2}.get(motion,0)
      check(b.size()==8 and b[0]==165 and b[1]==90 and b[2]+256*b[3]==stamp%65536,"marker identity")
      check(b[4]==frame and b[5]==slot+1 and b[6]==mc+int(flipped)*128,"pose and client separation")
      var xorv:=0
      for v:int in b:xorv=xorv^v
      check(xorv==0,"xor checksum")
      var im:=image_for(b)
      check(Fixture.decoded_marker(im)==b,"independent pixel encoder to production decoder")
 var b:Array[int]=Fixture.marker_bytes(401,14,1,"launch",true)
 for bit:int in 64:
  var im:=image_for(b)
  var x:int=5+bit*2
  var col:=im.get_pixel(x,5)
  im.set_pixel(x,5,Color.BLACK if col.r>0.5 else Color.WHITE)
  check(Fixture.decoded_marker(im)!=b,"one-bit pixel corruption rejected")
 print("MARKER_BOUNDARY_INDEPENDENT: "+("PASS" if failures.is_empty() else "FIX")+" (%d checks)"%checks)
 for failure:String in failures:printerr(failure)
 root.get_node("ForestArenaAudio").shutdown()
 quit(0 if failures.is_empty() else 1)
