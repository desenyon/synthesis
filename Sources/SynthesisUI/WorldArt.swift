import SwiftUI

/// A deterministic character engraving, drawn natively. Never part of world data.
struct WorldArt:View {
    let t:Theme
    static let lines:[String] = {
        let cols=118,rows=64
        let shades=Array(" .,:;+=ox%#@")
        return (0..<rows).map{row in
            (0..<cols).map{col -> String in
                let x=(Double(col)-59)/25,y=(Double(row)-31)/25
                let sphere=x*x+y*y
                let ringX=x*0.93+y*0.38,ringY=y*0.93-x*0.38
                let ring=sqrt(ringX*ringX/4.9+ringY*ringY/0.18)
                if sphere<1 {
                    let z=sqrt(1-sphere)
                    let longitude=atan2(x,z),latitude=asin(y)
                    let continent=sin(longitude*5+cos(latitude*7))*cos(latitude*4)+sin(longitude*11+latitude*9)*0.28
                    let light=max(0.05,-x*0.35-y*0.45+z*0.8)
                    let value=continent > 0.15 ? light*9+1:light*3
                    return String(shades[min(shades.count-1,max(0,Int(value)))])
                }
                if abs(ring-1)<0.055 || abs(ring-1.1)<0.025 {return ((col+row)%3 == 0) ? "+":"·"}
                if (col*73+row*137)%503 == 0 {return "+"}
                if (col*41+row*29)%223 == 0 {return "."}
                return " "
            }.joined()
        }
    }()
    var body:some View{
        GeometryReader{proxy in
            let width=proxy.size.width,height=proxy.size.height
            Canvas{context,size in
                let fontSize=min(width/80,height/68)*1.1
                let cell=fontSize*0.62,line=fontSize*1.05
                let origin=CGPoint(x:(size.width-cell*118)/2,y:(size.height-line*64)/2)
                for (i,row) in Self.lines.enumerated(){context.draw(Text(row).font(.system(size:fontSize,weight:.medium,design:.monospaced)).foregroundColor(t.accent.opacity(t.dark ? 0.28:0.34)),at:CGPoint(x:origin.x,y:origin.y+Double(i)*line),anchor:.topLeading)}
            }
        }.accessibilityHidden(true).allowsHitTesting(false)
    }
}
