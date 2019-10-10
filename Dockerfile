FROM ubuntu
ARG wiki_date=latest
ARG wiki_lang=tr
RUN echo "Selected language $wiki_lang, Selected data $wiki_date"
RUN apt update && apt install -y wget unzip curl bzip2 git apt-utils sed make vim
RUN curl -LO http://repo.continuum.io/miniconda/Miniconda-latest-Linux-x86_64.sh
RUN bash Miniconda-latest-Linux-x86_64.sh -p /miniconda -b
RUN rm Miniconda-latest-Linux-x86_64.sh
ENV PATH=/miniconda/bin:${PATH}
RUN conda update -y conda
RUN conda create -n wiki-proc python=3.7 && bash -c "source activate wiki-proc && conda install -y pip spacy && pip install bs4 && pip install hanziconv"
RUN echo "source activate wiki-proc" > ~/.bashrc
RUN mkdir /workspace/ && cd /workspace/ && git clone https://github.com/attardi/wikiextractor && git clone -b dev --single-branch https://github.com/CogComp/wikidump-preprocessing.git
RUN cd /workspace/wikidump-preprocessing \
    && sed -i "s/wiki_date=latest/wiki_date=$wiki_date/g" makefile \
    && sed -i "s/wiki_lang=tr/wiki_lang=$wiki_lang/g" makefile
WORKDIR /workspace
