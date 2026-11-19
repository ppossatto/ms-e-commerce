CREATE TABLE item (
    id   UUID         PRIMARY KEY,
    sku  VARCHAR(64)  NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL
);
