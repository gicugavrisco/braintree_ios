import Foundation
import PayPalMessages

public enum BTPayPalMessagingResponseOfferType {
    case payLaterShortTerm
    case payLaterLongTerm
    case payLaterPayInOne
    case payPalCreditNoInterest
    case generic

    var offerTypeRawValue: PayPalMessageResponseOfferType {
        switch self {
        case .payLaterShortTerm:
            return .payLaterShortTerm
        case .payLaterLongTerm:
            return .payLaterLongTerm
        case .payLaterPayInOne:
            return .payLaterPayIn1
        case .payPalCreditNoInterest:
            return .payPalCreditNoInterest
        case .generic:
            return .generic
        }
    }
}
