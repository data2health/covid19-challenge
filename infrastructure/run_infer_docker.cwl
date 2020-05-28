#!/usr/bin/env cwl-runner
#
# Run Docker Submission
#
cwlVersion: v1.1
class: CommandLineTool
baseCommand: python

inputs:
  - id: submissionid
    type: int
  - id: docker_repository
    type: string
  - id: docker_digest
    type: string
  - id: docker_registry
    type: string
  - id: docker_authentication
    type: string
  - id: parentid
    type: string
  - id: synapse_config
    type: File
  - id: input_dir
    type: string
  - id: stage
    type: string
  - id: model
    type: File
  - id: scratch
    type: File
  - id: docker_script
    type: File
  - id: quota
    type: int

arguments: 
  - valueFrom: $(inputs.docker_script.path)
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.docker_repository)
    prefix: -p
  - valueFrom: $(inputs.docker_digest)
    prefix: -d
  - valueFrom: $(inputs.parentid)
    prefix: --parentid
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.input_dir)
    prefix: -i
  - valueFrom: $(inputs.stage)
    prefix: --stage
  - valueFrom: $(inputs.model.path)
    prefix: -m
  - valueFrom: $(inputs.scratch.path)
    prefix: -f
  - valueFrom: $(inputs.quota)
    prefix: -q

requirements:
  - class: InitialWorkDirRequirement
    listing:
      - $(inputs.docker_script)
      - entryname: .docker/config.json
        entry: |
          {"auths": {"$(inputs.docker_registry)": {"auth": "$(inputs.docker_authentication)"}}}
  - class: InlineJavascriptRequirement
  # - class: ToolTimeLimit
  #   timelimit: 1200

outputs:
  predictions:
    type: File
    outputBinding:
      glob: output/predictions.csv
