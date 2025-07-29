import os
from typing import Optional

from google.cloud import bigquery
from google.cloud.bigquery.client import Client
from google.cloud.bigquery.table import RowIterator, Table
from google.cloud.bigquery.dataset import Dataset
from google.api_core.exceptions import NotFound


def gcp_set_auth(keyfile: str) -> None:
    """Sets the Google Cloud Project authentication environment variable using the provided keyfile"""
    if not os.path.exists(keyfile):
        raise RuntimeError(f"Provided keyfile does not exist: {keyfile}")
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = keyfile


def bq_run_query(project: str, query: str, client: Optional[Client] = None) -> RowIterator:
    """Runs a query in bigquery.

    :param project: The name of the project to run the query under.
    :param query: The query to run
    :param client: The bigquery client. Created if not supplied.
    :return: The query result as a RowIterator
    """
    if not client:
        client = Client(project=project)
    return client.query_and_wait(query)


def bq_create_dataset(project: str, dataset: str, exists_ok: bool = True, client: Optional[Client] = None) -> Dataset:
    """Creates a dataset in bigquery.

    :param project: The project to create the dataset under
    :param dataset: The name of the dataset to create
    :param exists_ok: If true, will not raise error if the dataset already exists
    :param client: The bigquery client. Created if not supplied.
    :return: The dataset object that was created
    """
    if not client:
        client = Client(project=project)
    return client.create_dataset(dataset, exists_ok=exists_ok)


def bq_check_table_exists(project: str, dataset: str, table_name: str, client: Client = None) -> bool:
    """Checks if a table exists in bigquery

    :param project: The project that the table is stored in.
    :param dataset: The dataset that the table is stored in.
    :param table_name: The name of the table.
    :param client: The bigquery client. Created if not supplied.
    :return: True if table exists, false otherwise
    """
    if not client:
        client = Client(project=project)
    table_id = f"{project}.{dataset}.{table_name}"
    try:
        client.get_table(table_id)
    except NotFound:
        return False
    return True


def bq_copy_table(
    project: str,
    src_dataset: str,
    src_table_name: str,
    dest_dataset: str,
    dest_table_name: str,
    overwrite: bool = False,
    client: Optional[Client] = None,
):
    """Copies a bigquery table to another destination within the same project

    :param project: The project to work within
    :param src_dataset: The dataset of the source table
    :param src_table_name: The table name of the source table
    :param dest_dataset: The dataset to copy the source table to
    :param dest_table_name: The table name to copy the source table to
    :param overwrite: If true, will overwrite any existing table
    :client: The bigquery client. Created if not supplied
    """
    if not client:
        client = client(project=project)
    src_table_id = f"{project}.{src_dataset}.{src_table_name}"
    dest_table_id = f"{project}.{dest_dataset}.{dest_table_name}"
    if not bq_check_table_exists(project=project, dataset=src_dataset, table_name=src_table_name, client=client):
        raise RuntimeError(f"Table not found: {src_table_id}")

    config = bigquery.CopyJobConfig()
    config.write_disposition = "WRITE_TRUNCATE" if overwrite else "WRITE_EMPTY"
    job = client.copy_table(source=src_table_id, destination=dest_table_id, job_config=config)
    job.result()


def bq_delete_table(
    project: str, dataset: str, table_name: str, not_found_ok=False, client: Optional[Client] = None
) -> None:
    """Deletes a table in bigquery

    :param project: The project that the table is stored in.
    :param dataset: The dataset that the table is stored in.
    :param table_name: The name of the table.
    :param client: The bigquery client. Created if not supplied.
    :param not_found_ok: If true, will not raise an error if the table is not found
    """
    if not client:
        client = Client(project=project)
    table = client.get_table(f"{project}.{dataset}.{table_name}")
    client.delete_table(table, not_found_ok=not_found_ok)


def bq_get_view_content(project: str, dataset: str, view_name: str, client: Optional[Client] = None) -> str:
    """Gets the content of a view

    Raises google.api_core.exceptions.NotFound if view does not exist
    Raises RuntimeError if the table exists but is not a view

    :param project: The project that the table is stored in.
    :param dataset: The dataset that the table is stored in.
    :param view_name: The name of the view.
    :param client: The bigquery client. Created if not supplied.
    :return: The content of the view
    """
    if not client:
        client = Client(project=project)
    view_id = f"{project}.{dataset}.{view_name}"
    view = client.get_table(view_id)  # Can raise NotFound if not exists.
    if view.view_query:
        return view.view_query
    else:
        raise RuntimeError(f"Provided table is not a view: {view_id}")


def bq_create_view(
    project: str, dataset: str, view_name: str, view_content: str, client: Optional[Client] = None
) -> None:
    """Creates a new view.

    Raises RuntimeError if already exists

    :param project: The project to store the table in.
    :param dataset: The dataset to store the table in.
    :param view_name: The name of the view.
    :param view_content: The content of the view.
    :param client: The bigquery client. Created if not supplied.
    """
    if not client:
        client = Client(project=project)
    view_id = f"{project}.{dataset}.{view_name}"
    if bq_check_table_exists(project=project, dataset=dataset, table_name=view_name, client=client):
        raise RuntimeError(f"Attempted to create view that already exists: {view_id}")

    table = Table(view_id)
    table.view_query = view_content
    client.create_table(table)
