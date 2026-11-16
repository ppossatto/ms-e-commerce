package com.ppossatto.template.config;

import com.ppossatto.template.application.ItemService;
import com.ppossatto.template.domain.port.out.CatalogPort;
import com.ppossatto.template.domain.port.out.ItemRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class UseCaseConfig {

    @Bean
    ItemService itemService(ItemRepository repository, CatalogPort catalog) {
        return new ItemService(repository, catalog);
    }
}
