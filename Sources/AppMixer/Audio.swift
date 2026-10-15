import AppKit
import CoreAudio
import AudioDSP

struct AudioFailure: LocalizedError { let message: String; var errorDescription: String? { message } }
func check(_ status: OSStatus, _ action: String) throws { if status != noErr { throw AudioFailure(message: "\(action): Core Audio \(status)") } }
func address(_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress { .init(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain) }
func value<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ initial: T, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> T { var a=address(selector,scope), v=initial, size=UInt32(MemoryLayout<T>.size); try withUnsafeMutablePointer(to:&v) { ptr in try check(AudioObjectGetPropertyData(id,&a,0,nil,&size,ptr),"Read audio property") }; return v }
func ids(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> [AudioObjectID] { var a=address(selector,scope), size:UInt32=0; try check(AudioObjectGetPropertyDataSize(id,&a,0,nil,&size),"Read audio list"); var result=[AudioObjectID](repeating:0,count:Int(size)/4); try check(AudioObjectGetPropertyData(id,&a,0,nil,&size,&result),"Read audio list"); return result }
func string(_ id: AudioObjectID,_ selector: AudioObjectPropertySelector) throws -> String { var a=address(selector); var raw:Unmanaged<CFString>?; var size=UInt32(MemoryLayout<Unmanaged<CFString>?>.size); try check(AudioObjectGetPropertyData(id,&a,0,nil,&size,&raw),"Read audio identifier"); guard let raw else {throw AudioFailure(message:"Missing device identifier")}; return raw.takeRetainedValue() as String }
func groupID(_ bundle: String) -> String { for root in ["com.google.Chrome", "com.spotify.client"] { if bundle == root || bundle.hasPrefix(root+".") { return root } }; return bundle }
struct AudioGroup: Identifiable { let id: String; var name: String; var processes: [AudioObjectID]; var active: Bool }
func discover() throws -> [AudioGroup] { var groups=[String:AudioGroup](); for id in try ids(AudioObjectID(kAudioObjectSystemObject),kAudioHardwarePropertyProcessObjectList) { guard let pid = try? value(id,kAudioProcessPropertyPID,pid_t(0)), pid != getpid() else {continue}; let app=NSRunningApplication(processIdentifier:pid); let raw=(try? string(id,kAudioProcessPropertyBundleID)) ?? app?.bundleIdentifier ?? ""; guard !raw.isEmpty else {continue}; let key=groupID(raw); let active=(try? value(id,kAudioProcessPropertyIsRunningOutput,UInt32(0))) == 1; let name=key == "com.google.Chrome" ? "Google Chrome" : key == "com.spotify.client" ? "Spotify" : app?.localizedName ?? key; if groups[key] == nil { groups[key] = AudioGroup(id:key,name:name,processes:[],active:false) }; groups[key]!.processes.append(id); groups[key]!.active = groups[key]!.active || active }; return groups.values.sorted{$0.name<$1.name} }

@available(macOS 14.2, *)
final class AudioSession {
 var tap:AudioObjectID=0, device:AudioObjectID=0; var proc:AudioDeviceIOProcID?; let state=mixer_create()!; let output:AudioObjectID; let processes:[AudioObjectID]; var lastTicks:UInt=0; var misses=0
 init(group:AudioGroup, gain:Float) throws {
  output=try value(AudioObjectID(kAudioObjectSystemObject),kAudioHardwarePropertyDefaultOutputDevice,AudioObjectID(0)); processes=group.processes.sorted()
  do {
   // Reject physical-input / multichannel devices rather than guessing buffer routing.
   guard try ids(output,kAudioDevicePropertyStreams,scope:kAudioObjectPropertyScopeInput).isEmpty else { throw AudioFailure(message:"This prototype requires an output device without input streams. Try the built-in speakers.") }
   let streams=try ids(output,kAudioDevicePropertyStreams,scope:kAudioObjectPropertyScopeOutput)
   guard streams.count == 1 else { throw AudioFailure(message:"Only a single stereo output stream is supported.") }
   let format=try value(streams[0],kAudioStreamPropertyVirtualFormat,AudioStreamBasicDescription())
   guard format.mFormatID == kAudioFormatLinearPCM, format.mFormatFlags & kAudioFormatFlagIsFloat != 0, format.mBitsPerChannel == 32, format.mChannelsPerFrame == 2 else {throw AudioFailure(message:"Float32 stereo output is required.")}
   let uid=try string(output,kAudioDevicePropertyDeviceUID)
   let desc=CATapDescription(processes:group.processes,deviceUID:uid,stream:0); desc.name="AppMixer \(group.name)"; desc.isPrivate=true; desc.muteBehavior = .mutedWhenTapped
   try check(AudioHardwareCreateProcessTap(desc,&tap),"Create audio tap (system audio recording access required)")
   let tapFormat=try value(tap,kAudioTapPropertyFormat,AudioStreamBasicDescription())
   guard tapFormat.mSampleRate == format.mSampleRate, tapFormat.mChannelsPerFrame == format.mChannelsPerFrame, tapFormat.mFormatFlags == format.mFormatFlags, tapFormat.mBitsPerChannel == 32 else {throw AudioFailure(message:"Tap and output formats are incompatible. Original audio restored.")}
   let spec:[String:Any]=[kAudioAggregateDeviceNameKey:"AppMixer Private", kAudioAggregateDeviceUIDKey:UUID().uuidString,kAudioAggregateDeviceIsPrivateKey:true,kAudioAggregateDeviceMainSubDeviceKey:uid,kAudioAggregateDeviceSubDeviceListKey:[[kAudioSubDeviceUIDKey:uid]],kAudioAggregateDeviceTapListKey:[[kAudioSubTapUIDKey:desc.uuid.uuidString,kAudioSubTapDriftCompensationKey:true]],kAudioAggregateDeviceTapAutoStartKey:true]
   try check(AudioHardwareCreateAggregateDevice(spec as CFDictionary,&device),"Create private playback device")
   mixer_gain(state,gain)
   try check(AudioDeviceCreateIOProcID(device,mixer_io,UnsafeMutableRawPointer(state),&proc),"Create playback callback")
   try check(AudioDeviceStart(device,proc),"Start playback")
  } catch { stop(); throw error }
 }
 func gain(_ v:Float) {mixer_gain(state,v)}
 func healthy() -> Bool {let ticks=mixer_ticks(state); misses = ticks == lastTicks ? misses+1 : 0; lastTicks=ticks; return mixer_failed(state)==0 && misses<3}
 func stop() {if let p=proc {AudioDeviceStop(device,p); AudioDeviceDestroyIOProcID(device,p); proc=nil}; if device != 0 {AudioHardwareDestroyAggregateDevice(device);device=0}; if tap != 0 {AudioHardwareDestroyProcessTap(tap);tap=0}}
 deinit {stop();mixer_free(state)}
}

// Creating an unmuted, empty inclusion tap lets macOS handle consent even
// when no other application is playing. It is never attached or read.
@available(macOS 14.2, *)
func requestAudioAccess() throws {
 let description = CATapDescription(stereoMixdownOfProcesses: [])
 description.name = "AppMixer Audio Access"
 description.isPrivate = true
 description.muteBehavior = .unmuted
 var tap: AudioObjectID = 0
 let status = AudioHardwareCreateProcessTap(description, &tap)
 defer { if tap != 0 { AudioHardwareDestroyProcessTap(tap) } }
 try check(status, "Unable to enable audio access. Check audio recording permissions in System Settings, then enable again.")
}
