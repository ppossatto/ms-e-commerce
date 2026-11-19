package com.ppossatto.payment.application;

import com.ppossatto.payment.domain.port.in.ProcessPaymentUseCase;
import com.ppossatto.payment.domain.port.out.PaymentGatewayPort;

/**
 * Implements the use cases. No Spring annotations: wiring lives in config/.
 */
public class PaymentService implements ProcessPaymentUseCase {

    private final PaymentGatewayPort paymentGatewayPort;

    public PaymentService(PaymentGatewayPort paymentGatewayPort) {
        this.paymentGatewayPort = paymentGatewayPort;
    }
}
