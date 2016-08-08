export PATH := tools:$(PATH)

NEARBY_FILES=index.lua bookmark.png \
	external/gentium_regular.ttf external/gentium_italic.ttf

all: cia 3dsx

dist: build/drider.tar.gz build/drider.zip

cia: build/drider.cia

3dsx: $(NEARBY_FILES) build/drider.smdh
	@mkdir -p build/3ds/drider
	@mkdir -p build/books
	cp -f $(NEARBY_FILES) build/3ds/drider/
	cp -f build/drider.smdh build/3ds/drider/
	cp -f external/lpp-3ds.3dsx build/3ds/drider/drider.3dsx

upload: cia
	java -jar tools/sockfile* 192.168.0.12 build/drider.cia

clean:
	rm -rf build

.PHONY: all cia 3dsx upload clean


build/drider.tar.gz: build/drider.cia 3dsx
	tar --create --file $@ \
		build/drider.cia \
		build/3ds

build/drider.zip: build/drider.cia 3dsx
	rm -f build/drider.zip
	cd build && zip -r drider.zip drider.cia 3ds

build/drider.bnr: banner.png jingle.wav
	@mkdir -p $(@D)
	bannertool makebanner --output $@ \
		--image banner.png \
		--audio jingle.wav

build/drider.smdh: icon.png
	@mkdir -p $(@D)
	bannertool makesmdh --output $@ \
		--shorttitle "Drider" \
		--longtitle "Drider epub reader" \
		--publisher "ingolemo" \
		--icon icon.png

build/romfs.bin: $(NEARBY_FILES)
	@mkdir -p build/romfs
	cp -f $^ build/romfs/
	3dstool --file $@ \
		--create --type romfs \
		--romfs-dir build/romfs

build/drider.cia: build/romfs.bin build/drider.bnr drider.rsf build/drider.smdh
	makerom -o $@ \
		-f cia \
		-elf external/lpp-3ds.elf \
		-rsf drider.rsf \
		-romfs build/romfs.bin \
		-banner build/drider.bnr \
		-icon build/drider.smdh
