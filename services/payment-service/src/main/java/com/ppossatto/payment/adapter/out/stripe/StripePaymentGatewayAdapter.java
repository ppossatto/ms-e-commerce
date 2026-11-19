package com.ppossatto.payment.adapter.out.stripe;

import com.ppossatto.payment.domain.model.PaymentGatewayUnavailableException;
import com.ppossatto.payment.domain.model.PaymentRequest;
import com.ppossatto.payment.domain.model.PaymentResult;
import com.ppossatto.payment.domain.port.out.PaymentGatewayPort;
import com.stripe.StripeClient;
import com.stripe.exception.CardException;
import com.stripe.exception.StripeException;
import com.stripe.model.PaymentIntent;
import com.stripe.net.RequestOptions;
import com.stripe.param.PaymentIntentCreateParams;
import com.stripe.param.PaymentIntentCreateParams.AutomaticPaymentMethods;
import com.stripe.param.PaymentIntentCreateParams.AutomaticPaymentMethods.AllowRedirects;
import org.springframework.stereotype.Component;

@Component
class StripePaymentGatewayAdapter implements PaymentGatewayPort {

    private final StripeClient stripe;

    StripePaymentGatewayAdapter(StripeClient stripe) {
        this.stripe = stripe;
    }

    @Override
    public PaymentResult charge(PaymentRequest request) {
        PaymentIntentCreateParams params = PaymentIntentCreateParams.builder()
                .setAmount(request.amountInMinorUnits())
                .setCurrency(request.currency())
                .setPaymentMethod(request.paymentMethod())
                .setConfirm(true)
                .setAutomaticPaymentMethods(AutomaticPaymentMethods.builder()
                        .setEnabled(true)
                        .setAllowRedirects(AllowRedirects.NEVER)
                        .build())
                .putMetadata("orderId", request.orderId().toString())
                .build();

        // Same order, same key: a retry (e.g. Kafka redelivery) never charges twice.
        RequestOptions options = RequestOptions.builder()
                .setIdempotencyKey("order-" + request.orderId())
                .build();

        try {
            PaymentIntent intent = stripe.v1().paymentIntents().create(params, options);
            return switch (intent.getStatus()) {
                case "succeeded" -> PaymentResult.approved(intent.getId());
                case "processing", "requires_action", "requires_capture" -> PaymentResult.pending(intent.getId());
                // After confirm=true, "requires_payment_method" means the payment failed.
                default -> PaymentResult.declined(intent.getId(), intent.getStatus());
            };
        } catch (CardException e) {
            return PaymentResult.declined(null, e.getCode());
        } catch (StripeException e) {
            throw new PaymentGatewayUnavailableException("Stripe request failed: " + e.getMessage(), e);
        }
    }
}
