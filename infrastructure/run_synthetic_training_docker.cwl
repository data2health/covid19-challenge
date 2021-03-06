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
  - id: previous
    type: boolean?
  - id: synapse_config
    type: File
  - id: input_dir
    type: string
  - id: docker_script
    type: File
  - id: training
    type: boolean
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
  - valueFrom: $(inputs.training)
    prefix: --training
  - valueFrom: $(inputs.parentid)
    prefix: --parentid
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.input_dir)
    prefix: -i
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

  model:
    type: File
    outputBinding:
      glob: model_files.tar.gz

  # scratch:
  #   type: File
  #   outputBinding:
  #     glob: scratch_files.tar.gz
