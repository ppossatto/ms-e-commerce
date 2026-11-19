package com.ppossatto.notifications.config;

import com.ppossatto.notifications.application.ItemService;
import com.ppossatto.notifications.domain.port.out.CatalogPort;
import com.ppossatto.notifications.domain.port.out.ItemRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class UseCaseConfig {

    @Bean
    ItemService itemService(ItemRepository repository, CatalogPort catalog) {
        return new ItemService(repository, catalog);
    }
}
