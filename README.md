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

Once these `docker volumes` are created, `infrastructure/get_site.cwl` must be changed to have the correct dataset names and version.

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
