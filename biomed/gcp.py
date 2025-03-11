import os
from typing import Optional

from google.cloud.bigquery.client import Client
from google.cloud.bigquery.table import RowIterator
from google.cloud.bigquery.dataset import Dataset
from google.api_core.exceptions import NotFound


def gcp_set_auth(keyfile: str) -> None:
    """Sets the Google Cloud Project authentication environment variable using the provided keyfile"""
    if not os.path.exists(keyfile):
        raise RuntimeError(f"Provided keyfile does not exist: {keyfile}")
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = keyfile


def bq_run_query(project: str, query: str) -> RowIterator:
    """Runs a query in bigquery.

    :param project: The name of the project to run the query under.
    :param query: The query to run
    """
    client: Client = Client(project=project)
    return client.query_and_wait(query)


def bq_create_dataset(project: str, dataset: str, exists_ok: bool = True) -> Dataset:
    """Creates a dataset in bigquery.

    :param project: The project to create the dataset under
    :param dataset: The name of the dataset to create
    :param exists_ok: If true, will not raise error if the dataset already exists
    """
    client: Client = Client(project=project)
    return client.create_dataset(dataset, exists_ok=exists_ok)


def bq_check_table_exists(project: str, dataset: str, table_name: str) -> bool:
    """Checks if a table exists in bigquery

    :param project: The project that the table is stored in.
    :param dataset: The dataset that the table is stored in.
    :param table_name: The name of the table.
    """
    client: Client = Client(project=project)
    table_id = f"{project}.{dataset}.{table_name}"
    try:
        client.get_table(table_id)
    except NotFound:
        return False
    return True
