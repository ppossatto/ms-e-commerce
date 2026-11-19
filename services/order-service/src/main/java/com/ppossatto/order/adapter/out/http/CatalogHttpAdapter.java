package com.ppossatto.order.adapter.out.http;

import com.ppossatto.order.domain.port.out.CatalogPort;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
class CatalogHttpAdapter implements CatalogPort {

    private final RestClient client;

    CatalogHttpAdapter(RestClient.Builder builder, @Value("${clients.catalog.base-url}") String baseUrl) {
        this.client = builder.baseUrl(baseUrl).build();
    }

    @Override
    public boolean exists(String sku) {
        return client.get().uri("/catalog/{sku}", sku).exchange((request, response) -> {
            var status = response.getStatusCode();
            if (status.is2xxSuccessful()) {
                return true;
            }
            if (status.value() == 404) {
                return false;
            }
            throw new IllegalStateException("Unexpected response from catalog: HTTP " + status.value());
        });
    }
}
