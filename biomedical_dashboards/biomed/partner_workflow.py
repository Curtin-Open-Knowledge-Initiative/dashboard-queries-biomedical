from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Tuple
import os

import google

from biomedical_dashboards.biomed.config import Partner, Context
from biomedical_dashboards.biomed.gcp import (
    bq_check_table_exists,
    bq_create_dataset,
    bq_run_query,
    bq_copy_table,
)
from biomedical_dashboards.biomed.logs import bioprint
from biomedical_dashboards.biomed.queries import query_alltrials, query_trials, query_pubs


def partner_workflow(partner: Partner, context: Context) -> None:
    """Workflow for a single partner. Does the following:
    - Checks that the static tables exist
    - Creates output datasets if they don't exist
    - Generates the queries and writes them to files
    - Runs the queries
    - Makes a copy of the created table, placing it in the "latest" dataset

    If context.dryrun setting is enabled, will only create and output the queries.
    """
    # Check/make datasets
    if not context.dryrun:
        check_static_tables_exist(partner=partner, context=context)
        bioprint(partner, "All expected static tables exist")
        try:
            bq_create_dataset(project=context.project, dataset=partner.output_dataset, exists_ok=False)
            bioprint(partner, f"Created dataset: {context.project}.{partner.output_dataset}")
        except google.cloud.exceptions.Conflict:
            bioprint(
                partner,
                f"Dataset already exists, no need to create: {context.project}.{partner.output_dataset}",
            )
        try:
            bq_create_dataset(project=context.project, dataset=partner.latest_dataset, exists_ok=False)
            bioprint(partner, f"Created dataset: {context.project}.{partner.latest_dataset}")
        except google.cloud.exceptions.Conflict:
            bioprint(
                partner,
                f"Dataset already exists, no need to create: {context.project}.{partner.latest_dataset}",
            )

    # Query creation
    generate_queries(partner=partner, context=context)

    # Query run
    if not context.dryrun:
        run_queries(partner=partner, context=context)
        check_generated_tables_exist(partner=partner, context=context)
        update_latest_tables(partner=partner, context=context)


def check_static_tables_exist(partner: Partner, context: Context):
    """Checks that the static tables exist"""

    def _wrapped_check(project, dataset, table_name) -> Tuple[bool, str]:
        """Wrapped function that also returns the table name"""
        return (bq_check_table_exists(project, dataset, table_name), table_name)

    table_names = [
        partner.trials_aact_table_name,
        partner.dois_table_name,
        partner.oddpub_table_name,
    ]
    futures = []
    with ThreadPoolExecutor(max_workers=4) as executor:
        for t in table_names:
            futures.append(executor.submit(_wrapped_check, context.project, partner.static_dataset, t))

    errors = []
    for f in as_completed(futures):
        result = f.result()
        if result[0] == False:
            errors.append(f"{context.project}.{partner.static_dataset}.{result[1]}")
    if errors:
        msg = "\n\t".join(errors)
        raise RuntimeError(f"Expected table(s) missing:\n\t{msg}")


def generate_queries(partner: Partner, context: Context) -> None:
    """Generates all of the queries for the partner and saves them to file"""
    # Create queries
    alltrials = query_alltrials(**partner.to_dict(), **context.to_dict())
    trials = query_trials(**partner.to_dict(), **context.to_dict())
    pubs = query_pubs(**partner.to_dict(), **context.to_dict())

    # Save queries to file
    path = os.path.join(context.output_dir, partner.alltrials_query_fname)
    save_query(alltrials, path)
    bioprint(partner, f"Query written to file: {path}")
    path = os.path.join(context.output_dir, partner.trials_query_fname)
    save_query(trials, path)
    bioprint(partner, f"Query written to file: {path}")
    path = os.path.join(context.output_dir, partner.pubs_query_fname)
    save_query(pubs, path)
    bioprint(partner, f"Query written to file: {path}")


def check_generated_tables_exist(partner: Partner, context: Context):
    """Checks that the generated tables exist"""

    def _wrapped_check(project, dataset, table_name) -> Tuple[bool, str]:
        """Wrapped function that also returns the table name"""
        return (bq_check_table_exists(project, dataset, table_name), table_name)

    table_names = [context.generated_alltrials_name, context.generated_trials_name, context.generated_pubs_name]
    futures = []
    with ThreadPoolExecutor(max_workers=4) as executor:
        for t in table_names:
            futures.append(executor.submit(_wrapped_check, context.project, partner.output_dataset, t))

    errors = []
    for f in as_completed(futures):
        result = f.result()
        if result[0] == False:
            errors.append(f"{context.project}.{partner.static_dataset}.{result[1]}")
    if errors:
        msg = "\n\t".join(errors)
        raise RuntimeError(f"Expected table(s) missing:\n\t{msg}")


def run_queries(partner: Partner, context: Context) -> None:
    """Reads the queries from file and runs them"""
    for query_fname in [
        partner.alltrials_query_fname,
        partner.trials_query_fname,
        partner.pubs_query_fname,
    ]:
        path = os.path.join(context.output_dir, query_fname)
        with open(path) as f:
            query = f.read()
        bioprint(partner, f"Running query: {path}")
        bq_run_query(context.project, query)


def update_latest_tables(partner: Partner, context: Context) -> None:
    """Copies the tables created from this run to the 'latest' dataset"""
    latest_dataset = f"{partner.institution_id}_data_latest"
    try:
        bq_create_dataset(project=context.project, dataset=latest_dataset, exists_ok=True)
        bioprint(partner, f"Created dataset: {context.project}.{partner.output_dataset}")
    except google.cloud.exceptions.Conflict:
        bioprint(
            partner,
            f"Dataset already exists, no need to create: {context.project}.{partner.output_dataset}",
        )
    bq_copy_table(
        project=context.project,
        src_dataset=partner.output_dataset,
        src_table_name=context.generated_trials_name,
        dest_dataset=latest_dataset,
        dest_table_name="trials",
        overwrite=True,
    )
    bioprint(
        partner, f"Copied table {partner.output_dataset}.{context.generated_trials_name} to {latest_dataset}.trials"
    )
    bq_copy_table(
        project=context.project,
        src_dataset=partner.output_dataset,
        src_table_name=context.generated_pubs_name,
        dest_dataset=latest_dataset,
        dest_table_name="pubs",
        overwrite=True,
    )
    bioprint(partner, f"Copied table {partner.output_dataset}.{context.generated_pubs_name} to {latest_dataset}.pubs")


def save_query(query: str, path: str) -> None:
    dir = os.path.dirname(path)
    if not os.path.exists(dir):
        raise RuntimeError(f"Directory does not exist: {dir}")

    with open(path, "w") as f:
        f.write(query)
