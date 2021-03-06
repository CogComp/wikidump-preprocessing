# Wikipedia Dump Processing
Script for processing wikipedia dumps (in any language) and extracting useful metadata (inter-language links, how often a string refers to a wikipage etc.) from it.

Install the requirements, modify the makefile appropriately, and run. 

## Requirements
You need python >=3.5. Also install the following two packages.

````python
pip3 install bs4
pip3 install spacy # (for generating mid files)
pip3 install hanziconv # (for chinese traditional to simplified conversion)
````

## Running
### 1. Using makefile 
For ease of use, we provide a `makefile` that specifies targets to automatically run all processing scripts. To use the makefile, you need to

1. Run `git submodule update --init --recursive` to download `WikiExtractor` submodule.

2. Identify a path to store Wikipedia dumps; since wikipedia dumps can be large, choose accodingly.
We will refer to this location as `PATH_DUMPDIR`. Wikipedia dump will be downloaded in 
`PATH_DUMPDIR/LANG/LANG-DATE`.

3. The processed wikipedia output will be written as multiple files and directories. 
Identify a suitable path to store this output, henceforth referred to as `PATH_OUTDIR`. 
The output will be written in  `PATH_OUTDIR/LANG/LANG-DATE`; 
therefore `PATH_OUTDIR` does not need to contain this information. 
This path should be the same when processing multiple languages and/or dates; this codebase will create an appropriate nested directory structure.

4. Identify the Wikipedia language `WIKI_LANG` (usually 2 or 3 letter code) and the date `WIKI_DATE` (YEARMONTHDATE) that needs to be processed.
You can find available dates here (https://dumps.wikimedia.org/${lang}wiki)

Run the following command to generate the processed wikipedia output:
```
make DATE=WIKI_DATE \
     LANG=WIKI_LANG \
     DUMPDIR_BASE=PATH_DUMPDIR \
     OUTDIR_BASE=PATH_OUTDIR \
     PYTHONBIN=python all
```

For example, to process Somali (so) wikipedia dump dated 12-Dec-2019, run the command
```
make DATE=20191220 \
     LANG=so \
     DUMPDIR_BASE=PATH_DUMPDIR \
     OUTDIR_BASE=PATH_OUTDIR \ 
     PYTHONBIN=python all
```

List of available Wikipedia and their langauge codes can be found [here](https://en.wikipedia.org/wiki/List_of_Wikipedias).

List of recent dumps for a particular language `LANG` can be found at [dumps.wikimedia.org/LANGwiki](https://dumps.wikimedia.org/LANGwiki/). E.g. [dumps.wikimedia.org/enwiki/](https://dumps.wikimedia.org/enwiki/)

### 2. Using docker
We also provide a Dockerfile that will setup all the required environment for you. To use it:
1. Build a docker image with the provided Dockerfile. 
2. Run the newly built docker image (you can use the docker-compose.yml file provided). 
3. Go to /workspace/
4. The following example will process the 20200101 wiki dump snapshot for Somali language:
`make DATE=20200101 LANG=so DUMPDIR_BASE=/workspace/linked_volume/dump OUTDIR_BASE=/workspace/linked_volume/wiki PYTHONBIN=python all` 

## Description
This repository contains scripts to perform the following preprocessing steps.

1. Download the relevant files from the wikipedia dump (target `dumps` in `makefile`). Specifically, it downloads

````
*-pages-articles.xml.bz2
*-page.sql.gz
*-pagelinks.sql.gz
*-redirect.sql.gz
*-categorylinks.sql.gz
*-langlinks.sql.gz
````

2. Extract text with hyperlinks from the \*pages-articles.xml.bz2 file (target `text` in `makefile`), using the [wikiextractor](https://github.com/attardi/wikiextractor).

3. Create a inter-language link mapping from Wikipedia titles to English Wikipedia titles using \*langlinks.sql.gz (target `langlinks` in `makefile`). Inter-language links indicate that the page [Barack_Obama](https://en.wikipedia.org/wiki/Barack_Obama) in English Wikipedia is for the same entity as the page [बराक_ओबामा](https://hi.wikipedia.org/wiki/%E0%A4%AC%E0%A4%B0%E0%A4%BE%E0%A4%95_%E0%A4%93%E0%A4%AC%E0%A4%BE%E0%A4%AE%E0%A4%BE) in Hindi Wikipedia.

4. Compute hyperlink counts (how many hyperlinks point to a certain title) for wikipedia titles (target `countsmap` in `makefile`). This is basically inlink counts for each title.

5. Compute probability indices using which we can compute the probability for a string (e.g., Berlin) referring a Wikipedia title (e.g., Berlin_(Band)) (target `probmap` in `makefile`).

Major output files are explained below:

### Wikipedia Page ID to Page Title Map
Creates Wikipedia page id to page title map using \*page.sql.gz (target `id2title` in `makefile`). The result is saved in `${OUTDIR}/${lang}wiki/idmap/${lang}wiki-data.id2t`

Every Wikipedia page is associated with a unique page id. 
For instance, the page [Barack_Obama](https://en.wikipedia.org/wiki/Barack_Obama) in the English Wikipedia has the page id 534366. 
You can verify this by visiting https://en.wikipedia.org/?curid=534366 or visiting the page information link on the Tools panel on the left on the Wikipedia page. 
This page id serves as the canonical identifier of the page, and is used in other dump files (e.g., enwiki-\*-redirect.sql.gz etc.) to refer to the page. 

The output map is a tsv file that looks like this (example from Turkish wiki dump for 20181020):

````
10	Cengiz_Han	0
16	Film_(anlam_ayrımı)	0
22	Mustafa_Suphi	0
24	Linux	0
25	MHP	1
````

Each line represents an entry for one page, where the first field is the page id, the second field is the page title, and the third field is a boolean indicating whether the page is redirection.

### Wikipedia Page hyperlink json output
In this precessing steps, for each dumped wiki file, we create 2 json files that summarize the information for each pages: wiki_{no.}.json and wiki_{no.}.json.brief. 
The processed json files are saved in `${OUTDIR}/${lang}link_in_pages`.
Those information are later used to create training dataset.

In wiki_{no.}.json files, for each wiki page, we store: 
````
title: the page title
curid: the wikipage id
text: the raw text of this page, with all hyperlinks removed
linked_spans: a list of all the words appeared in this page that has an outlink to some other page. 
For those words, we record their starting and ending character position.
````
An example from part of a turkish language wiki.json file (from 2019/05/01 dump):
````
{
        "title": "Kimya",
        "curid": "58",
        "text": "\nKimya\n\nKimya, maddenin yap......"
        "linked_spans": [
            {
                "label": "Madde",
                "end": 20,
                "start": 15
            },
            {
                "label": "'Kimyasal_reaksiyon'",
                "end": 86,
                "start": 79
            }, ...
        ]
}
````

The wiki_{no.}.json.brief file contains only the curid, title and raw text.
An example of the same wikipage as above:
````angular2
{
        "title": "Kimya",
        "curid": "58",
        "text": "\nKimya\n\nKimya, maddenin yap......"
}
````

### Wikipedia Training Data for xling-el
The [xling-el](https://github.com/shyamupa/xling-el) project for cross-lingual entity linking requires training data to be provided in a certain format. Generating this data from wikipedia text is handled in the `mid` target in the makefile. The training data format is the following fields in a tab separated file,

a. The freebase mid of the wikipedia page.

b. The wikipedia page title.

c. Start token offset of the mention.

d. End token offset of the mention.

e. The mention string.

f. The context around (and including) the mention, of a certain window size. 

g. All other mentions in the same document as the current mention.

The output tab separated files are saved in `${OUTDIR}/${lang}mid`.

Here is a line of example output from Turkish wiki (from 2018/11/01 dump):
````
MID 163500  Krokau  4   4   Almanya     Almanya Schleswig-Holstein Plön_(il) Almanya'nın_belediyeleri 31_Aralık 2015
````
The tab-separated fields, are, from left to right:

1. MID keyword

2. Page ID of the Wiki page

3. Normalized page title

4. Start index of the tokens that contains a mention

5. End index of the tokens that contains a mention

6. The context for the mention. It contains n characters before and after the mention, where n is the window size.

7. All mentions in the same page.

### Wikipedia Page Redirects to Page Title Map
Redirects map using \*redirect.sql.gz (target `redirects` in `makefile`). 

Redirects tell you that the wikipedia link [POTUS44](https://en.wikipedia.org/wiki/POTUS44) redirects to the page [Barack_Obama](https://en.wikipedia.org/wiki/Barack_Obama) in the English Wikipedia.

Sanity Check
------

After `make all` completes successfully (takes ~18 mins on single-core machine for Turkish Wikipedia), you should have files with following line counts (for 20180720 dump of Turkish Wikipedia),

````
222367  idmap/fr2entitles   
559553  idmap/trwiki-20180720.id2t
247338  idmap/trwiki-20180720.r2t
559552  trwiki-20180720.counts
2941652 surface_links
936100  probmap/trwiki-20180720.p2t2prob
936100  probmap/trwiki-20180720.t2p2prob
1426771 probmap/trwiki-20180720.t2w2prob
745829  probmap/trwiki-20180720.tnr.p2t2prob
745829  probmap/trwiki-20180720.tnr.t2p2prob
1273216 probmap/trwiki-20180720.tnr.t2w2prob
1273216 probmap/trwiki-20180720.tnr.w2t2prob
1426771 probmap/trwiki-20180720.w2t2prob
````

Citation
------

If you use this code, please cite

```
@inproceedings{UGR18,
  author = {Upadhyay, Shyam and Gupta, Nitish and Roth, Dan},
  title = {Joint Multilingual Supervision for Cross-lingual Entity Linking},
  booktitle = {EMNLP},
  year = {2018}
}
```
