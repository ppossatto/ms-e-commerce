package com.ppossatto.template.domain.port.in;

import com.ppossatto.template.domain.model.Item;
import java.util.Optional;
import java.util.UUID;

public interface FindItemUseCase {

    Optional<Item> findById(UUID id);
}
