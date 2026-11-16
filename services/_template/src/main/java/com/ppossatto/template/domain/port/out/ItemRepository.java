package com.ppossatto.template.domain.port.out;

import com.ppossatto.template.domain.model.Item;
import java.util.Optional;
import java.util.UUID;

public interface ItemRepository {

    Item save(Item item);

    Optional<Item> findById(UUID id);
}
