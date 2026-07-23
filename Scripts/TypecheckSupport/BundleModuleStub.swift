// Used only by Scripts/typecheck_without_xcode.sh. SwiftPM generates this accessor in real builds.
import Foundation

extension Bundle {
    static var module: Bundle { .main }
}
