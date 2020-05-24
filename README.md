# COVID-19 DREAM Challenge

## Creating Datasets

Datasets must be put in `docker volumes` and must be named.

```
{site}_{data_model}_covid_q{number}_train_{train_dataset_version}
{site}_{data_model}_covid_q{number}_infer_{infer_dataset_version}
# Examples
uw_omop_covid_q1_train_05-06-2020
uw_omop_covid_q1_infer_05-06-2020
```

Here is how you create a docker volume.

```
docker volume create --driver local --opt type=none --opt device=/path/to/training/data --opt o=bind uw_omop_covid_q1_train_05-06-2020
docker volume create --driver local --opt type=none --opt device=/path/to/infer/data --opt o=bind uw_omop_covid_q1_infer_05-06-2020
```

Once these `docker volumes` are created, this the [Dataset Mapping](https://www.synapse.org/#!Synapse:syn22093564) Synapse Table must be changed to have the correct dataset names and version.

## Adding Challenge Questions
Please run `scripts/add_challenge.py`. An example would be

```
# This will add the main submission queues + internal queues
python add_challenge.py 2 --sites UW
```

Please follow the instructions printed out from `add_challenge.py`.  An example would be:

```
Add to NCAT's docker-compose .env
{'9614502': 'syn22076995', '9614503': 'syn22076996'}
Add to UW's docker-compose .env
{'9614504': 'syn22076997', '9614505': 'syn22076998'}
Make sure you run
git add infrastructure/2_workflow.cwl
git add infrastructure/2_internal_workflow.cwl
```

## Setting up SynpaseWorkflowOrchestrator

Follow instructions [here](https://github.com/Sage-Bionetworks/SynapseWorkflowOrchestrator) to configure and run the orchestrator.

Each site also needs their own synapse log folder (e.g. UW Submission Logs) due to permissions issue. The EHR Synapse service account creates folders per participant and when a site admin tries to create that same folder, it will fail.  The folder's Synapse id will be the `WORKFLOW_OUTPUT_ROOT_ENTITY_ID` value.


### Can't use docker-compose?

If you are a site that can't use `docker-compose`, Here is a series of shell commands you must run to run this infrastructure
```
export DOCKER_ENGINE_URL=unix:///var/run/docker.sock
export SYNAPSE_USERNAME=username
export SYNAPSE_PASSWORD=password
export WORKFLOW_OUTPUT_ROOT_ENTITY_ID=synapseid
export TOIL_CLI_OPTIONS="--defaultMemory 150G --retryCount 0 --defaultDisk 100G --defaultCores 12.0"
export EVALUATION_TEMPLATES='{"queueid":"synapseid"}'
export MAX_CONCURRENT_WORKFLOWS=5
export SUBMITTER_NOTIFICATION_MASK=28
export COMPOSE_PROJECT_NAME=covid_challenge_project
export RUN_WORKFLOW_CONTAINER_IN_PRIVILEGED_MODE=true

docker volume create ${COMPOSE_PROJECT_NAME}_shared
docker run -d --name covid_production_pipeline -v ${COMPOSE_PROJECT_NAME}_shared:/shared:rw -v /var/run/docker.sock:/var/run/docker.sock:rw \
-e DOCKER_ENGINE_URL=${DOCKER_ENGINE_URL} \
-e SYNAPSE_USERNAME=${SYNAPSE_USERNAME} \
-e SYNAPSE_PASSWORD=${SYNAPSE_PASSWORD} \
-e WORKFLOW_OUTPUT_ROOT_ENTITY_ID=${WORKFLOW_OUTPUT_ROOT_ENTITY_ID} \
-e EVALUATION_TEMPLATES=${EVALUATION_TEMPLATES} \
-e NOTIFICATION_PRINCIPAL_ID=${NOTIFICATION_PRINCIPAL_ID} \
-e SHARE_RESULTS_IMMEDIATELY=${SHARE_RESULTS_IMMEDIATELY} \
-e DATA_UNLOCK_SYNAPSE_PRINCIPAL_ID=${DATA_UNLOCK_SYNAPSE_PRINCIPAL_ID} \
-e TOIL_CLI_OPTIONS="${TOIL_CLI_OPTIONS}" \
-e MAX_CONCURRENT_WORKFLOWS=${MAX_CONCURRENT_WORKFLOWS} \
-e SUBMITTER_NOTIFICATION_MASK=${SUBMITTER_NOTIFICATION_MASK} \
-e COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME} \
-e RUN_WORKFLOW_CONTAINER_IN_PRIVILEGED_MODE=${RUN_WORKFLOW_CONTAINER_IN_PRIVILEGED_MODE} \
--privileged \
sagebionetworks/synapseworkfloworchestrator:1.1
```

### Can't use Docker?

Use the `WES` implementation + singularity.