#!/usr/bin/env bash

# Function to display usage
usage() {
    echo "Creates a service account and gives it the necessary permissions to create tables in the given project. Creates a .keyfile.json"
    echo "Usage: $0 MY_PROJECT BIOMED_PROJECT"
    exit 1
}

# Check if the number of arguments is exactly 2
if [ "$#" -ne 2 ]; then
    usage
fi

# Assign arguments to variables
my_project=$1
biomed_project=$2
sa_name="biomed"
sa_full_name="${sa_name}@${my_project}.iam.gserviceaccount.com"
keyfile=".keyfile.json"
echo "Institution Biomed project: $my_project"
echo "Service account name: $sa_full_name"

# Check if the user is logged in
if gcloud auth list --filter="status:ACTIVE" --format="value(account)" | grep -q '@'; then
    :
else
    echo "No active user logged in. Please log in first."
    exit 1  # Exit the script if no user is logged in
fi

# Create service account if it doesn't exist
if [[ -z $(gcloud iam service-accounts list --filter="email:${sa_full_name}" --format="value(email)") ]]; then
    gcloud iam service-accounts create biomed --project=${biomed_project} \
        --description="Service account for Biomed workflows" \
        --display-name="biomed"
    echo "Service account ${sa_full_name} created"
else
    echo "Service account ${sa_full_name} already exists. Will not recreate."
fi


# Key creation if not exists
if [ -f "${keyfile}" ]; then
    echo "A key (${keyfile}) already exists for ${sa_full_name}. Skipping key creation. To create a new key, delete the old one manually."
else
    gcloud iam service-accounts keys create $keyfile --iam-account=${sa_full_name}
    echo "Key file created: $keyfile"
fi


# Create the Biomed Workflow Role. A custom role is created so that we don't provide more permissions than necessary.
permissions="bigquery.datasets.create,bigquery.jobs.create,bigquery.tables.create,bigquery.tables.createSnapshot,bigquery.tables.delete,bigquery.tables.deleteSnapshot,bigquery.tables.get,bigquery.tables.getData,bigquery.tables.list,bigquery.tables.update,bigquery.tables.updateData"
output=$(gcloud iam roles list --project=${biomed_project} --filter="name:BiomedWorkflow" 2>&1)
if [[ $output == *"Listed 0 items"* ]]; then
    echo "BiomedWorkflow role doesn't exist for project '${biomed_project}'. Creating role."
    gcloud iam roles create BiomedWorkflow --project=$biomed_project \
        --title="Biomed Workflow Role" \
        --description="Gives necessary permissions to run the Biomed workflow" \
        --permissions=$permissions
else
    echo "BiomedWorkflow for project '${biomed_project}' already exists. running update."
    gcloud iam roles update BiomedWorkflow --project=$biomed_project \
        --title="Biomed Workflow Role" \
        --description="Gives necessary permissions to run the Biomed workflow" \
        --permissions=$permissions
fi

# Add Role to our service account
gcloud projects add-iam-policy-binding $biomed_project \
    --member=serviceAccount:$sa_full_name \
    --role=projects/$biomed_project/roles/BiomedWorkflow \

    # Create the Biomed Workflow Role to access the academic observatory data
permissions="bigquery.jobs.create,bigquery.tables.get,bigquery.tables.getData,bigquery.tables.list"
output=$(gcloud iam roles list --project=academic-observatory --filter="name:BiomedWorkflow" 2>&1)
if [[ $output == *"Listed 0 items"* ]]; then
    echo "BiomedWorkflow role doesn't exist for project 'academic-observatory' Creating role."
    gcloud iam roles create BiomedWorkflow --project=academic-observatory \
        --title="Biomed Workflow Role" \
        --description="Gives necessary permissions to run the Biomed workflow" \
        --permissions=$permissions
else
    echo "BiomedWorkflow role for project 'academic-observatory' already exists. running update."
    gcloud iam roles update BiomedWorkflow --project=academic-observatory \
        --title="Biomed Workflow Role" \
        --description="Gives necessary permissions to run the Biomed workflow" \
        --permissions=$permissions
fi

# Add academic-observatory biomed Role to our service account
gcloud projects add-iam-policy-binding academic-observatory \
    --member=serviceAccount:$sa_full_name \
    --role=projects/academic-observatory/roles/BiomedWorkflow \

