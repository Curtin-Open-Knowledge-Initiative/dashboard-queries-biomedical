-----------------------------------------------------------------------
-- Montreal Neuro - Trial Data query 
-- Run this second
-- See instructions at https://github.com/Curtin-Open-Knowledge-Initiative/dashboard-queries-biomedical
-- The in put trials data was created here: https://github.com/maia-sh/the-neuro-trials/tree/main
-----------------------------------------------------------------------

###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSIONS
DECLARE var_SQL_script_name STRING DEFAULT 'p01_ver2a_query2_trials_20250219';
DECLARE var_data_trials STRING DEFAULT 'theneuro_trials_20231111';
DECLARE var_data_dois STRING DEFAULT 'theneuro_dois_20230217';
DECLARE var_output_table STRING DEFAULT 'p01_ver2a_trials_20250219';

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
-- 2. Setup table 
-----------------------------------------------------------------------
####---###---###---###---###---### CHECK OUTPUT BELOW FOR CORRECT VERSION
CREATE TABLE `university-of-ottawa.p01_neuro_data.p01_ver2a_trials_20250219`
 AS (

-----------------------------------------------------------------------
-- 3. PROCESS IMPORTED TRIAL DATA
-----------------------------------------------------------------------
with d_3_contributed_trials_data AS (
  SELECT
  # descriptions of fields are here: https://github.com/maia-sh/the-neuro-trials/blob/main/R/03_combine-trials.R
  
  # ==== Metric name on dashboard: # Trials
  UPPER(function_cast_string(nct_id)) as nct_id,
  CASE
    WHEN nct_id IS NULL THEN FALSE
    ELSE TRUE
    END as nct_id_found,

  CASE
    WHEN nct_id IS NULL THEN "No Trial-ID"
    ELSE "Has Trial-ID"
    END as nct_id_found_PRETTY,

  -----------------------------------------------------------------------
  # The following comemnted out variables are extract columns in the input data that are not used upstream

  #function_cast_string(source) as source,
  #function_cast_date(last_update_submitted_date) as last_update_submitted_date,
  function_cast_date(registration_date) as registration_date,
  #function_cast_date(summary_results_date) as summary_results_date,
  #function_cast_string(study_type) as study_type,
  #function_cast_string(phase) as phase,
  #function_cast_int(enrollment) as enrollment,
  #function_cast_string(recruitment_status) as recruitment_status,
  #function_cast_string(title) as title,
  function_cast_datetime(start_date) as start_date,
  function_cast_datetime(completion_date) as completion_date,
  #function_cast_datetime(primary_completion_date) as primary_completion_date,
  #function_cast_boolean(has_summary_results) as has_summary_results,
  #function_cast_string(allocation) as allocation,
  #function_cast_string(masking) as masking,
  #function_cast_string(main_sponsor) as main_sponsor,
  #function_cast_boolean(is_multicentric) as is_multicentric,
  #function_cast_int(registration_year) as registration_year,
  #function_cast_int(start_year) as start_year,
  #function_cast_int(completion_year) as completion_year,

  # ==== Metric name on dashboard: # Prospective registrations 
  function_cast_boolean(is_prospective) as is_prospective,
  CASE
    WHEN function_cast_boolean(is_prospective) IS TRUE THEN "Registered before enrollment started"
    ELSE "Registered after enrollment started"
    END as is_prospective_PRETTY,

  #function_cast_int(days_cd_to_summary) as days_cd_to_summary,
  #function_cast_int(days_pcd_to_summary) as days_pcd_to_summary,

  # ==== Metric name on dashboard: # Trial results in a registry < 1 year post completion 
  ############## NOTE FOR NEW CATEGORIES ONCE WE HAVE THE NEW DATA ##############
  # Category 1 (turquoise): Trials that reported summary results on time i.e., within 1 year of primary completion (whether due or not) 
  # Category 2 (orange): Due trials that reported summary results late i.e., after 1 year of primary completion 
  # Category 3 (another color to indicate bad, e.g., red, if colorblind safe in your scheme): “Due trials that did not report summary results”.  
  # Category 4 (grey): Trials not yet due to report results  

  function_cast_boolean(is_summary_results_1y_cd) as is_summary_results_1y_cd,
  CASE
    WHEN function_cast_boolean(is_summary_results_1y_cd) IS TRUE THEN "Trials that reported summary results on time i.e., within 1 year of primary completion (whether due or not)"
    WHEN function_cast_boolean(is_summary_results_1y_cd) IS FALSE THEN "Due trials that reported summary results late i.e., after 1 year of primary completion"
    ELSE "Due trials that did not report summary results"
    END as is_summary_results_1y_cd_PRETTY,
    
  #function_cast_boolean(is_summary_results_1y_pcd) as is_summary_results_1y_pcd,

##---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
# of the imported trials from the partner.
FROM `university-of-ottawa.p01_neuro_from_partners.theneuro_trials_aact_20231111`
), # End of d_3_contributed_trials_data

-----------------------------------------------------------------------
-- 4. This group of steps are to get a list of ANY publications that mention 
-- the imported Trials. his extract will be used in multiple script sections.
-----------------------------------------------------------------------
-- Extract and flatten the DOIs (1) and Trial-IDs (MANY)
-- associated with ANY SOURCE (ie from Crossref or Pubmed), reulting in a
-- many-to-many file
-- This step needs to be done as the data in Step 1 is by DOIs not TrialIDs
-----------------------------------------------------------------------
d_4_anysource_extract_flat AS (
SELECT 
  LOWER(doi) as ANYSOURCE_doi,
  UPPER(TRIM(ANYSOURCE_clintrial_id_flat)) as ANYSOURCE_clintrial_id_flat  
FROM
  ###---###---###---###---###---### CHECK OUTPUT BELOW FOR CORRECT VERSION 
  # of the all trials processed in Step 1 - query1
  `university-of-ottawa.p01_neuro_data.p01_ver2a_alltrials_20250218`,
  UNNEST(SPLIT(TRIM(ANYSOURCE_clintrial_idlist)," ")) as ANYSOURCE_clintrial_id_flat
  WHERE ANYSOURCE_clintrial_found
), # END d_4_anysource_extract_flat

-----------------------------------------------------------------------
-- STEP 5:
-- These next steps are to get the data that inthe dashboard this will go 
-- into the section titled "Linking The Neuro's trial dataset to The Neuro's publications"
-- Data from Crossref and PubMed is used to link the two datasets
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- 5A. To the list of Contributed trial IDs (ie #3), join to the flattened table of 
-- Trial-ID/DOIs from Crossref/Pubmed (ie #4), using the trial IDs
-- to match the tables. Also join the 
-----------------------------------------------------------------------
d_5a_trials_joined_to_anysource AS (
  SELECT 
  p1.nct_id,
  TRIM(STRING_AGG(LOWER(p2.ANYSOURCE_doi), ' ')) AS ANYSOURCE_dois_matching_trialid

  FROM d_3_contributed_trials_data as p1
  INNER JOIN d_4_anysource_extract_flat as p2
    ON lower(p1.nct_id) = lower(p2.ANYSOURCE_clintrial_id_flat)
  GROUP BY p1.nct_id
  # END OF  d_5a_trials_joined_to_anysource
),

-----------------------------------------------------------------------
-- 5B. Add this list of dois that contain trial IDs 
-- (i.e. ANYSOURCE_dois_matching_trialid from #5A) to the the rest of the 
-- contributed trial data, and add some extra calculated fields
-- There may be multiple DOIs per trial ID
-----------------------------------------------------------------------
d_5b_trials_data_joined_to_anysource AS (
  SELECT 
  p4.*,
  p5.ANYSOURCE_dois_matching_trialid,

  CASE
    WHEN p5.ANYSOURCE_dois_matching_trialid IS NOT NULL
    THEN TRUE
    ELSE FALSE
    END AS ANYSOURCE_doi_found,

  CASE
    WHEN p5.ANYSOURCE_dois_matching_trialid IS NOT NULL
    THEN "Trial-IDs from the Neuro's trial dataset found in a Crossref or Pubmed publication"
    ELSE "No Trial-IDs from the Neuro's trial dataset found in a Crossref or Pubmed publication"
    END AS ANYSOURCE_doi_found_PRETTY,

  FROM d_3_contributed_trials_data as p4
  LEFT JOIN d_5a_trials_joined_to_anysource as p5
    ON lower(p4.nct_id) = lower(p5.nct_id)  
  # END OF d_5b_trials_data_joined_to_anysource
),

-----------------------------------------------------------------------
-- STEP 6:
-- These next steps are to get the data that inthe dashboard this will go 
-- into the section titled "Trial-IDs from The Neuro's trial dataset that 
-- are found in The Neuro's manuscript-style publication dataset"
-- Data from Crossref and PubMed is used to link the two datasets
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- 6A.From the many-to-many flatted list of DOIs and Trial-IDs associated with ANY SOURCE 
-- (ie re-used from step 4A from earlier), subset JUST the rows/Trial-IDs with DOIs that 
-- are in the contributed PUBLICATION set. This is done so that we can identify 
-- which of the contributed publications have Trial-ID references, by looking up
-- trialIDs from the Pubmed/Crossref data
-----------------------------------------------------------------------
d_6a_pubs_data_intersect_anysource AS (
  SELECT
  TRIM(LOWER(p6.doi)) AS PUBSDATA_doi,
  p7.ANYSOURCE_clintrial_id_flat
  FROM
    ###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
    # of the imported dois from the partner.
    `university-of-ottawa.p01_neuro_from_partners.theneuro_dois_20230217` as p6
    INNER JOIN d_4_anysource_extract_flat as p7
      ON LOWER(p6.doi) = LOWER(p7.ANYSOURCE_doi)
), # END OF d_6a_pubs_data_intersect_anysource

----------------------------------------------------------------------
-- 6B.Further subset the previous subset of DOI-to-TrialIDs by just the TrialIDs 
-- that are found in the contributed Clinical Trial list. This step
-- could be done in combination with the following step, but it is being
-- implemented seperately to improve clarity and allow QC of the data
-----------------------------------------------------------------------
d_6b_pubs_data_intersect_anysource AS (
  SELECT
    p9.nct_id,
    TRIM(STRING_AGG(p8.PUBSDATA_doi, ' ')) AS PUBSDATA_doi #could be more than 1

  FROM
    d_6a_pubs_data_intersect_anysource AS p8
    INNER JOIN d_3_contributed_trials_data AS p9

  ON LOWER(p8.ANYSOURCE_clintrial_id_flat) = LOWER(p9.nct_id)
  GROUP BY p9.nct_id
) # END OF d_6b_pubs_data_intersect_anysource

-----------------------------------------------------------------------
-- STEP 7:
-- Final select and adding extra variables
-- To the enhanced Trial Data join the subset of TrialIDs that 
-- are found in the contributed PUBLICATIONS set, and add some extra fields
-----------------------------------------------------------------------
SELECT
  p10.*,
  p11.PUBSDATA_doi,

  CASE
    WHEN p11.PUBSDATA_doi IS NOT NULL
    THEN TRUE
    ELSE FALSE
    END AS PUBSDATA_doi_found,

  CASE
    WHEN p11.PUBSDATA_doi IS NOT NULL
    THEN "Trial-IDs from the Neuro's trial dataset found in a publication from The Neuro"
    ELSE "No Trial-IDs from the Neuro's trial dataset found in a publication from The Neuro"
    END AS PUBSDATA_doi_found_PRETTY,

  ----- UTILITY - add a variable for the script and input data versions
  var_SQL_script_name,
  var_data_trials,
  var_data_dois,
  var_output_table

  FROM d_5b_trials_data_joined_to_anysource as p10
  LEFT JOIN d_6b_pubs_data_intersect_anysource as p11 
  ON lower(p10.nct_id) = lower(p11.nct_id)

  # END OF FINAL SELECT #7
)
