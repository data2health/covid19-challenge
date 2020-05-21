"""Run training synthetic docker models"""
from __future__ import print_function
import argparse
from functools import partial
import getpass
import os
import signal
import subprocess
import sys
import time

import docker
import synapseclient


def create_log_file(log_filename, log_text=None):
    """Create log file"""
    with open(log_filename, 'w') as log_file:
        if log_text is not None:
            if isinstance(log_text, bytes):
                log_text = log_text.decode('utf-8')
            log_file.write(log_text.encode("ascii", "ignore").decode("ascii"))
        else:
            log_file.write("No Logs")


def store_log_file(syn, log_filename, parentid, test=False):
    """Store log file"""
    statinfo = os.stat(log_filename)
    if statinfo.st_size > 0:
        ent = synapseclient.File(log_filename, parent=parentid)
        # Don't store if test
        if not test:
            try:
                syn.store(ent)
            except synapseclient.core.exceptions.SynapseHTTPError as err:
                print(err)


def remove_docker_container(container_name):
    """Remove docker container"""
    client = docker.from_env()
    try:
        cont = client.containers.get(container_name)
        cont.stop()
        cont.remove()
    except Exception:
        print("Unable to remove container")


def remove_docker_image(image_name):
    """Remove docker image"""
    client = docker.from_env()
    try:
        client.images.remove(image_name, force=True)
    except Exception:
        print("Unable to remove image")


def tar(directory, tar_filename):
    """Tar all files in a directory and remove the files

    Args:
        directory: Directory path to files to tar
        tar_filename:  Name of tar file
    """
    tar_command = ['tar', '-C', directory, '--remove-files', '.', '-cvzf',
                   tar_filename]
    subprocess.check_call(tar_command)


def main(syn, args):
    if args.status == "INVALID":
        raise Exception("Docker image is invalid")

    client = docker.from_env()

    print(getpass.getuser())

    #Add docker.config file
    docker_image = args.docker_repository + "@" + args.docker_digest

    #These are the volumes that you want to mount onto your docker container
    # directory = "/data/common/DREAM Challenge/data/submissions"
    scratch_dir = os.path.join(os.getcwd(), "scratch")
    model_dir = os.path.join(os.getcwd(), "model")
    input_dir = args.input_dir

    print("mounting volumes")
    # These are the locations on the docker that you want your mounted
    # volumes to be + permissions in docker (ro, rw)
    # It has to be in this format '/output:rw'
    mounted_volumes = {scratch_dir: '/scratch:rw',
                       input_dir: '/train:ro',
                       model_dir: '/model:rw'}
    #All mounted volumes here in a list
    all_volumes = [scratch_dir, input_dir, model_dir]
    #Mount volumes
    volumes = {}
    for vol in all_volumes:
        volumes[vol] = {'bind': mounted_volumes[vol].split(":")[0],
                        'mode': mounted_volumes[vol].split(":")[1]}

    #Look for if the container exists already, if so, reconnect
    print("checking for containers")
    container = None
    errors = None
    for cont in client.containers.list(all=True):
        if args.submissionid in cont.name:
            # Must remove container if the container wasn't killed properly
            if cont.status == "exited":
                cont.remove()
            else:
                container = cont
    # If the container doesn't exist, make sure to run the docker image
    if container is None:
        #Run as detached, logs will stream below
        print("running container")
        try:
            container = client.containers.run(docker_image,
                                              'bash /app/train.sh',
                                              detach=True, volumes=volumes,
                                              name=args.submissionid,
                                              network_disabled=True,
                                              mem_limit='10g', stderr=True)
        except docker.errors.APIError as err:
            remove_docker_container(args.submissionid)
            errors = str(err) + "\n"

    print("creating logfile")
    #Create the logfile
    log_filename = args.submissionid + "_training_log.txt"
    open(log_filename, 'w').close()

    # If the container doesn't exist, there are no logs to write out and
    # no container to remove
    if container is not None:
        # Check if container is still running
        while container in client.containers.list():
            log_text = container.logs()
            create_log_file(log_filename, log_text=log_text)
            store_log_file(syn, log_filename, args.parentid)
            time.sleep(60)
        # Must run again to make sure all the logs are captured
        log_text = container.logs()
        create_log_file(log_filename, log_text=log_text)
        store_log_file(syn, log_filename, args.parentid)
        # Remove container and image after being done
        container.remove()

    statinfo = os.stat(log_filename)

    if statinfo.st_size == 0:
        create_log_file(log_filename, log_text=errors)
        store_log_file(syn, log_filename, args.parentid)

    print("finished training")
    # Try to remove the image
    remove_docker_image(docker_image)

    list_model = os.listdir(model_dir)
    if not list_model:
    #    raise Exception("No model generated, please check training docker")
        model_fill = os.path.join(model_dir, "model_fill.txt")
        open(model_fill, 'w').close()
        log_text = "No training files generated"
        create_log_file(log_filename, log_text=log_text)
        store_log_file(syn, log_filename, args.parentid)

    tar(model_dir, 'model_files.tar.gz')

    list_scratch = os.listdir(scratch_dir)
    if not list_scratch:
        scratch_fill = os.path.join(scratch_dir, "scratch_fill.txt")
        open(scratch_fill, 'w').close()

    tar(scratch_dir, 'scratch_files.tar.gz')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--submissionid", required=True,
                        help="Submission Id")
    parser.add_argument("-p", "--docker_repository", required=True,
                        help="Docker Repository")
    parser.add_argument("-d", "--docker_digest", required=True,
                        help="Docker Digest")
    parser.add_argument("-i", "--input_dir", required=True,
                        help="Input Directory")
    parser.add_argument("-c", "--synapse_config", required=True,
                        help="credentials file")
    parser.add_argument("--parentid", required=True,
                        help="Parent Id of submitter directory")
    parser.add_argument("--status", required=True, help="Docker image status")
    args = parser.parse_args()
    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login()

    main(syn, args)
