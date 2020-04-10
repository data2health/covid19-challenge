#!/usr/bin/env cwl-runner
#
# Extract the submitted Docker repository and Docker digest
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

inputs:
  - id: submissionid
    type: int
  - id: docker_repository
    type: string
  - id: docker_digest
    type: string
  - id: parentid
    type: string
  - id: status
    type: string
  - id: synapse_config
    type: File
  - id: docker_registry
    type: string
  - id: docker_authentication
    type: string

arguments:
  - valueFrom: archive_docker.py
  - valueFrom: $(inputs.docker_repository)
    prefix: -p
  - valueFrom: $(inputs.docker_digest)
    prefix: -d
  - valueFrom: $(inputs.status)
    prefix: --status
  - valueFrom: $(inputs.submissionid)
    prefix: --submissionid
  - valueFrom: $(inputs.parentid)
    prefix: --parentid
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: .docker/config.json
        entry: |
          {"auths": {"$(inputs.docker_registry)": {"auth": "$(inputs.docker_authentication)"}}}
      - entryname: archive_docker.py
        entry: |
            """Run inference synthetic docker models"""
            import argparse
            import json

            import docker
            import synapseclient


            def main(args):
                # if args.status == "INVALID":
                #     raise Exception("Docker image is invalid")
                syn = synapseclient.Synapse(configPath=args.synapse_config)
                syn.login()

                client = docker.from_env()
                #Add docker.config file
                docker_image = args.docker_repository + "@" + args.docker_digest
                image = client.images.pull(docker_image)
                new_image_name = "docker.synapse.org/{}/{}".format(args.parentid,
                                                                   args.submissionid)
                image.tag(new_image_name)
                client.images.push(new_image_name)
                repos = list(syn.getChildren(args.parentid, includeTypes=['dockerrepo']))
                for repo in repos:
                    name = syn.get(repo['id']).repositoryName
                    if name == new_image_name:
                        entity_id = repo['id']
                        break
                
                results = {'archived_docker': entity_id}
                with open(args.results, 'w') as o:
                    o.write(json.dumps(results))

            if __name__ == '__main__':
                parser = argparse.ArgumentParser()
                parser.add_argument("-s", "--submissionid", required=True,
                                    help="Submission Id")
                parser.add_argument("-p", "--docker_repository", required=True,
                                    help="Docker Repository")
                parser.add_argument("-d", "--docker_digest", required=True,
                                    help="Docker Digest")
                parser.add_argument("-c", "--synapse_config", required=True,
                                    help="Synapse configuration")
                parser.add_argument("--parentid", required=True,
                                    help="Parent Id of submitter directory")
                parser.add_argument("--status", required=True, help="Docker image status")
                parser.add_argument("-r", "--results", required=True, help="result output")

                args = parser.parse_args()

                main(args)

outputs:

  - id: results
    type: File
    outputBinding:
      glob: results.json   

  - id: archived_docker
    type: string
    outputBinding:
      # This tool depends on the submission.json to be named submission.json
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['archived_docker'])
