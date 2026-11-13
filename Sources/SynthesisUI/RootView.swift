import SwiftUI
import SynthesisCore

public struct RootView:View {
    @ObservedObject var studio:Studio
    public init(studio:Studio){self.studio=studio}
    public var body:some View{
        GeometryReader{geo in
            let compact=geo.size.width<700
            VStack(spacing:0){
                header(compact:compact)
                HStack(spacing:0){
                    if !compact {Sidebar(studio:studio,collapsed:studio.collapsed || geo.size.width<1100)}
                    ZStack(alignment:.topLeading){
                        Group{
                            if let record=studio.selectedRecord {EditorScreen(studio:studio,record:record).id(record.id)}
                            else {switch studio.destination {
                            case .chat: if studio.mode == .manual {ManualHome(studio:studio)}else{ChatWorkspace(studio:studio)}
                            case .manual:ManualHome(studio:studio)
                            case .library:LibraryScreen(studio:studio)
                            case .canvas:CanvasScreen(studio:studio)
                            case .knowledge:KnowledgeScreen(studio:studio)
                            case .timeline:TimelineScreen(studio:studio)
                            case .atlas:AtlasScreen(studio:studio)
                            }}
                        }.frame(maxWidth:.infinity,maxHeight:.infinity)
                        if compact && studio.mobileNavigation {Sidebar(studio:studio,collapsed:false).frame(width:240).shadow(color:.black.opacity(0.12),radius:20,x:10,y:0).zIndex(10)}
                    }
                }
            }.background(studio.t.background).foregroundStyle(studio.t.text)
        }
        .preferredColorScheme(studio.dark ? .dark:.light)
        .sheet(item:$studio.sheet){sheet in StudioSheet(studio:studio,sheet:sheet)}
        .alert("Something needs attention",isPresented:Binding(get:{studio.error != nil},set:{if !$0{studio.error=nil}})){Button("OK"){studio.error=nil}}message:{Text(studio.error ?? "")}
        .overlay(alignment:.bottom){if let notice=studio.notice{HStack{Text(notice).font(.system(size:12));Button("Dismiss"){studio.notice=nil}.buttonStyle(.plain)}.padding(14).background(studio.t.surface,in:RoundedRectangle(cornerRadius:12)).shadow(color:.black.opacity(0.1),radius:14).padding(20)}}
    }
    private func header(compact:Bool)->some View{
        HStack(spacing:compact ? 8:16){
            if compact {IconButton(icon:"line.3.horizontal",label:"Navigation",t:studio.t){studio.mobileNavigation.toggle()}}
            BrandMark(size:22,color:studio.t.text)
            if !compact {Text("Synthesis").font(.system(size:17,weight:.semibold)).tracking(-0.6);Text("/").foregroundStyle(studio.t.muted)}
            Menu{
                ForEach(studio.worlds){world in Button(world.name){studio.switchWorld(world.id)}}
                Divider();Button("Create world…"){studio.sheet = .world}
                Button("Open sample world"){studio.loadSample()}
            }label:{HStack(spacing:7){Text(studio.world?.name ?? "World").font(.system(size:13,weight:.medium)).lineLimit(1);Image(systemName:"chevron.down").font(.system(size:9))}.foregroundStyle(studio.t.secondary)}.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            Spacer(minLength:4)
            HStack(spacing:3){modeButton(.assisted,label:compact ? "AI":"AI Assisted");modeButton(.manual,label:"Manual")}.padding(4).background(studio.t.secondarySurface,in:Capsule())
            if !compact {IconButton(icon:"magnifyingglass",label:"Search · ⌘K",t:studio.t){studio.sheet = .search}.keyboardShortcut("k",modifiers:.command)}
            IconButton(icon:studio.dark ? "sun.max":"moon",label:"Switch appearance",t:studio.t){studio.toggleTheme()}
            if !compact {IconButton(icon:"slider.horizontal.3",label:"Settings",t:studio.t){studio.sheet = .settings}.keyboardShortcut(",",modifiers:.command)}
        }.padding(.horizontal,compact ? 14:24).frame(height:60).background(studio.t.surface.opacity(0.7)).overlay(alignment:.bottom){Rectangle().fill(studio.t.border.opacity(0.65)).frame(height:0.5)}
    }
    private func modeButton(_ mode:WorkspaceMode,label:String)->some View{
        Button{withAnimation(.easeInOut(duration:0.18)){studio.setMode(mode)}}label:{HStack(spacing:6){if mode == .assisted{Image(systemName:"sparkle").font(.system(size:11))};Text(label).font(.system(size:12,weight:.medium))}.padding(.horizontal,12).padding(.vertical,7).foregroundStyle(studio.mode==mode ? studio.t.text:studio.t.secondary).background(studio.mode==mode ? studio.t.surface:.clear,in:Capsule()).shadow(color:.black.opacity(studio.mode==mode ? 0.05:0),radius:3,y:1)}.buttonStyle(.plain).accessibilityLabel(label).accessibilityAddTraits(studio.mode==mode ? .isSelected:[])
    }
}
struct Sidebar:View {
    @ObservedObject var studio:Studio
    var collapsed:Bool
    var body:some View{
        VStack(alignment:.leading,spacing:0){
            HStack(spacing:11){ZStack{RoundedRectangle(cornerRadius:12).fill(studio.t.accentSoft);Image(systemName:"globe.europe.africa").font(.system(size:21,weight:.light)).foregroundStyle(studio.t.accent)}.frame(width:38,height:38)
                if !collapsed{VStack(alignment:.leading,spacing:4){Text(studio.world?.name ?? "World").font(.system(size:14,weight:.semibold));Text(studio.world?.demo == true ? "Sample world":"Your creative universe").font(.system(size:11)).foregroundStyle(studio.t.secondary)}}
            }.padding(.horizontal,collapsed ? 15:20).padding(.top,28).padding(.bottom,28)
            VStack(spacing:5){
                navButton(studio.mode == .assisted ? "New chat":"New document",icon:"plus",selected:false){if studio.mode == .assisted{studio.newChat()}else{studio.sheet = .document}}
                navButton("Search",icon:"magnifyingglass",selected:false){studio.sheet = .search}
            }.padding(.horizontal,12)
            if !collapsed{Text("Workspace").font(.system(size:11,weight:.medium)).foregroundStyle(studio.t.muted).padding(.leading,24).padding(.top,32).padding(.bottom,10)}else{Spacer().frame(height:26)}
            VStack(spacing:5){
                if studio.mode == .manual {destination(.manual)}else{destination(.chat)}
                destination(.library);destination(.canvas)
            }.padding(.horizontal,12)
            if !collapsed{Text("Explore").font(.system(size:11,weight:.medium)).foregroundStyle(studio.t.muted).padding(.leading,24).padding(.top,26).padding(.bottom,10)}else{Spacer().frame(height:24)}
            VStack(spacing:5){destination(.knowledge);destination(.timeline);destination(.atlas)}.padding(.horizontal,12)
            if !collapsed && studio.mode == .assisted {
                HStack{Text("Recent conversations");Spacer();Text("\(studio.conversations.count)")}.font(.system(size:11)).foregroundStyle(studio.t.muted).padding(.horizontal,24).padding(.top,30).padding(.bottom,10)
                ScrollView{VStack(alignment:.leading,spacing:3){ForEach(studio.conversations.prefix(12)){chat in
                    Button{studio.openChat(chat)}label:{Text(chat.title).font(.system(size:12)).lineLimit(1).foregroundStyle(studio.t.secondary).padding(.horizontal,12).padding(.vertical,9).frame(maxWidth:.infinity,alignment:.leading).background(studio.conversationID==chat.id ? studio.t.surface.opacity(0.8):.clear,in:RoundedRectangle(cornerRadius:8))}.buttonStyle(.plain).contextMenu{Button("Rename"){studio.openChat(chat);studio.sheet = .rename}}
                }
                if studio.conversations.isEmpty{Text("Your conversations will live here.").font(.system(size:12)).foregroundStyle(studio.t.muted).padding(.horizontal,12).padding(.top,8).lineSpacing(4)}}.padding(.horizontal,12)}
            }
            Spacer(minLength:16)
            VStack(spacing:6){navButton("Settings",icon:"gearshape",selected:false){studio.sheet = .settings};navButton(collapsed ? "Expand sidebar":"Collapse sidebar",icon:collapsed ? "sidebar.left":"sidebar.leading",selected:false){withAnimation(.easeInOut(duration:0.18)){studio.toggleSidebar()}}}.padding(12)
        }.frame(width:collapsed ? 68:240).frame(maxHeight:.infinity).background(studio.t.sidebar)
    }
    private func destination(_ dest:Destination)->some View{navButton(dest.rawValue,icon:dest.icon,selected:studio.destination==dest && studio.selectedRecord==nil){studio.navigate(dest)}}
    private func navButton(_ label:String,icon:String,selected:Bool,action:@escaping()->Void)->some View{
        Button(action:action){HStack(spacing:12){Image(systemName:icon).font(.system(size:16,weight:.regular)).frame(width:20);if !collapsed{Text(label).font(.system(size:14,weight:selected ? .medium:.regular));Spacer()}}.foregroundStyle(selected ? studio.t.accent:studio.t.secondary).frame(maxWidth:.infinity,minHeight:38).padding(.horizontal,collapsed ? 0:12).background(selected ? studio.t.accentSoft:.clear,in:RoundedRectangle(cornerRadius:10))}.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
}
