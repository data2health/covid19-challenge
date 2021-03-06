#!/usr/bin/env cwl-runner
#
# Submit to different internal queues based on the main queue
# DEVELOP vs PROD
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.2.2

inputs:
  - id: queueid
    type: string
  - id: synapse_config
    type: File

arguments:
  - valueFrom: get_dataset.py
  - valueFrom: $(inputs.queueid)
    prefix: -e
  - valueFrom: results.json
    prefix: -r
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: get_dataset.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import json
          import os
          parser = argparse.ArgumentParser()
          parser.add_argument("-e", "--evaluation_id", required=True, help="Queue ID")
          parser.add_argument("-r", "--results", required=True, help="download results info")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")

          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()
          evaluation_id = args.evaluation_id
          dataset_mapping = syn.tableQuery(
              f"select * from syn22093564 where queue = '{evaluation_id}'"
          )
          dataset_mappingdf = dataset_mapping.asDataFrame()
          if dataset_mappingdf.empty:
            raise ValueError("Dataset Mapping is not set")
          if len(dataset_mappingdf) > 1:
            raise ValueError("Duplicated 'queue' not allowed")
          dataset_mappingdf = dataset_mappingdf.fillna('')
          dataset_info = dataset_mappingdf.to_dict('records')[0]
          dataset_info['submission_status'] = "EVALUATION_IN_PROGRESS"
          dataset_info['train_volume'] = f"{dataset_info['dataset_name']}_train_{dataset_info['train_dataset_version']}"
          dataset_info['infer_volume'] = f"{dataset_info['dataset_name']}_infer_{dataset_info['infer_dataset_version']}"
          with open(args.results, 'w') as o:
            o.write(json.dumps(dataset_info))

outputs:

  - id: site
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['site'])

  - id: train_volume
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['train_volume'])

  - id: infer_volume
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['infer_volume'])

  - id: train_runtime
    type: int
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['train_runtime'])

  - id: infer_runtime
    type: int
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['infer_runtime'])

  - id: goldstandard
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['goldstandard'])

  - id: question
    type: int
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['question'])

  - id: results
    type: File
    outputBinding:
      glob: results.json
