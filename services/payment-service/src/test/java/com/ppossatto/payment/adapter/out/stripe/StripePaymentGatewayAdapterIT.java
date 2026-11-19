package com.ppossatto.payment.adapter.out.stripe;

import static com.github.tomakehurst.wiremock.client.WireMock.aResponse;
import static com.github.tomakehurst.wiremock.client.WireMock.containing;
import static com.github.tomakehurst.wiremock.client.WireMock.equalTo;
import static com.github.tomakehurst.wiremock.client.WireMock.post;
import static com.github.tomakehurst.wiremock.client.WireMock.postRequestedFor;
import static com.github.tomakehurst.wiremock.client.WireMock.urlEqualTo;
import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.wireMockConfig;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.github.tomakehurst.wiremock.client.ResponseDefinitionBuilder;
import com.github.tomakehurst.wiremock.junit5.WireMockExtension;
import com.ppossatto.payment.domain.model.PaymentGatewayUnavailableException;
import com.ppossatto.payment.domain.model.PaymentRequest;
import com.ppossatto.payment.domain.model.PaymentResult;
import com.ppossatto.payment.domain.model.PaymentResult.Status;
import com.stripe.StripeClient;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.RegisterExtension;

/**
 * Business scenarios that stripe-mock cannot produce (it is stateless and always returns the same fixture):
 * approved, declined and provider failure. WireMock plays the Stripe API.
 */
class StripePaymentGatewayAdapterIT {

    @RegisterExtension
    static WireMockExtension stripeApi = WireMockExtension.newInstance()
            .options(wireMockConfig().dynamicPort())
            .build();

    StripePaymentGatewayAdapter adapter;

    @BeforeEach
    void setUp() {
        StripeClient client = StripeClient.builder()
                .setApiKey("sk_test_wiremock")
                .setApiBase(stripeApi.baseUrl())
                .setMaxNetworkRetries(0)
                .build();
        adapter = new StripePaymentGatewayAdapter(client);
    }

    @Test
    void approvesWhenPaymentIntentSucceeds() {
        stripeApi.stubFor(post(urlEqualTo("/v1/payment_intents")).willReturn(json(200, """
                        {"id": "pi_ok", "object": "payment_intent", "status": "succeeded",
                         "amount": 1999, "currency": "eur"}
                        """)));
        UUID orderId = UUID.randomUUID();

        PaymentResult result = adapter.charge(new PaymentRequest(orderId, 1999, "eur", "pm_card_visa"));

        assertThat(result.status()).isEqualTo(Status.APPROVED);
        assertThat(result.providerReference()).isEqualTo("pi_ok");
        stripeApi.verify(postRequestedFor(urlEqualTo("/v1/payment_intents"))
                .withHeader("Idempotency-Key", equalTo("order-" + orderId))
                .withRequestBody(containing("amount=1999"))
                .withRequestBody(containing("confirm=true")));
    }

    @Test
    void declinesWhenCardIsDeclined() {
        stripeApi.stubFor(post(urlEqualTo("/v1/payment_intents")).willReturn(json(402, """
                        {"error": {"type": "card_error", "code": "card_declined",
                                   "decline_code": "generic_decline", "message": "Your card was declined."}}
                        """)));

        PaymentResult result =
                adapter.charge(new PaymentRequest(UUID.randomUUID(), 1999, "eur", "pm_card_chargeDeclined"));

        assertThat(result.status()).isEqualTo(Status.DECLINED);
        assertThat(result.failureCode()).isEqualTo("card_declined");
    }

    @Test
    void reportsUnavailableWhenStripeFails() {
        stripeApi.stubFor(post(urlEqualTo("/v1/payment_intents")).willReturn(json(500, """
                        {"error": {"type": "api_error", "message": "Something went wrong."}}
                        """)));

        assertThatThrownBy(() -> adapter.charge(new PaymentRequest(UUID.randomUUID(), 1999, "eur", "pm_card_visa")))
                .isInstanceOf(PaymentGatewayUnavailableException.class);
    }

    private static ResponseDefinitionBuilder json(int status, String body) {
        return aResponse()
                .withStatus(status)
                .withHeader("Content-Type", "application/json")
                .withBody(body);
    }
}
