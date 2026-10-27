import AppKit

let args=CommandLine.arguments
let source=URL(fileURLWithPath:args[1]), output=URL(fileURLWithPath:args[2])
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let headings=["A fresh trail.\nEvery day.","Small changes.\nNew words.","Take the\nhigher trail.","Find your\nshortest route.","Every walk,\nremembered.","A result worth\nsharing.","Grow a little,\nevery day.","See how far\nyou’ve come.","Keep finding\nnew milestones.","A little nudge,\nat your time."]
let captions=["Find your way, one letter at a time.","Every step is a word.","Choose from three to six letters.","Beat par at your own pace.","Revisit your completed trails.","Beautiful cards. Your route stays secret.","Earn seeds. Make a garden of your own.","Follow your progress at every difficulty.","24 badges, with more to work towards.","Choose an optional daily reminder."]
let ink=NSColor(calibratedRed:0.13,green:0.27,blue:0.22,alpha:1)
let cream=NSColor(calibratedRed:0.975,green:0.97,blue:0.945,alpha:1)
let files=try FileManager.default.contentsOfDirectory(at:source,includingPropertiesForKeys:nil).filter{Int($0.lastPathComponent.prefix(2)) != nil}.sorted{$0.lastPathComponent<$1.lastPathComponent}
for (i,file) in files.enumerated() where i<10 {
    guard let image=NSImage(contentsOf:file),let rep=NSBitmapImageRep(data:try Data(contentsOf:file)) else{fatalError("Invalid screenshot")}
    let w=rep.pixelsWide,h=rep.pixelsHigh
    // Core Graphics requires a supported 32-bit drawing surface. Export RGB
    // separately so App Store screenshots contain no alpha channel.
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    guard let context=NSGraphicsContext(bitmapImageRep:bitmap) else{fatalError("No bitmap drawing context")}
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=context
    let W=CGFloat(w),H=CGFloat(h),pad=W>1600
    cream.setFill();NSBezierPath(rect:NSRect(x:0,y:0,width:W,height:H)).fill()
    func text(_ value:String,_ rect:NSRect,_ size:CGFloat,_ serif:Bool=false,_ spacing:CGFloat=0){
        let style=NSMutableParagraphStyle();style.alignment = .center;style.lineSpacing=4
        let base=NSFont.systemFont(ofSize:size,weight:serif ? .medium:.regular)
        let font=serif ? NSFont(descriptor:base.fontDescriptor.withDesign(.serif)!,size:size)!:base
        (value as NSString).draw(in:rect,withAttributes:[.font:font,.foregroundColor:ink,.paragraphStyle:style,.kern:spacing])
    }
    text("WORD TRAILS",NSRect(x:0,y:H-H*0.055,width:W,height:H*0.025),W*0.019,false,W*0.003)
    text(headings[i],NSRect(x:W*0.04,y:H*0.785,width:W*0.92,height:H*0.15),W*(pad ? 0.049:0.067),true)
    text(captions[i],NSRect(x:W*0.035,y:H*0.745,width:W*0.93,height:H*0.037),W*(pad ? 0.018:0.025))
    let scale=min((W-W*0.12)/CGFloat(w),(H*0.69)/CGFloat(h))
    let sw=CGFloat(w)*scale,sh=CGFloat(h)*scale
    let frame=NSRect(x:(W-sw)/2,y:H*0.025,width:sw,height:sh)
    let shadow=NSShadow();shadow.shadowColor=ink.withAlphaComponent(0.16);shadow.shadowBlurRadius=W*0.028;shadow.shadowOffset=NSSize(width:0,height:-W*0.012)
    NSGraphicsContext.saveGraphicsState();shadow.set();NSColor.white.setFill();NSBezierPath(roundedRect:frame,xRadius:W*0.025,yRadius:W*0.025).fill();NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState();NSBezierPath(roundedRect:frame,xRadius:W*0.025,yRadius:W*0.025).addClip();image.draw(in:frame,from:.zero,operation:.copy,fraction:1);NSGraphicsContext.restoreGraphicsState()
    context.flushGraphics();NSGraphicsContext.restoreGraphicsState()
    let rgb=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:3,hasAlpha:false,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    let src=bitmap.bitmapData!,dst=rgb.bitmapData!
    for y in 0..<h {for x in 0..<w {
        let a=y*bitmap.bytesPerRow+x*4,b=y*rgb.bytesPerRow+x*3
        guard src[a+3]==255 else{fatalError("Screenshot canvas must be opaque")}
        dst[b]=src[a];dst[b+1]=src[a+1];dst[b+2]=src[a+2]
    }}
    guard dst[0]>100 else{fatalError("Canvas was not rendered")}
    try rgb.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(file.lastPathComponent))
}
