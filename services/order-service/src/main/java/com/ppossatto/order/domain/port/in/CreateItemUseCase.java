package com.ppossatto.order.domain.port.in;

import com.ppossatto.order.domain.model.Item;

public interface CreateItemUseCase {

    Item create(CreateItemCommand command);

    record CreateItemCommand(String sku, String name) {}
}
