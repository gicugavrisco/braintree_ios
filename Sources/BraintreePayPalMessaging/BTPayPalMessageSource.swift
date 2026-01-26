import Foundation

public enum BTPayPalMessagingSource {
    case config(BTPayPalMessagingRequest)
    case data(BTPayPalMessagingData, config: BTPayPalMessagingRequest)
}
