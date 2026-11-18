package com.ppossatto.catalog.domain.port.in;

import com.ppossatto.catalog.domain.model.Item;
import java.util.Optional;
import java.util.UUID;

public interface FindItemUseCase {

    Optional<Item> findById(UUID id);
}
