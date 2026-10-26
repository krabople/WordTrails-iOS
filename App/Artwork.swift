import SwiftUI

enum Palette {
    static let canvas = Color(uiColor:UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red:0.075,green:0.10,blue:0.085,alpha:1) : UIColor(red:0.975,green:0.97,blue:0.945,alpha:1) })
    static let ink = Color(uiColor:UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red:0.78,green:0.86,blue:0.72,alpha:1) : UIColor(red:0.13,green:0.27,blue:0.22,alpha:1) })
    static let paper = Color(red:0.97,green:0.96,blue:0.92)
    static let forest = Color(red:0.13,green:0.27,blue:0.22)
    static let sage = Color(red:0.77,green:0.83,blue:0.71)
    static let ochre = Color(red:0.77,green:0.53,blue:0.23)
}

/// Original geometry, drawn at device resolution. No generated image textures or portraits.
struct Landscape: View {
    var planted = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            context.fill(Path(ellipseIn: CGRect(x:w*0.76,y:h*0.09,width:38,height:38)), with:.color(Palette.ochre.opacity(0.65)))
            var rear = Path(); rear.move(to: CGPoint(x:0,y:h*0.62))
            rear.addCurve(to:CGPoint(x:w,y:h*0.57),control1:CGPoint(x:w*0.36,y:h*0.03),control2:CGPoint(x:w*0.65,y:h*0.94))
            rear.addLine(to:CGPoint(x:w,y:h)); rear.addLine(to:CGPoint(x:0,y:h)); rear.closeSubpath()
            context.fill(rear,with:.color(Palette.sage.opacity(0.55)))
            var front = Path(); front.move(to:CGPoint(x:0,y:h*0.82))
            front.addCurve(to:CGPoint(x:w,y:h*0.63),control1:CGPoint(x:w*0.4,y:h*0.36),control2:CGPoint(x:w*0.68,y:h*0.5))
            front.addLine(to:CGPoint(x:w,y:h)); front.addLine(to:CGPoint(x:0,y:h)); front.closeSubpath()
            context.fill(front,with:.color(Palette.sage))
            var trail = Path(); trail.move(to:CGPoint(x:w*0.43,y:h+6))
            trail.addCurve(to:CGPoint(x:w*0.63,y:h*0.53),control1:CGPoint(x:w*0.88,y:h*0.82),control2:CGPoint(x:w*0.29,y:h*0.76))
            context.stroke(trail,with:.color(Palette.paper),style:StrokeStyle(lineWidth:13,lineCap:.round))
            for i in 0..<max(3,planted+3) {
                let x = w*(0.08+Double((i*23)%83)/100), y = h*(0.64+Double((i*7)%26)/100)
                let treeHeight = 24.0+Double(i%3)*9
                var trunk = Path(); trunk.move(to:CGPoint(x:x,y:y)); trunk.addLine(to:CGPoint(x:x,y:y-treeHeight))
                context.stroke(trunk,with:.color(Palette.forest),style:StrokeStyle(lineWidth:2,lineCap:.round))
                for j in 0..<3 {
                    let level = y-treeHeight+Double(j)*7
                    var leaf = Path(); leaf.move(to:CGPoint(x:x,y:level+8)); leaf.addQuadCurve(to:CGPoint(x:x-9,y:level),control:CGPoint(x:x-13,y:level+10)); leaf.addQuadCurve(to:CGPoint(x:x,y:level+8),control:CGPoint(x:x-1,y:level-3))
                    context.fill(leaf,with:.color(Palette.forest.opacity(0.86)))
                    context.fill(Path(ellipseIn:CGRect(x:x+1,y:level-3,width:10,height:5)),with:.color(Palette.forest.opacity(0.7)))
                }
            }
        }.accessibilityHidden(true)
    }
}

struct WordTiles: View {
    let word: String
    var previous: String? = nil
    var active = false
    var body: some View {
        HStack(spacing:6) {
            ForEach(Array(word.enumerated()), id:\.offset) { i, letter in
                let old = previous.map(Array.init)
                let changed = old != nil && i < old!.count && old![i] != letter
                Text(String(letter)).font(.system(.title2,design:.rounded,weight:.semibold)).underline(changed).lineLimit(1).minimumScaleFactor(0.5).frame(maxWidth:.infinity,minHeight:48)
                    .background(changed ? Palette.ochre.opacity(0.17) : (active ? Palette.sage.opacity(0.45) : Color.primary.opacity(0.035)),in:RoundedRectangle(cornerRadius:11))
                    .overlay(RoundedRectangle(cornerRadius:11).stroke(active ? Palette.forest.opacity(0.45) : Color.primary.opacity(0.08),lineWidth:1))
            }
        }.accessibilityElement(children:.ignore).accessibilityLabel(word.map(String.init).joined(separator:" "))
    }
}
struct PaperCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:22)).overlay(RoundedRectangle(cornerRadius:22).stroke(Palette.forest.opacity(0.07))) }
}
struct TrailButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration:Configuration) -> some View { configuration.label.font(.headline).frame(maxWidth:.infinity,minHeight:50).foregroundStyle(.white).background(Palette.forest.opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.35),in:RoundedRectangle(cornerRadius:15)) }
}
