select
    month(service_date) as month,
    station,
    count(*) as num_services
from {{ ref('services') }}
group by all
