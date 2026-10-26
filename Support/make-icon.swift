import AppKit
import Foundation

let folder = URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
let image = NSImage(size:NSSize(width:1024,height:1024))
image.lockFocus()
NSColor(calibratedRed:0.13,green:0.27,blue:0.22,alpha:1).setFill()
NSBezierPath(rect:NSRect(x:0,y:0,width:1024,height:1024)).fill()
NSColor(calibratedRed:0.77,green:0.83,blue:0.71,alpha:0.25).setFill()
let hill = NSBezierPath(); hill.move(to:NSPoint(x:0,y:180)); hill.curve(to:NSPoint(x:1024,y:380),controlPoint1:NSPoint(x:260,y:620),controlPoint2:NSPoint(x:630,y:700)); hill.line(to:NSPoint(x:1024,y:0)); hill.line(to:.zero); hill.close(); hill.fill()
NSColor(calibratedRed:0.87,green:0.68,blue:0.34,alpha:1).setFill()
NSBezierPath(ovalIn:NSRect(x:690,y:695,width:120,height:120)).fill()
let path = NSBezierPath(); path.move(to:NSPoint(x:370,y:110)); path.curve(to:NSPoint(x:590,y:430),controlPoint1:NSPoint(x:850,y:280),controlPoint2:NSPoint(x:260,y:350)); path.curve(to:NSPoint(x:600,y:670),controlPoint1:NSPoint(x:850,y:550),controlPoint2:NSPoint(x:430,y:610)); path.lineWidth = 82; path.lineCapStyle = .round
NSColor(calibratedRed:0.97,green:0.96,blue:0.92,alpha:1).setStroke(); path.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data:image.tiffRepresentation!)!
try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("icon.png"))
let contents: [String:Any] = ["images":[["filename":"icon.png","idiom":"universal","platform":"ios","size":"1024x1024"]],"info":["author":"xcode","version":1]]
try JSONSerialization.data(withJSONObject:contents,options:.prettyPrinted).write(to:folder.appendingPathComponent("Contents.json"))
