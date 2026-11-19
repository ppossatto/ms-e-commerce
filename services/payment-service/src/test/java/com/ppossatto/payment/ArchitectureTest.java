package com.ppossatto.payment;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

/** Enforces the hexagonal architecture rules on every build. */
@AnalyzeClasses(packagesOf = ArchitectureTest.class, importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

    private static final String BASE = "com.ppossatto.payment";

    @ArchTest
    static final ArchRule domainIsPureJava = noClasses()
            .that()
            .resideInAPackage(BASE + ".domain..")
            .should()
            .dependOnClassesThat()
            .resideInAnyPackage(
                    BASE + ".application..",
                    BASE + ".adapter..",
                    BASE + ".config..",
                    "org.springframework..",
                    "jakarta..");

    @ArchTest
    static final ArchRule applicationDoesNotKnowAdaptersOrFrameworks = noClasses()
            .that()
            .resideInAPackage(BASE + ".application..")
            .should()
            .dependOnClassesThat()
            .resideInAnyPackage(BASE + ".adapter..", BASE + ".config..", "org.springframework..", "jakarta..");

    @ArchTest
    static final ArchRule inboundAdaptersDoNotUseOutboundAdapters = noClasses()
            .that()
            .resideInAPackage(BASE + ".adapter.in..")
            .should()
            .dependOnClassesThat()
            .resideInAPackage(BASE + ".adapter.out..");

    @ArchTest
    static final ArchRule outboundAdaptersDoNotUseInboundAdapters = noClasses()
            .that()
            .resideInAPackage(BASE + ".adapter.out..")
            .should()
            .dependOnClassesThat()
            .resideInAPackage(BASE + ".adapter.in..");

    @ArchTest
    static final ArchRule adaptersTalkToDomainThroughPorts = noClasses()
            .that()
            .resideInAPackage(BASE + ".adapter..")
            .should()
            .dependOnClassesThat()
            .resideInAPackage(BASE + ".application..");
}
