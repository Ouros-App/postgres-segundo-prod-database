CREATE TABLE IF NOT EXISTS addresses (
    id SERIAL PRIMARY KEY,
    zip_code VARCHAR(32) NOT NULL CHECK(length(zip_code) > 0),
    state VARCHAR(2) NOT NULL CHECK(length(state) = 2),
    city VARCHAR(32) NOT NULL CHECK(length(city) > 0),
    number VARCHAR(32) NOT NULL CHECK(length(number) > 0),
    country VARCHAR(2) NOT NULL CHECK(length(country) = 2)
);

CREATE TABLE IF NOT EXISTS enterprises (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL CHECK(length(name) > 0),
    email VARCHAR(32) NOT NULL CHECK(length(email) > 0),
    cnpj VARCHAR(14) UNIQUE NOT NULL CHECK(length(cnpj) = 14),
    document_number VARCHAR UNIQUE,
    telephone VARCHAR(13) NOT NULL CHECK(length(telephone) > 9),
    id_address INTEGER REFERENCES addresses(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS farms (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL CHECK(length(name) > 0),
    area_property DOUBLE PRECISION NOT NULL,
    region VARCHAR(20) NOT NULL CHECK(length(region) > 0),
    poultry_capacity INTEGER NOT NULL,
    place VARCHAR(40) NOT NULL CHECK(length(place) > 0),
    id_adress INTEGER REFERENCES addresses(id) NOT NULL,
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
    pointing INTEGER NOT NULL,
    id_tip INTEGER REFERENCES tips(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS farm_owners (
    id SERIAL PRIMARY KEY,
    name VARCHAR(32) NOT NULL CHECK(length(name) > 0),
    password VARCHAR(32) NOT NULL CHECK(length(password) > 0),
    email VARCHAR(32) NOT NULL CHECK(length(email) > 0),
    document_number VARCHAR UNIQUE,
    telephone VARCHAR(13) NOT NULL CHECK(length(telephone) > 9),
    id_farm INTEGER REFERENCES farms(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS individual_goals (
    id SERIAL PRIMARY KEY,
    descripition VARCHAR,
    type VARCHAR(30) NOT NULL CHECK(length(type) > 0),
    status VARCHAR(30) NOT NULL CHECK(length(status) > 0),
    target_value DOUBLE PRECISION NOT NULL,
    title VARCHAR(40) NOT NULL CHECK(length(title) > 0),
    id_farm INTEGER REFERENCES farms(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS water_registries (
    id SERIAL PRIMARY KEY,
    registration_date DATE NOT NULL,
    strart_hydrometer DOUBLE PRECISION NOT NULL,
    end_hydrometer DOUBLE PRECISION NOT NULL,
    id_farm INTEGER REFERENCES farms(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS energy_registries (
    id SERIAL PRIMARY KEY,
    registration_date DATE NOT NULL,
    energy_consumption DOUBLE PRECISION NOT NULL,
    id_farm INTEGER REFERENCES farms(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS lots (
    id SERIAL PRIMARY KEY,
    received_chickens INTEGER NOT NULL,
    delivered_chickens INTEGER NOT NULL,
    date_birth DATE NOT NULL,
    delivery_date DATE NOT NULL,
    gain DOUBLE PRECISION NOT NULL,
    id_enterprise INTEGER REFERENCES enterprises(id) NOT NULL,
    id_farm INTEGER REFERENCES farms(id) NOT NULL,
    id_energy_restries INTEGER REFERENCES energy_registries(id) NOT NULL,
    id_water_restries INTEGER REFERENCES water_registries(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS company_employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(32) NOT NULL CHECK(length(name) > 0),
    document_number VARCHAR UNIQUE,
    email VARCHAR(32) NOT NULL CHECK(length(email) > 0),
    telephone VARCHAR(13) NOT NULL CHECK(length(telephone) > 9),
    password VARCHAR(32) NOT NULL CHECK(length(password) > 0),
    id_enterprise INTEGER REFERENCES enterprises(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS adms (
    id SERIAL PRIMARY KEY,
    email VARCHAR(32) NOT NULL CHECK(length(email) > 0),
    password VARCHAR(32) NOT NULL CHECK(length(password) > 0)
);

CREATE TABLE IF NOT EXISTS medication_plans (
    id SERIAL PRIMARY KEY,
    title VARCHAR(40) NOT NULL CHECK(length(title) > 0),
    date_start_validity DATE NOT NULL,
    date_end_validity DATE NOT NULL,
    description TEXT,
    id_enterprise INTEGER REFERENCES enterprises(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS regions_medication_plans (
    id SERIAL PRIMARY KEY,
    region VARCHAR(20) NOT NULL CHECK(length(region) > 0),
    id_plan INTEGER REFERENCES medication_plans(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS vaccines (
    id SERIAL PRIMARY KEY,
    aplication_days INTEGER NOT NULL,
    name VARCHAR(20) NOT NULL CHECK(length(name) > 0),
    dose DOUBLE PRECISION NOT NULL,
    aplication_route VARCHAR(50) NOT NULL CHECK(length(aplication_route) > 0),
    id_plan INTEGER REFERENCES medication_plans(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS diseases (
    id SERIAL PRIMARY KEY,
    disease VARCHAR(100) NOT NULL CHECK(length(disease) > 0),
    id_vacinne INTEGER REFERENCES vaccines(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS state_goals (
    id SERIAL PRIMARY KEY,
    description TEXT,
    type VARCHAR(30) NOT NULL CHECK(length(type) > 0),
    status VARCHAR(30) NOT NULL CHECK(length(status) > 0),
    target_value DOUBLE PRECISION NOT NULL,
    title VARCHAR(40) NOT NULL CHECK(length(title) > 0),
    date_creation TIMESTAMP NOT NULL,
    date_end TIMESTAMP NOT NULL,
    id_farm INTEGER REFERENCES farms(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS regions_goals (
    id SERIAL PRIMARY KEY,
    region VARCHAR(20) NOT NULL CHECK(length(region) > 0),
    id_goal INTEGER REFERENCES state_goals(id) NOT NULL
);

CREATE TABLE IF NOT EXISTS status (
    id SERIAL PRIMARY KEY,
    status VARCHAR(30) NOT NULL CHECK(length(status) > 0),
    id_estado INTEGER REFERENCES state_goals(id) NOT NULL
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
    id_categories INTEGER NOT NULL REFERENCES categories(id),
    UNIQUE (id_tip, id_categories)
);

CREATE TABLE IF NOT EXISTS state_goal_regions (
    id SERIAL PRIMARY KEY,
    id_goal INTEGER NOT NULL REFERENCES state_goals(id),
    id_region INTEGER NOT NULL REFERENCES regions_goals(id),
    UNIQUE (id_goal, id_region)
);

CREATE TABLE IF NOT EXISTS medication_regions_plan (
    id SERIAL PRIMARY KEY,
    id_medication INTEGER NOT NULL REFERENCES medication_plans(id),
    id_region INTEGER NOT NULL REFERENCES regions_medication_plans(id),
    UNIQUE (id_medication, id_region)
);

CREATE TABLE IF NOT EXISTS medication_plans_vaccines (
    id SERIAL PRIMARY KEY,
    id_medication INTEGER NOT NULL REFERENCES medication_plans(id),
    id_vaccine INTEGER NOT NULL REFERENCES vaccines(id),
    UNIQUE (id_medication, id_vaccine)
);

CREATE TABLE IF NOT EXISTS farms_tips (
    id SERIAL PRIMARY KEY,
    id_farm INTEGER NOT NULL REFERENCES farms(id),
    id_tips INTEGER NOT NULL REFERENCES tips(id),
    UNIQUE (id_farm, id_tips)
);
