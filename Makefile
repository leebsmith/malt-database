MALSTERS := briess

.PHONY: all source db clean $(MALSTERS)

all: db

source:
	@for m in $(MALSTERS); do bin/fetch-$$m.sh; done

briess: data/maltsters/briess.json

data/source/briess/products.html: bin/fetch-briess.sh bin/fetch.sh
	bin/fetch-briess.sh

data/maltsters/briess.json: data/source/briess/products.html bin/process-briess.sh bin/validate.py bin/briess.jq
	bin/process-briess.sh
	python3 bin/validate.py briess

db: $(MALSTERS:%=data/maltsters/%.json) bin/unify.py lib/malt.py
	python3 bin/unify.py

clean:
	rm -rf data
