package com.ppossatto.catalog.domain.port.out;

import com.ppossatto.catalog.domain.model.Item;
import java.util.Optional;
import java.util.UUID;

public interface ItemRepository {

    Item save(Item item);

    Optional<Item> findById(UUID id);
}
