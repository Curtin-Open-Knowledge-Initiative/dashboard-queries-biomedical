-----------------------------------------------------------------------
-- Montreal Neuro - Run this first
-- See instructions at https://github.com/Curtin-Open-Knowledge-Initiative/dashboard-queries-biomedical
-- Creates a data subset of the Academic Observatory to extract Crossref 
-- and Pubmed data and make a combined list of Clinical trials from these datasets
-----------------------------------------------------------------------
###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSIONS
DECLARE var_SQL_script_name STRING DEFAULT 'neuro_ver1p_query1_alltrials_2024_05_29';
DECLARE var_SQL_year_cutoff INT64 DEFAULT 1; # e.g. 2000
DECLARE var_AcademicObservatory_doi STRING DEFAULT 'doi20240512';
DECLARE var_output_table STRING DEFAULT 'OUTPUT_ver1p_query1_alltrials_2024_05_29';

-----------------------------------------------------------------------
-- 0. FUNCTIONS
-----------------------------------------------------------------------
CREATE TEMP FUNCTION
  dedupe_string(input_string STRING, separator STRING)
    RETURNS STRING AS ( 
      # Flatten the deduplicated array of sub-strings
      ARRAY_TO_STRING (
        # Reconsitutute the de-duplicated flattened sb-strings into an array
        ARRAY( 
          SELECT
            DISTINCT substrings
          FROM
            UNNEST(
            SPLIT(input_string, separator)
            ) AS substrings
        ) # End of ARRAY
      , separator) # End of ARRAY_TO_STRING
    ); # End of RETURNS

# --------------------------------------------------
# 0. Setup table 
# --------------------------------------------------
###---###---###---###---###---### CHECK OUTPUT BELOW FOR CORRECT VERSION
CREATE TABLE `university-of-ottawa.neuro_dashboard_data_archive.OUTPUT_ver1p_query1_alltrials_2024_05_29`
AS (

-----------------------------------------------------------------------
-- 1. EXTRACT AND TIDY FIELDS OF INTEREST (except Pubmed clintrial/databank data)
-----------------------------------------------------------------------
WITH main_select AS (
  SELECT
  ------ 1.1 DOI TABLE: Misc METADATA
  academic_observatory.doi as doi,
  academic_observatory.crossref.published_year, -- from doi table

  ------ 1.2 ABSTRACTS from any sources
  academic_observatory.crossref.abstract AS abstract_CROSSREF,  
  academic_observatory.pubmed.MedlineCitation.Article.Abstract.AbstractText AS abstract_PUBMED,

  ------ 1.3 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF Abstract search for trial numbers
  CASE
    WHEN academic_observatory.crossref.abstract IS NULL THEN FALSE
    WHEN academic_observatory.crossref.abstract = '' THEN FALSE
    WHEN academic_observatory.crossref.abstract = "{}" THEN FALSE
    WHEN REGEXP_CONTAINS(UPPER(academic_observatory.crossref.abstract), r'NCT[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]') THEN TRUE
    ELSE FALSE
    END as CROSSREF_clintrial_fromabstract_found,
 
  # create struct for CROSSREF_clintrial_fromabstract which is null for the whole struct if no NCT*s were found
  CASE
    WHEN academic_observatory.crossref.abstract IS NULL THEN NULL
    WHEN academic_observatory.crossref.abstract = '' THEN NULL
    WHEN academic_observatory.crossref.abstract = "{}" THEN NULL
    
    # Could have multiple NCT's in the abstract, and they could be mentioned multiple times
    WHEN REGEXP_CONTAINS(UPPER(academic_observatory.crossref.abstract), r'NCT[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]') THEN 
    (SELECT
          ARRAY_AGG(unnested_1) ,
          FROM (
            SELECT DISTINCT *  
            FROM UNNEST(
            REGEXP_EXTRACT_ALL(UPPER(academic_observatory.crossref.abstract), r'NCT[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
            ) as id ) AS unnested_1   
          )  # end of SELECT for deduplicating found NCTs
    
      ELSE NULL
      END as CROSSREF_clintrial_fromabstract, # END of create struct for CROSSREF_clintrial_fromabstract

   ------ 1.4 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - PUBMED Abstract search for trial numbers
   ------ NOTE: the code below only looks for NCTs, not IDs from other registries
  CASE
    WHEN pubmed.MedlineCitation.Article.Abstract.AbstractText IS NULL THEN FALSE
    WHEN pubmed.MedlineCitation.Article.Abstract.AbstractText = '' THEN FALSE
    WHEN pubmed.MedlineCitation.Article.Abstract.AbstractText = "{}" THEN FALSE
    WHEN REGEXP_CONTAINS(UPPER(pubmed.MedlineCitation.Article.Abstract.AbstractText), r'NCT[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]') THEN TRUE
    ELSE FALSE
    END as PUBMED_clintrial_fromabstract_found,
 
  # create struct for PUBMED_clintrial_from abstract which is null for the whole struct if no NCT's were found
  CASE
    WHEN pubmed.MedlineCitation.Article.Abstract.AbstractText IS NULL THEN NULL
    WHEN pubmed.MedlineCitation.Article.Abstract.AbstractText = '' THEN NULL
    WHEN pubmed.MedlineCitation.Article.Abstract.AbstractText = "{}" THEN NULL
    
    # Could have multiple NCT's in the abstract, and they could be mentioned multiple times
    WHEN REGEXP_CONTAINS(UPPER(pubmed.MedlineCitation.Article.Abstract.AbstractText), r'NCT[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]') THEN 
    (SELECT
          ARRAY_AGG(unnested_2) ,
          FROM (
            SELECT DISTINCT *  
            FROM UNNEST(
            REGEXP_EXTRACT_ALL(UPPER(pubmed.MedlineCitation.Article.Abstract.AbstractText), r'NCT[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
            ) as id ) AS unnested_2  
          )  # end of SELECT for deduplicating found NCTs
    
    ELSE NULL
    END as PUBMED_clintrial_fromabstract, # END of create struct for PUBMED_clintrial_fromabstract

 ------ 1.5 CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF - contained in fields
  academic_observatory.crossref.clinical_trial_number AS CROSSREF_clintrial_fromfield_raw,

  CASE
    WHEN academic_observatory.crossref.clinical_trial_number IS NULL THEN FALSE
    WHEN ARRAY_LENGTH(academic_observatory.crossref.clinical_trial_number) > 0 THEN TRUE
    ELSE FALSE
    END as CROSSREF_clintrial_fromfield_found,

 -----------------------------------------------------------------------
 FROM
    ------ Crossref from Academic Observatory.
    ###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
    `academic-observatory.observatory.doi20240512` AS academic_observatory
    WHERE academic_observatory.crossref.published_year > var_SQL_year_cutoff

 ), # END OF 1. SELECT main_select

-----------------------------------------------------------------------
-- 2a, Extract just the CLINICAL TRIAL Registries from the overloaded PUBMED field
-----------------------------------------------------------------------
pubmed_1_clintrials AS (
 SELECT
   pubmed.doi as doi,

   ARRAY_AGG(
     STRUCT(
       p2a.AccessionNumberList AS id,
       p2a.DataBankName AS registry     
       )
      ) as PUBMED_clintrial_fromfield, 

  FROM 
   ###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
   `academic-observatory.observatory.doi20240512` AS academic_observatory,
   UNNEST(pubmed.MedlineCitation.Article.DataBankList) AS p2a

   WHERE academic_observatory.crossref.published_year > var_SQL_year_cutoff 
   AND REGEXP_CONTAINS(p2a.DataBankName,'ANZCTR|ChiCTR|CRiS|ClinicalTrials\\.gov|CTRI|DRKS|EudraCT|IRCT|ISRCTN|JapicCTI|JMACCT|JPRN|NTR|PACTR|ReBec|REPEC|RPCEC|SLCTR|TCTR|UMIN CTR|UMIN-CTR')
   
   group by pubmed.doi
), # END. SELECT pubmed_1_clintrials

-----------------------------------------------------------------------
-- 2b, Extract just the DATABANKS from the overloaded PUBMED field
-----------------------------------------------------------------------
pubmed_2_databanks AS (
 SELECT
   pubmed.doi as doi,   
    
   ARRAY_AGG(
    STRUCT(
      p2b.AccessionNumberList AS id,
      p2b.DataBankName AS registry
    )
   ) as PUBMED_opendata_fromfield,
      
  FROM 
   ###---###---###---###---###---### CHECK INPUTS BELOW FOR CORRECT VERSION
   `academic-observatory.observatory.doi20240512` AS academic_observatory,
   UNNEST(pubmed.MedlineCitation.Article.DataBankList) AS p2b

   WHERE academic_observatory.crossref.published_year > var_SQL_year_cutoff AND
   REGEXP_CONTAINS(p2b.DataBankName,'BioProject|dbGaP|dbSNP|dbVar|Dryad|figshare|GDB|GENBANK|GEO|OMIM|PIR|PubChem-BioAssay|PubChem-Compound|PubChem-Substance|RefSeq|SRA|SWISSPROT|UniMES|UniParc|UniProtKB|UniRef|PDB|Protein')
   
  group by pubmed.doi
), # END. SELECT pubmed_2_databanks

-----------------------------------------------------------------------
-- 3a: Link Pubmed data to main query - Clintrials
-----------------------------------------------------------------------
enhanced_4ba AS (
SELECT
  main_select.*,
  enhanced_4ba_joined.PUBMED_clintrial_fromfield,
  CASE
    WHEN enhanced_4ba_joined.PUBMED_clintrial_fromfield IS NULL THEN FALSE
  ELSE TRUE
  END AS PUBMED_clintrial_fromfield_found

FROM main_select
  LEFT JOIN pubmed_1_clintrials as enhanced_4ba_joined
  ON LOWER(main_select.doi) = LOWER(enhanced_4ba_joined.doi)
), # END enhanced_4ba

-----------------------------------------------------------------------
-- 3b: Link Pubmed data to main query - Databanks
-----------------------------------------------------------------------
enhanced_3b AS (
SELECT
  enhanced_4ba.*,
  enhanced_3b_joined.PUBMED_opendata_fromfield,
  CASE
    WHEN enhanced_3b_joined.PUBMED_opendata_fromfield IS NULL THEN FALSE
  ELSE TRUE
  END AS PUBMED_opendata_fromfield_found

FROM enhanced_4ba
  LEFT JOIN pubmed_2_databanks as enhanced_3b_joined
  ON LOWER(enhanced_4ba.doi) = LOWER(enhanced_3b_joined.doi)
), # END enhanced_3b

-----------------------------------------------------------------------
-- 4a: Rename the sub-fields of Crossref's 
---   CLINICAL TRIAL NUMBERS ASSOCIATED WITH PUBLICATIONS - CROSSREF - contained in fields
-----------------------------------------------------------------------
enhanced_4a AS (
SELECT
  doi,
  ARRAY_AGG(
    STRUCT(
      UPPER(n1.clinical_trial_number) AS id,
      n1.type AS type
      )
    ) AS CROSSREF_clintrial_fromfield,

 FROM
    main_select,
    UNNEST (CROSSREF_clintrial_fromfield_raw) as n1
    GROUP BY doi
),

-----------------------------------------------------------------------
-- 4b: Join the re-named Crossref structure back into the main query
-----------------------------------------------------------------------
enhanced_4b AS (
 SELECT
  enhanced_3b.* EXCEPT(CROSSREF_clintrial_fromfield_raw),
  enhanced_4a_joined.CROSSREF_clintrial_fromfield,

  FROM enhanced_3b
    LEFT JOIN enhanced_4a as enhanced_4a_joined
    ON LOWER(enhanced_3b.doi) = LOWER(enhanced_4a_joined.doi)
), # END enhanced_4b

-----------------------------------------------------------------------
-- 5: Combine trial IDs and registies for BOTH Crossref and Pubmed
--    Make concatenated string version of clinical trial IDs for each source (to be used upstream)
--    List all variables here so as to re-order them
--    Have stored IDs as both a STRUCT and concatenated stings, to be more useful upstream
-----------------------------------------------------------------------
 enhanced_5 AS (
  SELECT
    doi,
    published_year,
    abstract_CROSSREF,
    abstract_PUBMED,
  
    ------ 5.1 Make concatenated string version of clinical trial IDs from CROSSREF_clintrial_fromabstract
    CROSSREF_clintrial_fromabstract_found,
    CROSSREF_clintrial_fromabstract,

    CASE
      WHEN CROSSREF_clintrial_fromabstract IS NULL THEN ''
    ELSE
      TRIM((SELECT 
       STRING_AGG(TRIM(id_unnest_c1.id), ' ')
       FROM UNNEST(CROSSREF_clintrial_fromabstract) AS id_unnest_c1
       ))
      END AS CROSSREF_clintrial_fromabstract_idlist,

  ------ 5.2 Make concatenated string version of clinical trial IDs from CROSSREF_clintrial_fromfield
    CROSSREF_clintrial_fromfield_found,
    CROSSREF_clintrial_fromfield,

    CASE
      WHEN CROSSREF_clintrial_fromfield IS NULL THEN ''
    ELSE
      TRIM((SELECT 
      STRING_AGG(TRIM(id_unnest_c2.id), ' ')
      FROM UNNEST(CROSSREF_clintrial_fromfield) AS id_unnest_c2
      ))
    END AS CROSSREF_clintrial_fromfield_idlist,

    ------ 5.3 Make concatenated string version of clinical trial IDs from PUBMED_clintrial_fromabstract
    PUBMED_clintrial_fromabstract_found,
    PUBMED_clintrial_fromabstract,

    CASE
      WHEN PUBMED_clintrial_fromabstract IS NULL THEN ''
    ELSE
      TRIM((SELECT 
      STRING_AGG(TRIM(id_unnest_p1.id), ' ')
      FROM UNNEST(PUBMED_clintrial_fromabstract) AS id_unnest_p1
      ))
    END AS PUBMED_clintrial_fromabstract_idlist,

    ------ 5.4 Make concatenated string version of clinical trial IDs from PUBMED_clintrial_fromfield
    PUBMED_clintrial_fromfield_found,
    PUBMED_clintrial_fromfield,

    CASE
      WHEN PUBMED_clintrial_fromfield IS NULL THEN ''
    ELSE
      TRIM((SELECT 
      STRING_AGG(TRIM(id_unnest_p2_id), ' ')
      FROM
      UNNEST(PUBMED_clintrial_fromfield) AS id_unnest_p2,
      UNNEST(id_unnest_p2.id) AS id_unnest_p2_id
      ))
    END AS PUBMED_clintrial_fromfield_idlist,

    ------ 5.5 Make concatenated string version of clinical trial IDs from PUBMED_opendata_fromfield
    PUBMED_opendata_fromfield_found,
    PUBMED_opendata_fromfield,
  
    (SELECT 
      STRING_AGG(TRIM(id_unnest_p3_id), ' ')
      FROM
      UNNEST(PUBMED_opendata_fromfield) AS id_unnest_p3,
      UNNEST(id_unnest_p3.id) AS id_unnest_p3_id
      ) AS PUBMED_opendata_fromfield_idlist,

  FROM enhanced_4b
)

-----------------------------------------------------------------------
-- 6: Combine Trial-IDs from all sources
-----------------------------------------------------------------------
SELECT 
* ,
 ------ 6.1 Determine if ANY Clinical Trial is found from ANY source
 IF (CROSSREF_clintrial_fromfield_found 
  OR CROSSREF_clintrial_fromabstract_found
  OR PUBMED_clintrial_fromfield_found
  OR PUBMED_clintrial_fromabstract_found, 
  TRUE, FALSE) AS ANYSOURCE_clintrial_found,
  
  ------ 6.2 Clinical Trial - combine Trial-IDs from all sources

  dedupe_string(TRIM(REPLACE(CONCAT(
    CROSSREF_clintrial_fromabstract_idlist, ' ',
    CROSSREF_clintrial_fromfield_idlist, ' ',
    PUBMED_clintrial_fromabstract_idlist, ' ',
    PUBMED_clintrial_fromfield_idlist
    ),'  ',' ')), ' ') AS ANYSOURCE_clintrial_idlist,
 ----- 6.3 UTILITY - add a variable for the script and data versions
var_AcademicObservatory_doi,
var_SQL_script_name,
var_output_table

FROM enhanced_5

) # End create table 
