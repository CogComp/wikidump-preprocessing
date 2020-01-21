Wikipedia Dump Processing
------------
Script for processing wikipedia dumps (in any language) and extracting useful metadata (inter-language links, how often a string refers to a wikipage etc.) from it.

Install the requirements, modify the makefile appropriately, and run. 

Requirements
-----------------
You need python >=3.5. Also install the following two packages.

````python
pip3 install bs4
pip3 install spacy # (for generating mid files)
pip3 install hanziconv # (for chinese traditional to simplified conversion)
````

Running
-------
**Option 1**:\
For ease of use, we provide a `makefile` that specifies targets to automatically run all processing scripts. To use the makefile, you need to

1. Run `git submodule update --init --recursive` to download `WikiExtractor` submodule.

2. Create a download directory for wikipedia dumps (say `/path/to/dumpdir`) and set `DUMPDIR_BASE` environment variable accordingly. The wikipedia dumps will be downloaded under `DUMPDIR` in a subdirectory with language and date information (for instance the Turkish Wikipedia dumps will be downloaded under `DUMPDIR/tr-date/trwiki/`). This variable is **MANDATORY** and if not set `make` will fail.

**For Cogcomp Internal Use**: 
Wikipedia dumps are already available under `/shared/corpora/wikipedia_dumps`, so simply set the `DUMPDIR` to `/shared/corpora/wikipedia_dumps`. For instance, the Turkish wikipedia resources are in `/shared/corpora/wikipedia_dumps/trwiki`.

3. Set the `LANG` environment variable to the two-letter language code used by Wikipedia to identify the language (eg. `tr` for Turkish, `es` for Spanish etc.). This variable is **MANDATORY** and if not set `make` will fail.

4. Specify a `OUTDIR_BASE` environment variable. This is the directory where the resources will be generated (eg. `path/to/my/resources/trwiki` for Turkish Wikipedia). The result will be saved in `${OUTPUT_BASE}/${LANG}-${DATE}`. This variable is **MANDATORY** and if not set `make` will fail.

5. Set the `DATE` environment variable to identify the timestamp of the Wikipedia dump to download. Make sure that this link works `https://dumps.wikimedia.org/${LANG}wiki/${DATE}/`. A safe choice is `latest`. Note that you can view what dates are available by visiting `https://dumps.wikimedia.org/${LANG}wiki`. This variable is **MANDATORY** and if not set `make` will fail.

6. Make sure `PYTHONBIN` points to the correct python binary. The default value is `python3`.

7. For generating mid files, you may want to modify the default window size for capturing the context of the link. The default value is 20. You can change that by settting the `WINDOW` environment variable.

8. Run the command `make all`. This should perform all the preprocessing steps above by following the build dependencies specified in the makefile.

9. Make sure your environment variable is available to the forked processes. The command to do this depends on the shell you use. If you use `bash` you would do `export VAR=value`.

**Option 2: For Docker users**\
We also provide a Dockerfile that will setup all the required environment for you. To use it:
1. Build a docker image with the provided Dockerfile. Our Dockerfile comes with two arguments: `wiki_date`, and `wiki_lang`. `wiki_date` specifies a date for the wiki dumps, and `wiki_lang` specifies the default language for download and preprocessing. Both can later be changed once built (see step 4 and 5). See https://docs.docker.com/engine/reference/commandline/build/ is you have trouble building the docker image.
2. Run the newly built docker image. Your working directory should be `/workspace`. See https://docs.docker.com/engine/reference/commandline/run/ if you have any problems running the image.
3. Go to /workspace/wikidump_preprocessing
4. If you want to modify date of wiki dump, you can simply set environment variable `DATE`. If you are using bash and want to override date to be 20191001, for instance, simply run `export DATE=20191001` before running step 6.
5. Now if you want to override the built wiki language, simply set environment variable `lang` to the two-letter language code such as 'en', 'fr', etc. If you are using bash and want to override language to be French, for instance, simply run `export lang=fr` before running step 6.
6. `make all` will download all the wiki articles and run all the preprocessing steps.

Description
------------
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
