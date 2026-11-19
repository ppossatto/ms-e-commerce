package com.ppossatto.order.domain.port.in;

import com.ppossatto.order.domain.model.Item;
import java.util.Optional;
import java.util.UUID;

public interface FindItemUseCase {

    Optional<Item> findById(UUID id);
}
