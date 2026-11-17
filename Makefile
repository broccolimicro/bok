.PHONY: gdstk googletest lib install coverage-all coverage-collect coverage-report

ifeq ($(OS),Windows_NT)
    UNAME_S := $(OS)
else
    UNAME_S := $(shell uname -s)
endif

# Use + instead of spaces in the below list
LIBS = \
	lib/common \
	lib/parse \
	lib/parse_expression \
	lib/parse_prs \
	lib/parse_spice \
	lib/parse_astg \
	lib/parse_dot \
	lib/parse_gc \
	lib/parse_chp \
	lib/parse_cog \
	lib/parse_choy \
	lib/parse_verilog \
	lib/boolean \
	lib/arithmetic \
	lib/phy \
	lib/sch \
	lib/verilog \
	lib/prs \
	lib/petri \
	lib/hse \
	lib/gc \
	lib/chp \
	lib/flow \
	lib/choy \
	lib/interpret_boolean \
	lib/interpret_arithmetic \
	lib/interpret_phy \
	lib/interpret_sch \
	lib/interpret_verilog \
	lib/interpret_prs \
	lib/interpret_hse \
	lib/interpret_gc \
	lib/interpret_chp \
	lib/interpret_flow \
	lib/interpret_choy \
	bin/ckt

COVERAGE_INFOS := $(LIBS:%=%/coverage_%*.info)

MAINTAINER_NAME = "$(shell git config user.name)"
MAINTAINER_EMAIL = "$(shell git config user.email)"

all: lib
	cp bin/ckt/bok .

version:
	@git fetch --tags --no-recurse-submodules
	@git fetch origin $(shell git rev-list --tags --max-count=1)
	@git describe --tags --abbrev=0 | cut -c2- > VERSION

linux: lib
	mkdir -p bok-linux/usr/local/bin
	cp bin/ckt/bok bok-linux/usr/local/bin
	mkdir -p bok-linux/usr/local/share/
	cp -r tech bok-linux/usr/local/share
	mkdir -p bok-linux/DEBIAN
	mkdir -p debian
	touch debian/control
	echo "Package: bok" > bok-linux/DEBIAN/control
	cat VERSION | sed 's/\([0-9]\+\)\.\([0-9]\+\)\.\([0-9]\+\)/\1.\2-\3/g' | xargs -I{} echo "Version: {}" >> bok-linux/DEBIAN/control
	echo "Section: base" >> bok-linux/DEBIAN/control
	echo "Priority: optional" >> bok-linux/DEBIAN/control
	echo "Architecture: amd64" >> bok-linux/DEBIAN/control
	dpkg-shlibdeps -O bok-linux/usr/local/bin/bok | sed 's/.*Depends=/Depends: /g' >> bok-linux/DEBIAN/control
	echo "Maintainer: $(MAINTAINER_NAME) <$(MAINTAINER_EMAIL)>" >> bok-linux/DEBIAN/control
	echo "Description: Bok" >> bok-linux/DEBIAN/control
	echo " A programming language for quasi-delay insensitive asynchronous circuits" >> bok-linux/DEBIAN/control
	dpkg-deb --build --root-owner-group bok-linux
	rm -rf debian bok-linux

windows: lib
	mkdir -p Bok/bin
	mkdir -p Bok/share
	cp bin/ckt/bok.exe Bok/bin/bok.exe
	cp -r tech Bok/share/tech
	ldd Bok/bin/bok.exe | grep "mingw64" | sed 's/.*\/mingw64/\/mingw64/g' | sed 's/ (.*$$//g' | xargs -I{} cp {} Bok/bin
	zip -r bok-windows.zip Bok
	rm -rf Bok

macos: lib
	mkdir -p bok-macos/bin
	mkdir -p bok-macos/share
	cp bin/ckt/bok bok-macos/bin/bok
	cp -r tech bok-macos/share/tech
	tar -czvf bok-macos.tar.gz bok-macos

lib: gdstk
	@$(foreach item,$(LIBS),echo "$(subst +, ,$(item))"; $(MAKE) VERSION="v$(shell cat VERSION)" -s $(MAKE_FLAGS) -C $(subst +, ,$(item));)

wasm:
	@$(foreach item,$(LIBS),echo "$(subst +, ,$(item))"; $(MAKE) VERSION="v$(shell cat VERSION)" -s $(MAKE_FLAGS) -C $(subst +, ,$(item)) wasm;)

test: googletest
	@$(foreach item,$(LIBS),echo "$(subst +, ,$(item))"; $(MAKE) -s $(MAKE_FLAGS) -C $(subst +, ,$(item)) test;)

ifeq ($(UNAME_S),Darwin)
gdstk:
	grep "CMAKE_OSX_DEPLOYMENT_TARGET" lib/gdstk/Makefile || ( \
		mv lib/gdstk/Makefile lib/gdstk/Makefile_old; \
		sed 's/Ninja/Ninja \-DCMAKE_OSX_DEPLOYMENT_TARGET\=15\.0/g' lib/gdstk/Makefile_old > lib/gdstk/Makefile; \
		mv lib/gdstk/CMakeLists.txt lib/gdstk/CMakeLists.txt_old; \
		sed 's/-mmacosx-version-min\=[0-9][0-9]\.[0-9]/-mmacosx-version-min\=15\.0/g' lib/gdstk/CMakeLists.txt_old > lib/gdstk/CMakeLists.txt)
	$(MAKE) -s $(MAKE_FLAGS) -C lib/gdstk lib
else ifeq ($(UNAME_S),Windows_NT)
gdstk:
	grep "CMAKE_PREFIX_PATH" lib/gdstk/Makefile || ( \
		mv lib/gdstk/Makefile lib/gdstk/Makefile_old; \
		sed 's/Ninja/Ninja \-DCMAKE_PREFIX_PATH\="\/mingw64\/"/g' lib/gdstk/Makefile_old > lib/gdstk/Makefile)
	$(MAKE) -s $(MAKE_FLAGS) -C lib/gdstk lib
else
gdstk:
	$(MAKE) -s $(MAKE_FLAGS) -C lib/gdstk lib
endif

googletest:
	mkdir -p googletest/build; cd googletest/build; cmake .. -DBUILD_GMOCK=OFF
	$(MAKE) -s $(MAKE_FLAGS) -C googletest/build

coverage: coverage-collect
	genhtml coverage_merged.info --output-directory coverage_report_all

coverage-collect: coverage-build
	@rm -f coverage_merged.info
	@$(foreach item,$(LIBS), \
		echo "== Coverage: $(item) =="; \
		$(MAKE) -s $(MAKE_FLAGS) -C $(subst +, ,$(item)) coverage; \
		lcov -a coverage_merged.info \
		     -a $(item)/coverage_filtered.info \
		     -o coverage_merged.info || \
		cp $(item)/coverage_filtered.info coverage_merged.info; \
	)

coverage-build:
	@$(foreach item,$(LIBS),echo "$(subst +, ,$(item))"; $(MAKE) -s $(MAKE_FLAGS) -C $(subst +, ,$(item)) COVERAGE=1;)

check:	
	@$(foreach item,$(LIBS),echo "$(subst +, ,$(item))"; ./$(subst +, ,$(item))/test;)

clean:
	@$(foreach item,$(LIBS),echo "$(subst +, ,$(item))"; $(MAKE) -s $(MAKE_FLAGS) -C $(subst +, ,$(item)) clean;)
ifeq ($(UNAME_S),Darwin)
	rm -rf bok-macos bok-macos.tar.gz
endif
