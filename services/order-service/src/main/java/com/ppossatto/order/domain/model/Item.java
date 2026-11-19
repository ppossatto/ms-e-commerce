package com.ppossatto.order.domain.model;

import java.util.Objects;
import java.util.UUID;

/** Example domain entity: plain Java, no Spring/JPA. */
public record Item(UUID id, String sku, String name) {

    public Item {
        Objects.requireNonNull(id, "id");
        if (sku == null || sku.isBlank()) {
            throw new IllegalArgumentException("sku is required");
        }
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("name is required");
        }
    }

    public static Item create(String sku, String name) {
        return new Item(UUID.randomUUID(), sku, name);
    }
}
