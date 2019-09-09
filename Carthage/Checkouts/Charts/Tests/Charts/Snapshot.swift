import CoreGraphics
import FBSnapshotTestCase

public struct Snapshot
{
    public static let tolerance: CGFloat = 0.001
    
    public static func identifier(_ size: CGSize) -> String {
        #if os(tvOS)
        let identifier = "tvOS"
        #elseif os(iOS)
        let identifier = "iOS"
        #elseif os(OSX)
        let identifier = "macOS"
        #else
        let identifier = ""
        #endif
        
        return "\(identifier)_\(size.width)_\(size.height)"
    }
}

public extension FBSnapshotTestCase
{
    func ChartsSnapshotVerifyView(_ view: UIView, identifier: String = "", suffixes: NSOrderedSet = NSOrderedSet(object: "_64"), perPixelTolerance: CGFloat = 0, overallTolerance: CGFloat = 0, file: StaticString = #file, line: UInt = #line)
    {
        FBSnapshotVerifyView(view, identifier: identifier, suffixes: suffixes, perPixelTolerance: perPixelTolerance, overallTolerance: overallTolerance, file: file, line: line)
    }
}
