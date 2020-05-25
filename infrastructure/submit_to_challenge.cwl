#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: [ python3, submit.py ]

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.0.0

inputs:
  - id: submission_file
    type: string
    inputBinding:
      prefix: -s
      position: 1

  - id: submissionid
    type: int
    inputBinding:
      prefix: -i
      position: 2

  - id: synapse_config
    type: File
    inputBinding:
      prefix: -c
      position: 0

  - id: evaluationid
    type: string[]
    inputBinding:
      prefix: -e
      itemSeparator: " "
      position: 3

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: submit.py
        entry: |
          #!/usr/bin/env python
          import argparse
          import json

          import synapseclient

          parser = argparse.ArgumentParser()
          parser.add_argument("-s", "--submission", required=True, help="Submission status")
          parser.add_argument("-i", "--submissionid", required=True, help="Submission ID")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          parser.add_argument("-e", "--evaluationid", required=True, nargs="+", help="Internal evaluation ids")
          args = parser.parse_args()

          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()
          for queueid in args.evaluationid:
            syn.submit(evaluation=queueid, entity=args.submission, name=args.submissionid)

outputs: []
