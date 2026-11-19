package com.ppossatto.payment.domain.model;

/** The provider could not process the request (network, 5xx, auth). Safe to retry: charges are idempotent per order. */
public class PaymentGatewayUnavailableException extends RuntimeException {

    public PaymentGatewayUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}
