import SwiftUI

public struct Theme {
    public let dark:Bool
    public var background:Color{Color(hex:dark ? 0x242426:0xF8F9FB)}
    public var sidebar:Color{Color(hex:dark ? 0x202022:0xF0F2F5)}
    public var surface:Color{Color(hex:dark ? 0x303033:0xFFFFFF)}
    public var secondarySurface:Color{Color(hex:dark ? 0x37373B:0xF0F2F6)}
    public var text:Color{Color(hex:dark ? 0xECEBED:0x20232B)}
    public var secondary:Color{Color(hex:dark ? 0xB0ACB6:0x697281)}
    public var muted:Color{Color(hex:dark ? 0x9A96A1:0x7D8593)}
    public var border:Color{Color(hex:dark ? 0x454248:0xE1E5EC)}
    public var accent:Color{Color(hex:dark ? 0xA2B4FF:0x526EEA)}
    public var accentSoft:Color{Color(hex:dark ? 0x353B51:0xE8EDFF)}
}
extension Color {
    init(hex:UInt32){self.init(.sRGB,red:Double((hex>>16)&255)/255,green:Double((hex>>8)&255)/255,blue:Double(hex&255)/255,opacity:1)}
}
struct QuietButton:ButtonStyle {
    let t:Theme;var primary=false
    func makeBody(configuration:Configuration)->some View {configuration.label.font(.system(size:13,weight:.medium)).padding(.horizontal,14).padding(.vertical,10).background(primary ? t.accent:t.surface,in:RoundedRectangle(cornerRadius:10)).foregroundStyle(primary ? Color.white:t.text).overlay(RoundedRectangle(cornerRadius:10).stroke(primary ? .clear:t.border.opacity(0.7),lineWidth:1)).opacity(configuration.isPressed ? 0.75:1)}
}
struct IconButton:View {
    var icon:String;var label:String;var t:Theme;var action:()->Void
    var body:some View{Button(action:action){Image(systemName:icon).font(.system(size:16,weight:.regular)).foregroundStyle(t.secondary).frame(width:32,height:32).contentShape(RoundedRectangle(cornerRadius:8))}.buttonStyle(.plain).help(label).accessibilityLabel(label)}
}
struct BrandMark:View {
    var size:CGFloat=24;var color:Color
    var body:some View{ZStack{ForEach(0..<4){i in RoundedRectangle(cornerRadius:2).fill(color).frame(width:size*0.17,height:size*0.72).rotationEffect(.degrees(45+Double(i)*45))}}.frame(width:size,height:size).accessibilityHidden(true)}
}
