package com.ppossatto.payment.local;

import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.options;

import com.github.tomakehurst.wiremock.WireMockServer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Profile;

/**
 * Starts WireMock when the "local" profile is active.
 * Stubs are loaded from the classpath folder "wiremock":
 *   src/test/resources/wiremock/mappings/  request/response definitions (JSON)
 *   src/test/resources/wiremock/__files/   response bodies referenced by "bodyFileName"
 * Lives in src/test so WireMock never ends up in the production jar.
 */
@Profile("local")
@TestConfiguration(proxyBeanMethods = false)
public class LocalWireMockConfiguration {

    @Bean(initMethod = "start", destroyMethod = "stop")
    WireMockServer wireMockServer(@Value("${wiremock.port}") int port) {
        return new WireMockServer(options().port(port).usingFilesUnderClasspath("wiremock"));
    }
}
