#!/usr/bin/env cwl-runner
#
# Example validate submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.0.0

inputs:

  - id: entity_type
    type: string
  - id: inputfile
    type: File?
  - id: submissionid
    type: int
  - id: parentid
    type: string
  - id: synapse_config
    type: File
  - id: goldstandard
    type: File

arguments:
  - valueFrom: validate.py
  - valueFrom: $(inputs.inputfile)
    prefix: -s
  - valueFrom: results.json
    prefix: -r
  - valueFrom: $(inputs.entity_type)
    prefix: -e
  - valueFrom: $(inputs.submissionid)
    prefix: -i
  - valueFrom: $(inputs.parentid)
    prefix: -p
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.goldstandard.path)
    prefix: -g

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: validate.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import os
          import json
          import pandas as pd

          parser = argparse.ArgumentParser()
          parser.add_argument("-r", "--results", required=True, help="validation results")
          parser.add_argument("-e", "--entity_type", required=True, help="synapse entity type downloaded")
          parser.add_argument("-s", "--submission_file", help="Submission File")
          parser.add_argument("-i", "--submissionid", help="Submission ID")
          parser.add_argument("-p", "--parentid", help="Parent ID")
          parser.add_argument("-c", "--synapse_config", help="Parent ID")
          parser.add_argument("-g", "--goldstandard", required=True, help="Goldstandard for scoring")

          args = parser.parse_args()

          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()

          #Create the logfile
          log_text = "empty"
          if args.submission_file is None:
              prediction_file_status = "INVALID"
              invalid_reasons = ['Please submit a file to the challenge']
          else:
              subdf = pd.read_csv(args.submission_file)
              invalid_reasons = []
              prediction_file_status = "VALIDATED"

              if subdf.get("score") is None:
                invalid_reasons.append("Submission must have 'score' column")
                prediction_file_status = "INVALID"
              else:
                try:
                  subdf['score'] = subdf['score'].astype(float)
                except ValueError:
                  invalid_reasons.append("Submission 'score' must contain values between 0 and 1")
                  prediction_file_status = "INVALID"
                if subdf['score'].isnull().any():
                  invalid_reasons.append("Submission 'score' must not contain any NA or blank values")
                  prediction_file_status = "INVALID"
                if not all([score >= 0 and score <= 1 for score in subdf['score']]):
                  invalid_reasons.append("Submission 'score' must contain values between 0 and 1")
                  prediction_file_status = "INVALID"
              
              if subdf.get("person_id") is None:
                invalid_reasons.append("Submission must have 'person_id' column")
                prediction_file_status = "INVALID"
              else:
                goldstandard = pd.read_csv(args.goldstandard)
                if not goldstandard['person_id'].isin(subdf['person_id']).all():
                  invalid_reasons.append("Submission 'person_id' does not have scores for all goldstandard patients.")
                  prediction_file_status = "INVALID"
                if subdf['person_id'].duplicated().any():
                  invalid_reasons.append("Submission has duplicated 'person_id' values.")
                  prediction_file_status = "INVALID"

          if prediction_file_status == "INVALID":
            submission_status = "INVALID"
          else:
            submission_status = "SCORING"
            
          result = {'submission_errors': "\n".join(invalid_reasons),
                    'submission_status': submission_status,
                    'round': 1}
          with open(args.results, 'w') as o:
              o.write(json.dumps(result))
     
outputs:

  - id: results
    type: File
    outputBinding:
      glob: results.json   

  - id: status
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submission_status'])

  - id: invalid_reasons
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['submission_errors'])
