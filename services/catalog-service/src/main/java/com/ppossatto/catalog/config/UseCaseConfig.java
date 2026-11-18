package com.ppossatto.catalog.config;

import com.ppossatto.catalog.application.ItemService;
import com.ppossatto.catalog.domain.port.out.CatalogPort;
import com.ppossatto.catalog.domain.port.out.ItemRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class UseCaseConfig {

    @Bean
    ItemService itemService(ItemRepository repository, CatalogPort catalog) {
        return new ItemService(repository, catalog);
    }
}
