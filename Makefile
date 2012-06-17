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
WISH4.1 = /usr/local/bin/wish4.1
WISH4.2 = /usr/local/bin/wish4.2
WISH8.0 = /usr/local/bin/wish8.0
WISH8.3	= /usr/local/bin/wish8.3
WISH = $(WISH8.3)

# ---------------- NO NEED TO CHANGE ANYTHING BELOW THIS LINE ---------------

EXECUTABLE = tkMOO-lite
LIB_FILES = plugins
# WORLDS_FILE = dot.worlds.tkm
BIN_FILES = $(EXECUTABLE)

all: executable 

# some shells are set 'noclobber', so force overwriting of the
# executable and installation
clean:
	\rm -f $(EXECUTABLE)
	\rm -f $(TKMOO_BIN_DIR)/$(EXECUTABLE)

executable: clean
	if [ ! -e $(WISH) ]; then \
	    echo "***"; \
	    echo "*** Can't find executable '$(WISH)', building anyway..."; \
	    echo "*** You can set the correct path for the wish executable"; \
	    echo "*** by editing the variable 'WISH' in this Makefile"; \
	    echo "***"; \
	fi
	echo "#!$(WISH)" > $(EXECUTABLE)
	echo "set tkmooLibrary $(TKMOO_LIB_DIR)" >> $(EXECUTABLE)
	cat ./source.tcl >> $(EXECUTABLE)
	# r-xr-xr-x
	chmod 0555 $(EXECUTABLE)

install: $(EXECUTABLE)
	-mkdir -p $(TKMOO_LIB_DIR)
	-cp -fr $(LIB_FILES) $(TKMOO_LIB_DIR)
	-mkdir -p $(TKMOO_BIN_DIR)
	cp -fr $(BIN_FILES) $(TKMOO_BIN_DIR)
