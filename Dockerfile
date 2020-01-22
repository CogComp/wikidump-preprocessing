FROM ubuntu 
RUN mkdir /workspace/
WORKDIR /workspace
COPY . .
RUN apt update && apt install -y wget unzip curl bzip2 git apt-utils sed make vim
RUN curl -LO http://repo.continuum.io/miniconda/Miniconda-latest-Linux-x86_64.sh
RUN bash Miniconda-latest-Linux-x86_64.sh -p /miniconda -b
RUN rm Miniconda-latest-Linux-x86_64.sh
ENV PATH=/miniconda/bin:${PATH}
RUN conda update -y conda
RUN conda create -n wiki-proc python=3.7 && bash -c "source activate wiki-proc && conda install -y pip spacy && pip install bs4 && pip install hanziconv"
RUN echo "source activate wiki-proc" > ~/.bashrc
RUN echo "Start container: docker-compose up"
RUN echo "Get into the container: docker exec -it wikidumppre /bin/bash"
RUN echo "How to use: make DATE=20200101 LANG=so DUMPDIR_BASE=/workspace/linked_volume/dump OUTDIR_BASE=/workspace/linked_volume/wiki PYTHONBIN=python all"
