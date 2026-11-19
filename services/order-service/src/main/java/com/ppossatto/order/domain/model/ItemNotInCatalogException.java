package com.ppossatto.order.domain.model;

public class ItemNotInCatalogException extends RuntimeException {

    public ItemNotInCatalogException(String sku) {
        super("SKU not found in catalog: " + sku);
    }
}
