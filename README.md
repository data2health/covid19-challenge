# COVID-19 DREAM Challenge

## Creating Datasets

TODO: Add information about how to create docker volumes linking to local data.

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
```

Please follow the instructions printed out from `add_challenge.py`.  An example would be:

```
ACTION ITEM-Add to NCAT's docker-compose .env
{'9614502': 'syn21897228', '9614503': 'syn21897227'}
ACTION ITEM-Add to UW's docker-compose .env
{'9614504': 'syn21897230', '9614505': 'syn21897229'}
ACTION ITEM-Update table syn22093564 with dataset version/name
ACTION ITEM-Revise https://www.synapse.org/#!Synapse:syn21849256/wiki/603349
ACTION ITEM-Revise https://www.synapse.org/#!Synapse:syn21849256/wiki/603350
```
