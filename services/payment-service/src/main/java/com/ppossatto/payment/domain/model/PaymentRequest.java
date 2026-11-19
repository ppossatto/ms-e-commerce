package com.ppossatto.payment.domain.model;

import java.util.Objects;
import java.util.UUID;

/**
 * A charge for one order.
 *
 * @param amountInMinorUnits amount in the smallest currency unit (cents for EUR/USD)
 * @param currency ISO 4217 code, lowercase (e.g. "eur")
 * @param paymentMethod provider payment method id (e.g. "pm_card_visa" in Stripe test mode)
 */
public record PaymentRequest(UUID orderId, long amountInMinorUnits, String currency, String paymentMethod) {

    public PaymentRequest {
        Objects.requireNonNull(orderId, "orderId");
        if (amountInMinorUnits <= 0) {
            throw new IllegalArgumentException("amountInMinorUnits must be positive");
        }
        if (currency == null || currency.length() != 3) {
            throw new IllegalArgumentException("currency must be an ISO 4217 code");
        }
        if (paymentMethod == null || paymentMethod.isBlank()) {
            throw new IllegalArgumentException("paymentMethod is required");
        }
    }
}
