#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: score.R

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn21849256/covid-scoring:v2

inputs:
  - id: inputfile
    type: File
  - id: goldstandard
    type: File
  - id: question
    type: int
  - id: submissionid
    type: int
  - id: previous
    type: boolean

arguments:
  - valueFrom: $(inputs.inputfile.path)
    prefix: -f
  - valueFrom: $(inputs.question)
    prefix: -q
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