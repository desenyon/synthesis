import SwiftUI
import AppKit
import SynthesisCore

struct ManualHome:View {
    @ObservedObject var studio:Studio
    var body:some View{
        ScrollView{
            VStack(alignment:.leading,spacing:30){
                HStack(spacing:7){Image(systemName:"hand.draw");Text("Manual studio");Spacer();Label("AI is off",systemImage:"pause.circle")}.font(.system(size:12)).foregroundStyle(studio.t.secondary)
                VStack(alignment:.leading,spacing:14){Text("Room for your\nown kind of world.").font(.system(size:44,weight:.regular,design:.serif)).tracking(-1.4);Text("Write freely. Connect the pieces. Make it yours.").font(.system(size:16)).foregroundStyle(studio.t.secondary)}.padding(.top,15)
                LazyVGrid(columns:[GridItem(.adaptive(minimum:220),spacing:16)],spacing:16){
                    action("Start writing","An empty page. All yours.","square.and.pencil"){studio.sheet = .document}
                    action("Capture an idea","Keep it before it slips away.","lightbulb"){studio.createRecord(title:"Untitled idea",kind:"capture")}
                    action("Open your canvas","Put thoughts in relation.","square.on.square"){studio.navigate(.canvas)}
                }.padding(.vertical,8)
                HStack{Text("Your recent work").font(.system(size:16,weight:.medium));Spacer();Button("Open library ↗"){studio.navigate(.library)}.font(.system(size:12)).foregroundStyle(studio.t.accent).buttonStyle(.plain)}
                if studio.records.isEmpty{VStack(alignment:.leading,spacing:14){Text("Your first idea belongs here.").font(.system(size:17));Text("Create a document or explore a clearly labeled sample world.").font(.system(size:14)).foregroundStyle(studio.t.secondary);Button("Explore sample world"){studio.loadSample();studio.navigate(.manual)}.buttonStyle(QuietButton(t:studio.t))}.padding(.vertical,20)}else{ForEach(studio.records.prefix(6)){record in RecordRow(studio:studio,record:record)}}
            }.padding(36).frame(maxWidth:980,alignment:.leading).frame(maxWidth:.infinity)
        }
    }
    private func action(_ title:String,_ subtitle:String,_ icon:String,action:@escaping()->Void)->some View{Button(action:action){VStack(alignment:.leading,spacing:18){Image(systemName:icon).font(.system(size:23,weight:.light)).foregroundStyle(studio.t.accent);VStack(alignment:.leading,spacing:7){Text(title).font(.system(size:15,weight:.medium)).foregroundStyle(studio.t.text);Text(subtitle).font(.system(size:12)).foregroundStyle(studio.t.secondary)}}.padding(24).frame(maxWidth:.infinity,minHeight:155,alignment:.leading).background(studio.t.surface,in:RoundedRectangle(cornerRadius:18))}.buttonStyle(.plain)}
}
struct LibraryScreen:View {
    @ObservedObject var studio:Studio
    @State private var query=""
    @State private var filter="All"
    var visible:[LoreRecord]{studio.records.filter{r in (filter=="All" || (filter=="Documents" && r.kind=="lore") || (filter=="Entities" && r.kind=="entity") || (filter=="Inbox" && r.kind=="capture")) && (query.isEmpty || r.title.localizedCaseInsensitiveContains(query) || r.body.localizedCaseInsensitiveContains(query) || r.category.localizedCaseInsensitiveContains(query))}}
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:28){
        HStack(alignment:.top){VStack(alignment:.leading,spacing:10){Text("Your world, gathered.").font(.system(size:36,weight:.regular,design:.serif)).tracking(-1);Text("The people, places, and possibilities taking shape.").font(.system(size:14)).foregroundStyle(studio.t.secondary)};Spacer();Button{studio.sheet = .document}label:{Image(systemName:"plus")}.buttonStyle(QuietButton(t:studio.t,primary:true)).help("Create document or entity")}
        HStack{Image(systemName:"magnifyingglass").foregroundStyle(studio.t.muted);TextField("Search your library",text:$query).textFieldStyle(.plain).font(.system(size:14))}.padding(13).background(studio.t.surface,in:RoundedRectangle(cornerRadius:12))
        HStack(spacing:6){ForEach(["All","Documents","Entities","Inbox"],id:\.self){type in Button{filter=type}label:{Text(type).font(.system(size:12,weight:.medium)).padding(.horizontal,14).padding(.vertical,8).background(filter==type ? studio.t.accentSoft:.clear,in:Capsule()).foregroundStyle(filter==type ? studio.t.accent:studio.t.secondary)}.buttonStyle(.plain)}}
        if visible.isEmpty{VStack(alignment:.leading,spacing:12){Image(systemName:"books.vertical").font(.system(size:30,weight:.ultraLight)).foregroundStyle(studio.t.accent);Text(query.isEmpty ? "Give your ideas a place to live.":"No matching material yet.").font(.system(size:22,design:.serif));Text("Documents, entities, and loose thoughts share one library.").font(.system(size:14)).foregroundStyle(studio.t.secondary);Button("Create something"){studio.sheet = .document}.buttonStyle(QuietButton(t:studio.t,primary:true))}.padding(.vertical,50)}else{VStack(spacing:0){ForEach(visible){record in RecordRow(studio:studio,record:record)}}}
    }.padding(36).frame(maxWidth:1080,alignment:.leading).frame(maxWidth:.infinity)}}
}
struct RecordRow:View {
    @ObservedObject var studio:Studio;let record:LoreRecord
    var body:some View{Button{studio.openRecord(record)}label:{HStack(spacing:16){Image(systemName:record.kind=="entity" ? "person.crop.square":record.kind=="capture" ? "lightbulb":"doc.text").font(.system(size:20,weight:.light)).foregroundStyle(studio.t.accent).frame(width:42,height:44).background(studio.t.accentSoft.opacity(0.55),in:RoundedRectangle(cornerRadius:11));VStack(alignment:.leading,spacing:6){Text(record.title).font(.system(size:15,weight:.medium)).foregroundStyle(studio.t.text);Text(record.body.isEmpty ? "An open possibility":record.body.replacingOccurrences(of:"\n",with:" ")).font(.system(size:12)).foregroundStyle(studio.t.secondary).lineLimit(1)};Spacer(minLength:10);Text(record.state.capitalized).font(.system(size:11)).foregroundStyle(studio.t.secondary)}.padding(.vertical,16).contentShape(Rectangle())}.buttonStyle(.plain).overlay(alignment:.bottom){Rectangle().fill(studio.t.border.opacity(0.7)).frame(height:0.5)}}
}
struct EditorScreen:View {
    @ObservedObject var studio:Studio
    @State private var record:LoreRecord
    @State private var title:String
    @State private var bodyText:String
    @State private var richText:String?
    @State private var category:String
    @State private var dirty=false
    @State private var status="Saved locally"
    @State private var saving:Task<Void,Never>?
    @State private var reloadToken=0
    @State private var showHistory=false
    @State private var showCanon=false
    @State private var focus=false
    @State private var revisions:[RecordRevision]=[]
    init(studio:Studio,record:LoreRecord){self.studio=studio;_record=State(initialValue:record);_title=State(initialValue:record.title);_bodyText=State(initialValue:record.body);_richText=State(initialValue:record.rtf);_category=State(initialValue:record.category)}
    var body:some View{
        VStack(spacing:0){
            HStack{Button{if save(){studio.selectedRecord=nil;studio.editorSave=nil}}label:{Label("Library",systemImage:"arrow.left")}.buttonStyle(.plain).foregroundStyle(studio.t.secondary);Spacer();Text(status).font(.system(size:11)).foregroundStyle(status.contains("failed") ? .red:studio.t.muted);Menu{Button("Revision history"){if save(){studio.perform{revisions=try studio.store.history(worldID:studio.worldID,id:record.id);showHistory=true}}};Button("Review for canon"){if save(){showCanon=true}};if record.kind=="capture"{Button("Turn into document"){if save(){studio.perform{record=try studio.store.convertCapture(worldID:studio.worldID,id:record.id);try studio.reload()}}}};Button("Export as Markdown…"){export()}}label:{Image(systemName:"ellipsis")}.menuStyle(.borderlessButton).fixedSize();IconButton(icon:focus ? "arrow.down.right.and.arrow.up.left":"arrow.up.left.and.arrow.down.right",label:"Focus writing",t:studio.t){focus.toggle();studio.collapsed=focus}}.padding(.horizontal,28).padding(.vertical,18)
            VStack(alignment:.leading,spacing:16){
                HStack(spacing:8){Text(record.kind=="entity" ? "Entity":record.kind=="capture" ? "Idea":"Document");Text("·");Text(record.state.capitalized);if record.canonical != nil && record.state != "canon"{Text("· Accepted canon preserved")}}.font(.system(size:11)).foregroundStyle(studio.t.secondary)
                TextField("Untitled",text:$title,axis:.vertical).font(.system(size:36,weight:.medium,design:.serif)).textFieldStyle(.plain).onChange(of:title){_,_ in changed()}.accessibilityLabel("Document title")
                if !focus{HStack(spacing:14){formatButton("bold","toggleBoldface:");formatButton("italic","toggleItalics:");formatButton("underline","underline:");Divider().frame(height:16);TextField("Category",text:$category).font(.system(size:12)).textFieldStyle(.plain).frame(maxWidth:180).onChange(of:category){_,_ in changed()};Spacer();Text("\(bodyText.split{ $0.isWhitespace || $0.isNewline }.count) words").font(.system(size:11)).foregroundStyle(studio.t.muted)}.padding(.vertical,12).overlay(alignment:.bottom){Rectangle().fill(studio.t.border).frame(height:0.5)}}
                RichDocumentEditor(id:record.id,body:bodyText,rtf:richText,t:studio.t,reloadToken:reloadToken){text,rtf in bodyText=text;richText=rtf;changed()}.frame(maxHeight:.infinity)
            }.padding(.horizontal,28).padding(.top,22).frame(maxWidth:806).frame(maxWidth:.infinity,maxHeight:.infinity)
        }.onAppear{studio.editorSave={save()}}.onDisappear{saving?.cancel()}
        .sheet(isPresented:$showHistory){VStack(alignment:.leading,spacing:20){Text("Revision history").font(.title2);Text("Restoring creates a new draft. Accepted canon stays intact.").font(.subheadline).foregroundStyle(.secondary);ScrollView{VStack(alignment:.leading,spacing:20){ForEach(revisions){revision in VStack(alignment:.leading,spacing:8){HStack{Text("Revision \(revision.version)");Spacer();Button("Restore as draft"){restore(revision)}};Text(revision.snapshot.body).lineLimit(5).font(.system(size:13)).foregroundStyle(.secondary);Divider()}}}};Button("Done"){showHistory=false}}.padding(28).frame(width:540,height:500)}
        .sheet(isPresented:$showCanon){VStack(alignment:.leading,spacing:18){Text("Review this exact revision").font(.title2);Text("\(title) · revision \(record.version)").font(.subheadline);Text("Current accepted canon").font(.headline);ScrollView{Text(canonBody).font(.system(size:13)).frame(maxWidth:.infinity,alignment:.leading)}.frame(maxHeight:100);Text("Proposed replacement").font(.headline);ScrollView{Text(bodyText).font(.system(size:14)).frame(maxWidth:.infinity,alignment:.leading)}.frame(maxHeight:180);Text("This explicit approval promotes the displayed revision. Previous versions remain in history.").font(.caption).foregroundStyle(.secondary);HStack{Button("Cancel"){showCanon=false};Spacer();Button("Accept as canon"){studio.perform{record=try studio.store.promote(worldID:studio.worldID,id:record.id,version:record.version,confirmation:record.id);try studio.reload();showCanon=false}}.buttonStyle(QuietButton(t:studio.t,primary:true))}}.padding(28).frame(width:520)}
    }
    private var canonBody:String{guard let data=record.canonical?.data(using:.utf8),let object=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else{return "No accepted canon yet."};return object["body"] as? String ?? "No accepted text."}
    private func formatButton(_ image:String,_ selector:String)->some View{Button{NSApp.sendAction(Selector(selector),to:nil,from:nil)}label:{Image(systemName:image).font(.system(size:13)).frame(width:24,height:24)}.buttonStyle(.plain).help(image.capitalized)}
    private func changed(){dirty=true;status="Saving…";saving?.cancel();saving=Task{@MainActor in try? await Task.sleep(for:.milliseconds(650));guard !Task.isCancelled else{return};_ = save()}}
    @discardableResult private func save()->Bool{saving?.cancel();guard dirty else{return true};do{record=try studio.store.saveRecord(worldID:record.worldID,id:record.id,version:record.version,title:title,body:bodyText,rtf:richText,category:category);dirty=false;status="Saved locally";try studio.reload();return true}catch{status="Save failed · draft retained";studio.error=error.localizedDescription;return false}}
    private func restore(_ revision:RecordRevision){bodyText=revision.snapshot.body;richText=revision.snapshot.rtf;title=revision.snapshot.title;category=revision.snapshot.category;dirty=true;reloadToken += 1;if save(){showHistory=false}}
    private func export(){let panel=NSSavePanel();panel.nameFieldStringValue="\(title).md";if panel.runModal() == .OK,let url=panel.url{studio.perform{try "# \(title)\n\n\(bodyText)".write(to:url,atomically:true,encoding:.utf8)}}}
}
