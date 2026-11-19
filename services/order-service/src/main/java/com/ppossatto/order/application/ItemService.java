package com.ppossatto.order.application;

import com.ppossatto.order.domain.model.Item;
import com.ppossatto.order.domain.model.ItemNotInCatalogException;
import com.ppossatto.order.domain.port.in.CreateItemUseCase;
import com.ppossatto.order.domain.port.in.FindItemUseCase;
import com.ppossatto.order.domain.port.out.CatalogPort;
import com.ppossatto.order.domain.port.out.ItemRepository;
import java.util.Optional;
import java.util.UUID;

/** Implements the use cases. No Spring annotations: wiring lives in config/. */
public class ItemService implements CreateItemUseCase, FindItemUseCase {

    private final ItemRepository repository;
    private final CatalogPort catalog;

    public ItemService(ItemRepository repository, CatalogPort catalog) {
        this.repository = repository;
        this.catalog = catalog;
    }

    @Override
    public Item create(CreateItemCommand command) {
        if (!catalog.exists(command.sku())) {
            throw new ItemNotInCatalogException(command.sku());
        }
        return repository.save(Item.create(command.sku(), command.name()));
    }

    @Override
    public Optional<Item> findById(UUID id) {
        return repository.findById(id);
    }
}
