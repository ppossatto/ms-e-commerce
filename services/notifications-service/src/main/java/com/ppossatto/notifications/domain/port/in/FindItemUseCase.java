package com.ppossatto.notifications.domain.port.in;

import com.ppossatto.notifications.domain.model.Item;
import java.util.Optional;
import java.util.UUID;

public interface FindItemUseCase {

    Optional<Item> findById(UUID id);
}
