ARCHIVE_NAME = cspice.tar.Z
ARCHIVE_URL = https://naif.jpl.nasa.gov/pub/naif/toolkit//C/PC_Linux_GCC_64bit/packages/$(ARCHIVE_NAME)

# directories
TARGET_DIR := ./priv
SRC_DIR := ./c_src
SPICE_SRC_DIR = $(SRC_DIR)/cspice

# compilation
CC = gcc

# Erlang headers (env variable comes from :elixir_make dependency)
CFLAGS += -I$(ERTS_INCLUDE_DIR)

# First-party C warning policy. Keep warnings focused on project-owned NIF
# sources; vendored CSPICE is linked from its prebuilt archive below.
CFLAGS += -fPIC -finline-functions
CFLAGS += -Wall -Wextra -Wmissing-prototypes -Wstrict-prototypes -Wold-style-definition
CFLAGS += -Wint-conversion -Wpointer-arith -Wcast-function-type -Wvla
CFLAGS += -Walloc-size-larger-than=1048576
CFLAGS += -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -Werror=vla
# NIF callbacks have fixed signatures; unused argc/priv fields are intentional.
CFLAGS += -Wno-unused-parameter

# C SPICE libraries
CFLAGS += -I$(SPICE_SRC_DIR)/include
# Keep each NIF bound to its own statically linked CSPICE copy and mutex.
LDFLAGS += -Wl,-Bsymbolic
LDFLAGS += -L$(SPICE_SRC_DIR)/lib -l:cspice.a -l:csupport.a

# ERFA libraries
LDFLAGS += -lerfa -lgmp

.PHONY: all
all: $(TARGET_DIR)/time.so $(TARGET_DIR)/ephemeris.so $(TARGET_DIR)/support.so

# NIFs compilation

$(TARGET_DIR)/%.so: $(SRC_DIR)/%.c $(SRC_DIR)/utils.h $(SPICE_SRC_DIR)/lib/cspice.a
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -shared -o $@ $< $(LDFLAGS)

$(SPICE_SRC_DIR)/lib/cspice.a:
	@rm -rf $(SPICE_SRC_DIR)
	echo "Downloading library files..."
	@wget $(ARCHIVE_URL)
	echo "Extracting files..."
	@gzip -d $(ARCHIVE_NAME)
	@tar xfv cspice.tar
	@mv cspice $(SRC_DIR)
	@rm cspice.tar

# cleaning

.PHONY: clean
clean:
	@rm -f $(TARGET_DIR)/*.so
	@rm -rf $(SPICE_SRC_DIR)
