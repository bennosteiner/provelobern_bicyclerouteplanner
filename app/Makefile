SITE_PACKAGES = $(shell .build/venv/bin/python -c "import distutils; print(distutils.sysconfig.get_python_lib())" 2> /dev/null)
CLOSURE_UTIL_PATH := openlayers/node_modules/closure-util
CLOSURE_LIBRARY_PATH = $(shell node -e 'process.stdout.write(require("$(CLOSURE_UTIL_PATH)").getLibraryPath())' 2> /dev/null)
CLOSURE_COMPILER_PATH = $(shell node -e 'process.stdout.write(require("$(CLOSURE_UTIL_PATH)").getCompilerPath())' 2> /dev/null)
OL_JS_FILES = $(shell find node_modules/openlayers/src/ol -type f -name '*.js' 2> /dev/null)
NGEO_JS_FILES = $(shell find node_modules/ngeo/src -type f -name '*.js' 2> /dev/null)
APP_JS_FILES = $(shell find provelobern/static/js -type f -name '*.js')
APP_HTML_FILES = $(shell find provelobern/templates -type f -name '*.html')
LESS_FILES = $(shell find less -type f -name '*.less')

.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo
	@echo "Main targets:"
	@echo
	@echo "- check               Perform a number of checks on the code"
	@echo "- clean               Remove generated files"
	@echo "- cleanall            Remove all the build artefacts"
	@echo "- compile-catalog     Compile the translation catalog"
	@echo "- flake8              Run flake8 checker on the Python code"
	@echo "- install             Install and build the project"
	@echo "- lint                Check the JavaScript code with linters"
	@echo "- serve               Run the development server (pserve)"
	@echo "- update-node-modules Update node modules (using --force)"
	@echo "- modwsgi             Create files for Apache mod_wsgi"
	@echo

.PHONY: check
check: flake8 lint build

.PHONY: build
build: provelobern/static/build/build.js provelobern/static/build/build.css provelobern/static/build/build.min.css compile-catalog

.PHONY: clean
clean:
	rm -f .build/node_modules.timestamp
	rm -f .build/dev-requirements.timestamp
	rm -f common.ini
	rm -f provelobern/locale/*.pot
	rm -rf provelobern/static/build

.PHONY: cleanall
cleanall: clean
	rm -rf .build
	rm -rf node_modules

.PHONY: compile-catalog
compile-catalog: provelobern/static/build/locale/de/provelobern.json

.PHONY: flake8
flake8: .build/venv/bin/flake8
	.build/venv/bin/flake8 provelobern

.PHONY: install
install: build install-dev-egg .build/node_modules.timestamp

.PHONY: lint
lint: .build/venv/bin/gjslint .build/node_modules.timestamp .build/gjslint.timestamp .build/jshint.timestamp

.PHONY: install-dev-egg
install-dev-egg: $(SITE_PACKAGES)/provelobern.egg-link

.PHONY: serve
serve: install build common.ini
	.build/venv/bin/pserve --reload development.ini

.PHONY: update-node-modules
update-node-modules:
	npm install --force

provelobern/closure/%.py: $(CLOSURE_LIBRARY_PATH)/closure/bin/build/%.py
	cp $< $@

provelobern/locale/provelobern-client.pot: $(APP_HTML_FILES) $(APP_JS_FILES)
	node tasks/extract-messages.js $^ > $@

provelobern/locale/de/LC_MESSAGES/provelobern-client.po: provelobern/locale/provelobern-client.pot
	cd provelobern/locale && msgmerge --update de/LC_MESSAGES/provelobern-client.po provelobern-client.pot

provelobern/static/build/build.js: build.json $(OL_JS_FILES) $(NGEO_JS_FILES) $(APP_JS_FILES) .build/externs/angular-1.3.js .build/externs/angular-1.3-q.js .build/externs/angular-1.3-http-promise.js .build/node_modules.timestamp
	mkdir -p $(dir $@)
	node tasks/build.js $< $@

provelobern/static/build/build.min.css: $(LESS_FILES) .build/node_modules.timestamp
	mkdir -p $(dir $@)
	./node_modules/.bin/lessc --clean-css less/provelobern.less > $@

provelobern/static/build/build.css: $(LESS_FILES) .build/node_modules.timestamp
	mkdir -p $(dir $@)
	./node_modules/.bin/lessc less/provelobern.less > $@

provelobern/static/build/locale/de/provelobern.json: provelobern/locale/de/LC_MESSAGES/provelobern-client.po
	mkdir -p $(dir $@)
	node tasks/compile-catalog $< > $@

.build/externs/angular-1.3.js:
	mkdir -p $(dir $@)
	wget -O $@ https://raw.githubusercontent.com/google/closure-compiler/master/contrib/externs/angular-1.3.js
	touch $@

.build/externs/angular-1.3-q.js:
	mkdir -p $(dir $@)
	wget -O $@ https://raw.githubusercontent.com/google/closure-compiler/master/contrib/externs/angular-1.3-q.js
	touch $@

.build/externs/angular-1.3-http-promise.js:
	mkdir -p $(dir $@)
	wget -O $@ https://raw.githubusercontent.com/google/closure-compiler/master/contrib/externs/angular-1.3-http-promise.js
	touch $@

.build/node_modules.timestamp: package.json
	mkdir -p $(dir $@)
	npm install
	touch $@

.build/gjslint.timestamp: $(APP_JS_FILES)
	.build/venv/bin/gjslint --jslint_error=all --strict --custom_jsdoc_tags=event,fires,function,classdesc,api,observable $?
	touch $@

.build/jshint.timestamp: $(APP_JS_FILES)
	./node_modules/.bin/jshint --verbose $?
	touch $@

.build/venv/bin/gjslint: .build/dev-requirements.timestamp

.build/venv/bin/flake8: .build/dev-requirements.timestamp

.build/dev-requirements.timestamp: .build/venv
	.build/venv/bin/pip install -r dev-requirements.txt > /dev/null 2>&1
	touch $@

.build/venv:
	mkdir -p $(dir $@)
	virtualenv --no-site-packages $@

$(SITE PACKAGES)/provelobern.egg-link: .build/venv setup.py
	.build/venv/bin/pip install -r requirements.txt

common.ini: common.ini.in
	sed 's|__CLOSURE_LIBRARY_PATH__|$(CLOSURE_LIBRARY_PATH)|' $< > $@

.PHONY: modwsgi
modwsgi: install .build/venv/provelobern.wsgi .build/apache.conf

.build/venv/provelobern.wsgi: provelobern.wsgi
	sed 's#{{DIR}}#$(CURDIR)#' $< > $@
	chmod 755 $@

.build/apache.conf: apache.conf .build/venv
	sed -e 's#{{PYTHONPATH}}#$(shell .build/venv/bin/python -c "import distutils; print(distutils.sysconfig.get_python_lib())")#' \
		-e 's#{{WSGISCRIPT}}#$(abspath .build/venv/provelobern.wsgi)#' $< > $@
