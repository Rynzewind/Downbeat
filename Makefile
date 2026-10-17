FLUTTER := .tooling/flutter/bin/flutter.bat
DART := .tooling/flutter/bin/cache/dart-sdk/bin/dart.exe
NODE := node

.PHONY: generate test lint

generate:
	cd tools && ../$(DART) run prepare_assets.dart ../assets/source ../apps/client/assets

test:
	$(NODE) --test contracts/tests/test_contract_examples.mjs
	cd tools && ../$(DART) test
	cd apps/client && ../../$(FLUTTER) test

lint:
	cd apps/client && ../../$(FLUTTER) analyze
