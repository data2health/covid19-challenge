#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: score.R

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn18405992/scoring_harness

inputs:
  - id: inputfile
    type: File
  - id: goldstandard
    type: File
  - id: status
    type: string
  - id: submissionid
    type: int

arguments:
  - valueFrom: $(inputs.inputfile.path)
    prefix: -f
  - valueFrom: $(inputs.status)
    prefix: -s
  - valueFrom: $(inputs.goldstandard.path)
    prefix: -g
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement

outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json