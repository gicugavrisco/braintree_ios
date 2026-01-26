import UIKit
import SwiftUI
import PayPalMessages

#if canImport(BraintreeCore)
import BraintreeCore
#endif

/// Use `BTPayPalMessagingView` to display PayPal messages to promote offers such as Pay Later and PayPal Credit to customers.
/// - Warning: This module is in beta. It's public API may change or be removed in future releases.
public class BTPayPalMessagingView: UIView {

    // MARK: - Properties

    public weak var delegate: BTPayPalMessagingDelegate?

    var messageView: PayPalMessageView?
    var apiClient: BTAPIClient

    // MARK: - Initializers

    ///  Initializes a `BTPayPalMessagingView`.
    /// - Parameter apiClient: The Braintree API client
    public init(apiClient: BTAPIClient) {
        self.apiClient = apiClient

        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Method

    public func start(_ source: BTPayPalMessagingSource) {
        PayPalMessageConfig.setGlobalAnalytics(
            integrationName: "BT_SDK",
            integrationVersion: BTCoreConstants.braintreeSDKVersion)

        apiClient.sendAnalyticsEvent(BTPayPalMessagingAnalytics.started)

        switch source {
        case let .config(request):
            startLoadind(request)

        case let .data(data, request):

            let messageData = PayPalMessageData(
                clientID: data.configurationClientID,
                environment: data.configurationEnvironment == "production" ? .live : .sandbox,
                amount: request.amount,
                pageType: request.pageType?.pageTypeRawValue,
                offerType: request.offerType?.offerTypeRawValue)

            messageData.buyerCountry = request.buyerCountry

            let messageConfig = PayPalMessageConfig(
                data: messageData,
                style: PayPalMessageStyle(
                    logoType: request.logoType.logoTypeRawValue,
                    color: request.color.messageColorRawValue,
                    textAlign: request.textAlignment.textAlignmentRawValue))

            let configData = PayPalMessageConfigData(
                offerType: data.offerType.offerTypeRawValue,
                productGroup: data.productGroup.productGroupRawValue,
                modalCloseButtonWidth: data.modalCloseButtonWidth,
                modalCloseButtonHeight: data.modalCloseButtonHeight,
                modalCloseButtonAvailWidth: data.modalCloseButtonAvailWidth,
                modalCloseButtonAvailHeight: data.modalCloseButtonAvailHeight,
                modalCloseButtonColor: data.modalCloseButtonColor,
                modalCloseButtonColorType: data.modalCloseButtonColorType,
                modalCloseButtonAlternativeText: data.modalCloseButtonAlternativeText,
                defaultMainContent: data.defaultMainContent,
                defaultMainAlternative: data.defaultMainAlternative,
                defaultDisclaimer: data.defaultDisclaimer,
                genericMainContent: data.genericMainContent,
                genericMainAlternative: data.genericMainAlternative,
                genericDisclaimer: data.genericDisclaimer,
                logoPlaceholder: data.logoPlaceholder)

            setupMessageView(with: .data(configData, config: messageConfig))
        }
    }

    private func startLoadind(_ request: BTPayPalMessagingRequest) {
        apiClient.fetchOrReturnRemoteConfiguration { configuration, error in
            if let error {
                self.notifyFailure(with: error)
                return
            }

            guard let configuration else {
                self.notifyFailure(with: BTPayPalMessagingError.fetchConfigurationFailed)
                return
            }

            guard let clientID = configuration.json?["paypal"]["clientId"].asString() else {
                self.notifyFailure(with: BTPayPalMessagingError.payPalClientIDNotFound)
                return
            }

            let messageData = PayPalMessageData(
                clientID: clientID,
                environment: configuration.environment == "production" ? .live : .sandbox,
                amount: request.amount,
                pageType: request.pageType?.pageTypeRawValue,
                offerType: request.offerType?.offerTypeRawValue
            )

            messageData.buyerCountry = request.buyerCountry

            let messageConfig = PayPalMessageConfig(
                data: messageData,
                style: PayPalMessageStyle(
                    logoType: request.logoType.logoTypeRawValue,
                    color: request.color.messageColorRawValue,
                    textAlign: request.textAlignment.textAlignmentRawValue
                )
            )

            self.setupMessageView(with: .config(messageConfig))
        }
    }
    
    private func setupMessageView(with payPalSource: PayPalMessageSource) {
        if let messageView {
            messageView.setSource(payPalSource)

        } else {
            let payPalMessageView = PayPalMessageView(
                source: payPalSource,
                stateDelegate: self,
                eventDelegate: self)

            payPalMessageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(payPalMessageView)
            
            NSLayoutConstraint.activate([
                payPalMessageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                payPalMessageView.trailingAnchor.constraint(equalTo: trailingAnchor),
                payPalMessageView.topAnchor.constraint(equalTo: topAnchor),
                payPalMessageView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            
            messageView = payPalMessageView
        }
    }

    private func notifyFailure(with error: Error) {
        apiClient.sendAnalyticsEvent(BTPayPalMessagingAnalytics.failed, errorDescription: error.localizedDescription)
        delegate?.onError(self, error: error)
    }
}

// MARK: - UIViewRepresentable protocol conformance

public extension BTPayPalMessagingView {

    /// PayPal Messaging for SwiftUI
    struct Representable: UIViewRepresentable {

        private let apiClient: BTAPIClient
        private let delegate: BTPayPalMessagingDelegate?

        private var source = BTPayPalMessagingSource.config(BTPayPalMessagingRequest())

        ///  Initializes a `BTPayPalMessagingView`.
        /// - Parameters:
        ///   - apiClient: The Braintree API client
        ///   - request: an optional `BTPayPalMessagingRequest`
        ///   - delegate: an optional `BTPayPalMessagingDelegate`
        public init(
            apiClient: BTAPIClient,
            source: BTPayPalMessagingSource = .config(BTPayPalMessagingRequest()),
            delegate: BTPayPalMessagingDelegate? = nil
        ) {
            self.apiClient = apiClient
            self.source = source
            self.delegate = delegate
        }

        // MARK: - UIViewRepresentable Methods

        public func makeUIView(context: Context) -> BTPayPalMessagingView {
            let payPalMessagingView = BTPayPalMessagingView(apiClient: apiClient)
            payPalMessagingView.start(source)
            payPalMessagingView.delegate = delegate
            return payPalMessagingView
        }

        public func updateUIView(_ view: BTPayPalMessagingView, context: Context) {
            view.apiClient = apiClient
        }
    }
}

// MARK: - PayPalMessageViewEventDelegate and PayPalMessageViewStateDelegate protocol conformance

extension BTPayPalMessagingView: PayPalMessageViewEventDelegate, PayPalMessageViewStateDelegate {

    public func onClick(_ paypalMessageView: PayPalMessages.PayPalMessageView) {
        delegate?.didSelect(self)
    }

    public func onApply(_ paypalMessageView: PayPalMessages.PayPalMessageView) {
        delegate?.willApply(self)
    }

    public func onLoading(_ paypalMessageView: PayPalMessages.PayPalMessageView) {
        delegate?.willAppear(self)
    }

    public func onSuccess(_ paypalMessageView: PayPalMessages.PayPalMessageView) {
        apiClient.sendAnalyticsEvent(BTPayPalMessagingAnalytics.succeeded)
        delegate?.didAppear(self)
    }

    public func onError(_ paypalMessageView: PayPalMessages.PayPalMessageView, error: PayPalMessages.PayPalMessageError) {
        apiClient.sendAnalyticsEvent(BTPayPalMessagingAnalytics.failed, errorDescription: error.localizedDescription)
        delegate?.onError(self, error: error)
    }
}
