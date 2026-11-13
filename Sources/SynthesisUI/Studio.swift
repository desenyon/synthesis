import SwiftUI
import AppKit
import SynthesisCore

public enum Destination:String,CaseIterable,Identifiable {
    case chat="Chat",library="Library",canvas="Canvas",knowledge="Knowledge",timeline="Timeline",atlas="Atlas",manual="Studio"
    public var id:String{rawValue}
    var icon:String {switch self {case .chat:return "bubble.left.and.bubble.right";case .library:return "books.vertical";case .canvas:return "square.on.square";case .knowledge:return "point.3.connected.trianglepath.dotted";case .timeline:return "clock.arrow.circlepath";case .atlas:return "map";case .manual:return "square.grid.2x2"}}
}
@MainActor public final class Studio:ObservableObject {
    public let store:WorkspaceStore
    public let engine:AgentEngine
    @Published public var worlds:[World]=[]
    @Published public var worldID=""
    @Published public var records:[LoreRecord]=[]
    @Published public var conversations:[Conversation]=[]
    @Published public var messages:[ChatMessage]=[]
    @Published public var conversationID:String?
    @Published public var selectedRecord:LoreRecord?
    @Published public var destination:Destination = .chat
    @Published public var mode:WorkspaceMode = .assisted
    @Published public var dark=false
    @Published public var collapsed=false
    @Published public var mobileNavigation=false
    @Published public var draft=""
    @Published public var preset="Create"
    @Published public var busy=false
    @Published public var streamed=""
    @Published public var error:String?
    @Published public var notice:String?
    @Published public var sheet:Sheet?
    @Published public var providerConfigured=false
    @Published public var modelName=""
    @Published public var search=""
    @Published public var editorSave: (() -> Bool)?
    @Published public var inspector=false
    private var running:Task<Void,Never>?
    private var requestID=UUID()
    public enum Sheet:String,Identifiable { case settings,world,search,document,rename;public var id:String{rawValue} }
    public var world:World?{worlds.first{$0.id==worldID}}
    public var t:Theme{Theme(dark:dark)}
    public init(store:WorkspaceStore,transport:(any ModelTransport)?=nil) throws {
        self.store=store
        let configuredModel=try store.preference("model") ?? ""
        self.engine=AgentEngine(store:store,transport:transport ?? OpenAITransport(model:{UserDefaults.standard.string(forKey:"Synthesis.model") ?? ""}))
        modelName=configuredModel
        UserDefaults.standard.set(configuredModel,forKey:"Synthesis.model")
        worlds=try store.worlds()
        if worlds.isEmpty {worlds=[try store.createWorld(name:"My world")]}
        let last=try store.preference("world")
        worldID=worlds.first{$0.id==last}?.id ?? worlds[0].id
        mode=WorkspaceMode(rawValue:try store.preference("mode") ?? "assisted") ?? .assisted
        dark=try store.preference("theme") == "dark"
        collapsed=try store.preference("sidebar") == "collapsed"
        destination=mode == .manual ? .manual:.chat
        draft=try store.preference("composer:\(worldID)") ?? ""
        providerConfigured=ProviderKeychain.configured && !configuredModel.isEmpty
        try reload()
    }
    public func reload() throws {
        worlds=try store.worlds();records=try store.records(worldID:worldID);conversations=try store.conversations(worldID:worldID)
        if let conversationID {messages=try store.messages(worldID:worldID,conversationID:conversationID)}else{messages=[]}
    }
    public func perform(_ body:() throws -> Void) {do{try body()}catch{self.error=error.localizedDescription}}
    public func persistComposer(){perform{try store.setPreference("composer:\(worldID)",value:draft)}}
    public func setMode(_ value:WorkspaceMode) {
        guard flushEditor() else{return}
        perform{try engine.setMode(value);mode=value;stop();selectedRecord=nil;destination=value == .manual ? .manual:.chat;try reload()}
    }
    public func toggleTheme(){dark.toggle();perform{try store.setPreference("theme",value:dark ? "dark":"light")}}
    public func toggleSidebar(){collapsed.toggle();perform{try store.setPreference("sidebar",value:collapsed ? "collapsed":"expanded")}}
    public func flushEditor()->Bool {editorSave?() ?? true}
    public func navigate(_ value:Destination){guard flushEditor() else{return};selectedRecord=nil;editorSave=nil;destination=value;mobileNavigation=false;inspector=false}
    public func switchWorld(_ id:String){guard flushEditor() else{return};stop();perform{persistComposer();worldID=id;conversationID=nil;selectedRecord=nil;editorSave=nil;try store.setPreference("world",value:id);draft=try store.preference("composer:\(id)") ?? "";destination=mode == .manual ? .manual:.chat;try reload()}}
    public func newChat(){guard flushEditor() else{return};stop();selectedRecord=nil;editorSave=nil;conversationID=nil;messages=[];destination = .chat;mobileNavigation=false}
    public func openChat(_ chat:Conversation){guard flushEditor() else{return};stop();perform{conversationID=chat.id;selectedRecord=nil;editorSave=nil;destination = .chat;try reload();mobileNavigation=false}}
    public func openRecord(_ record:LoreRecord){guard flushEditor() else{return};selectedRecord=record;editorSave=nil;destination = .library;mobileNavigation=false;inspector=false}
    public func createRecord(title:String,kind:String="lore",body:String="") {perform{let record=try store.createRecord(worldID:worldID,title:title,body:body,kind:kind);try reload();openRecord(record);sheet=nil}}
    public func createWorld(_ name:String){perform{let world=try store.createWorld(name:name);try reload();switchWorld(world.id);sheet=nil}}
    public func stop(){requestID=UUID();engine.cancel();running?.cancel();running=nil;busy=false;streamed=""}
    public func send(){
        guard mode == .assisted,!busy,!draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return}
        let prompt=draft,wid=worldID
        perform{
            if conversationID==nil {conversationID=try store.createConversation(worldID:worldID).id}
            let cid=conversationID!;let chosenPreset=preset;let request=UUID();requestID=request
            busy=true;streamed="";draft="";persistComposer();destination = .chat
            running=Task{[weak self] in
                guard let self else{return}
                do {
                    try await self.engine.submit(worldID:wid,conversationID:cid,prompt:prompt,preset:chosenPreset){[weak self] output in
                        await self?.receive(output, worldID:wid, conversationID:cid,request:request)
                    }
                }catch{if !(error is CancellationError),self.requestID==request,self.worldID==wid,self.mode == .assisted {self.error=error.localizedDescription}}
                if self.requestID==request,self.worldID==wid,self.conversationID==cid {self.busy=false;self.streamed="";self.perform{try self.reload()}}
            }
            // The user message is committed by the core before the transport awaits.
            Task{await Task.yield();self.perform{try self.reload()}}
        }
    }
    private func receive(_ output:String,worldID:String,conversationID:String,request:UUID){guard requestID==request,busy,self.worldID==worldID,self.conversationID==conversationID,mode == .assisted else{return};streamed=output;try? reload()}
    public func saveResponse(_ message:ChatMessage,entity:Bool=false){perform{let record=try store.createRecord(worldID:worldID,title:entity ? "New entity":"Conversation draft",body:message.body,kind:entity ? "entity":"lore",origin:"ai-proposed");try reload();openRecord(record)}}
    public func attachText(){
        let panel=NSOpenPanel();panel.allowedContentTypes=[.plainText,.text];panel.canChooseDirectories=false;panel.allowsMultipleSelection=false
        if panel.runModal() == .OK,let url=panel.url {perform{let data=try Data(contentsOf:url);guard data.count<=50000,let text=String(data:data,encoding:.utf8) else{throw SynthesisError.invalid("Attach a UTF-8 text or Markdown file under 50 KB.")};draft += "\n\nAttached reference: \(url.lastPathComponent)\n\(text)";persistComposer()}}
    }
    public func exportWorld(){let panel=NSSavePanel();panel.nameFieldStringValue="\(world?.name ?? "world").json";if panel.runModal() == .OK,let url=panel.url{perform{try store.exportWorld(worldID).write(to:url,options:.atomic);notice="World exported with records, conversations and revisions."}}}
    public func loadSample(){perform{
        if let existing=try store.worlds().first(where:{$0.demo}){switchWorld(existing.id);return}
        let w=try store.createWorld(name:"Aster",description:"The drowned world · sample",demo:true)
        _ = try store.createRecord(worldID:w.id,title:"The Glass Sea",body:"At dawn, the sea remembers how to be solid.\n\nFor a few quiet hours, the water becomes a single sheet of dark glass. Beneath it, the lights of the drowned city still burn.\n\nThose who cross\n\nMira Vale is the only cartographer who has walked beyond the old bell tower. The Tidekeepers guide travelers back before the glass becomes water.\n\nAn unresolved thought\n\nWhat if the glass preserves the memory of everyone who has crossed it?",category:"Places")
        let mira=try store.createRecord(worldID:w.id,title:"Mira Vale",body:"A cartographer tracing places that do not stay still.",kind:"entity",category:"Characters")
        let keepers=try store.createRecord(worldID:w.id,title:"Tidekeepers",body:"A coastal order responsible for safe passage.",kind:"entity",category:"Factions")
        _ = try store.addRelation(worldID:w.id,source:mira.id,target:keepers.id,label:"guided by")
        _ = try store.addEvent(worldID:w.id,title:"The first crossing",date:"Before the coastal order",source:mira.id)
        switchWorld(w.id)
    }}
}
