package com.ppossatto.notifications.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.Mockito.never;

import com.ppossatto.notifications.domain.model.Item;
import com.ppossatto.notifications.domain.model.ItemNotInCatalogException;
import com.ppossatto.notifications.domain.port.in.CreateItemUseCase.CreateItemCommand;
import com.ppossatto.notifications.domain.port.out.CatalogPort;
import com.ppossatto.notifications.domain.port.out.ItemRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ItemServiceTest {

    @Mock
    ItemRepository repository;

    @Mock
    CatalogPort catalog;

    @InjectMocks
    ItemService service;

    @Test
    void createsItemWhenSkuExistsInCatalog() {
        given(catalog.exists("SKU-1")).willReturn(true);
        given(repository.save(any(Item.class))).willAnswer(inv -> inv.getArgument(0));

        Item item = service.create(new CreateItemCommand("SKU-1", "Mug"));

        assertThat(item.sku()).isEqualTo("SKU-1");
        assertThat(item.name()).isEqualTo("Mug");
        then(repository).should().save(item);
    }

    @Test
    void rejectsItemWhenSkuIsNotInCatalog() {
        given(catalog.exists("SKU-X")).willReturn(false);

        assertThatThrownBy(() -> service.create(new CreateItemCommand("SKU-X", "Mug")))
                .isInstanceOf(ItemNotInCatalogException.class);
        then(repository).should(never()).save(any());
    }
}
