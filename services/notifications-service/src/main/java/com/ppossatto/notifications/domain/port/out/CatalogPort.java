package com.ppossatto.notifications.domain.port.out;

/** Example external dependency (another service/API), implemented over HTTP. */
public interface CatalogPort {

    boolean exists(String sku);
}
