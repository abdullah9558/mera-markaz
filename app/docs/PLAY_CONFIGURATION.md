# Google Play and monetization configuration

## Product identifiers

The application reads product IDs at build time. It never embeds display prices.

```text
--dart-define=PAKPOCKET_MONTHLY_PRODUCT_ID=<play-product-id>
--dart-define=PAKPOCKET_YEARLY_PRODUCT_ID=<play-product-id>
--dart-define=PAKPOCKET_LIFETIME_PRODUCT_ID=<play-product-id>
```

Monthly and yearly products must be configured as subscriptions in Play Console. Lifetime must be configured as a one-time product. Titles and localized prices displayed by PakPocket come from Google Play product details.

If IDs are omitted, the development gateway returns no products, shows no invented pricing, and explains that Play products are unconfigured.

## Verification requirement

The included client adapter handles the purchase stream, acknowledgement/completion, restore, cancellation, store errors, and cached entitlement state. Before production release, purchase tokens must also be sent to a trusted backend and verified with the Google Play Developer API. The backend must remain the authority for subscription expiry, cancellation, refunds, grace periods, account hold, upgrades, and revocation. Client purchase status alone is not sufficient protection for a production entitlement.

## Advertising

Advertising is disabled in development. `AdPolicy` prevents ads for Premium users and prevents interstitials during expense entry, Udhaar entry, and repayment flows. Before enabling ads, add environment-specific AdMob IDs, Google consent handling, test-device configuration, frequency caps, and an accurate Data Safety declaration.

## Release prerequisites

- Configure an upload keystore outside source control.
- Create Play products and activate base plans/offers.
- Complete license-test purchases and restore/refund scenarios.
- Deploy server-side purchase verification and Real-time Developer Notifications.
- Configure privacy/consent, Data Safety, ads declarations, and subscription disclosures.
- Replace development policy/legal copy with reviewed hosted documents and support contact details.
