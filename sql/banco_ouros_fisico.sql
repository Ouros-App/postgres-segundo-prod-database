CREATE TABLE IF NOT EXISTS addresses (
    id SERIAL PRIMARY KEY,
    zip_code VARCHAR(50) NOT NULL CHECK(length(zip_code) > 0),
    state VARCHAR(2) NOT NULL CHECK(length(state) = 2),
    city VARCHAR(100) NOT NULL CHECK(length(city) > 0),
    number VARCHAR(50) NOT NULL CHECK(length(number) > 0),
    country VARCHAR(2) NOT NULL CHECK(length(country) = 2)
);

CREATE TABLE IF NOT EXISTS enterprises (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL CHECK(length(name) > 0),
    email VARCHAR(50) NOT NULL CHECK(length(email) > 0),
    document_number VARCHAR(14) NOT NULL CHECK(length(document_number) = 14),
    telephone VARCHAR(13) NOT NULL CHECK(length(telephone) > 9),
    id_address INTEGER REFERENCES addresses(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS farms (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL CHECK(length(name) > 0),
    area_property NUMERIC NOT NULL CHECK(area_property > 0),
    region VARCHAR(50) NOT NULL CHECK(btrim(region) <> ''),
    poultry_capacity INTEGER NOT NULL CHECK(poultry_capacity >= 0),
    place VARCHAR(50) NOT NULL CHECK(length(place) > 0),
    id_address INTEGER REFERENCES addresses(id) NOT NULL,
    id_enterprise INTEGER REFERENCES enterprises(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS tips (
    id SERIAL PRIMARY KEY,
    tip TEXT NOT NULL CHECK(length(tip) > 0),
    id_farm INTEGER REFERENCES farms(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    category VARCHAR(50) NOT NULL CHECK(length(category) > 0),
    id_tip INTEGER REFERENCES tips(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS reviews (
    id SERIAL PRIMARY KEY,
    comment TEXT NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 0),
    id_tip INTEGER REFERENCES tips(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS farm_owners (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL CHECK(length(name) > 0),
    password TEXT NOT NULL CHECK(length(password) > 0),
    email VARCHAR(50) NOT NULL CHECK(length(email) > 0),
    document_number VARCHAR(11) NOT NULL CHECK (length(document_number) = 11),
    telephone VARCHAR(13) NOT NULL CHECK(length(telephone) > 9),
    id_farm INTEGER REFERENCES farms(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS individual_goals (
    id SERIAL PRIMARY KEY,
    description VARCHAR,
    type VARCHAR(50) NOT NULL CHECK(length(type) > 0),
    status VARCHAR(50) NOT NULL CHECK(length(status) > 0),
    target_value NUMERIC NOT NULL CHECK(target_value > 0),
    title VARCHAR(50) NOT NULL CHECK(length(title) > 0),
    id_farm INTEGER REFERENCES farms(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS water_registries (
    id SERIAL PRIMARY KEY,
    registration_date DATE NOT NULL,
    start_hydrometer NUMERIC NOT NULL CHECK(start_hydrometer > 0),
    end_hydrometer NUMERIC NOT NULL CHECK(end_hydrometer > 0),
    id_farm INTEGER REFERENCES farms(id) NOT NULL,
    CHECK (end_hydrometer >= start_hydrometer)
);

CREATE TABLE IF NOT EXISTS energy_registries (
    id SERIAL PRIMARY KEY,
    registration_date DATE NOT NULL,
    energy_consumption NUMERIC NOT NULL CHECK(energy_consumption > 0),
    id_farm INTEGER REFERENCES farms(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS lots (
    id SERIAL PRIMARY KEY,
    received_chickens INTEGER NOT NULL CHECK (received_chickens >= 0),
    delivered_chickens INTEGER NOT NULL CHECK (delivered_chickens >= 0),
    date_birth DATE NOT NULL,
    delivery_date DATE NOT NULL,
    gain NUMERIC NOT NULL CHECK(gain >= 0),
    id_enterprise INTEGER REFERENCES enterprises(id) NOT NULL,
    id_farm INTEGER REFERENCES farms(id) NOT NULL,
    CHECK (delivered_chickens <= received_chickens),
    CHECK (delivery_date >= date_birth)
);

CREATE TABLE IF NOT EXISTS company_employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL CHECK(length(name) > 0),
    document_number VARCHAR(11) UNIQUE NOT NULL CHECK (length(document_number) = 11),
    email VARCHAR(50) NOT NULL CHECK(length(email) > 0),
    telephone VARCHAR(13) NOT NULL CHECK(length(telephone) > 9),
    password TEXT NOT NULL CHECK(length(password) > 0),
    id_enterprise INTEGER REFERENCES enterprises(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS adms (
    id SERIAL PRIMARY KEY,
    email VARCHAR(50) NOT NULL CHECK(length(email) > 0),
    password TEXT NOT NULL CHECK(length(password) > 0)
);

CREATE TABLE IF NOT EXISTS state_goals (
    id SERIAL PRIMARY KEY,
    description TEXT,
    type VARCHAR(50) NOT NULL CHECK(length(type) > 0),
    status VARCHAR(40) NOT NULL CHECK(length(status) > 0),
    target_value NUMERIC NOT NULL CHECK(target_value > 0),
    title VARCHAR(50) NOT NULL CHECK(length(title) > 0),
    date_creation TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_end TIMESTAMP NOT NULL,
    id_farm INTEGER REFERENCES farms(id) NOT NULL,
    CHECK (date_end >= date_creation)
);

CREATE TABLE IF NOT EXISTS regions_goals (
    id SERIAL PRIMARY KEY,
    region VARCHAR(50) NOT NULL CHECK(btrim(region) <> ''),
    id_goal INTEGER REFERENCES state_goals(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS farm_goals (
    id SERIAL PRIMARY KEY,
    id_farm INTEGER NOT NULL REFERENCES farms(id),
    id_goal INTEGER NOT NULL REFERENCES state_goals(id),
    UNIQUE (id_farm, id_goal)
);

CREATE TABLE IF NOT EXISTS tip_categories (
    id SERIAL PRIMARY KEY,
    id_tip INTEGER NOT NULL REFERENCES tips(id),
    id_category INTEGER NOT NULL REFERENCES categories(id),
    UNIQUE (id_tip, id_category)
);

CREATE TABLE IF NOT EXISTS state_goal_regions (
    id SERIAL PRIMARY KEY,
    id_goal INTEGER NOT NULL REFERENCES state_goals(id),
    id_region INTEGER NOT NULL REFERENCES regions_goals(id),
    UNIQUE (id_goal, id_region)
);

CREATE TABLE IF NOT EXISTS farms_tips (
    id SERIAL PRIMARY KEY,
    id_farm INTEGER NOT NULL REFERENCES farms(id),
    id_tip INTEGER NOT NULL REFERENCES tips(id),
    UNIQUE (id_farm, id_tip)
);
