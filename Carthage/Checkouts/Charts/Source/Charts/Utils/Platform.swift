import Foundation

/** This file provides a thin abstraction layer atop of UIKit (iOS, tvOS) and Cocoa (OS X). The two APIs are very much 
 alike, and for the chart library's usage of the APIs it is often sufficient to typealias one to the other. The NSUI*
 types are aliased to either their UI* implementation (on iOS) or their NS* implementation (on OS X). */
#if os(iOS) || os(tvOS)
import UIKit

public typealias NSUIFont = UIFont
public typealias NSUIColor = UIColor
public typealias NSUIEvent = UIEvent
public typealias NSUITouch = UITouch
public typealias NSUIImage = UIImage
public typealias NSUIScrollView = UIScrollView
public typealias NSUIGestureRecognizer = UIGestureRecognizer
public typealias NSUIGestureRecognizerState = UIGestureRecognizer.State
public typealias NSUIGestureRecognizerDelegate = UIGestureRecognizerDelegate
public typealias NSUITapGestureRecognizer = UITapGestureRecognizer
public typealias NSUIPanGestureRecognizer = UIPanGestureRecognizer
#if !os(tvOS)
public typealias NSUIPinchGestureRecognizer = UIPinchGestureRecognizer
public typealias NSUIRotationGestureRecognizer = UIRotationGestureRecognizer
#endif
public typealias NSUIScreen = UIScreen

public typealias NSUIDisplayLink = CADisplayLink

extension NSUITapGestureRecognizer
{
    @objc final func nsuiNumberOfTouches() -> Int
    {
        return numberOfTouches
    }

    @objc final var nsuiNumberOfTapsRequired: Int
        {
        get
        {
            return self.numberOfTapsRequired
        }
        set
        {
            self.numberOfTapsRequired = newValue
        }
    }
}

extension NSUIPanGestureRecognizer
{
    @objc final func nsuiNumberOfTouches() -> Int
    {
        return numberOfTouches
    }

    @objc final func nsuiLocationOfTouch(_ touch: Int, inView: UIView?) -> CGPoint
    {
        return super.location(ofTouch: touch, in: inView)
    }
}

#if !os(tvOS)
extension NSUIRotationGestureRecognizer
{
    @objc final var nsuiRotation: CGFloat
        {
        get { return rotation }
        set { rotation = newValue }
    }
}
#endif

#if !os(tvOS)
extension NSUIPinchGestureRecognizer
{
    @objc final var nsuiScale: CGFloat
        {
        get
        {
            return scale
        }
        set
        {
            scale = newValue
        }
    }

    @objc final func nsuiLocationOfTouch(_ touch: Int, inView: UIView?) -> CGPoint
    {
        return super.location(ofTouch: touch, in: inView)
    }
}
#endif

open class NSUIView: UIView
{
    public final override func touchesBegan(_ touches: Set<NSUITouch>, with event: NSUIEvent?)
    {
        self.nsuiTouchesBegan(touches, withEvent: event)
    }

    public final override func touchesMoved(_ touches: Set<NSUITouch>, with event: NSUIEvent?)
    {
        self.nsuiTouchesMoved(touches, withEvent: event)
    }

    public final override func touchesEnded(_ touches: Set<NSUITouch>, with event: NSUIEvent?)
    {
        self.nsuiTouchesEnded(touches, withEvent: event)
    }

    public final override func touchesCancelled(_ touches: Set<NSUITouch>, with event: NSUIEvent?)
    {
        self.nsuiTouchesCancelled(touches, withEvent: event)
    }

    @objc open func nsuiTouchesBegan(_ touches: Set<NSUITouch>, withEvent event: NSUIEvent?)
    {
        super.touchesBegan(touches, with: event!)
    }

    @objc open func nsuiTouchesMoved(_ touches: Set<NSUITouch>, withEvent event: NSUIEvent?)
    {
        super.touchesMoved(touches, with: event!)
    }

    @objc open func nsuiTouchesEnded(_ touches: Set<NSUITouch>, withEvent event: NSUIEvent?)
    {
        super.touchesEnded(touches, with: event!)
    }

    @objc open func nsuiTouchesCancelled(_ touches: Set<NSUITouch>?, withEvent event: NSUIEvent?)
    {
        super.touchesCancelled(touches!, with: event!)
    }

    @objc var nsuiLayer: CALayer?
    {
        return self.layer
    }
}

extension UIView
{
    @objc final var nsuiGestureRecognizers: [NSUIGestureRecognizer]?
    {
        return self.gestureRecognizers
    }
}

extension UIScrollView
{
    @objc var nsuiIsScrollEnabled: Bool
        {
        get { return isScrollEnabled }
        set { isScrollEnabled = newValue }
    }
}

extension UIScreen
{
    @objc final var nsuiScale: CGFloat
    {
        return self.scale
    }
}

func NSUIGraphicsGetCurrentContext() -> CGContext?
{
    return UIGraphicsGetCurrentContext()
}

func NSUIGraphicsGetImageFromCurrentImageContext() -> NSUIImage!
{
    return UIGraphicsGetImageFromCurrentImageContext()
}

func NSUIGraphicsPushContext(_ context: CGContext)
{
    UIGraphicsPushContext(context)
}

func NSUIGraphicsPopContext()
{
    UIGraphicsPopContext()
}

func NSUIGraphicsEndImageContext()
{
    UIGraphicsEndImageContext()
}

func NSUIImagePNGRepresentation(_ image: NSUIImage) -> Data?
{
    return image.pngData()
}

func NSUIImageJPEGRepresentation(_ image: NSUIImage, _ quality: CGFloat = 0.8) -> Data?
{
    return image.jpegData(compressionQuality: quality)
}

func NSUIMainScreen() -> NSUIScreen?
{
    return NSUIScreen.main
}

func NSUIGraphicsBeginImageContextWithOptions(_ size: CGSize, _ opaque: Bool, _ scale: CGFloat)
{
    UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
}

#endif

#if os(OSX)
import Cocoa
import Quartz

public typealias NSUIFont = NSFont
public typealias NSUIColor = NSColor
public typealias NSUIEvent = NSEvent
public typealias NSUITouch = NSTouch
public typealias NSUIImage = NSImage
public typealias NSUIScrollView = NSScrollView
public typealias NSUIGestureRecognizer = NSGestureRecognizer
public typealias NSUIGestureRecognizerState = NSGestureRecognizer.State
public typealias NSUIGestureRecognizerDelegate = NSGestureRecognizerDelegate
public typealias NSUITapGestureRecognizer = NSClickGestureRecognizer
public typealias NSUIPanGestureRecognizer = NSPanGestureRecognizer
public typealias NSUIPinchGestureRecognizer = NSMagnificationGestureRecognizer
public typealias NSUIRotationGestureRecognizer = NSRotationGestureRecognizer
public typealias NSUIScreen = NSScreen

/** On OS X there is no CADisplayLink. Use a 60 fps timer to render the animations. */
public class NSUIDisplayLink
{
    private var timer: Timer?
    private var displayLink: CVDisplayLink?
    private var _timestamp: CFTimeInterval = 0.0

    private weak var _target: AnyObject?
    private var _selector: Selector

    public var timestamp: CFTimeInterval
    {
        return _timestamp
    }

		init(target: Any, selector: Selector)
    {
        _target = target as AnyObject
        _selector = selector

        if CVDisplayLinkCreateWithActiveCGDisplays(&displayLink) == kCVReturnSuccess
        {

            CVDisplayLinkSetOutputCallback(displayLink!, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, userData) -> CVReturn in

                let _self = unsafeBitCast(userData, to: NSUIDisplayLink.self)
                    
                _self._timestamp = CFAbsoluteTimeGetCurrent()
                _self._target?.performSelector(onMainThread: _self._selector, with: _self, waitUntilDone: false)
                    
                return kCVReturnSuccess
                }, Unmanaged.passUnretained(self).toOpaque())
        }
        else
        {
            timer = Timer(timeInterval: 1.0 / 60.0, target: target, selector: selector, userInfo: nil, repeats: true)
        }
		}

    deinit
    {
        stop()
    }

    open func add(to runloop: RunLoop, forMode mode: RunLoop.Mode)
    {
        if displayLink != nil
        {
            CVDisplayLinkStart(displayLink!)
        }
        else if timer != nil
        {
            runloop.add(timer!, forMode: mode)
        }
    }

    open func remove(from: RunLoop, forMode: RunLoop.Mode)
    {
        stop()
    }

    private func stop()
    {
        if displayLink != nil
        {
            CVDisplayLinkStop(displayLink!)
        }
        if timer != nil
        {
            timer?.invalidate()
        }
    }
}

/** The 'tap' gesture is mapped to clicks. */
extension NSUITapGestureRecognizer
{
    final func nsuiNumberOfTouches() -> Int
    {
        return 1
    }

    final var nsuiNumberOfTapsRequired: Int
        {
        get
        {
            return self.numberOfClicksRequired
        }
        set
        {
            self.numberOfClicksRequired = newValue
        }
    }
}

extension NSUIPanGestureRecognizer
{
    final func nsuiNumberOfTouches() -> Int
    {
        return 1
    }

    /// FIXME: Currently there are no more than 1 touch in OSX gestures, and not way to create custom touch gestures.
    final func nsuiLocationOfTouch(_ touch: Int, inView: NSView?) -> NSPoint
    {
        return super.location(in: inView)
    }
}

extension NSUIRotationGestureRecognizer
{
    /// FIXME: Currently there are no velocities in OSX gestures, and not way to create custom touch gestures.
    final var velocity: CGFloat
    {
        return 0.1
    }

    final var nsuiRotation: CGFloat
        {
        get { return -rotation }
        set { rotation = -newValue }
    }
}

extension NSUIPinchGestureRecognizer
{
    final var nsuiScale: CGFloat
        {
        get
        {
            return magnification + 1.0
        }
        set
        {
            magnification = newValue - 1.0
        }
    }

    /// FIXME: Currently there are no more than 1 touch in OSX gestures, and not way to create custom touch gestures.
    final func nsuiLocationOfTouch(_ touch: Int, inView view: NSView?) -> NSPoint
    {
        return super.location(in: view)
    }
}

extension NSView
{
    final var nsuiGestureRecognizers: [NSGestureRecognizer]?
    {
        return self.gestureRecognizers
    }
}

extension NSScrollView
{
    var nsuiIsScrollEnabled: Bool
    {
        get { return scrollEnabled }
        set { scrollEnabled = newValue }
    }
}

open class NSUIView: NSView
{
    /// A private constant to set the accessibility role during initialization.
    /// It ensures parity with the iOS element ordering as well as numbered counts of chart components.
    /// (See Platform+Accessibility for details)
    private let role: NSAccessibility.Role = .list

    public override init(frame frameRect: NSRect)
    {
        super.init(frame: frameRect)
        setAccessibilityRole(role)
    }

    required public init?(coder decoder: NSCoder)
    {
        super.init(coder: decoder)
        setAccessibilityRole(role)
    }

    public final override var isFlipped: Bool
    {
        return true
    }

    func setNeedsDisplay()
    {
        self.setNeedsDisplay(self.bounds)
    }

    public final override func touchesBegan(with event: NSEvent)
    {
        self.nsuiTouchesBegan(event.touches(matching: .any, in: self), withEvent: event)
    }

    public final override func touchesEnded(with event: NSEvent)
    {
        self.nsuiTouchesEnded(event.touches(matching: .any, in: self), withEvent: event)
    }

    public final override func touchesMoved(with event: NSEvent)
    {
        self.nsuiTouchesMoved(event.touches(matching: .any, in: self), withEvent: event)
    }

    open override func touchesCancelled(with event: NSEvent)
    {
        self.nsuiTouchesCancelled(event.touches(matching: .any, in: self), withEvent: event)
    }

    open func nsuiTouchesBegan(_ touches: Set<NSUITouch>, withEvent event: NSUIEvent?)
    {
        super.touchesBegan(with: event!)
    }

    open func nsuiTouchesMoved(_ touches: Set<NSUITouch>, withEvent event: NSUIEvent?)
    {
        super.touchesMoved(with: event!)
    }

    open func nsuiTouchesEnded(_ touches: Set<NSUITouch>, withEvent event: NSUIEvent?)
    {
        super.touchesEnded(with: event!)
    }

    open func nsuiTouchesCancelled(_ touches: Set<NSUITouch>?, withEvent event: NSUIEvent?)
    {
        super.touchesCancelled(with: event!)
    }

    open var backgroundColor: NSUIColor?
        {
        get
        {
            return self.layer?.backgroundColor == nil
                ? nil
                : NSColor(cgColor: self.layer!.backgroundColor!)
        }
        set
        {
            self.wantsLayer = true
            self.layer?.backgroundColor = newValue == nil ? nil : newValue!.cgColor
        }
    }

    final var nsuiLayer: CALayer?
    {
        return self.layer
    }
}

extension NSFont
{
    var lineHeight: CGFloat
    {
        // Not sure if this is right, but it looks okay
        return self.boundingRectForFont.size.height
    }
}

extension NSScreen
{
    final var nsuiScale: CGFloat
    {
        return self.backingScaleFactor
    }
}

extension NSImage
{
    var cgImage: CGImage?
    {
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

extension NSTouch
{
    /** Touch locations on OS X are relative to the trackpad, whereas on iOS they are actually *on* the view. */
    func locationInView(view: NSView) -> NSPoint
    {
        let n = self.normalizedPosition
        let b = view.bounds
        return NSPoint(x: b.origin.x + b.size.width * n.x, y: b.origin.y + b.size.height * n.y)
    }
}

extension NSScrollView
{
    var scrollEnabled: Bool
    {
        get
        {
            return true
        }
        set
        {
            // FIXME: We can't disable  scrolling it on OSX
        }
    }
}

func NSUIGraphicsGetCurrentContext() -> CGContext?
{
    return NSGraphicsContext.current?.cgContext
}

func NSUIGraphicsPushContext(_ context: CGContext)
{
    let cx = NSGraphicsContext(cgContext: context, flipped: true)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = cx
}

func NSUIGraphicsPopContext()
{
    NSGraphicsContext.restoreGraphicsState()
}

func NSUIImagePNGRepresentation(_ image: NSUIImage) -> Data?
{
    image.lockFocus()
    let rep = NSBitmapImageRep(focusedViewRect: NSMakeRect(0, 0, image.size.width, image.size.height))
    image.unlockFocus()
    return rep?.representation(using: .png, properties: [:])
}

func NSUIImageJPEGRepresentation(_ image: NSUIImage, _ quality: CGFloat = 0.9) -> Data?
{
    image.lockFocus()
    let rep = NSBitmapImageRep(focusedViewRect: NSMakeRect(0, 0, image.size.width, image.size.height))
    image.unlockFocus()
    return rep?.representation(using: .jpeg, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: quality])
}

private var imageContextStack: [CGFloat] = []

func NSUIGraphicsBeginImageContextWithOptions(_ size: CGSize, _ opaque: Bool, _ scale: CGFloat)
{
    var scale = scale
    if scale == 0.0
    {
        scale = NSScreen.main?.backingScaleFactor ?? 1.0
    }

    let width = Int(size.width * scale)
    let height = Int(size.height * scale)

    if width > 0 && height > 0
    {
        imageContextStack.append(scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4*width, space: colorSpace, bitmapInfo: (opaque ?  CGImageAlphaInfo.noneSkipFirst.rawValue : CGImageAlphaInfo.premultipliedFirst.rawValue))
            else { return }

        ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(height)))
        ctx.scaleBy(x: scale, y: scale)
        NSUIGraphicsPushContext(ctx)
    }
}

func NSUIGraphicsGetImageFromCurrentImageContext() -> NSUIImage?
{
    if !imageContextStack.isEmpty
    {
        guard let ctx = NSUIGraphicsGetCurrentContext()
            else { return nil }

        let scale = imageContextStack.last!
        if let theCGImage = ctx.makeImage()
        {
            let size = CGSize(width: CGFloat(ctx.width) / scale, height: CGFloat(ctx.height) / scale)
            let image = NSImage(cgImage: theCGImage, size: size)
            return image
        }
    }
    return nil
}

func NSUIGraphicsEndImageContext()
{
    if imageContextStack.last != nil
    {
        imageContextStack.removeLast()
        NSUIGraphicsPopContext()
    }
}

func NSUIMainScreen() -> NSUIScreen?
{
    return NSUIScreen.main
}

#endif
