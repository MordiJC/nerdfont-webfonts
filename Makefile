#!/usr/bin/env make

ifeq (${TOKEN},)
FONTS_URL_LIST := $(shell curl -Ls https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | jq -r '.assets | map(.browser_download_url) | @sh')
else
FONTS_URL_LIST := $(shell curl -H "Authorization: token ${TOKEN}" -Ls https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | jq -r '.assets | map(.browser_download_url) | @sh')
endif

FONTS_URL_LIST := $(foreach url,${FONTS_URL_LIST},$(subst ',,${url}))
FONTS_URL_LIST := $(filter-out %FontPatcher.zip,${FONTS_URL_LIST})
FONTS_URL_LIST := $(filter %.zip %.tar.gz %tar.xz %.tar.bz2 %.tar.zst,${FONTS_URL_LIST})

WORKDIR ?= workdir
BUILDDIR = build

$(shell mkdir -p ${BUILDDIR}/fonts)

.SECONDEXPANSION:

url_to_filename = $(shell basename $$(printf "%s" "$(1)" | tr "\"'" -d ))
url_to_basename = $(basename $(call url_to_filename,$(1)))

download-target-name = ${WORKDIR}/$(call url_to_filename,$(1))
extract-target-name = ${WORKDIR}/$(call url_to_basename,$(1))
convert-target-name = convert-$(call url_to_basename,$(1))
generate-target-name = generate-$(call url_to_basename,$(1))

# $1 - Font URL
define font-generator-template
# Download
$(call download-target-name,$(1)):
	echo "Download $$@"
	mkdir -p $$(dir $$@)
	curl -L -o $$@ "$(1)"

# Github will block too many requests at the same time
.NOTPARALLEL: $(call download-target-name, $(1))

# Extract
$(call extract-target-name, $(1)): $(call download-target-name,$(1))
	echo "Extracting $$< -> $$@"
	mkdir -p $$@
	aunpack -X $$@ $$<
	find $$@ -type f -iname "*Windows Compatible*" -delete

# Convert
$(call convert-target-name,$(1)): $(call extract-target-name,$(1))
	echo "Converting $$@"
	for file in ${WORKDIR}/$(call url_to_basename,$(1))/*.otf ; do \
		if [ -f "$$$$file" ]; then \
			echo "Converting file $$$$file to TTF"; \
			fontforge -quiet -lang=ff -c "Open(\$$$$1); Generate(\$$$$1:r + \".ttf\")" "$$$$file" 2>/dev/null ; \
		fi \
	done
	for file in ${WORKDIR}/$(call url_to_basename,$(1))/*.ttf ; do \
		if [ -f "$$$$file" ]; then \
			echo "Converting file $$$$file to WOFF2"; \
			fontforge -quiet -lang=ff -c "Open(\$$$$1); Generate(\$$$$1:r + \".woff2\")" "$$$$file" 2>/dev/null ; \
		fi \
	done

$(call generate-target-name,$(1)): $(call convert-target-name,$(1))
	echo "Generating $(call url_to_basename,$(1))"
	for file in "${WORKDIR}/$(call url_to_basename,$(1))"/*.ttf ; do \
		./gen_css_helper.sh "$(call url_to_basename,$(1))" "$$$$file" "${BUILDDIR}"; \
		cp "$$$$file" "${BUILDDIR}/fonts/" || echo >&2 "Failed to copy $$$$file"; \
	done
	for file in "${WORKDIR}/$(call url_to_basename,$(1))"/*.woff2 ; do \
		cp "$$$$file" "${BUILDDIR}/fonts" || echo>&2  "Failed to copy $$$$file"; \
	done

endef

$(foreach url,${FONTS_URL_LIST},$(eval $(call font-generator-template,$(subst ",,$(subst ',,${url})))))

clean:
	rm -r "${WORKDIR}/*"

download: $(foreach url,${FONTS_URL_LIST}, $(call download-target-name,$(subst ",,$(subst ',,${url}))))

extract: $(foreach url,${FONTS_URL_LIST}, $(call extract-target-name,$(subst ",,$(subst ',,${url}))))

convect: $(foreach url,${FONTS_URL_LIST}, $(call convect-target-name,$(subst ",,$(subst ',,${url}))))

generate: $(foreach url,${FONTS_URL_LIST}, $(call generate-target-name,$(subst ",,$(subst ',,${url}))))


build: download extract convert generate
	echo > ${BUILDDIR}/nerdfont-webfonts.css
	for file in ${BUILDDIR}/*.css; do \
		if [[ $file != ${BUILDDIR}/nerdfont-webfonts .css]]; then\
			cat $$file >> ${BUILDDIR}/nerdfont-webfonts.css; \
		fi \
	done
	echo "Build complete"

.PHONY: clean doenload extract convert generate build

