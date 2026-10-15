import SwiftUI
import AppKit
import CoreAudio

@available(macOS 14.2, *)
@MainActor final class MixerModel: ObservableObject {
 @Published var groups=[AudioGroup](); @Published var levels=[String:Level](); @Published var message="Not enabled. macOS may request system audio recording access."; @Published var enabled=false
 let updates = UpdateModel()
 var sessions=[String:AudioSession](); var timer:Timer?; var observers=[NSObjectProtocol](); let demo=CommandLine.arguments.contains("--demo") || CommandLine.arguments.contains("--updater-smoke") || CommandLine.arguments.contains("--check-feed")
 init(){ if demo {groups=[AudioGroup(id:"com.google.Chrome",name:"Google Chrome",processes:[],active:true),AudioGroup(id:"com.spotify.client",name:"Spotify",processes:[],active:true)];message="Preview only. No audio is captured or changed."} else {refresh(); timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true){[weak self] _ in Task{@MainActor in self?.refresh()}}; observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main){[weak self] _ in Task{@MainActor in self?.stop("Mac going to sleep. Original audio restored.")}}) } }
 func refresh(){do {groups=try discover(); if enabled {let output=try value(AudioObjectID(kAudioObjectSystemObject),kAudioHardwarePropertyDefaultOutputDevice,AudioObjectID(0)); for session in sessions.values {if session.output != output || !session.healthy(){stop("Output changed or playback stopped. Original audio restored. Please enable again.");return}}; try reconcile()} }catch{stop(error.localizedDescription)}}
 func reconcile() throws {let wanted=groups.filter{$0.active || sessions[$0.id] != nil}; let keys=Set(wanted.map(\.id)); for key in Array(sessions.keys) where !keys.contains(key){sessions.removeValue(forKey:key)?.stop()}; for group in wanted { if let old=sessions[group.id], old.processes != group.processes.sorted(){old.stop();sessions.removeValue(forKey:group.id)}; if sessions[group.id] == nil && group.active {sessions[group.id]=try AudioSession(group:group,gain:(levels[group.id] ?? Level()).gain)} } }
 func start(){guard !demo, !enabled else{return}; do {
 message="Enabling. If macOS requests audio access, choose whether to allow it."
 try requestAudioAccess()
 groups=try discover()
 enabled=true
 try reconcile()
 message="Enabled · Audio stays in memory only"
 } catch {stop(error.localizedDescription)} }
 func stop(_ reason:String="Stopped. Original app audio restored.") {enabled=false;for s in sessions.values{s.stop()};sessions.removeAll();message=reason}
 func set(_ id:String,volume:Double?=nil,muted:Bool?=nil){var l=levels[id] ?? Level();if let volume {l.volume=volume};if let muted {l.muted=muted};levels[id]=l;sessions[id]?.gain(l.gain)}
}
@available(macOS 14.2, *)
struct MixerView:View {
 @ObservedObject var model:MixerModel
 @StateObject private var loginItem = LoginItemModel()
 var body:some View {VStack(alignment:.leading,spacing:16){HStack{Image(systemName:"slider.horizontal.3");Text("AppMixer").font(.title2.bold());Spacer();Text(model.demo ? "Preview" : model.enabled ? "Active" : "Standby").foregroundStyle(.secondary)}
 Text("Your apps. Your volume.").foregroundStyle(.secondary)
 if model.groups.filter({$0.active}).isEmpty {Text("No apps are playing audio. Once enabled, new playback is detected automatically.").font(.callout)}
 ForEach(model.groups.filter{$0.active || model.sessions[$0.id] != nil}){group in let level=model.levels[group.id] ?? Level(); VStack(alignment:.leading){HStack{Text(group.name).font(.headline);Spacer();Text("\(Int(level.volume))%").monospacedDigit();Button {model.set(group.id,muted:!level.muted)}label:{Image(systemName:level.muted ? "speaker.slash.fill":"speaker.wave.2.fill")}.accessibilityLabel("\(group.name) Mute").help(level.muted ? "Unmute":"Mute")};Slider(value:Binding(get:{(model.levels[group.id] ?? Level()).volume},set:{model.set(group.id,volume:$0)}),in:0...100).accessibilityLabel("\(group.name) Volume");Text("\(group.processes.count) audio processes").font(.caption).foregroundStyle(.secondary)} }
 Divider()
 VStack(alignment:.leading,spacing:8) {
 Toggle("Launch at Login",isOn:Binding(get:{loginItem.isRequested},set:{loginItem.setEnabled($0)}))
 .toggleStyle(.switch).disabled(model.demo)
 if loginItem.status == .requiresApproval {
 Text("Approval required in System Settings.").font(.caption).foregroundStyle(.secondary)
 Button("Open Login Items Settings"){loginItem.openSettings()}.disabled(model.demo)
 }
 if let error=loginItem.errorMessage {Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal:false,vertical:true)}
 }
 UpdateSettingsView(updates:model.updates, demo:model.demo)
 Text(model.message).font(.caption).fixedSize(horizontal:false,vertical:true)
 HStack{Button(model.enabled ? "Stop & Restore":"Enable Volume Control"){if model.enabled{model.stop()}else{model.start()}}.disabled(model.demo);Spacer();Button("Quit"){model.stop();NSApp.terminate(nil)}}
 }.padding(20).frame(width:360).background(Color(nsColor:.windowBackgroundColor))
 .onAppear {loginItem.refresh()}
 .onReceive(NotificationCenter.default.publisher(for:NSApplication.didBecomeActiveNotification)){_ in loginItem.refresh()}
 }
}
@available(macOS 14.2, *)
@MainActor final class AppDelegate:NSObject,NSApplicationDelegate {let model=MixerModel();
 func applicationDidFinishLaunching(_ notification:Notification) {if CommandLine.arguments.contains("--render-preview") {Task {@MainActor in
 let preview=MixerModel(); preview.set("com.google.Chrome",volume:35);precondition(preview.levels["com.google.Chrome"]?.gain == 0.35);precondition(preview.levels["com.spotify.client"] == nil);preview.set("com.spotify.client",volume:80,muted:true);precondition(preview.levels["com.spotify.client"]?.gain == 0);preview.set("com.spotify.client",muted:false);precondition(preview.levels["com.spotify.client"]?.gain == 0.8);print("PASS 4 UI model checks (demo, no audio)"); let host=NSHostingView(rootView:MixerView(model:preview)); let window=NSWindow(contentRect:NSRect(x:0,y:0,width:360,height:430),styleMask:[.titled],backing:.buffered,defer:false);window.appearance=NSAppearance(named:.aqua);window.contentView=host;window.orderFront(nil);host.layoutSubtreeIfNeeded();window.displayIfNeeded();if let rep=host.bitmapImageRepForCachingDisplay(in:host.bounds){host.cacheDisplay(in:host.bounds,to:rep);try? rep.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:FileManager.default.currentDirectoryPath+"/build/preview.png"))};NSApp.terminate(nil)
 }} else if CommandLine.arguments.contains("--check-feed") {
 model.updates.start()
 if let error=model.updates.errorMessage {fatalError(error)}
 model.updates.inspectionFinished = { error in
  if let error { print("FAIL update feed: \(error.localizedDescription)"); exit(1) }
  print("PASS live signed update feed (information only, no download/install/audio)"); NSApp.terminate(nil)
 }
 model.updates.inspectFeed()
 DispatchQueue.main.asyncAfter(deadline:.now()+30) {print("FAIL update feed timeout");exit(1)}
 } else if CommandLine.arguments.contains("--updater-smoke") {
 model.updates.start(); precondition(model.updates.errorMessage == nil, model.updates.errorMessage ?? ""); precondition(model.updates.canCheck); print("PASS Sparkle initialization and configuration (no update check or audio capture)"); NSApp.terminate(nil)
 } else if !model.demo {
 model.updates.beforeInstall = { [weak model] in model?.stop("Installing update. Original audio restored.") }
 model.updates.start(); model.start()
 }}
 func applicationWillTerminate(_ notification:Notification){MainActor.assumeIsolated{model.stop()}}}
@main struct AppMixerApp:App {
 @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
 var body:some Scene {MenuBarExtra("AppMixer",systemImage:"slider.horizontal.3"){MixerView(model:delegate.model)}.menuBarExtraStyle(.window);Window("AppMixer",id:"preview"){MixerView(model:delegate.model)} }
}

@MainActor
struct UpdateSettingsView: View {
 @ObservedObject var updates: UpdateModel
 let demo: Bool
 var body: some View {
  VStack(alignment: .leading, spacing: 8) {
   Toggle("Automatically Check for Updates", isOn: Binding(get: { updates.automaticallyChecks }, set: { updates.setAutomaticChecks($0) }))
    .toggleStyle(.checkbox).disabled(demo || updates.errorMessage != nil)
   HStack {
    Button("Check for Updates…") { updates.check() }.disabled(demo || !updates.canCheck)
    Spacer()
    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "").font(.caption).foregroundStyle(.secondary)
   }
   if let error = updates.errorMessage { Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
  }
 }
}
