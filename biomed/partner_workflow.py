from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Tuple
import os

import google

from biomed.config import Partner, Context
from biomed.gcp import (
    bq_check_table_exists,
    bq_create_dataset,
    bq_run_query,
    bq_get_view_content,
    bq_delete_table,
    bq_create_view,
)
from biomed.logs import bioprint
from biomed.queries import query_alltrials, query_trials, query_pubs, query_latest_view


def partner_workflow(partner: Partner, context: Context) -> None:
    """Workflow for a single partner. Does the following:
    - Checks that the static tables exist
    - Creates output datasets if they don't exist
    - Generates the queries and writes them to files
    - Runs the queries
    - Creates views of the latest data

    If context.dryrun setting is enabled, will only create and output the queries.
    """
    # Check/make datasets
    if not context.dryrun:
        check_tables_exist(partner=partner, context=context)
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
    generate_views(partner=partner, context=context)

    # Query run
    if not context.dryrun:
        run_queries(partner=partner, context=context)
        create_views(partner=partner, context=context)


def check_tables_exist(partner: Partner, context: Context):
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


def generate_views(partner: Partner, context: Context) -> None:
    """Generates all of the latest views for the partner and saves them to file"""
    # Create views
    trials = query_latest_view(**partner.to_dict(), **context.to_dict(), table_name="trials")
    pubs = query_latest_view(**partner.to_dict(), **context.to_dict(), table_name="pubs")

    # Save views to file
    path = os.path.join(context.output_dir, partner.trials_latest_fname)
    save_query(trials, path)
    bioprint(partner, f"Query written to file: {path}")
    path = os.path.join(context.output_dir, partner.pubs_latest_fname)
    save_query(pubs, path)
    bioprint(partner, f"Query written to file: {path}")


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


def create_views(partner: Partner, context: Context) -> None:
    """Creates the views if they do not already exist. Will update the views if they change."""
    for view_name, view_fname in [("trials", partner.trials_latest_fname), ("pubs", partner.pubs_latest_fname)]:
        path = os.path.join(context.output_dir, view_fname)
        with open(path) as f:
            view_content = f.read()
        view_dataset = f"{partner.institution_id}_data_latest"

        # If view exists and is the same, don't update
        # If view exists but is different delete it and update it
        # If view doesn't exist, create it
        if bq_check_table_exists(project=context.project, dataset=view_dataset, table_name=view_name):
            existing_view_content = bq_get_view_content(
                project=context.project, dataset=view_dataset, view_name=view_name
            )
            if existing_view_content == view_content:
                bioprint(
                    partner,
                    f"View content identical, not updating: {context.project}.{view_dataset}_data_latest.{view_name}",
                )
                continue
            else:
                bioprint(
                    partner,
                    f"View exists, but content is different. Updating: {context.project}.{view_dataset}_data_latest.{view_name}",
                )
                bq_delete_table(project=context.project, dataset=view_dataset, table_name=view_name)
        bioprint(partner, f"Creating view: {context.project}.{view_dataset}.{view_name}")
        bq_create_view(project=context.project, dataset=view_dataset, view_name=view_name, view_content=view_content)


def save_query(query: str, path: str) -> None:
    dir = os.path.dirname(path)
    if not os.path.exists(dir):
        raise RuntimeError(f"Directory does not exist: {dir}")

    with open(path, "w") as f:
        f.write(query)
