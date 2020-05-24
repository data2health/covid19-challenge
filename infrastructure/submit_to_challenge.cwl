#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: synapse

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.0.0

inputs:
  - id: submission_file
    type: File
  - id: submissionid
    type: int
  - id: synapse_config
    type: File
  - id: parentid
    type: string
  - id: evaluationid
    type: string

arguments:
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: submit
  - valueFrom: $(inputs.evaluationid)
    prefix: --evalID
  - valueFrom: $(inputs.parentid)
    prefix: --parentId
  - valueFrom: $(inputs.submission_file.path)
    prefix: -f
  - valueFrom: $(inputs.submissionid)
    prefix: --name

requirements:
  - class: InlineJavascriptRequirement


outputs: []