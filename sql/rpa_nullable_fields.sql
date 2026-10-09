-- Allow legacy rows without a delivery date or employee telephone.
ALTER TABLE lots
    ALTER COLUMN delivery_date DROP NOT NULL;

ALTER TABLE company_employees
    ALTER COLUMN telephone DROP NOT NULL;
