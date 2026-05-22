import Foundation

extension String {
    var captureFlowNonEmpty: String? {
        isEmpty ? nil : self
    }
}
