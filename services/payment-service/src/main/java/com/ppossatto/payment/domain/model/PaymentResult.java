package com.ppossatto.payment.domain.model;

/**
 * Outcome of a charge, independent of the payment provider.
 *
 * @param providerReference provider id of the payment (e.g. Stripe PaymentIntent id), null when declined before creation
 * @param failureCode provider reason when declined (e.g. "card_declined"), null otherwise
 */
public record PaymentResult(Status status, String providerReference, String failureCode) {

    public enum Status {
        APPROVED,
        DECLINED,
        /** Not final yet (e.g. 3-D Secure or async processing); the outcome arrives later via webhook. */
        PENDING
    }

    public static PaymentResult approved(String providerReference) {
        return new PaymentResult(Status.APPROVED, providerReference, null);
    }

    public static PaymentResult pending(String providerReference) {
        return new PaymentResult(Status.PENDING, providerReference, null);
    }

    public static PaymentResult declined(String providerReference, String failureCode) {
        return new PaymentResult(Status.DECLINED, providerReference, failureCode);
    }
}
