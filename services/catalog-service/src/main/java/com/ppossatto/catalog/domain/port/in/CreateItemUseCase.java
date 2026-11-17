package com.ppossatto.catalog.domain.port.in;

import com.ppossatto.catalog.domain.model.Item;

public interface CreateItemUseCase {

    Item create(CreateItemCommand command);

    record CreateItemCommand(String sku, String name) {}
}
