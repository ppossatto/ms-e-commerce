package com.ppossatto.payment.adapter.out.stripe;

import static org.assertj.core.api.Assertions.assertThat;

import com.ppossatto.payment.domain.model.PaymentRequest;
import com.ppossatto.payment.domain.model.PaymentResult;
import com.stripe.StripeClient;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Contract check against stripe-mock, which validates every request against Stripe's OpenAPI spec.
 * An invalid parameter (name, type, enum value) makes stripe-mock answer 400 and this test fail.
 * The outcome itself is not asserted: stripe-mock is stateless and always returns its fixture
 * (status "requires_payment_method"), so business scenarios live in StripePaymentGatewayAdapterIT.
 */
@Testcontainers
class StripeMockContractIT {

    @Container
    static GenericContainer<?> stripeMock =
            new GenericContainer<>("stripe/stripe-mock:v0.206.0").withExposedPorts(12111);

    @Test
    void createPaymentIntentRequestIsValidForStripeApi() {
        StripeClient client = StripeClient.builder()
                .setApiKey("sk_test_stripe_mock")
                .setApiBase("http://" + stripeMock.getHost() + ":" + stripeMock.getMappedPort(12111))
                .setMaxNetworkRetries(0)
                .build();
        StripePaymentGatewayAdapter adapter = new StripePaymentGatewayAdapter(client);

        PaymentResult result = adapter.charge(new PaymentRequest(UUID.randomUUID(), 1999, "eur", "pm_card_visa"));

        assertThat(result.providerReference()).startsWith("pi_");
    }
}
