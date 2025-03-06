#!/usr/bin/env bash

# Function to display usage
usage() {
    cat <<EOF
Usage: $(basename "$0") AUTH_PROJECT BIOMED_PROJECT [OPTIONS]

Creates a service account and gives it the necessary permissions to create tables in the given project.
Creates a keyfile (.keyfile.json by default) for accessing the service account.

Commands:
    AUTH_PROJECT                The name of the project that the user will invoke
    BIOMED_PROJECT              The name of the biomedical project that the tables will be written to

Options:
    -h, --help                  Show this message and exit
    --skip-ao                   Will skip interactions with the Academic Observatory project in setup
    --keyfile keyfile           The path to the keyfile to save
    --overwrite                 Whether to force overwriting the keyfile

Example:
    bash $(basename "$0") my-project biomed --skip-ao
EOF
    exit 1
}

# Check if the number of arguments is at least 2
if [ "$#" -le 1 ]; then
    usage
fi

# Assign arguments to variables
AUTH_PROJECT=$1
shift
BIOMED_PROJECT=$1
shift
SA_FULL_NAME="biomed@${AUTH_PROJECT}.iam.gserviceaccount.com"
SKIP_AO=false
KEYFILE=".keyfile.json"
OVERWRITE=false


# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        --skip-ao)
            SKIP_AO=true
            shift
            ;;
        --keyfile)
            KEYFILE=$2
            shift
            shift
            ;;
        --overwrite)
            OVERWRITE=true
            shift
            ;;
        *)
            break  # Stop parsing options
            ;;
    esac
done
echo "Service account name: $SA_FULL_NAME"
echo "Institution Biomed project: $BIOMED_PROJECT"

# Check if the user is logged in
if gcloud auth list --filter="status:ACTIVE" --format="value(account)" | grep -q '@'; then
    :
else
    echo "No active user logged in. Please log in first."
    exit 1  # Exit the script if no user is logged in
fi

# Create service account if it doesn't exist
if [[ -z $(gcloud iam service-accounts list --filter="email:${SA_FULL_NAME}" --format="value(email)") ]]; then
    gcloud iam service-accounts create biomed --project=${BIOMED_PROJECT} \
        --description="Service account for Biomed workflows" \
        --display-name="biomed" || exit 1
    echo "Service account ${SA_FULL_NAME} created"
else
    echo "Service account ${SA_FULL_NAME} already exists. Will not recreate."
fi


# Key creation if not exists
if [[ -f "${KEYFILE}" && "$OVERWRITE" == "false" ]]; then
    echo "A key (${KEYFILE}) already exists for ${SA_FULL_NAME}. Skipping key creation. To create a new key, delete the old one manually or run with --overwrite."
else
    gcloud iam service-accounts keys create $KEYFILE --iam-account=${SA_FULL_NAME} || exit 1
    echo "Key file created: $KEYFILE"
fi


# Create the Biomed Workflow Role. A custom role is created so that we don't provide more permissions than necessary.
permissions="bigquery.datasets.create,bigquery.jobs.create,bigquery.tables.create,bigquery.tables.createSnapshot,bigquery.tables.delete,bigquery.tables.deleteSnapshot,bigquery.tables.get,bigquery.tables.getData,bigquery.tables.list,bigquery.tables.update,bigquery.tables.updateData"
output=$(gcloud iam roles list --project=${BIOMED_PROJECT} --filter="name:BiomedWorkflow" 2>&1)
if [[ $output == *"Listed 0 items"* ]]; then
    echo "BiomedWorkflow role doesn't exist for project '${BIOMED_PROJECT}'. Creating role."
    gcloud iam roles create BiomedWorkflow --project=$BIOMED_PROJECT \
        --title="Biomed Workflow Role" \
        --description="Gives necessary permissions to run the Biomed workflow" \
        --permissions=$permissions || exit 1
else
    echo "BiomedWorkflow for project '${BIOMED_PROJECT}' already exists. running update."
    gcloud iam roles update BiomedWorkflow --project=$BIOMED_PROJECT \
        --title="Biomed Workflow Role" \
        --description="Gives necessary permissions to run the Biomed workflow" \
        --permissions=$permissions || exit 1
fi

# Add Role to our service account
gcloud projects add-iam-policy-binding $BIOMED_PROJECT \
    --member=serviceAccount:$SA_FULL_NAME \
    --role=projects/$BIOMED_PROJECT/roles/BiomedWorkflow || exit 1

if [[ "$SKIP_AO" == "false" ]]; then
    # Create the Biomed Workflow Role to access the academic observatory data
    permissions="bigquery.jobs.create,bigquery.tables.get,bigquery.tables.getData,bigquery.tables.list"
    output=$(gcloud iam roles list --project=academic-observatory --filter="name:BiomedWorkflow" 2>&1)
    if [[ $output == *"Listed 0 items"* ]]; then
        echo "BiomedWorkflow role doesn't exist for project 'academic-observatory' Creating role."
        gcloud iam roles create BiomedWorkflow --project=academic-observatory \
            --title="Biomed Workflow Role" \
            --description="Gives necessary permissions to run the Biomed workflow" \
            --permissions=$permission || exit 1
    else
        echo "BiomedWorkflow role for project 'academic-observatory' already exists. running update."
        gcloud iam roles update BiomedWorkflow --project=academic-observatory \
            --title="Biomed Workflow Role" \
            --description="Gives necessary permissions to run the Biomed workflow" \
            --permissions=$permissions || exit 1
    fi

    # Add academic-observatory biomed Role to our service account
    gcloud projects add-iam-policy-binding academic-observatory \
        --member=serviceAccount:$SA_FULL_NAME \
        --role=projects/academic-observatory/roles/BiomedWorkflow || exit 1
else
    echo "Not configuring Academic Observatory as --skip-ao flag used"
fi
