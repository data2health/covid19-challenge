# COVID-19 DREAM Challenge

## Updating Datasets
Datasets must be put in `docker volumes` and must be named

```
{train_dataset_name}_{train_dataset_version}
{infer_dataset_name}_{infer_dataset_version}
```

Once these `docker volumes` are created, please edit `infrastructure/get_site.cwl` to have the correct dataset names and version.

## Adding Challenge Questions
Please run `scripts/add_challenge.py`. An example would be

```
# This will add the main submission queues + internal queues
python add_challenge.py 2 --sites UW
# This will only add the internal queues
python add_challenge.py 2 --sites UW --only_internal
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
