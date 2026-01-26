import Foundation
import PayPalMessages

#if canImport(BraintreeCore)
import BraintreeCore
#endif

public final class BTPayPalMessagingPrefetcher {

    private let apiClient: BTAPIClient
    private let prefetcher: MessagePrefetch

    public init(apiClient: BTAPIClient) {
        self.apiClient = apiClient
        self.prefetcher = MessagePrefetch(perRequestTimeout: 2)
    }

    /// Results are aligned by index with the input `requests`.
    public func prefetch(
        requests: [BTPayPalMessagingRequest],
        completion: @escaping ([Result<BTPayPalMessagingData, Error>]) -> Void
    ) {
        guard !requests.isEmpty else {
            completion([])
            return
        }

        apiClient.fetchOrReturnRemoteConfiguration { [weak self] configuration, error in
            guard let self else { return }

            if let error {
                completion(requests.map { _ in .failure(error) })
                return
            }

            guard let configuration else {
                completion(requests.map { _ in
                    .failure(BTPayPalMessagingError.fetchConfigurationFailed)
                })
                return
            }

            guard let clientID = configuration.json?["paypal"]["clientId"].asString() else {
                completion(requests.map { _ in
                    .failure(BTPayPalMessagingError.payPalClientIDNotFound)
                })
                return
            }

            let configs: [PayPalMessageConfig] = requests.map { request in
                let data = PayPalMessageData(
                    clientID: clientID,
                    environment: configuration.environment == "production" ? .live : .sandbox,
                    amount: request.amount,
                    pageType: request.pageType?.pageTypeRawValue,
                    offerType: request.offerType?.offerTypeRawValue)

                data.buyerCountry = request.buyerCountry

                let style = PayPalMessageStyle(
                    logoType: request.logoType.logoTypeRawValue,
                    color: request.color.messageColorRawValue,
                    textAlign: request.textAlignment.textAlignmentRawValue)

                return PayPalMessageConfig(data: data, style: style)
            }

            self.prefetcher.prefetch(configs: configs) { response in
                let btResults = response.map { result in
                    result.map {
                        BTPayPalMessagingData(
                            configurationEnvironment: configuration.environment,
                            configurationClientID: clientID,
                            offerType: BTPayPalMessagingResponseOfferType($0.offerType),
                            productGroup: BTPayPalMessageResponseProductGroup($0.productGroup),
                            modalCloseButtonWidth: $0.modalCloseButtonWidth,
                            modalCloseButtonHeight: $0.modalCloseButtonHeight,
                            modalCloseButtonAvailWidth: $0.modalCloseButtonAvailWidth,
                            modalCloseButtonAvailHeight: $0.modalCloseButtonAvailHeight,
                            modalCloseButtonColor: $0.modalCloseButtonColor,
                            modalCloseButtonColorType: $0.modalCloseButtonColorType,
                            modalCloseButtonAlternativeText: $0.modalCloseButtonAlternativeText,
                            defaultMainContent: $0.defaultMainContent,
                            defaultMainAlternative: $0.defaultMainAlternative,
                            defaultDisclaimer: $0.defaultDisclaimer,
                            genericMainContent: $0.genericMainContent,
                            genericMainAlternative: $0.genericMainAlternative,
                            genericDisclaimer: $0.genericDisclaimer,
                            logoPlaceholder: $0.logoPlaceholder)
                    }
                }

                completion(btResults)
            }
        }
    }
}

// MARK: -

extension BTPayPalMessagingResponseOfferType {

    init(_ offerType: PayPalMessageResponseOfferType) {
        switch offerType {
        case .payLaterShortTerm:
            self = .payLaterLongTerm

        case .payLaterLongTerm:
            self = .payLaterLongTerm

        case .payLaterPayIn1:
            self = .payLaterPayInOne

        case .payPalCreditNoInterest:
            self = .payPalCreditNoInterest
        case .generic:
            self = .generic
        }
    }
}

extension BTPayPalMessageResponseProductGroup {

    init(_ productGroup: PayPalMessageResponseProductGroup) {
        switch productGroup {
        case .payLater:
            self = .payLater
        case .paypalCredit:
            self = .paypalCredit
        }
    }
}
