package com.ppossatto.order.domain.port.out;

import com.ppossatto.order.domain.model.Item;
import java.util.Optional;
import java.util.UUID;

public interface ItemRepository {

    Item save(Item item);

    Optional<Item> findById(UUID id);
}
