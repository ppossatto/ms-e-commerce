package com.ppossatto.template.adapter.out.persistence;

import com.ppossatto.template.domain.model.Item;
import com.ppossatto.template.domain.port.out.ItemRepository;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
class ItemPersistenceAdapter implements ItemRepository {

    private final ItemJpaRepository jpa;

    ItemPersistenceAdapter(ItemJpaRepository jpa) {
        this.jpa = jpa;
    }

    @Override
    @Transactional
    public Item save(Item item) {
        jpa.save(new ItemJpaEntity(item.id(), item.sku(), item.name()));
        return item;
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<Item> findById(UUID id) {
        return jpa.findById(id).map(e -> new Item(e.getId(), e.getSku(), e.getName()));
    }
}
