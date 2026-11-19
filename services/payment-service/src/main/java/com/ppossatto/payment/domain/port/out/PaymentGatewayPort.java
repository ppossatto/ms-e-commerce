package com.ppossatto.payment.domain.port.out;

import com.ppossatto.payment.domain.model.PaymentRequest;
import com.ppossatto.payment.domain.model.PaymentResult;

/** Payment provider, seen from the domain. Stripe is one implementation; others can be added without touching the domain. */
public interface PaymentGatewayPort {

    /**
     * Charges the order. Calling it again for the same order never charges twice.
     *
     * @throws com.ppossatto.payment.domain.model.PaymentGatewayUnavailableException when the provider cannot be reached
     */
    PaymentResult charge(PaymentRequest request);
}
