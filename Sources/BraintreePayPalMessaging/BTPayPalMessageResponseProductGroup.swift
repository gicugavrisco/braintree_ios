import Foundation
import PayPalMessages

public enum BTPayPalMessageResponseProductGroup {
    case payLater
    case paypalCredit

    var productGroupRawValue: PayPalMessageResponseProductGroup {
        switch self {
        case .payLater:
            return .payLater
        case .paypalCredit:
            return .paypalCredit
        }
    }
}
