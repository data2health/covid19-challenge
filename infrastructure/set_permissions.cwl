#!/usr/bin/env cwl-runner
#
# Set permissions
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: challengeutils

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/challengeutils:develop

inputs:
  - id: entityid
    type: string
  - id: principalid
    type: string
  - id: permissions
    type: string
  - id: synapse_config
    type: File

arguments:
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: setentityacl
  - valueFrom: $(inputs.entityid)
  - valueFrom: $(inputs.principalid)
  - valueFrom: $(inputs.permissions)

outputs: []
