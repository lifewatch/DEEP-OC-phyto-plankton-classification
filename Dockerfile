# Dockerfile may have two Arguments: tag, branch
# tag - tag for the Base image, (e.g. 1.10.0-py3 for tensorflow)
# branch - user repository branch to clone (default: master, other option: test)

ARG tag=1.14.0-py3

# Base image, e.g. tensorflow/tensorflow:1.12.0-py3
FROM tensorflow/tensorflow:${tag}

# Add container's metadata to appear along the models metadata
ENV CONTAINER_MAINTAINER "Wout Decrop <wout.decrop@vliz.be>"
ENV CONTAINER_VERSION "0.1"
ENV CONTAINER_DESCRIPTION "DEEP as a Service Container: phyto-plankton Classification"

# What user branch to clone (!)
ARG branch=master

# Install ubuntu updates and python related stuff
# link python3 to python, pip3 to pip, if needed
ENV DEBIAN_FRONTEND=noninteractive

# Attempt to remove the file, and continue even if it fails (|| true)
RUN rm /etc/apt/sources.list.d/cuda.list || true
RUN rm /etc/apt/sources.list.d/nvidia-ml.list || true
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
    && rm -rf /tmp/*e/pip/* \
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

# Install deep-start script
# * allows to run shorter command "deep-start"
# * allows to install jupyterlab or code-server (vscode),
#   if requested during container creation
RUN git clone https://github.com/deephdc/deep-start /srv/.deep-start && \
    ln -s /srv/.deep-start/deep-start.sh /usr/local/bin/deep-start

# Install FLAAT (FLAsk support for handling Access Tokens)
RUN pip install --no-cache-dir flaat && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*


# # Install FLAAT (FLAsk support for handling Access Tokens)
# RUN pip install --no-cache-dir flaat && \
#     rm -rf /root/.cache/pip/* && \
#     rm -rf /tmp/*

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

# Necessary for the Jupyter Lab terminal, if requested
ENV SHELL /bin/bash

# Install user app:
RUN git clone -b $branch --depth 1 https://github.com/lifewatch/phyto-plankton-classification && \
    cd  phyto-plankton-classification && \
    pip3 install --no-cache-dir -e . && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    cd ..

# Download network weights
ENV SWIFT_CONTAINER https://api.cloud.ifca.es:8080/swift/v1/phytoplankton-tf/
ENV MODEL_TAR phytoplankton.tar.xz

RUN curl --insecure -o ./phyto-plankton-classification/models/${MODEL_TAR} \
    ${SWIFT_CONTAINER}${MODEL_TAR}

RUN cd phyto-plankton-classification/models && \
    tar -xf ${MODEL_TAR} &&\
    rm ${MODEL_TAR}

ENV SWIFT_CONTAINER https://share.services.ai4os.eu/index.php/s/GcJ3HPfWqNRoazj/download/final_model_big.h5
ENV MODEL_TAR final_model_big.h5

RUN mkdir -p ./phyto-plankton-classification/models/phytoplankton/ckpts && \
    curl --insecure -o ./phyto-plankton-classification/models/phytoplankton/ckpts/${MODEL_TAR} \
    ${SWIFT_CONTAINER}


# Open DEEPaaS port
EXPOSE 5000

# Open Monitoring port
EXPOSE 6006

# Open JupyterLab port
EXPOSE 8888

# Account for OpenWisk functionality (deepaas >=0.4.0) + proper docker stop
# OpenWhisk support is deprecated
CMD ["deepaas-run", "--listen-ip", "0.0.0.0", "--listen-port", "5000"]
