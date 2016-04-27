include Makefile.grid

HUB_NAME	=uabMetaBacteria1
GENOME_NAME	=$(HUB_NAME)
GENOME_DIR	=$(HUB_NAME)/$(GENOME_NAME)
GENOME_BASE	=$(HUB_NAME)/$(GENOME_NAME)/$(GENOME_NAME)

LOAD_UCSC	=module load ngs-ccts/ucsc_kent/2014-03-05


default: hub

HUB_DIRS=$(HUB_NAME) $(GENOME_DIR)

HUB_FILES= \
	$(GENOME_BASE).fa \
	$(GENOME_BASE).2bit \
	$(GENOME_DIR)/allgenome_links.html \
	$(GENOME_BASE).loci.bed \
	$(GENOME_BASE).loci.bb \

hub: $(HUB_DIRS) $(HUB_FILES)

#--- directory struct ---
$(HUB_NAME): 
	mkdir -p $@

$(GENOME_DIR): 
	mkdir -p $@


REFRENCE/genomes_ref.fa: 
	rsync -hav bmidat03:/BMI/rkumar/Current_Projects/metasnp2016/REFRENCE .

$(GENOME_BASE).fa: REFRENCE/genomes_ref.fa | $(GENOME_DIR)
	rsync -hav --progress $< $@

$(GENOME_BASE).dict: REFRENCE/genomes_ref.dict | $(GENOME_DIR)
	grep "^@SQ" $< | sed 's/:/\t/g' | cut -f 3,5 > $@

$(GENOME_BASE).2bit:$(GENOME_BASE).fa | $(GENOME_DIR)
	$(LOAD_UCSC); faToTwoBit $< $@

$(GENOME_DIR)/allgenome_links.html: REFRENCE/allgenome_links
	awk 'BEGIN{print "<html><header>allgenome_links</header><body><table>"} {print "<tr><td>"$$1"</td><td><a href=\"http://"$$2"\">"$$2"</a></td></tr>"} END{ print "</table></body></html>"}' \
	$< > $@

#
#-------
# BED
# -------
ALL_GBK_TGZ	= $(notdir $(wildcard REFRENCE/gbk_genomes/*.gbk.tgz))
ALL_GBK_DIR	= $(patsubst %.gbk.tgz,unzip/gbk_genomes/%,$(ALL_GBK_TGZ))
ALL_GBK		= $(notdir $(wildcard REFRENCE/gbk_genomes/*.gbk))
ALL_GENOMES	= $(ALL_GBK_TGZ:.gbk.tgz=) $(ALL_GBK:.gbk=)
ALL_BEDS	= $(patsubst %,beds/%.bed,$(ALL_GENOMES))
ALL_QSUB_BEDS	= $(patsubst %,jobs/%.done, $(notdir $(ALL_BEDS)))

qsub: $(ALL_QSUB_BEDS) | jobs beds
ifdef QSUB
ifndef NO_EMAIL
	nohup qstat_email_when_empty make_bed_ done in $PWD &
endif
endif

jobs/%.bed.done: | jobs
	job_name=make_bed_$(basename $(notdir $@)); \
	qsub -N $${job_name} \
		-j y -o 'jobs/$$JOB_NAME.$$JOB_ID.out.txt' \
		-l h_rt=$(ONE_WEEK):00:00,s_rt=$(ONE_WEEK):00:00 \
		-l vf=1.9G,h_vmem=2G -v GRID_RAM=2 \
		-cwd -V -m beas -M $(USER)@uab.edu \
		-b yes \
		$$(which make) $(MFLAGS) QSUB= \
		beds/$(basename $(notdir $@))



bed:	$(ALL_BEDS) | beds

beds:
	mkdir -p $@

unzip/gbk_genomes/%: REFRENCE/gbk_genomes/%.gbk.tgz
	mkdir -p $@; cd $@; tar xvf ../../../$<

beds/%.bed: unzip/gbk_genomes/% | beds
	FLIST=`ls -1 $</*.gbk | sort`; \
	gawk -v CHROM=$* \
	-f gbks2bed.awk \
	$$FLIST \
	> $@
	date >  jobs/$(notdir $<).done

beds/%.bed: REFRENCE/gbk_genomes/%.gbk | beds
	gawk -v CHROM=$* \
	-f gbks2bed.awk \
	$< \
	> $@
	date >  jobs/$(notdir $<).done


$(GENOME_BASE).loci.bed: beds/*.bed | beds/Bacteroides_vulgatus_PC510.bed 
	cat $^ | sort -k1,1 -k2,2n > $@

$(GENOME_BASE).loci.bb: $(GENOME_BASE).bed $(GENOME_BASE).dict
	$(LOAD_UCSC); bedToBigBed $^ $@

# ----------------------------------------------------------------------
info:
	@echo "GENOME_BASE: $(GENOME_BASE)"
	@echo ""
	@echo "HUB_DIRS= $(HUB_DIRS)"
	@echo ""
	@echo "HUB_FILES= $(HUB_FILES)"
	@echo ""
	@echo "ALL_GBK_DIR: $(ALL_GBK_DIR)"
	@echo ""
	@echo "ALL_GENOMES: $(ALL_GENOMES)"
