package com.ppossatto.template;

import static com.github.tomakehurst.wiremock.client.WireMock.aResponse;
import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.urlEqualTo;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.ppossatto.template.domain.model.Item;
import com.ppossatto.template.domain.model.ItemNotInCatalogException;
import com.ppossatto.template.domain.port.in.CreateItemUseCase;
import com.ppossatto.template.domain.port.in.CreateItemUseCase.CreateItemCommand;
import com.ppossatto.template.domain.port.in.FindItemUseCase;
import com.github.tomakehurst.wiremock.WireMockServer;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.wiremock.spring.ConfigureWireMock;
import org.wiremock.spring.EnableWireMock;
import org.wiremock.spring.InjectWireMock;

/**
 * Integration test: real Postgres (Testcontainers) + simulated external API (WireMock).
 * Exercises the persistence and HTTP adapters through the inbound ports.
 */
@SpringBootTest
@Import(TestcontainersConfiguration.class)
@EnableWireMock(@ConfigureWireMock(name = "catalog", baseUrlProperties = "clients.catalog.base-url"))
class ItemFlowIT {

    @InjectWireMock("catalog")
    WireMockServer catalog;

    @Autowired
    CreateItemUseCase createItem;

    @Autowired
    FindItemUseCase findItem;

    @Test
    void persistsItemWhenCatalogConfirmsSku() {
        catalog.stubFor(get(urlEqualTo("/catalog/SKU-1")).willReturn(aResponse().withStatus(200)));

        Item created = createItem.create(new CreateItemCommand("SKU-1", "Mug"));

        assertThat(findItem.findById(created.id())).contains(created);
    }

    @Test
    void rejectsItemWhenCatalogReturns404() {
        catalog.stubFor(get(urlEqualTo("/catalog/SKU-X")).willReturn(aResponse().withStatus(404)));

        assertThatThrownBy(() -> createItem.create(new CreateItemCommand("SKU-X", "Mug")))
                .isInstanceOf(ItemNotInCatalogException.class);
    }
}
