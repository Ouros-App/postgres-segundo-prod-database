-- Preenche as colunas novas de lots sem duplicar registros existentes.
UPDATE lots
SET
    lots = ((id - 1) % 5) + 1,
    cost = ROUND((received_chickens * 0.5 + gain * 100)::NUMERIC, 2)
WHERE lots = 0
  AND cost = 0;

-- Simula produtores que ainda precisam realizar o primeiro acesso.
UPDATE farm_owners
SET first_acess = CASE WHEN id % 4 = 0 THEN FALSE ELSE TRUE END;
