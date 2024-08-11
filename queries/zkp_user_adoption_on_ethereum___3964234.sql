-- part of a query repo
-- query name: ZKP User Adoption on Ethereum
-- query link: https://dune.com/queries/3964234


with base as (
    select date_trunc('month', block_time) as period
        , 'infra' as type
        , 'Scroll' as protocol
        , "from" as active_addresses
    from scroll.transactions r
    
    
    UNION ALL 
    
    select date_trunc('month', block_time) as period
        , 'infra' as type
        , 'Polygon zkEVM' as protocol
        , "from" as active_addresses
    from zkevm.transactions r
    
    
    UNION ALL 
    
    select date_trunc('month', block_time) as period
        , 'infra' as type
        , 'Linea' as protocol
        , "from" as active_addresses
    from linea.transactions r
    
    
    UNION ALL 
    
    select date_trunc('month', block_time) as period
        , 'infra' as type
        , 'zkSync Era' as protocol
        , "from" as active_addresses
    from zksync.transactions r
    
    
    UNION ALL 
    
    select date_trunc('month', block_time) as period
        , 'infra' as type
        , 'Starknet' as protocol
        , sender_address as active_addresses
    from starknet.transactions r
    
    
    UNION ALL
    
    select date_trunc('month', tr.block_time) as period
        , 'app' as type
        , 'Nocturne' as protocol
        , "from" as active_addresses
    from ethereum.traces tr
    where to in (
        select address---, name, namespace, detection_source, created_at
        from ethereum.contracts
        where namespace = 'nocturne'
    )
    
    
    UNION ALL
    
    select date_trunc('month', tr.block_time) as period
        , 'app' as type
        , 'Railgun' as protocol
        , "from" as active_addresses
    from ethereum.traces tr
    where to in (
        select address---, name, namespace, detection_source, created_at
        from ethereum.contracts
        where namespace = 'railgun'and name != 'RailToken' -- excluding all the activities on the ERC20 tokens
    )
    

    UNION ALL
    
    select date_trunc('month', tr.block_time) as period
        , 'app' as type
        , 'Tornado Cash' as protocol
        , "from" as active_addresses
    from ethereum.traces tr
    where to in (
        select address---, name, namespace, detection_source, created_at
        from ethereum.contracts
        where namespace in ('tornado_cash', 'tornado_cash_nova') and name != 'TORN' -- excluding all the activities on the ERC20 tokens
    )
    
)

, dedup_sum as (
    select period
        , type
        , protocol
        , count(distinct active_addresses) as active_addresses
    from base b
    group by 1,2,3
    
    UNION ALL 
    -- special treatment for Loopring as we pull daily aa from growthepie api
    select date_trunc('month', date("date")) as period
        , 'infra' as type
        , 'Loopring' as protocol
        , ceiling(sum(daa) * 0.5) as active_addresses -- we are overcounting because data pulled is daily, so there will be dupes, I'm putitng a dampening effect by * 0.5 until we get proper data
        -- , approx_percentile(daa, 0.8) as active_addresses 
    from dune.nebra.dataset_loopring_daa
    group by 1,2,3
)

select period, type, protocol, active_addresses
from dedup_sum 
where period >= now() - interval '4' year
order by period, protocolod, protocol