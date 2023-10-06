-----------------------------------------------------------------------
-- Montreal Neuro - Trial Data query 
-- Run this 4th and cascade to "dashboard_data_orcids"
-----------------------------------------------------------------------
DECLARE var_SQL_script_name STRING DEFAULT 'neuro_ver1n_query_orcid_2023_10_06';
DECLARE var_ORCID_Dataset_name STRING DEFAULT 'neuro_pis_orcid.csv';
DECLARE var_output_table STRING DEFAULT 'dashboard_data_ver1n_2023_10_06_orcid';
-----------------------------------------------------------------------
-- 1. FUNCTIONS
-----------------------------------------------------------------------

# == FUNCTION ====================================
CREATE TEMP FUNCTION function_cast_date(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS DATE));

# == FUNCTION ====================================
CREATE TEMP FUNCTION function_cast_string(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS STRING));

# == FUNCTION ====================================
CREATE TEMP FUNCTION function_cast_int(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS INT));

# == FUNCTION ====================================
CREATE TEMP FUNCTION function_cast_boolean(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS BOOLEAN));

# == FUNCTION ====================================
CREATE TEMP FUNCTION function_cast_datetime(x ANY TYPE)
AS (
   EXTRACT(DATE FROM (CAST(NULLIF(CAST(x AS STRING), "NA") AS TIMESTAMP)))
   );

-----------------------------------------------------------------------
-- 2. PROCESS ORCID DATA
-----------------------------------------------------------------------
with orcid_data AS (
  SELECT
   #function_cast_string(name_from_list) as name_from_list,
   #function_cast_string(orcid_first_name) as orcid_first_name,
   #function_cast_string(orcid_last_name) as orcid_last_name,
   #function_cast_string(orcid_affiliation) as orcid_affiliation,

   # ---------- orcid_id
   function_cast_string(orcid_id) as orcid_id_raw,
   CASE WHEN is_orcid THEN orcid_id
     ELSE NULL
     END as orcid_id,

   # ---------- is_orcid
   function_cast_boolean(is_orcid) as is_orcid,
   CASE WHEN is_orcid THEN "ORCID found for researcher"
     ELSE "No ORCID found for researcher"
     END as is_orcid_PRETTY,

   # ---------- orcid_verified
   function_cast_boolean(orcid_verified) as orcid_verified,
   CASE WHEN orcid_verified THEN "Verified ORCID found for researcher"
     ELSE "No verified ORCID found for researcher"
     END as orcid_verified_PRETTY,   
   # ---------- is_affiliation
   function_cast_boolean(is_affiliation) as is_affiliation,
   CASE WHEN is_affiliation THEN "ORCID affiliation found for researcher"
     ELSE "No ORCID affiliation found for researcher"
     END as is_affiliation_PRETTY,

FROM `university-of-ottawa.neuro_data_raw.neuro_pis_orcid`
) # End of 2. SELECT orcid_data

-----------------------------------------------------------------------
-- 3. Final select
--    Leaving this here as it is likely that we will expand this script
-----------------------------------------------------------------------
  SELECT
  orcid_data.*,

  ----- 3.2 UTILITY - add a variable for the script and input data versions
  var_SQL_script_name,
  var_ORCID_Dataset_name,
  var_output_table

  FROM orcid_data
  
 
