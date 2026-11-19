package com.ppossatto.payment.config;

import com.stripe.StripeClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class StripeConfig {

    /**
     * api-base points to the real Stripe API in production and to stripe-mock or WireMock elsewhere.
     * A client instance (instead of the static Stripe.apiKey) keeps tests isolated from each other.
     */
    @Bean
    StripeClient stripeClient(
            @Value("${app.payment.stripe.api-key}") String apiKey,
            @Value("${app.payment.stripe.api-base}") String apiBase) {
        return StripeClient.builder()
                .setApiKey(apiKey)
                .setApiBase(apiBase)
                .setMaxNetworkRetries(2)
                .build();
    }
}
