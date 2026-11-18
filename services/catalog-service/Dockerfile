# Expects the jar to be built beforehand (mvn package/verify), as the CI workflow does.
FROM eclipse-temurin:25-jre-alpine

RUN addgroup -S app && adduser -S app -G app
WORKDIR /app

COPY target/*.jar app.jar

USER app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]