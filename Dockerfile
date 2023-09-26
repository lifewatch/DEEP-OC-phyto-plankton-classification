# Dockerfile may have two Arguments: tag, branch
# tag - tag for the Base image, (e.g. 1.10.0-py3 for tensorflow)
# branch - user repository branch to clone (default: master, other option: test)

ARG tag=1.14.0-py3

# Base image, e.g. tensorflow/tensorflow:1.12.0-py3
FROM tensorflow/tensorflow:${tag}

# Add container's metadata to appear along the models metadata
ENV CONTAINER_MAINTAINER "Wout Decrop <wout.decrop@vliz.be>"
ENV CONTAINER_VERSION "0.1"
ENV CONTAINER_DESCRIPTION "DEEP as a Service Container: phyt-plankton Classification"

# What user branch to clone (!)
ARG branch=vliz

# Install ubuntu updates and python related stuff
# link python3 to python, pip3 to pip, if needed
ENV DEBIAN_FRONTEND=noninteractive
# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
         git \
         curl \
         wget \
         psmisc \
         python3-setuptools \
         python3-pip \
         python3-wheel \
         libgl1 \
         libsm6 \
         libxrender1 \
         libfontconfig1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /root/.cache/pip/* \
    && rm -rf /tmp/*

# Install OpenCV-Python (replace version with the one you want)
RUN pip3 install --upgrade pip setuptools wheel \
    && pip3 install opencv-python==3.4.17.61


# # Needed for open-cv
# RUN apt-get update && \
#     apt-get install -y libgl1 libsm6 libxrender1 libfontconfig1 && \
#     apt-get install -y python3-opencv


# Set LANG environment
ENV LANG C.UTF-8

# Set the working directory
WORKDIR /srv

# Install rclone
RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.deb && \
    dpkg -i rclone-current-linux-amd64.deb && \
    apt install -f && \
    mkdir /srv/.rclone/ && touch /srv/.rclone/rclone.conf && \
    rm rclone-current-linux-amd64.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Onedata is currently not supported @2023
## Install oneclient for ONEDATA
#RUN curl -sS  http://get.onedata.org/oneclient-1902.sh | bash -s -- oneclient="$oneclient_ver" && \
#    apt-get clean && \
#    mkdir -p /mnt/onedata && \
#    rm -rf /var/lib/apt/lists/* && \
#    rm -rf /tmp/*

# Install deep-start script
# N.B.: This repository also contains run_jupyter.sh
RUN git clone https://github.com/deephdc/deep-start /srv/.deep-start && \
    ln -s /srv/.deep-start/deep-start.sh /usr/local/bin/deep-start

# Install FLAAT (FLAsk support for handling Access Tokens)
RUN pip install --no-cache-dir flaat && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Disable FLAAT authentication by default
ENV DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER yes

# Install DEEPaaS from PyPi:
RUN pip install --no-cache-dir deepaas && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Useful tool to debug extensions loading
RUN pip install --no-cache-dir entry_point_inspector && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Install user app:
RUN git clone -b $branch https://github.com/woutdecrop/phyto-plankton-classification && \
    cd  phyto-plankton-classification && \
    pip3 install --no-cache-dir -e . && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    cd ..

# Download network weights
# ENV SWIFT_CONTAINER https://api.cloud.ifca.es:8080/swift/v1/imagenet-tf/
# ENV MODEL_TAR default_imagenet.tar.xz

# RUN curl --insecure -o ./image-classification-tf/models/${MODEL_TAR} \
#     ${SWIFT_CONTAINER}${MODEL_TAR}

# RUN cd image-classification-tf/models && \
#         tar -xf ${MODEL_TAR}

# Open DEEPaaS port
EXPOSE 5000

# Open Monitoring port
EXPOSE 6006

# Open JupyterLab port
EXPOSE 8888

# Account for OpenWisk functionality (deepaas >=0.4.0) + proper docker stop
# OpenWhisk support is deprecated
CMD ["deepaas-run", "--listen-ip", "0.0.0.0", "--listen-port", "5000"]
