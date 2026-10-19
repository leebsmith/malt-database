MALSTERS := briess bairds simpsons fawcett gambrinus great-western bestmalz dingemans canada-malting crisp brewtarget williams northern-brewer

DB := data/db/malts.json

.PHONY: all source db check clean $(MALSTERS)

all: db

source:
	@for m in $(MALSTERS); do bin/fetch-$$m.sh; done

briess: data/maltsters/briess.json

bairds: data/maltsters/bairds.json

simpsons: data/maltsters/simpsons.json

fawcett: data/maltsters/fawcett.json

gambrinus: data/maltsters/gambrinus.json

great-western: data/maltsters/great-western.json

bestmalz: data/maltsters/bestmalz.json

dingemans: data/maltsters/dingemans.json

canada-malting: data/maltsters/canada-malting.json

crisp: data/maltsters/crisp.json

brewtarget: data/maltsters/brewtarget.json

williams: data/maltsters/williams.json

northern-brewer: data/maltsters/northern-brewer.json

data/source/briess/products.html: bin/fetch-briess.sh bin/fetch.sh
	bin/fetch-briess.sh

data/source/bairds/malt-menu.html: bin/fetch-bairds.sh bin/fetch.sh
	bin/fetch-bairds.sh

data/source/simpsons/our-malts.html: bin/fetch-simpsons.sh bin/fetch.sh
	bin/fetch-simpsons.sh

data/source/fawcett/brewing-malts.html: bin/fetch-fawcett.sh bin/fetch.sh
	bin/fetch-fawcett.sh

data/source/gambrinus/_sitemap.xml: bin/fetch-gambrinus.sh bin/fetch-sitemap.sh bin/fetch.sh
	bin/fetch-gambrinus.sh

data/source/great-western/_listing.html: bin/fetch-great-western.sh bin/fetch.sh
	bin/fetch-great-western.sh

data/source/bestmalz/_listing.html: bin/fetch-bestmalz.sh bin/fetch.sh
	bin/fetch-bestmalz.sh

data/source/dingemans/_sitemap.xml: bin/fetch-dingemans.sh bin/fetch-sitemap.sh bin/fetch.sh
	bin/fetch-dingemans.sh

data/source/canada-malting/_sitemap.xml: bin/fetch-canada-malting.sh bin/fetch-sitemap.sh bin/fetch.sh
	bin/fetch-canada-malting.sh

data/source/crisp/_sitemap.xml: bin/fetch-crisp.sh bin/fetch-sitemap.sh bin/fetch.sh
	bin/fetch-crisp.sh

data/source/brewtarget/default_db.sqlite: bin/fetch-brewtarget.sh bin/fetch.sh
	bin/fetch-brewtarget.sh

data/source/williams/candi-syrups.html: bin/fetch-williams.sh bin/fetch.sh
	bin/fetch-williams.sh

data/source/northern-brewer/products.json: bin/fetch-northern-brewer.sh bin/fetch.sh
	bin/fetch-northern-brewer.sh

data/maltsters/briess.json: data/source/briess/products.html bin/process-briess.sh bin/validate.py bin/briess.jq
	bin/process-briess.sh
	python3 bin/validate.py briess

data/maltsters/bairds.json: data/source/bairds/malt-menu.html bin/process-bairds.sh bin/validate.py bin/bairds.jq
	bin/process-bairds.sh
	python3 bin/validate.py bairds

data/maltsters/simpsons.json: data/source/simpsons/our-malts.html bin/process-simpsons.sh bin/validate.py bin/simpsons.jq
	bin/process-simpsons.sh
	python3 bin/validate.py simpsons

data/maltsters/fawcett.json: data/source/fawcett/brewing-malts.html bin/process-fawcett.sh bin/validate.py bin/fawcett.jq
	bin/process-fawcett.sh
	python3 bin/validate.py fawcett

data/maltsters/gambrinus.json: data/source/gambrinus/_sitemap.xml bin/process-gambrinus.sh bin/validate.py bin/gambrinus.jq
	bin/process-gambrinus.sh
	python3 bin/validate.py gambrinus

data/maltsters/great-western.json: data/source/great-western/_listing.html bin/process-great-western.sh bin/validate.py bin/great-western.jq
	bin/process-great-western.sh
	python3 bin/validate.py great-western

data/maltsters/bestmalz.json: data/source/bestmalz/_listing.html bin/process-bestmalz.sh bin/validate.py bin/bestmalz.jq
	bin/process-bestmalz.sh
	python3 bin/validate.py bestmalz

data/maltsters/dingemans.json: data/source/dingemans/_sitemap.xml bin/process-dingemans.sh bin/validate.py bin/dingemans.jq
	bin/process-dingemans.sh
	python3 bin/validate.py dingemans

data/maltsters/canada-malting.json: data/source/canada-malting/_sitemap.xml bin/process-canada-malting.sh bin/validate.py bin/canada-malting.jq
	bin/process-canada-malting.sh
	python3 bin/validate.py canada-malting

data/maltsters/crisp.json: data/source/crisp/_sitemap.xml bin/process-crisp.sh bin/validate.py bin/crisp.jq
	bin/process-crisp.sh
	python3 bin/validate.py crisp

data/maltsters/brewtarget.json: data/source/brewtarget/default_db.sqlite bin/process-brewtarget.sh bin/extract_brewtarget.py bin/validate.py schema/brewtarget.schema.json
	bin/process-brewtarget.sh
	python3 bin/validate.py brewtarget

data/maltsters/williams.json: data/source/williams/candi-syrups.html bin/process-williams.sh bin/extract_williams.py bin/validate.py schema/williams.schema.json
	bin/process-williams.sh
	python3 bin/validate.py williams

data/maltsters/northern-brewer.json: data/source/northern-brewer/products.json bin/process-northern-brewer.sh bin/extract_northern_brewer.py bin/validate.py schema/northern-brewer.schema.json
	bin/process-northern-brewer.sh
	python3 bin/validate.py northern-brewer

$(DB): $(MALSTERS:%=data/maltsters/%.json) bin/unify.py lib/malt.py
	python3 bin/unify.py

check: $(DB) bin/check.py
	python3 bin/check.py

db: check

clean:
	rm -rf data
