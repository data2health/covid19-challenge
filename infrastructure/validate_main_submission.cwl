#!/usr/bin/env cwl-runner
#
# Validates Main JSON submission
# {
#   "docker": "docker.synapse.org/my-image@sha....",
#   "description": "My awesome model does X and Y",
#   "ranked_features": [
#     "age",
#     "gender"
#   ],
#   "references": [
#     "https://github.com/me/my-project",
#   ]
# }
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.0.0

inputs:
  - id: submission
    type: File?
  - id: synapse_config
    type: File

arguments:
  - valueFrom: validate_main_submission.py
  - valueFrom: $(inputs.submission)
    prefix: -s
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: validate_main_submission.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import os
          import json
          import base64
          import requests
          parser = argparse.ArgumentParser()
          parser.add_argument("-s", "--submission", help="Submission File")
          parser.add_argument("-r", "--results", required=True, help="validation results")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          args = parser.parse_args()

          def get_bearer_token_url(docker_request_url, user, password):
            initial_request = requests.get(docker_request_url)
            auth_headers = initial_request.headers['Www-Authenticate'].replace('"','').split(",")
            for head in auth_headers:
              if head.startswith("Bearer realm="):
                bearer_realm = head.split('Bearer realm=')[1]
              elif head.startswith('service='):
                service = head.split('service=')[1]
              elif head.startswith('scope='):
                scope = head.split('scope=')[1]
            return("{0}?service={1}&scope={2}".format(bearer_realm,service,scope))

          def get_auth_token(docker_request_url, user, password):
            bearer_token_url = get_bearer_token_url(docker_request_url, user, password)
            auth_string = user + ":" + password 
            auth = base64.b64encode(auth_string.encode()).decode()
            bearer_token_request = requests.get(bearer_token_url,
              headers={'Authorization': 'Basic %s' % auth})
            return(bearer_token_request.json()['token'])

          invalid_reasons = []
          docker_list = ['', '']
          # Submission must be a Docker image, not Project/Folder/File
          try:
            with open(args.submission, 'r') as sub_file:
              sub_content = json.load(sub_file)
          except Exception:
            invalid_reasons.append("Must submit a json file")
          
          if not invalid_reasons:
            required_keys = set(['docker', 'description', 'ranked_features', 'references'])
            if not required_keys.issubset(sub_content.keys()):
              invalid_reasons.append("Your submission must contain keys 'docker', 'description', 'ranked_features', and 'references'")
            else:
              #Must read in credentials (username and password)
              config = synapseclient.Synapse().getConfigFile(configPath=args.synapse_config)
              authen = dict(config.items("authentication"))
              if authen.get("username") is None and authen.get("password") is None:
                raise Exception('Config file must have username and password')
              
              if sub_content['description'] == '':
                invalid_reasons.append("Your must include a description in your submission")

              if not isinstance(sub_content['ranked_features'], list) or not sub_content['ranked_features']:
                invalid_reasons.append("Your must include ranked_features in your submission as a list")

              if not isinstance(sub_content['references'], list) or not sub_content['references']:
                invalid_reasons.append("Your must include references in your submission as a list")

              docker = sub_content['docker']
              docker_list = docker.split("@")
              if len(docker_list) == 1:
                invalid_reasons.append("Your docker submission must be accompanied by a sha digest. docker.synapse.org/...@sha....")
              else:
                docker_repo = docker_list[0].replace("docker.synapse.org/","")
                docker_digest = docker_list[1]
                index_endpoint = 'https://docker.synapse.org'

                #Check if docker is able to be pulled
                docker_request_url = '{0}/v2/{1}/manifests/{2}'.format(index_endpoint, docker_repo, docker_digest)
                token = get_auth_token(docker_request_url, authen['username'], authen['password'])

                resp = requests.get(docker_request_url, headers={'Authorization': 'Bearer %s' % token})
                if resp.status_code != 200:
                  invalid_reasons.append("Your docker image + sha digest must exist and be shared with `COVID-19 DREAM Challenge Admin` Synapse Team.  You submitted {}.".format(docker))
                else:
                  #Must check docker image size
                  #Synapse docker registry
                  docker_size = sum([layer['size'] for layer in resp.json()['layers']])
                  if docker_size/1000000000.0 >= 1000:
                    invalid_reasons.append("Docker container must be less than a teribyte")
              
          status = "INVALID" if invalid_reasons else "VALID"
          result = {'submission_errors': "\n".join(invalid_reasons),
                    'submission_status': status,
                    'docker_repository': docker_list[0],
                    'docker_digest': docker_list[1]}
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

  - id: docker_repository
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['docker_repository'])

  - id: docker_digest
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['docker_digest'])