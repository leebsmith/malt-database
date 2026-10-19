MALSTERS := briess bairds

.PHONY: all source db clean $(MALSTERS)

all: db

source:
	@for m in $(MALSTERS); do bin/fetch-$$m.sh; done

briess: data/maltsters/briess.json

bairds: data/maltsters/bairds.json

data/source/briess/products.html: bin/fetch-briess.sh bin/fetch.sh
	bin/fetch-briess.sh

data/source/bairds/malt-menu.html: bin/fetch-bairds.sh bin/fetch.sh
	bin/fetch-bairds.sh

data/maltsters/briess.json: data/source/briess/products.html bin/process-briess.sh bin/validate.py bin/briess.jq
	bin/process-briess.sh
	python3 bin/validate.py briess

data/maltsters/bairds.json: data/source/bairds/malt-menu.html bin/process-bairds.sh bin/validate.py bin/bairds.jq
	bin/process-bairds.sh
	python3 bin/validate.py bairds

db: $(MALSTERS:%=data/maltsters/%.json) bin/unify.py lib/malt.py
	python3 bin/unify.py

clean:
	rm -rf data
