--*******************************Total Sales(GMV),Total Purchase & Operational Revenue **********************************************  
WITH RawData AS (
    SELECT 
        SUM(CASE 
            WHEN ttt.record_type = 1 THEN (tttf.customer_price + tttf.deal_discount - tttf.customer_tax - tttf.rounding_amount) 
            ELSE 0 
        END) AS gmv_sale,
        SUM(CASE 
            WHEN ttt.record_type = 2 THEN (tttf.customer_price + tttf.deal_discount - tttf.customer_tax - tttf.rounding_amount) 
            ELSE 0 
        END) AS gmv_refund,
        SUM(CASE 
            WHEN ttt.record_type = 1 THEN (tttf.supplier_amount - tttf.supplier_tax) 
            ELSE 0 
        END) AS purchase_sale,
        SUM(CASE 
            WHEN ttt.record_type = 2 THEN (tttf.supplier_amount - tttf.supplier_tax) 
            ELSE 0 
        END) AS purchase_refund
    FROM dm_fin_service_fare_fact tttf
    JOIN dm_fin_service_fact ttt 
        ON tttf.fare_id = ttt.cus_base_fare_id
        AND tttf.service_type_id = ttt.service_type_id 
    JOIN dm_fin_ta_supp_doc_no_fact ttsdn 
        ON ttsdn.supp_doc_no_id = ttt.ta_supp_doc_no_id
    JOIN dm_fin_ta_service_dim tts 
        ON ttsdn.service_id = tts.service_id
    join dm_fin_service_type_dim dfstd    
    	on dfstd.service_type_id = tttf.service_type_id
    WHERE 
        ttsdn.last_action <> 0
        AND ttt.last_action <> 0
        AND (
            (ttt.record_type = 1 AND ttsdn.sys_sale_side_status = 2 AND ttsdn.sale_date BETWEEN '2025-07-01' AND '2025-07-31')
            OR
            (ttt.record_type = 2 AND ttsdn.sys_refund_side_status = 4 AND ttsdn.refund_date BETWEEN '2025-07-01' AND '2025-07-31')
        )
)
SELECT 
	(gmv_sale - gmv_refund) as gmv,
	(purchase_sale - purchase_refund) as purchase,
    (gmv_sale - gmv_refund) - (purchase_sale - purchase_refund) AS operational_revenue
FROM RawData;

-- Incentive and Other Mappping
SELECT
    tacoa.code ,
    SUM(-tat.base_cur_amount * tat.dr_or_cr) AS incentive_amount
FROM dm_fin_ac_transaction_fact tat
JOIN dm_fin_ac_chart_of_ac_dim tacoa
    ON tat.ac_main_ledger_id = tacoa.ac_chart_of_ac_id 
JOIN dm_fin_ba_documents_fact  tbd
    ON tbd.ba_documents_id = tat.ba_documents_id
join dm_fin_ac_mgmt_pandl_glcode_dim dfampgd 
	on dfampgd.ac_chart_of_ac_id = tacoa.ac_chart_of_ac_id
WHERE tat.transaction_date BETWEEN '2025-07-01' AND '2025-07-31'
  AND dfampgd.category = 9
  AND (
        tacoa.code = '300105'  
     OR tbd.doc_no_code_part NOT IN ('INV','RF') 
  )
GROUP BY tacoa.code ;

--Total Revenue (Operational Revenue + Incentive and other mapping)
with SalesPurchase as (
select
	SUM(case 
                when ttt.record_type = 1 
                then (tttf.customer_price + tttf.deal_discount - tttf.customer_tax - tttf.rounding_amount) 
                else 0 
            end) as gmv_sale,
	SUM(case 
                when ttt.record_type = 2 
                then (tttf.customer_price + tttf.deal_discount - tttf.customer_tax - tttf.rounding_amount) 
                else 0 
            end) as gmv_refund,
	SUM(case 
                when ttt.record_type = 1 
                then (tttf.supplier_amount - tttf.supplier_tax) 
                else 0 
            end) as purchase_sale,
	SUM(case 
                when ttt.record_type = 2 
                then (tttf.supplier_amount - tttf.supplier_tax) 
                else 0 
            end) as purchase_refund
from
	dm_fin_service_fare_fact tttf
join dm_fin_service_fact ttt 
        on
	tttf.fare_id = ttt.cus_base_fare_id
	and tttf.service_type_id = ttt.service_type_id
join dm_fin_ta_supp_doc_no_fact ttsdn 
        on
	ttsdn.supp_doc_no_id = ttt.ta_supp_doc_no_id
join dm_fin_ta_service_dim tts 
        on
	ttsdn.service_id = tts.service_id
join dm_fin_service_type_dim dfstd    
        on
	dfstd.service_type_id = tttf.service_type_id
where
	ttsdn.last_action <> 0
	and ttt.last_action <> 0
	and (
            (ttt.record_type = 1
		and ttsdn.sys_sale_side_status = 2
		and ttsdn.sale_date between '2025-07-01' and '2025-07-31')
	or
            (ttt.record_type = 2
		and ttsdn.sys_refund_side_status = 4
		and ttsdn.refund_date between '2025-07-01' and '2025-07-31')
        )
),
Incentive as (
select
	SUM(-tat.base_cur_amount * tat.dr_or_cr) as incentive_amount
from
	dm_fin_ac_transaction_fact tat
join dm_fin_ac_chart_of_ac_dim tacoa
        on
	tat.ac_main_ledger_id = tacoa.ac_chart_of_ac_id
join dm_fin_ba_documents_fact tbd
        on
	tbd.ba_documents_id = tat.ba_documents_id
join dm_fin_ac_mgmt_pandl_glcode_dim dfampgd 
	on dfampgd.ac_chart_of_ac_id = tacoa.ac_chart_of_ac_id
where
	tat.transaction_date between '2025-07-01' and '2025-07-31'
	AND dfampgd.category = 9
		and (
            tacoa.code = '300105'
			or tbd.doc_no_code_part not in ('INV', 'RF')
          )
)
select
    (sp.gmv_sale - sp.gmv_refund) as total_gmv,
    (sp.purchase_sale - sp.purchase_refund) as total_purchase,
    ((sp.gmv_sale - sp.gmv_refund) - (sp.purchase_sale - sp.purchase_refund)) as operational_revenue,
	inc.incentive_amount,
    ((sp.gmv_sale - sp.gmv_refund) - (sp.purchase_sale - sp.purchase_refund)) 
        + inc.incentive_amount as total_revenue
from
	SalesPurchase sp
cross join Incentive inc;

--Total Expense 
SELECT
    SUM(-tat.base_cur_amount * tat.dr_or_cr) AS expense
FROM dm_fin_ac_transaction_fact tat
JOIN dm_fin_ac_chart_of_ac_dim tacoa
    ON tat.ac_main_ledger_id = tacoa.ac_chart_of_ac_id
JOIN dm_fin_ba_documents_fact tbd
    ON tbd.ba_documents_id = tat.ba_documents_id
join dm_fin_ac_mgmt_pandl_glcode_dim dfampgd 
	on dfampgd.ac_chart_of_ac_id = tacoa.ac_chart_of_ac_id
WHERE
    tat.transaction_date BETWEEN '2025-07-01' AND '2025-07-31'
    AND dfampgd.category <> 9
    AND (
        tacoa.code = '421023'
        OR tbd.doc_no_code_part NOT IN ('INV','RF')
    );
   
-- Net Profit
WITH SalesPurchase AS (
    SELECT
        SUM(CASE WHEN ttt.record_type = 1
                 THEN (tttf.customer_price + tttf.deal_discount - tttf.customer_tax - tttf.rounding_amount)
                 ELSE 0 END) AS gmv_sale,
        SUM(CASE WHEN ttt.record_type = 2
                 THEN (tttf.customer_price + tttf.deal_discount - tttf.customer_tax - tttf.rounding_amount)
                 ELSE 0 END) AS gmv_refund,
        SUM(CASE WHEN ttt.record_type = 1
                 THEN (tttf.supplier_amount - tttf.supplier_tax)
                 ELSE 0 END) AS purchase_sale,
        SUM(CASE WHEN ttt.record_type = 2
                 THEN (tttf.supplier_amount - tttf.supplier_tax)
                 ELSE 0 END) AS purchase_refund
    FROM dm_fin_service_fare_fact tttf
    JOIN dm_fin_service_fact ttt 
        ON tttf.fare_id = ttt.cus_base_fare_id
       AND tttf.service_type_id = ttt.service_type_id
    JOIN dm_fin_ta_supp_doc_no_fact ttsdn 
        ON ttsdn.supp_doc_no_id = ttt.ta_supp_doc_no_id
    JOIN dm_fin_ta_service_dim tts 
        ON ttsdn.service_id = tts.service_id
    JOIN dm_fin_service_type_dim dfstd    
        ON dfstd.service_type_id = tttf.service_type_id
    WHERE
        ttsdn.last_action <> 0
        AND ttt.last_action <> 0
        AND (
            (ttt.record_type = 1 AND ttsdn.sys_sale_side_status = 2 AND ttsdn.sale_date BETWEEN '2025-07-01' AND '2025-07-31')
         OR (ttt.record_type = 2 AND ttsdn.sys_refund_side_status = 4 AND ttsdn.refund_date BETWEEN '2025-07-01' AND '2025-07-31')
        )
),
Incentive AS (
    SELECT
        SUM(-tat.base_cur_amount * tat.dr_or_cr) AS incentive_amount
    FROM dm_fin_ac_transaction_fact tat
    JOIN dm_fin_ac_chart_of_ac_dim tacoa
        ON tat.ac_main_ledger_id = tacoa.ac_chart_of_ac_id
    JOIN dm_fin_ba_documents_fact tbd
        ON tbd.ba_documents_id = tat.ba_documents_id
    join dm_fin_ac_mgmt_pandl_glcode_dim dfampgd 
		on dfampgd.ac_chart_of_ac_id = tacoa.ac_chart_of_ac_id
    WHERE
        tat.transaction_date BETWEEN '2025-07-01' AND '2025-07-31'
        AND dfampgd.category = 9
        AND (
            tacoa.code = '300105'
         OR tbd.doc_no_code_part NOT IN ('INV','RF')
        )
),
TotalExpense AS (
    SELECT
        SUM(-tat.base_cur_amount * tat.dr_or_cr) AS total_expense
    FROM dm_fin_ac_transaction_fact tat
    JOIN dm_fin_ac_chart_of_ac_dim tacoa
        ON tat.ac_main_ledger_id = tacoa.ac_chart_of_ac_id
    JOIN dm_fin_ba_documents_fact tbd
        ON tbd.ba_documents_id = tat.ba_documents_id
    join dm_fin_ac_mgmt_pandl_glcode_dim dfampgd 
	on dfampgd.ac_chart_of_ac_id = tacoa.ac_chart_of_ac_id
    WHERE
        tat.transaction_date BETWEEN '2025-07-01' AND '2025-07-31'
        AND dfampgd.category <> 9
        AND (
            tacoa.code = '421023'
         OR tbd.doc_no_code_part NOT IN ('INV','RF')
        )
)
SELECT
    ( (sp.gmv_sale - sp.gmv_refund) - (sp.purchase_sale - sp.purchase_refund) )
        + inc.incentive_amount AS total_revenue,
    te.total_expense,
    (
        ( (sp.gmv_sale - sp.gmv_refund) - (sp.purchase_sale - sp.purchase_refund) )
            + inc.incentive_amount
    ) + te.total_expense AS net_profit
FROM SalesPurchase sp
CROSS JOIN Incentive inc
CROSS JOIN TotalExpense te;
   
--EBITDA
WITH SalesPurchase AS (
    SELECT
        SUM(CASE WHEN ttt.record_type = 1
                 THEN (tttf.customer_price + tttf.deal_discount - tttf.customer_tax - tttf.rounding_amount)
                 ELSE 0 END) AS gmv_sale,
        SUM(CASE WHEN ttt.record_type = 2
                 THEN (tttf.customer_price + tttf.deal_discount - tttf.customer_tax - tttf.rounding_amount)
                 ELSE 0 END) AS gmv_refund,
        SUM(CASE WHEN ttt.record_type = 1
                 THEN (tttf.supplier_amount - tttf.supplier_tax)
                 ELSE 0 END) AS purchase_sale,
        SUM(CASE WHEN ttt.record_type = 2
                 THEN (tttf.supplier_amount - tttf.supplier_tax)
                 ELSE 0 END) AS purchase_refund
    FROM dm_fin_service_fare_fact tttf
    JOIN dm_fin_service_fact ttt 
        ON tttf.fare_id = ttt.cus_base_fare_id
       AND tttf.service_type_id = ttt.service_type_id
    JOIN dm_fin_ta_supp_doc_no_fact ttsdn 
        ON ttsdn.supp_doc_no_id = ttt.ta_supp_doc_no_id
    JOIN dm_fin_ta_service_dim tts 
        ON ttsdn.service_id = tts.service_id
    JOIN dm_fin_service_type_dim dfstd    
        ON dfstd.service_type_id = tttf.service_type_id
    WHERE
        ttsdn.last_action <> 0
        AND ttt.last_action <> 0
        AND (
            (ttt.record_type = 1 AND ttsdn.sys_sale_side_status = 2 AND ttsdn.sale_date BETWEEN '2025-07-01' AND '2025-07-31')
         OR (ttt.record_type = 2 AND ttsdn.sys_refund_side_status = 4 AND ttsdn.refund_date BETWEEN '2025-07-01' AND '2025-07-31')
        )
),
Incentive AS (
    SELECT
        SUM(-tat.base_cur_amount * tat.dr_or_cr) AS incentive_amount
    FROM dm_fin_ac_transaction_fact tat
    JOIN dm_fin_ac_chart_of_ac_dim tacoa
        ON tat.ac_main_ledger_id = tacoa.ac_chart_of_ac_id
    JOIN dm_fin_ba_documents_fact tbd
        ON tbd.ba_documents_id = tat.ba_documents_id
    join dm_fin_ac_mgmt_pandl_glcode_dim dfampgd 
	on dfampgd.ac_chart_of_ac_id = tacoa.ac_chart_of_ac_id
    WHERE
        tat.transaction_date BETWEEN '2025-07-01' AND '2025-07-31'
        AND dfampgd.category = 9
        AND (
            tacoa.code = '300105'
         OR tbd.doc_no_code_part NOT IN ('INV','RF')
        )
),
TotalExpense AS (
    SELECT
        SUM(-tat.base_cur_amount * tat.dr_or_cr) AS total_expense
    FROM dm_fin_ac_transaction_fact tat
    JOIN dm_fin_ac_chart_of_ac_dim tacoa
        ON tat.ac_main_ledger_id = tacoa.ac_chart_of_ac_id
    JOIN dm_fin_ba_documents_fact tbd
        ON tbd.ba_documents_id = tat.ba_documents_id
    join dm_fin_ac_mgmt_pandl_glcode_dim dfampgd 
		on dfampgd.ac_chart_of_ac_id = tacoa.ac_chart_of_ac_id
    WHERE
        tat.transaction_date BETWEEN '2025-07-01' AND '2025-07-31'
        AND dfampgd.category not in (9,10,11,12)
        AND (
            tacoa.code = '421023'
         OR tbd.doc_no_code_part NOT IN ('INV','RF')
        )
)
SELECT
    ( (sp.gmv_sale - sp.gmv_refund) - (sp.purchase_sale - sp.purchase_refund) )
        + inc.incentive_amount AS total_revenue,
    te.total_expense,
    (
        ( (sp.gmv_sale - sp.gmv_refund) - (sp.purchase_sale - sp.purchase_refund) )
            + inc.incentive_amount
    ) + te.total_expense AS EBITDA
FROM SalesPurchase sp
CROSS JOIN Incentive inc
CROSS JOIN TotalExpense te
;   