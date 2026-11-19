package com.ppossatto.notifications.domain.port.out;

import com.ppossatto.notifications.domain.model.Item;
import java.util.Optional;
import java.util.UUID;

public interface ItemRepository {

    Item save(Item item);

    Optional<Item> findById(UUID id);
}
