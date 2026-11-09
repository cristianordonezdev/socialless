import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Original vector construction. No UI/WindowServer connection or external assets.
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0x33 / 255.0, green: 0x5C / 255.0, blue: 0xDB / 255.0, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.move(to: CGPoint(x: 300, y: 310))
context.addCurve(to: CGPoint(x: 770, y: 768), control1: CGPoint(x: 215, y: 565), control2: CGPoint(x: 450, y: 770))
context.addCurve(to: CGPoint(x: 300, y: 310), control1: CGPoint(x: 786, y: 470), control2: CGPoint(x: 554, y: 223))
context.closePath()
context.setFillColor(CGColor(red: 0xED / 255.0, green: 0xF3 / 255.0, blue: 0xFF / 255.0, alpha: 1))
context.fillPath()
context.move(to: CGPoint(x: 246, y: 230))
context.addCurve(to: CGPoint(x: 627, y: 630), control1: CGPoint(x: 350, y: 425), control2: CGPoint(x: 496, y: 528))
context.setLineWidth(35)
context.setLineCap(.round)
context.setStrokeColor(CGColor(red: 0x33 / 255.0, green: 0x5C / 255.0, blue: 0xDB / 255.0, alpha: 1))
context.strokePath()
let directory = URL(fileURLWithPath: "SocialLess/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent("AppIcon.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
try """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
""".write(to: directory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
