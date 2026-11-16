package com.ppossatto.template.domain.port.in;

import com.ppossatto.template.domain.model.Item;

public interface CreateItemUseCase {

    Item create(CreateItemCommand command);

    record CreateItemCommand(String sku, String name) {}
}
