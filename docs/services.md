# Services: creating and updating

This guide covers the lifecycle of a backend service in this monorepo:
how a service is generated from `services/_template`, how to run it locally,
and how to bring later template changes into services that already exist.

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [The template](#the-template)
- [Creating a service](#creating-a-service)
- [Running a service locally](#running-a-service-locally)
- [CI and container images](#ci-and-container-images)
- [Changing the template](#changing-the-template)
- [Syncing existing services](#syncing-existing-services)
- [Troubleshooting](#troubleshooting)

---

## Overview

```
services/_template ──new-service.sh──► services/<name>     (once, at creation)
        │                                    ▲
        └──────────sync-service.sh───────────┘              (every time the template changes)
```

| Script | Purpose |
|---|---|
| `scripts/new-service.sh <name>` | Generates a new service from the template |
| `scripts/sync-service.sh <name>` | Applies template changes to an existing service (3-way merge) |
| `scripts/lib/template.sh` | Shared logic (renaming rules, example files). Sourced by both scripts, never run directly |

Both scripts use the same renaming logic, so a synced file looks exactly as if the service
had been generated from the current template.

## Prerequisites

- Bash, Git and the usual Unix tools (`sed`, `find`, `tar`, `cmp`)
- JDK 25 and Maven 3.9+ (enforced by `build-parent`)
- Docker, for the local stack (`infra/compose.yaml`) and for Testcontainers in integration tests
- Run every script from the repository root

## The template

`services/_template` is a complete, working service. It builds, its tests pass, and it follows
the architecture every service must follow. It uses a small **Item/Catalog example** to show
each piece working end to end. Each new service replaces that example with its real domain.

### Package layout (hexagonal architecture)

```
com.ppossatto.<pkg>/
├── domain/
│   ├── model/            entities and domain exceptions (plain Java, no Spring/JPA)
│   └── port/
│       ├── in/           use case interfaces
│       └── out/          what the use cases need from outside (repositories, clients)
├── application/          use case implementations (only depend on ports)
├── adapter/
│   ├── in/web/           REST controllers
│   └── out/              persistence (JPA), http (RestClient), messaging...
└── config/               Spring wiring (use case beans, security)
```

`ArchitectureTest` (ArchUnit) enforces these rules on every build:

- `domain` does not depend on `application`, `adapter`, `config`, Spring or Jakarta
- `application` does not depend on `adapter`, `config`, Spring or Jakarta
- inbound and outbound adapters do not depend on each other
- adapters reach the core only through ports, never through `application`

### What every service gets from the template

| Item | Where |
|---|---|
| Virtual threads | `application.yaml` → `spring.threads.virtual.enabled` |
| Log format | `src/main/resources/logback-spring.xml` (`LOG_PATTERN`) |
| Keycloak JWT validation, realm roles as `ROLE_*` | `config/SecurityConfig.java` + `spring.security.oauth2.resourceserver.jwt.*` |
| Connection settings (Postgres, mail, Valkey, Kafka, RustFS) | `application.yaml`, overridable through environment variables |
| Kafka topic names | `application.yaml` → `app.kafka.topics` |
| WireMock for external APIs in the `local` profile | `src/test/java/.../local/`, `src/test/resources/application-local.yaml`, `src/test/resources/wiremock/` |
| Unit, integration and architecture tests | `src/test/java/...` |
| Container image | `Dockerfile` |

Build plugins and test dependencies shared by all services live in `build-parent/pom.xml`,
not in the template. A change there applies to every service immediately, with no sync needed.

## Creating a service

```bash
./scripts/new-service.sh order-service
```

The name must be lowercase letters, digits and hyphens. Names starting with `_` are reserved.

### What the script derives from the name

For `order-service`:

| Item | Value |
|---|---|
| Directory and Maven `artifactId` | `services/order-service` |
| Java package | `com.ppossatto.order` |
| Main class | `OrderApplication` |
| Postgres role and schema | `order_svc` |
| Password variable | `ORDER_DB_PASSWORD` |

The schema has the same name as the role. That puts it in Postgres' default `search_path`
(`"$user"`) and avoids reserved words: `CREATE SCHEMA order` would fail.

### What the script changes

| File | Change |
|---|---|
| `services/<name>/` | Copy of the template with every rename applied |
| `services/<name>/.template-ref` | Commit of the template used, needed by `sync-service.sh` |
| `infra/data/postgres/init/01-schemas.sh` | `CREATE ROLE` / `CREATE SCHEMA` for the service |
| `infra/.env.example` | `<PKG>_DB_PASSWORD=` |
| `.github/workflows/<name>.yml` | CI workflow (build, test, SonarQube Cloud, image on release tag) |

Running it twice for the same name fails. The Postgres and `.env.example` entries are never duplicated.

> **Commit the template before creating a service.** If `services/_template` has uncommitted
> changes, `.template-ref` is not written and a later sync needs `--from <commit>`.

### After creating it

Replace the Item/Catalog example with the real domain. The script prints this list with full
paths. Every path below is relative to `services/<name>/`, with `<pkg>` standing for the service package.

1. **Domain model:** rename `domain/model/Item.java` to your aggregate and keep it plain Java.
   Replace or delete `ItemNotInCatalogException.java`.
2. **Ports:**
   - `domain/port/in`: one interface per use case.
   - `domain/port/out`: one interface per external need (persistence, other services, Kafka).
3. **Application:** implement the use cases in `application/` using only ports, then update
   the wiring in `config/UseCaseConfig.java`.
4. **Adapters:** replace the controller, the JPA classes and `CatalogHttpAdapter` with your own.
5. **Database:** replace `V1__create_item_table.sql` with your first migration. Flyway runs it
   in the service schema automatically.
6. **Configuration:**
   - `application.yaml`: client URLs and Kafka topics.
   - `application-local.yaml`: WireMock URLs for the `local` profile.
   - `wiremock/mappings/`: the local stubs.
7. **Tests:** replace `ItemServiceTest` and `ItemFlowIT`. Keep `ArchitectureTest` as it is.

Then format, build and commit:

```bash
(cd services/order-service && mvn spotless:apply verify)
git add -A && git commit -m "Add order-service"
```

## Running a service locally

### Infrastructure

```bash
cd infra
cp .env.example .env      # first time only: fill in the passwords
docker compose up -d
```

| Component | Host address | UI |
|---|---|---|
| Postgres | `localhost:5432` | – |
| Valkey | `localhost:6379` | – |
| Kafka | `localhost:9092` (containers: `kafka:29092`) | Kafka UI: http://localhost:8085 |
| RustFS (S3) | `localhost:9000` | http://localhost:9001 |
| Mailpit (SMTP) | `localhost:1025` | http://localhost:8025 |
| Keycloak | `localhost:8180` | http://localhost:8180 |

`01-schemas.sh` runs only when the Postgres volume is empty. After adding a service to an
existing volume, either recreate the volume (`docker compose down -v`, which **deletes all data**)
or run the two SQL lines for that service manually.

To import a Keycloak realm on startup, put its `realm-export.json` in `infra/security/keycloak/`.

### The service

```bash
cd services/order-service
mvn spring-boot:test-run -Dspring-boot.run.profiles=local
```

The `local` profile starts an embedded WireMock server on port `8089` and points every outbound
client at it. Stubs live in `src/test/resources/wiremock/`:

- `mappings/`: request/response definitions (JSON)
- `__files/`: response bodies referenced by `bodyFileName`

All of this lives in `src/test`, so WireMock never ends up in the production jar.

### Configuration through environment variables

Every connection setting has a local default and can be overridden:

| Variable | Default |
|---|---|
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | `jdbc:postgresql://localhost:5432/app`, `<pkg>_svc`, empty |
| `KEYCLOAK_ISSUER_URI` | `http://localhost:8180/realms/ppossatto` |
| `KEYCLOAK_JWK_SET_URI` | `<issuer>/protocol/openid-connect/certs` |
| `MAIL_HOST`, `MAIL_PORT` | `localhost`, `1025` |
| `VALKEY_URL` | `redis://localhost:6379` |
| `KAFKA_BOOTSTRAP_SERVERS` | `localhost:9092` |
| `RUSTFS_S3_URL` | `http://localhost:9000` |

When a service runs in a container, set `KEYCLOAK_JWK_SET_URI` to the internal address
(`http://keycloak:8080/realms/<realm>/protocol/openid-connect/certs`) and keep
`KEYCLOAK_ISSUER_URI` on the public one. The issuer must match the `iss` claim of the tokens.

## CI and container images

Each service has its own workflow, `.github/workflows/<name>.yml`, generated by
`write_workflow` in `scripts/lib/template.sh`. Pull requests and pushes to `main` run only when
files change in `services/<name>/`, `build-parent/` or `contracts/`.

| Event | Build + tests | SonarQube Cloud | Image |
|---|---|---|---|
| Pull request | yes | yes (if `SONAR_TOKEN` is available) | no |
| Push to `main` | yes | yes | no |
| Tag `<name>/v<semver>` | yes | yes | `ghcr.io/<owner>/<name>:<semver>` and `:latest` |
| Manual run (*Run workflow*) | yes | yes | `ghcr.io/<owner>/<name>:sha-<short-sha>` |

The workflow is trunk-based: `main` is always releasable, and a release is a tag.
Tags are prefixed with the service name, so each service is versioned independently in the monorepo.

### Releasing a service

```bash
git tag order-service/v1.2.0
git push origin order-service/v1.2.0
```

Use [semantic versioning](https://semver.org/). Tag pushes always run the workflow, even
though the `paths` filter does not match: GitHub does not evaluate path filters for tag pushes.

Publishing uses the built-in `GITHUB_TOKEN`, so no secret is needed. Images are private
the first time they are published. Make them public in the package settings on GitHub if others
should be able to pull them.

### SonarQube Cloud

The analysis runs in the same Maven call as the build (`mvn verify ...sonar-maven-plugin:sonar`),
so it reuses the compiled classes and the JaCoCo reports (unit and integration coverage).
`-Dsonar.qualitygate.wait=true` makes the job fail when the quality gate fails.

Settings live in `build-parent/pom.xml`:

| Property | Value |
|---|---|
| `sonar.host.url` | `https://sonarcloud.io` |
| `sonar.organization` | your SonarQube Cloud organization key |
| `sonar.projectKey` | `${sonar.organization}_${project.artifactId}` (e.g. `ppossatto_order-service`) |
| `sonar.coverage.jacoco.xmlReportPaths` | `target/site/jacoco/jacoco.xml`, `target/site/jacoco-it/jacoco.xml` |

One-time setup:

1. In SonarQube Cloud, create one project **per service**, using the key above. A monorepo needs
   a unique project key per service.
2. Turn off *Automatic Analysis* for those projects: the analysis comes from CI.
3. Create a token and add it to the GitHub repository as the secret `SONAR_TOKEN`.

Without `SONAR_TOKEN` (for example, pull requests from forks) the workflow skips the analysis
and still builds and tests.

### Updating the workflow of existing services

The workflow lives outside `services/`, so `sync-service.sh` does not merge it. To regenerate it
from the current generator:

```bash
./scripts/sync-service.sh order-service --workflow
git diff -- .github/workflows/
```

This overwrites the file: re-apply any manual change you made to it.

## Changing the template

1. Change `services/_template`. It must keep building and passing its tests on its own:
   ```bash
   (cd services/_template && mvn spotless:apply verify)
   ```
2. Do not use the words `template`, `template-service`, `template_svc` or `TemplateApplication`
   for anything that should stay literal: the renaming replaces them in `.java`, `.xml`, `.yaml`
   and `.sql` files.
3. If you add a new **example** file that services are expected to replace, add its exact file
   name to `EXAMPLE_FILES_REGEX` in `scripts/lib/template.sh`. Otherwise it will be synced into
   every service. The list uses exact names, not prefixes, so a service's own files are not
   excluded by accident (e.g. `CatalogApplication.java` in `catalog-service`).
4. Commit the change.
5. Sync the existing services (next section).

## Syncing existing services

```bash
./scripts/sync-service.sh order-service --dry-run   # show what would change
./scripts/sync-service.sh order-service             # apply
./scripts/sync-service.sh --all                     # every service that has a .template-ref
./scripts/sync-service.sh order-service --workflow  # also regenerate the CI workflow
```

### How it works

The script runs a 3-way merge for every file, the same idea as `git merge`:

| Side | Content |
|---|---|
| base | the template at the commit in `services/<name>/.template-ref`, renamed for the service |
| theirs | the template at its latest commit, renamed for the service |
| ours | the service as it is now |

Only what changed in the template between *base* and *theirs* is applied. The service's own code
is kept. When the template and the service changed the same lines, the file gets conflict markers.
When it finishes, `.template-ref` points to the new template commit.

### What happens to each file

| Situation | Result | Reported as |
|---|---|---|
| Template did not change the file | untouched | – |
| Template changed it, the service did not touch those lines | merged | `updated` |
| Both changed the same lines | conflict markers in the file | `CONFLICT` |
| New in the template | copied into the service | `added` |
| New in the template, but the service already has a different file at that path | conflict markers | `CONFLICT` |
| Deleted from the service on purpose | left deleted | `skipped` |
| Removed from the template | kept in the service; delete it yourself if no longer needed | `removed from template, kept here` |
| Item/Catalog example file | never synced | – |

### Requirements

- The template changes are committed.
- The service has no uncommitted changes. Commit or stash first, so the result can be reviewed and undone.

### After syncing

```bash
git diff -- services/                    # review
# resolve any <<<<<<< / >>>>>>> markers in the CONFLICT files
(cd services/order-service && mvn spotless:apply verify)
git add -A && git commit -m "Sync order-service with template"
```

To discard the sync:

```bash
git restore -- services/order-service && git clean -fd -- services/order-service
```

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Success (or already up to date) |
| `1` | Error: unknown service, uncommitted changes, unknown commit, not a git repository |
| `2` | Synced, but there are conflicts to resolve |

### Services without `.template-ref`

Services generated before `.template-ref` existed, or while the template had uncommitted
changes, do not have the file. Pass the template commit the service was created from:

```bash
git log --oneline -- services/_template        # find the commit
./scripts/sync-service.sh order-service --from <commit>
```

After the first sync, `.template-ref` is written and `--from` is no longer needed.

## Troubleshooting

| Problem | Cause and fix |
|---|---|
| `services/_template has uncommitted changes` | Commit the template first. Both scripts read it from Git history. |
| `[<name>] has uncommitted changes` | Commit or stash the service's changes, then sync again. |
| `[<name>] no .template-ref` | Use `--from <commit>` (see above). |
| Many conflicts in one sync | The service diverged a lot in that file. Resolve them once: the next sync starts from the new base. |
| A synced file brought back example code | That file is missing from `EXAMPLE_FILES_REGEX`. Add it, discard the sync and run it again. |
| New service has no database schema | `01-schemas.sh` runs only on an empty volume. Run its SQL lines manually or recreate the volume. |
| `401` with a valid token | The `iss` claim does not match `KEYCLOAK_ISSUER_URI`. Check `KC_HOSTNAME` in `infra/compose.yaml` and the realm name in the URL. |
| `mvn verify` fails on formatting | Run `mvn spotless:apply`. |
| Sonar step fails with "project not found" | The project key in SonarQube Cloud must be `<organization>_<artifactId>`. Check `sonar.organization` in `build-parent/pom.xml`. |
| Sonar fails saying Automatic Analysis is enabled | Turn off Automatic Analysis for that project in SonarQube Cloud. |
| Tag pushed but no image | The tag must be exactly `<name>/v<version>`, e.g. `order-service/v1.2.0`. |