UPDATE lots
SET
    losts = received_chickens - delivered_chickens,
    cost = ROUND((received_chickens * 0.5 + gain * 100)::NUMERIC, 2)
WHERE losts = 0
  AND cost = 0;

UPDATE farm_owners
SET first_acess = CASE WHEN id % 4 = 0 THEN FALSE ELSE TRUE END;
