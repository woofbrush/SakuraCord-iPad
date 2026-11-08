// The AppKit API used by SakuraCord's macOS sources, implemented on UIKit so the
// same views and layout code run on iPadOS. Only what the app uses exists here.
@_exported import CoreGraphics
@_exported import Foundation
@_exported import SwiftUI
@_exported import UIKit
@_exported import UniformTypeIdentifiers

public typealias NSRect = CGRect
public typealias NSPoint = CGPoint
public typealias NSSize = CGSize
public typealias NSEdgeInsets = UIEdgeInsets
public typealias NSView = UIView
public typealias NSWindow = UIWindow
public typealias NSResponder = UIResponder
public typealias NSColor = UIColor
public typealias NSFont = UIFont
public typealias NSImage = UIImage
public typealias NSBezierPath = UIBezierPath
public typealias NSViewController = UIViewController
public typealias NSLayoutGuide = UILayoutGuide
public typealias NSFontDescriptor = UIFontDescriptor
public typealias NSUserInterfaceItemIdentifier = String

public let NSZeroRect = CGRect.zero
public let NSZeroPoint = CGPoint.zero
public let NSZeroSize = CGSize.zero

public func NSMakeRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(x: x, y: y, width: w, height: h)
}

public func NSPointInRect(_ point: CGPoint, _ rect: CGRect) -> Bool { rect.contains(point) }
public func NSIntersectsRect(_ a: CGRect, _ b: CGRect) -> Bool { a.intersects(b) }
public func NSIsEmptyRect(_ rect: CGRect) -> Bool { rect.isEmpty }
public func NSStringFromRect(_ rect: CGRect) -> String { "\(rect)" }
