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

ifndef wiki_date
wiki_date=latest
endif
ifndef wiki_lang
wiki_lang=tr
endif
# window size for mention context
window=20
# location where wikipedia dumps are downloaded
DUMPDIR_BASE = "/workspace/dumpdir"
DUMPDIR="${DUMPDIR_BASE}-${wiki_lang}-${wiki_date}"

# good practice to make this different from the dumpdir, to separate
# resources from processed output
OUTDIR_BASE = "/workspace/outdir"
OUTDIR="${OUTDIR_BASE}-${wiki_lang}-${wiki_date}"
WIKIEXTRACTOR = "/workspace/wikiextractor/WikiExtractor.py"
ENCODING = utf-8
# path to python3 binary
PYTHONBIN = /miniconda/envs/wiki-proc/bin/python
dumps:
	@if [ -f "${DUMPDIR}/${wiki_lang}wiki/${wiki_lang}wiki-${wiki_date}-pages-articles.xml.bz2" ]; then \
	echo $(ERROR_COLOR) "dump exists in ${DUMPDIR}!" $(NO_COLOR); \
	else echo $(OK_COLOR) "getting dumps" $(NO_COLOR); \
	./scripts/download_dump.sh ${wiki_lang} ${wiki_date} ${DUMPDIR}; \
	fi
softlinks:
	@mkdir -p ${OUTDIR}; \
	echo $(OK_COLOR) "making softlinks into output folder ${OUTDIR}" $(NO_COLOR); \
	./scripts/make_softlinks.sh ${wiki_lang} ${wiki_date} ${DUMPDIR} ${OUTDIR};

text: dumps
	@if [ -d "${OUTDIR}/${wiki_lang}wiki_with_links" ]; then \
	echo $(ERROR_COLOR) "text already extracted!" $(NO_COLOR); \
	else echo $(OK_COLOR) "extracting text to ${OUTDIR}/${wiki_lang}wiki_with_links" $(NO_COLOR); \
	${WIKIEXTRACTOR} \
	-o ${OUTDIR}/${wiki_lang}wiki_with_links \
	-l -q --filter_disambig_pages \
	${DUMPDIR}/${wiki_lang}wiki/${wiki_lang}wiki-${wiki_date}-pages-articles.xml.bz2; \
	fi
id2title: dumps softlinks
	@if [ -f "${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.id2t" ]; then \
	echo $(ERROR_COLOR) "id2title exists!" $(NO_COLOR); \
	else echo $(OK_COLOR) "making id2title" $(NO_COLOR); \
	mkdir -p "${OUTDIR}/idmap/"; \
	${PYTHONBIN} -m dp.create_id2title \
	--wiki ${OUTDIR}/${wiki_lang}wiki-${wiki_date} \
	--out ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.id2t; \
	fi
redirects: dumps softlinks id2title
	@if [ -e "${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.r2t" ]; then \
	echo $(ERROR_COLOR) "redirects exists!" $(NO_COLOR); \
	else echo $(OK_COLOR) "making redirects" $(NO_COLOR); \
	${PYTHONBIN} -m dp.create_redirect2title \
	--id2t ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.id2t \
	--wiki ${OUTDIR}/${wiki_lang}wiki-${wiki_date} \
	--out ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.r2t; \
	fi
hyperlinks: text id2title redirects
	@if [ -d "${OUTDIR}/${wiki_lang}link_in_pages" ]; then \
	echo ${ERROR_COLOR} "hyperlink already extracted!" ${NO_COLOR} ; \
	else echo $(OK_COLOR) "extracting links to ${OUTDIR}/${wiki_lang}link_in_pages" $(NO_COLOR); \
	mkdir -p ${OUTDIR}/${wiki_lang}link_in_pages; \
	${PYTHONBIN} -m dp.extract_link_from_pages --dump ${OUTDIR}/${wiki_lang}wiki_with_links/ \
	--out ${OUTDIR}/${wiki_lang}link_in_pages \
	--lang ${wiki_lang} \
	--id2t ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.id2t \
	--redirects ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.r2t; \
	fi
mid: hyperlinks
	@if [ -d "${OUTDIR}/${wiki_lang}mid" ]; then \
	echo $(ERROR_COLOR) "training files already there" $(NO_COLOR); \
	else echo $(OK_COLOR) "extracting training files to $(OUTDIR)/${wiki_lang}mid" $(NO_COLOR); \
	mkdir -p $(OUTDIR)/${wiki_lang}mid; \
	${PYTHONBIN} -m dp.create_mid --dump ${OUTDIR}/${wiki_lang}link_in_pages \
		--out ${OUTDIR}/${wiki_lang}mid \
		--lang ${wiki_lang} \
		--id2t ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.id2t \
		--redirects ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.r2t \
		--window ${window} ; \
	fi
langlinks: dumps id2title redirects
	@if [ -f "${OUTDIR}/idmap/fr2entitles" ]; then \
	echo $(ERROR_COLOR) "fr2entitle exists!" $(NO_COLOR); \
	else echo $(OK_COLOR) "making fr2entitle" $(NO_COLOR); \
	${PYTHONBIN} -m dp.langlinks \
	--langlinks ${DUMPDIR}/${wiki_lang}wiki/${wiki_lang}wiki-${wiki_date}-langlinks.sql.gz \
	--frid2t ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.id2t \
	--out ${OUTDIR}/idmap/fr2entitles; \
	fi
countsmap: id2title redirects text
	@if [ -e "${OUTDIR}/${wiki_lang}wiki-${wiki_date}.counts" ]; then \
	echo $(ERROR_COLOR) "countsmap exists!" $(NO_COLOR); \
	else echo $(OK_COLOR) "making surface to title map and title counts" $(NO_COLOR); \
	${PYTHONBIN} -m dp.count_popular_entities_v2 \
	--wikitext ${OUTDIR}/${wiki_lang}wiki_with_links \
	--id2title ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.id2t \
	--redirects ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.r2t \
	--contsout ${OUTDIR}/${wiki_lang}wiki-${wiki_date}.counts \
	--linksout ${OUTDIR}/surface_links; \
	fi
probmap: id2title redirects countsmap langlinks
	@if [ -e "${OUTDIR}/probmap/${wiki_lang}wiki-${wiki_date}.p2t2prob" ]; then \
	echo "probmap phrase exists!"; \
	else echo "computing phrase probmap"; \
	mkdir -p "${OUTDIR}/probmap"; \
	${PYTHONBIN} -m dp.compute_probs2 \
	--links ${OUTDIR}/surface_links \
	--id2t ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.id2t \
	--redirects ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.r2t \
	--mode phrase \
	--out_prefix ${OUTDIR}/probmap/${wiki_lang}wiki-${wiki_date} \
	--lang ${wiki_lang}; \
	fi; \
	if [ -e "${OUTDIR}/probmap/${wiki_lang}wiki-${wiki_date}.w2t2prob" ]; then \
	echo "probmap word exists!"; \
	else echo "computing word probmap"; \
	${PYTHONBIN} -m dp.compute_probs2 \
	--links ${OUTDIR}/surface_links \
	--id2t ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.id2t \
	--redirects ${OUTDIR}/idmap/${wiki_lang}wiki-${wiki_date}.r2t \
	--mode word \
	--out_prefix ${OUTDIR}/probmap/${wiki_lang}wiki-${wiki_date} \
	--lang ${wiki_lang}; \
	fi	
all:	dumps softlinks text id2title redirects langlinks countsmap probmap hyperlinks mid
	echo "all done"
