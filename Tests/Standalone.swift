import Foundation
import CoreAudio
import AudioDSP
@main struct Checks {
 static func main() throws {
 var checks=0
 func verify(_ condition:Bool,_ name:String){precondition(condition,name);checks += 1;print("PASS \(name)")}
 verify(groupID("com.google.Chrome.helper.renderer")=="com.google.Chrome","Chrome helpers grouped")
 verify(groupID("com.google.ChromeCanary")=="com.google.ChromeCanary","Other browser identity preserved")
 verify(groupID("com.spotify.client.helper")=="com.spotify.client","Spotify helpers grouped")
 var a=Level(),b=Level();a.volume=25;verify(a.gain==0.25 && b.gain==1,"Independent volume");b.muted=true;verify(b.gain==0 && a.gain==0.25,"Independent mute");b.muted=false;verify(b.gain==1,"Unmute restores level");a.volume = -1;verify(a.gain==0,"Lower clamp");a.volume=120;verify(a.gain==1,"Upper clamp")
 let state=mixer_create()!;defer{mixer_free(state)}
 func render(_ gain:Float)->[Float]{mixer_gain(state,gain);var src:[Float]=[1,1,1,1];var dst=[Float](repeating:0,count:4);src.withUnsafeMutableBytes{ip in dst.withUnsafeMutableBytes{op in var i=AudioBufferList(mNumberBuffers:1,mBuffers:AudioBuffer(mNumberChannels:2,mDataByteSize:16,mData:ip.baseAddress));var o=AudioBufferList(mNumberBuffers:1,mBuffers:AudioBuffer(mNumberChannels:2,mDataByteSize:16,mData:op.baseAddress));var t=AudioTimeStamp();_ = mixer_io(0,&t,&i,&t,&o,&t,UnsafeMutableRawPointer(state))}};return dst}
 verify(render(0.5)==[0.75,0.75,0.5,0.5],"Smooth stereo gain ramp");_ = render(0);verify(render(0)==[0,0,0,0],"DSP silence");_ = render(1);verify(render(1)==[1,1,1,1],"DSP unity restoration");verify(mixer_ticks(state)==5,"Callback heartbeat")
 var bad=AudioBufferList(mNumberBuffers:0,mBuffers:AudioBuffer());var output=AudioBufferList(mNumberBuffers:1,mBuffers:AudioBuffer());var t=AudioTimeStamp();_ = mixer_io(0,&t,&bad,&t,&output,&t,UnsafeMutableRawPointer(state));verify(mixer_failed(state)==1,"Topology mismatch fail-safe")
 print("\(checks) checks passed. No process tap was created.")
 let groups=try discover();print("Read-only process discovery: \(groups.count) app groups")
 }
}
