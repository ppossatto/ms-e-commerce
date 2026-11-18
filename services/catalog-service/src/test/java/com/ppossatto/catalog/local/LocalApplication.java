package com.ppossatto.catalog.local;

import com.ppossatto.catalog.CatalogApplication;
import org.springframework.boot.SpringApplication;

/**
 * Runs the service locally with the test classpath (WireMock available).
 *   mvn spring-boot:test-run -Dspring-boot.run.profiles=local
 */
public class LocalApplication {

    static void main(String[] args) {
        SpringApplication.from(CatalogApplication::main)
                .with(LocalWireMockConfiguration.class)
                .run(args);
    }
}
