#!/bin/sh
#
#	tkMOO
#	Makefile
#

# where will the client's support files be installed?
# ... in the '.tkMOO-lite' directory under your home directory
# ** if you change this value then you'll need to set your TKMOO_LIB_DIR
# ** environment variable to the same value
TKMOO_LIB_DIR = $(HOME)/.tkMOO-lite

# where will the executable be installed?
# ... in the 'bin' directory under your home directory
TKMOO_BIN_DIR = $(HOME)/bin

# which version of WISH will the client use? 'make' will warn you
# if WISH can't be found where you say it is.
WISH = /usr/bin/wish

# ---------------- NO NEED TO CHANGE ANYTHING BELOW THIS LINE ---------------

EXECUTABLE = tkMOO-lite-PLGd
LIB_FILES = plugins
# WORLDS_FILE = dot.worlds.tkm
BIN_FILES = $(EXECUTABLE)

all: executable 

# some shells are set 'noclobber', so force overwriting of the
# executable and installation
clean:
	rm -f $(EXECUTABLE)
	rm -f $(TKMOO_BIN_DIR)/$(EXECUTABLE)

executable: clean
	@if [ ! -h $(WISH) ]; then \
	    echo "***"; \
	    echo "*** Can't find executable '$(WISH)', building anyway..."; \
	    echo "*** You can set the correct path for the wish executable"; \
	    echo "*** by editing the variable 'WISH' in this Makefile"; \
	    echo "***"; \
	fi
	echo "#!/bin/sh" >> $(EXECUTABLE)
	echo "# the next line restarts using wish \\" >> $(EXECUTABLE)
	echo 'exec wish "$$0" "$$@"\n' >> $(EXECUTABLE)
	echo "set tkmooLibrary $(TKMOO_LIB_DIR)\n" >> $(EXECUTABLE)
	cat ./source.tcl >> $(EXECUTABLE)
	chmod 0755 $(EXECUTABLE)

install: $(EXECUTABLE)
	-mkdir -p $(TKMOO_LIB_DIR)
	-cp -fr $(LIB_FILES) $(TKMOO_LIB_DIR)
	-mkdir -p $(TKMOO_BIN_DIR)
	cp -fr $(BIN_FILES) $(TKMOO_BIN_DIR)
