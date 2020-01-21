COM_COLOR   = "\033[0;34m"
OBJ_COLOR   = "\033[0;36m"
OK_COLOR    = "\033[0;32m"
ERROR_COLOR = "\033[0;31m"
WARN_COLOR  = "\033[0;33m"
NO_COLOR    = "\033[m"

OK_STRING    = "[OK]"
ERROR_STRING = "[ERROR]"
WARN_STRING  = "[WARNING]"
COM_STRING   = "Compiling"

# MAKEFILEDIR stores the path to the present makefile, which is also
# the path to the repo's directory 
MAKEFILEDIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
WIKIEXTRACTOR="${MAKEFILEDIR}/wikiextractor/WikiExtractor.py"
ENCODING=utf-8
PYTHONIOENCODING=utf-8
# path to python3 binary
ifndef PYTHONBIN
PYTHONBIN=python3
endif
ifndef DATE
$(error DATE is not defined!)	
endif
ifndef LANG
$(error LANG is not defined!)
endif
# location where wikipedia dumps are downloaded
ifndef DUMPDIR_BASE
$(error DUMPDIR_BASE is not defined!)
endif
DUMPDIR=${DUMPDIR_BASE}/${LANG}/${LANG}-${DATE}
# good practice to make this different from the dumpdir, to separate
# resources from processed output
ifndef OUTDIR_BASE
$(error OUTDIR_BASE is not defined!)
endif
OUTDIR=${OUTDIR_BASE}/${LANG}/${LANG}-${DATE}
# window size for mention context
# this is used in generating .mid files
ifndef WINDOW
WINDOW=20
endif

dumps:
	@if [ -f "${DUMPDIR}/${LANG}wiki/${LANG}wiki-${DATE}-pages-articles.xml.bz2" ]; then \
	echo $(ERROR_COLOR) "dump exists in ${DUMPDIR}!" $(NO_COLOR); \
	else echo $(OK_COLOR) "getting dumps" $(NO_COLOR); \
	./scripts/download_dump.sh ${LANG} ${DATE} ${DUMPDIR}; \
	fi
softlinks:
	@mkdir -p ${OUTDIR}; \
	echo $(OK_COLOR) "making softlinks into output folder ${OUTDIR}" $(NO_COLOR); \
	./scripts/make_softlinks.sh ${LANG} ${DATE} ${DUMPDIR} ${OUTDIR};

cleanlinks:
	echo $(OK_COLOR) "cleaning softlinks from output folder ${OUTDIR}" $(NO_COLOR); \
	./scripts/clean_softlinks.sh ${LANG} ${DATE} ${OUTDIR};

text: dumps
	@if [ -d "${OUTDIR}/${LANG}wiki_with_links" ]; then \
	echo $(ERROR_COLOR) "text already extracted!" $(NO_COLOR); \
	else echo $(OK_COLOR) "extracting text to ${OUTDIR}/${LANG}wiki_with_links" $(NO_COLOR); \
	${WIKIEXTRACTOR} \
	-o ${OUTDIR}/${LANG}wiki_with_links \
	-l -q --filter_disambig_pages \
	${DUMPDIR}/${LANG}wiki/${LANG}wiki-${DATE}-pages-articles.xml.bz2; \
	fi
id2title: dumps softlinks
	@if [ -f "${OUTDIR}/idmap/${LANG}wiki-${DATE}.id2t" ]; then \
	echo $(ERROR_COLOR) "id2title exists!" $(NO_COLOR); \
	else echo $(OK_COLOR) "making id2title" $(NO_COLOR); \
	mkdir -p "${OUTDIR}/idmap/"; \
	${PYTHONBIN} -m dp.create_id2title \
	--wiki ${OUTDIR}/${LANG}wiki-${DATE} \
	--out ${OUTDIR}/idmap/${LANG}wiki-${DATE}.id2t; \
	fi
redirects: dumps softlinks id2title
	@if [ -e "${OUTDIR}/idmap/${LANG}wiki-${DATE}.r2t" ]; then \
	echo $(ERROR_COLOR) "redirects exists!" $(NO_COLOR); \
	else echo $(OK_COLOR) "making redirects" $(NO_COLOR); \
	${PYTHONBIN} -m dp.create_redirect2title \
	--id2t ${OUTDIR}/idmap/${LANG}wiki-${DATE}.id2t \
	--wiki ${OUTDIR}/${LANG}wiki-${DATE} \
	--out ${OUTDIR}/idmap/${LANG}wiki-${DATE}.r2t; \
	fi
hyperlinks: text id2title redirects
	@if [ -d "${OUTDIR}/${LANG}link_in_pages" ]; then \
	echo ${ERROR_COLOR} "hyperlink already extracted!" ${NO_COLOR} ; \
	else echo $(OK_COLOR) "extracting links to ${OUTDIR}/${LANG}link_in_pages" $(NO_COLOR); \
	mkdir -p ${OUTDIR}/${LANG}link_in_pages; \
	${PYTHONBIN} -m dp.extract_link_from_pages --dump ${OUTDIR}/${LANG}wiki_with_links/ \
	--out ${OUTDIR}/${LANG}link_in_pages \
	--lang ${LANG} \
	--id2t ${OUTDIR}/idmap/${LANG}wiki-${DATE}.id2t \
	--redirects ${OUTDIR}/idmap/${LANG}wiki-${DATE}.r2t; \
	fi
mid: hyperlinks
	@if [ -d "${OUTDIR}/${LANG}mid" ]; then \
	echo $(ERROR_COLOR) "training files already there" $(NO_COLOR); \
	else echo $(OK_COLOR) "extracting training files to $(OUTDIR)/${LANG}mid" $(NO_COLOR); \
	mkdir -p $(OUTDIR)/${LANG}mid; \
	${PYTHONBIN} -m dp.create_mid --dump ${OUTDIR}/${LANG}link_in_pages \
		--out ${OUTDIR}/${LANG}mid \
		--lang ${LANG} \
		--id2t ${OUTDIR}/idmap/${LANG}wiki-${DATE}.id2t \
		--redirects ${OUTDIR}/idmap/${LANG}wiki-${DATE}.r2t \
		--window ${WINDOW} ; \
	fi
langlinks: dumps id2title redirects
	@if [ -f "${OUTDIR}/idmap/fr2entitles" ]; then \
	echo $(ERROR_COLOR) "fr2entitle exists!" $(NO_COLOR); \
	else echo $(OK_COLOR) "making fr2entitle" $(NO_COLOR); \
	${PYTHONBIN} -m dp.langlinks \
	--langlinks ${DUMPDIR}/${LANG}wiki/${LANG}wiki-${DATE}-langlinks.sql.gz \
	--frid2t ${OUTDIR}/idmap/${LANG}wiki-${DATE}.id2t \
	--out ${OUTDIR}/idmap/fr2entitles; \
	fi
countsmap: id2title redirects text
	@if [ -e "${OUTDIR}/${LANG}wiki-${DATE}.counts" ]; then \
	echo $(ERROR_COLOR) "countsmap exists!" $(NO_COLOR); \
	else echo $(OK_COLOR) "making surface to title map and title counts" $(NO_COLOR); \
	${PYTHONBIN} -m dp.count_popular_entities_v2 \
	--wikitext ${OUTDIR}/${LANG}wiki_with_links \
	--id2title ${OUTDIR}/idmap/${LANG}wiki-${DATE}.id2t \
	--redirects ${OUTDIR}/idmap/${LANG}wiki-${DATE}.r2t \
	--contsout ${OUTDIR}/${LANG}wiki-${DATE}.counts \
	--linksout ${OUTDIR}/surface_links; \
	fi
probmap: id2title redirects countsmap langlinks
	@if [ -e "${OUTDIR}/probmap/${LANG}wiki-${DATE}.p2t2prob" ]; then \
	echo "probmap phrase exists!"; \
	else echo "computing phrase probmap"; \
	mkdir -p "${OUTDIR}/probmap"; \
	${PYTHONBIN} -m dp.compute_probs2 \
	--links ${OUTDIR}/surface_links \
	--id2t ${OUTDIR}/idmap/${LANG}wiki-${DATE}.id2t \
	--redirects ${OUTDIR}/idmap/${LANG}wiki-${DATE}.r2t \
	--mode phrase \
	--out_prefix ${OUTDIR}/probmap/${LANG}wiki-${DATE} \
	--lang ${LANG}; \
	fi; \
	if [ -e "${OUTDIR}/probmap/${LANG}wiki-${DATE}.w2t2prob" ]; then \
	echo "probmap word exists!"; \
	else echo "computing word probmap"; \
	${PYTHONBIN} -m dp.compute_probs2 \
	--links ${OUTDIR}/surface_links \
	--id2t ${OUTDIR}/idmap/${LANG}wiki-${DATE}.id2t \
	--redirects ${OUTDIR}/idmap/${LANG}wiki-${DATE}.r2t \
	--mode word \
	--out_prefix ${OUTDIR}/probmap/${LANG}wiki-${DATE} \
	--lang ${LANG}; \
	fi	
all:	dumps softlinks text id2title redirects langlinks countsmap probmap hyperlinks cleanlinks # mid
	echo "all done"
