# directories
TARGET_DIR := ./priv
SRC_DIR := ./c_src
SPICE_DIR := $(SRC_DIR)/vendor/cspice
SPICE_INCLUDE_DIR := $(SPICE_DIR)/include
SPICE_LIB_DIR := $(SPICE_DIR)/lib

# compilation
# Make's built-in CC default is `cc`, so `?=` would never pick gcc; honor an
# externally supplied CC (environment or command line) instead.
ifeq ($(origin CC),default)
CC = gcc
endif
TARGET := $(TARGET_DIR)/ex_astro_nif.so
SOURCES := nif.c utils.c kernel.c kernel_pool.c time.c time_spice.c ephemeris.c support.c star.c
OBJECTS := $(SOURCES:%.c=$(SRC_DIR)/%.o)
HEADERS := $(wildcard $(SRC_DIR)/*.h)
SPICE_HEADERS := $(wildcard $(SPICE_INCLUDE_DIR)/*.h)
SPICE_LIBS := $(SPICE_LIB_DIR)/cspice.a $(SPICE_LIB_DIR)/csupport.a

# Erlang headers (env variable comes from :elixir_make dependency)
CFLAGS += -I$(ERTS_INCLUDE_DIR)

# First-party C warning policy. Keep warnings focused on project-owned NIF
# sources; vendored CSPICE is linked from its prebuilt static libraries.
CFLAGS += -O2 -fPIC -finline-functions -fvisibility=hidden
CFLAGS += -Wall -Wextra -Wmissing-prototypes -Wstrict-prototypes -Wold-style-definition
CFLAGS += -Wint-conversion -Wpointer-arith -Wcast-function-type -Wvla
CFLAGS += -Walloc-size-larger-than=1048576
CFLAGS += -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -Werror=vla
# NIF callbacks have fixed signatures; unused argc/priv fields are intentional.
CFLAGS += -Wno-unused-parameter

# C SPICE libraries
CFLAGS += -I$(SPICE_INCLUDE_DIR)
# Bind this object's CSPICE symbols against interposition by other loaded NIFs.
LDFLAGS += -Wl,-Bsymbolic
LDFLAGS += $(SPICE_LIBS)

# ERFA libraries
LDFLAGS += -lerfa

.PHONY: all check-platform clean
all: check-platform $(TARGET)

check-platform:
	@if [ "$$(uname -s)-$$(uname -m)" != "Linux-x86_64" ]; then \
	  echo "ex_astro: vendored CSPICE supports only Linux x86_64" >&2; exit 1; fi

# Makefile is a prerequisite so flag changes rebuild objects and the library.
$(TARGET): $(OBJECTS) $(SPICE_LIBS) Makefile | check-platform
	@mkdir -p $(@D)
	$(CC) $(OBJECTS) -shared -o $@ $(LDFLAGS)

$(SRC_DIR)/%.o: $(SRC_DIR)/%.c $(HEADERS) $(SPICE_HEADERS) Makefile | check-platform
	$(CC) $(CFLAGS) -c -o $@ $<

# cleaning

clean:
	@rm -f $(TARGET_DIR)/*.so $(SRC_DIR)/*.o

