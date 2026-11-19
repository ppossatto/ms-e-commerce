package com.ppossatto.notifications.local;

import com.ppossatto.notifications.NotificationsApplication;
import org.springframework.boot.SpringApplication;

/**
 * Runs the service locally with the test classpath (WireMock available).
 *   mvn spring-boot:test-run -Dspring-boot.run.profiles=local
 */
public class LocalApplication {

    static void main(String[] args) {
        SpringApplication.from(NotificationsApplication::main)
                .with(LocalWireMockConfiguration.class)
                .run(args);
    }
}
