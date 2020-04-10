#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.0.0

inputs:
  - id: status
    type: string
  - id: entityid
    type: string
  - id: submissionid
    type: int
  - id: synapse_config
    type: File
  - id: evaluationid
    type: string
  - id: previous_annotation_finished
    type: boolean?
  - id: previous_email_finished
    type: boolean?

arguments:
  - valueFrom: submit.py
  - valueFrom: $(inputs.status)
    prefix: -s
  - valueFrom: $(inputs.entityid)
    prefix: -i
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.evaluationid)
    prefix: -e
  - valueFrom: $(inputs.submissionid)
    prefix: --submission
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: submit.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import json

          parser = argparse.ArgumentParser()
          parser.add_argument("-s", "--status", required=True, help="Submission status")
          parser.add_argument("-r", "--results", required=True, help="Scoring results")
          parser.add_argument("-i", "--entityid", required=True, help="Submission ID")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          parser.add_argument("-e", "--evaluationid", required=True, help="Internal evaluation id")
          parser.add_argument("--submissionid", required=True, help="Submission id")

          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()
          if args.status.startswith("VALID"):
            submission_status = {"submission_status": "EVALUATION_IN_PROGRESS"}
            syn.submit(evaluation=args.evaluationid,
                       entity=args.entityid, name=args.submissionid)
          else:
            submission_status = {"submission_status": "INVALID"}
          with open(args.results, 'w') as status_file:
            status_file.write(json.dumps(submission_status))

outputs:
  - id: json_out
    type: File
    outputBinding:
      glob: results.json