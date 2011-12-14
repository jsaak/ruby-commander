INSTALL    = /usr/bin/install -c
PREFIX     = $(DESTDIR)/usr
GLADEPATH  = $(PREFIX)/share/ruby-commander/glade/
LIBPATH    = $(PREFIX)/lib/ruby/1.8/ruby-commander/
BINPATH    = $(PREFIX)/bin/

clean:

configure:

install:
	mkdir -p $(BINPATH)
	${INSTALL} -m 0755 rc $(BINPATH)
	mkdir -p $(LIBPATH)
	${INSTALL} -m 0644 commander.rb $(LIBPATH)
	${INSTALL} -m 0644 local.rb $(LIBPATH)
	${INSTALL} -m 0644 mplayer.rb $(LIBPATH)
	${INSTALL} -m 0644 bookmark.rb $(LIBPATH)
	mkdir -p $(GLADEPATH)
	${INSTALL} -m 0644 gui.glade $(GLADEPATH)
	${INSTALL} -m 0644 local.glade $(GLADEPATH)
	${INSTALL} -m 0644 mplayer.glade $(GLADEPATH)
	${INSTALL} -m 0644 bookmark.glade $(GLADEPATH)

all: build

build:

.PHONY: clean configure install build all
