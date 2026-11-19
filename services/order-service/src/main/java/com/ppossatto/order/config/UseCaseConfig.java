package com.ppossatto.order.config;

import com.ppossatto.order.application.ItemService;
import com.ppossatto.order.domain.port.out.CatalogPort;
import com.ppossatto.order.domain.port.out.ItemRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class UseCaseConfig {

    @Bean
    ItemService itemService(ItemRepository repository, CatalogPort catalog) {
        return new ItemService(repository, catalog);
    }
}
