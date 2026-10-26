import SwiftUI
import TrailCore

struct ResultCard:View {
    let run:Run
    private let ink=Color(red:0.08,green:0.25,blue:0.20)
    private let cream=Color(red:0.97,green:0.96,blue:0.92)
    private var heading:String {
        if run.isDaily,run.puzzle.id.hasPrefix("daily-"){return "DAILY TRAIL · \(run.puzzle.id.dropFirst(6).prefix(10))"}
        return run.mode == .coop ? "A TRAIL TOGETHER":"A LITTLE WORDPLAY"
    }
    var body:some View {
        VStack(spacing:0){
            HStack{Image(systemName:"leaf.fill");Text("WORD TRAILS").tracking(5)}.font(.system(size:18,weight:.semibold)).padding(.top,38)
            Text(heading).font(.system(size:12,weight:.medium)).tracking(2).padding(.top,15)
            Landscape().frame(height:155).padding(.top,18).accessibilityHidden(true)
            VStack(spacing:20){
                Text("\(run.puzzle.start) → \(run.puzzle.goal)").font(.system(size:44,weight:.medium,design:.serif)).lineLimit(1).minimumScaleFactor(0.6)
                Text(run.scoreDescription).font(.system(size:46,weight:.semibold,design:.serif)).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing:0){metric("STEPS",run.moves);metric("PAR",run.puzzle.par);metric("MINIMUM",run.puzzle.minimum)}.padding(.vertical,12)
                HStack(spacing:7){
                    ForEach(0..<min(run.moves+1,11),id:\.self){index in
                        if index>0{Capsule().fill(ink.opacity(0.3)).frame(width:12,height:2)}
                        Circle().fill(index==0 || index==min(run.moves,10) ? ink:ink.opacity(0.25)).frame(width:14,height:14)
                    }
                }.frame(height:18).accessibilityHidden(true)
                Text(run.hints==0 ? "Found my way without hints":"Found my way · \(run.hints) \(run.hints==1 ? "hint":"hints")").font(.system(size:16)).opacity(0.8)
                if run.isShortestSolution{Label("Shortest possible route",systemImage:"rosette").font(.system(size:18,weight:.semibold))}
                Text("Can you find your way?").font(.system(size:23,design:.serif)).padding(.top,6)
                Spacer(minLength:0)
                Text("Word Trails · apps.apple.com/app/id6827240623").font(.system(size:11)).opacity(0.6).padding(.bottom,28)
            }.padding(.horizontal,38).padding(.top,20)
        }.frame(width:600,height:780).foregroundStyle(ink).background(cream).environment(\.colorScheme,.light)
    }
    private func metric(_ name:String,_ value:Int)->some View {
        VStack(spacing:8){Text("\(value)").font(.system(size:30,weight:.medium,design:.serif));Text(name).font(.system(size:10,weight:.semibold)).tracking(2)}.frame(maxWidth:.infinity)
    }
}

struct ResultShareView:View {
    let run:Run
    @Environment(\.dismiss) private var dismiss
    @State private var image:UIImage?
    @State private var sharing=false
    private let appURL=URL(string:"https://apps.apple.com/app/id6827240623")!
    var body:some View {
        NavigationStack{
            ScrollView{VStack(spacing:18){
                if let image{
                    Image(uiImage:image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius:20)).accessibilityLabel("Word Trails result card. \(run.scoreDescription). \(run.moves) steps, par \(run.puzzle.par).")
                    Button("Share card",systemImage:"square.and.arrow.up"){sharing=true}.buttonStyle(TrailButton()).accessibilityIdentifier("shareCard")
                    Text("Your route stays a secret. Share your card and a small link to Word Trails.").font(.subheadline).foregroundStyle(.secondary)
                }else{ProgressView("Preparing your card…")}
            }.padding(20)}.background(Palette.canvas).navigationTitle("Your trail card").navigationBarTitleDisplayMode(.inline)
            .toolbar{Button("Done"){dismiss()}}
            .task{
                let renderer=ImageRenderer(content:ResultCard(run:run));renderer.scale=2;image=renderer.uiImage
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--ui-test"),let data=image?.pngData(){
                    let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("share-card-test.png")
                    try? data.write(to:url,options:.atomic)
                }
                #endif
            }
            .sheet(isPresented:$sharing){if let image{ResultActivitySheet(image:image,url:appURL)}}
        }
    }
}
struct ResultActivitySheet:UIViewControllerRepresentable {
    let image:UIImage
    let url:URL
    func makeUIViewController(context:Context)->UIActivityViewController{UIActivityViewController(activityItems:[image,url],applicationActivities:nil)}
    func updateUIViewController(_ controller:UIActivityViewController,context:Context){}
}
