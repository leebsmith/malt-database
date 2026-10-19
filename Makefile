MALSTERS := briess bairds simpsons fawcett gambrinus great-western bestmalz

.PHONY: all source db clean $(MALSTERS)

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

db: $(MALSTERS:%=data/maltsters/%.json) bin/unify.py lib/malt.py
	python3 bin/unify.py

clean:
	rm -rf data
