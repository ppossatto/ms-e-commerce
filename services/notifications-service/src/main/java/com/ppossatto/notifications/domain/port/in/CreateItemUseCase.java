package com.ppossatto.notifications.domain.port.in;

import com.ppossatto.notifications.domain.model.Item;

public interface CreateItemUseCase {

    Item create(CreateItemCommand command);

    record CreateItemCommand(String sku, String name) {}
}
