CREATE OR REPLACE FUNCTION log_payments_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    payment_row payments%ROWTYPE;
BEGIN
    IF TG_OP = 'DELETE' THEN
        payment_row := OLD;
    ELSE
        payment_row := NEW;
    END IF;

    INSERT INTO payments_logs (
        id,
        type,
        value,
        date_creation,
        id_enterprise
    ) VALUES (
        payment_row.id,
        payment_row.type,
        payment_row.value,
        payment_row.date_creation,
        payment_row.id_enterprise
    );

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS payments_logs_trigger ON payments;

CREATE TRIGGER payments_logs_trigger
AFTER INSERT OR UPDATE OR DELETE ON payments
FOR EACH ROW
EXECUTE FUNCTION log_payments_changes();

CREATE OR REPLACE FUNCTION log_lots_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    lot_row lots%ROWTYPE;
BEGIN
    IF TG_OP = 'DELETE' THEN
        lot_row := OLD;
    ELSE
        lot_row := NEW;
    END IF;

    INSERT INTO lots_logs (
        id,
        received_chickens,
        delivered_chickens,
        delivery_date,
        losts,
        cost,
        id_enterprise,
        id_farm
    ) VALUES (
        lot_row.id,
        lot_row.received_chickens,
        lot_row.delivered_chickens,
        lot_row.delivery_date,
        lot_row.losts,
        lot_row.cost,
        lot_row.id_enterprise,
        lot_row.id_farm
    );

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS lots_logs_trigger ON lots;

CREATE TRIGGER lots_logs_trigger
AFTER INSERT OR UPDATE OR DELETE ON lots
FOR EACH ROW
EXECUTE FUNCTION log_lots_changes();

CREATE OR REPLACE FUNCTION log_farms_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    farm_row farms%ROWTYPE;
BEGIN
    IF TG_OP = 'DELETE' THEN
        farm_row := OLD;
    ELSE
        farm_row := NEW;
    END IF;

    INSERT INTO farms_logs (
        id,
        name,
        area_property,
        region,
        poulty_capacity,
        place,
        chickens_now,
        id_adress,
        id_enterprise
    ) VALUES (
        farm_row.id,
        farm_row.name,
        farm_row.area_property,
        farm_row.region,
        farm_row.poultry_capacity,
        farm_row.place,
        farm_row.chickens_now,
        farm_row.id_address,
        farm_row.id_enterprise
    );

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS farms_logs_trigger ON farms;

CREATE TRIGGER farms_logs_trigger
AFTER INSERT OR UPDATE OR DELETE ON farms
FOR EACH ROW
EXECUTE FUNCTION log_farms_changes();
