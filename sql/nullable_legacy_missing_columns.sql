-- Allow null values where the legacy database has no corresponding source.
ALTER TABLE farms ALTER COLUMN place DROP NOT NULL;
ALTER TABLE company_employees ALTER COLUMN password DROP NOT NULL;
ALTER TABLE state_goals ALTER COLUMN date_end DROP NOT NULL;
