-- NL railway services loaded straight from the public CSV.
-- Columns are renamed to lowercase because the Glue catalog (option C) hides tables
-- whose column names contain capital letters.
select
    "Service:Date" as service_date,
    "Stop:Station name" as station
from read_csv('https://blobs.duckdb.org/nl-railway/services-2025-03.csv.gz')
