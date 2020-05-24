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
    dockerPull: sagebionetworks/synapsepythonclient:v2.0.0

inputs:
  - id: queueid
    type: string
  - id: synapse_config
    type: File

arguments:
  - valueFrom: get_evaluation_id.py
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
      - entryname: get_evaluation_id.py
        entry: |
          #!/usr/bin/env python
          from collections import defaultdict
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
          queue_mapping_table = syn.tableQuery("select * from syn22077175")
          queue_mappingdf = queue_mapping_table.asDataFrame()
          mapping = defaultdict(list)
          for _, row in queue_mappingdf.iterrows():
            mapping[str(row['main'])].append(str(row['internal']))

          # mapping = {str(row['main']): str(row['internal'])
          #            for _, row in queue_mappingdf.iterrows()}
          submit_to = mapping.get(args.evaluation_id)
          if submit_to is None:
            raise ValueError("Evaluation Id not set")
          result = {'evaluation_id': submit_to}
          with open(args.results, 'w') as o:
            o.write(json.dumps(result))

outputs:
  - id: evaluation_id
    type: string[]
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['evaluation_id'])
  - id: results
    type: File
    outputBinding:
      glob: results.json