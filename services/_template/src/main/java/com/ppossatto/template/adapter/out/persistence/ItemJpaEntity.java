package com.ppossatto.template.adapter.out.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

@Entity
@Table(name = "item")
class ItemJpaEntity {

    @Id
    private UUID id;

    @Column(nullable = false, unique = true)
    private String sku;

    @Column(nullable = false)
    private String name;

    protected ItemJpaEntity() {}

    ItemJpaEntity(UUID id, String sku, String name) {
        this.id = id;
        this.sku = sku;
        this.name = name;
    }

    UUID getId() {
        return id;
    }

    String getSku() {
        return sku;
    }

    String getName() {
        return name;
    }
}
