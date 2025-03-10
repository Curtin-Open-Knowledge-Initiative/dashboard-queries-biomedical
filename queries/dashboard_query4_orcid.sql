-----------------------------------------------------------------------
-- Biomedical Open Science Dashboard Processing - Process ORCID data
-- Run this FOUTH
-- See https://github.com/Curtin-Open-Knowledge-Initiative/dashboard-queries-biomedical
-----------------------------------------------------------------------
###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSIONS
DECLARE var_SQL_script_name STRING DEFAULT 'p01_ver2b_query4_orcid_20250310';
DECLARE var_output_table STRING DEFAULT 'p01_orcid_20250310';

DECLARE var_ORCID_Dataset_name STRING DEFAULT 'theneuro_orcids_20230906';
DECLARE var_institution_id STRING DEFAULT 'p01_theneuro';

-----------------------------------------------------------------------
-- 1. FUNCTIONS
-----------------------------------------------------------------------
# == FUNCTION ====================================
CREATE TEMP FUNCTION function_cast_string(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS STRING));

# == FUNCTION ====================================
CREATE TEMP FUNCTION function_cast_boolean(x ANY TYPE)
AS (CAST(NULLIF(CAST(x AS STRING), "NA") AS BOOLEAN));

-----------------------------------------------------------------------
-- 0. Setup table 
-----------------------------------------------------------------------
###---###---###---###---###---### CHECK OUTPUT BELOW FOR CORRECT VERSION
CREATE TABLE `university-of-ottawa.p01_neuro_data.p01_orcid_20250310`
 AS (

-----------------------------------------------------------------------
-- 2. PROCESS ORCID DATA
-----------------------------------------------------------------------
with orcid_data AS (
  SELECT
  
   # ---------- orcid_id
   function_cast_string(orcid_id) as orcid_id_raw,

   CASE WHEN is_orcid THEN function_cast_string(orcid_id)
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

###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
# of the contributed ORCID data from the partner institution
FROM `university-of-ottawa.p01_neuro_from_partners.p01_theneuro_orcid_20230906`

) # End of 2. SELECT orcid_data

-----------------------------------------------------------------------
-- 3. Final select
--    Leaving this here as it is likely that we will expand this script
-----------------------------------------------------------------------
  SELECT
  orcid_data.*,

  ----- 3.2 UTILITY - add variables for the script version and data files
  var_SQL_script_name,
  var_ORCID_Dataset_name,
  var_output_table,
  var_institution_id

  FROM orcid_data

) # End create table
