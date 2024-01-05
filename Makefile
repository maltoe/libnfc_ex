SRCDIR=src
DSTDIR=priv

ERLANG_PATH=$(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)

CFLAGS=-std=c11 -g -O2 -Wall -Wextra -Wno-unused-parameter -Wmissing-prototypes

ifneq ($(OS),Windows_NT)
CFLAGS += -fPIC
endif

ifeq ($(shell uname),Darwin)
LDFLAGS=-dynamiclib -undefined dynamic_lookup
else
LDFLAGS=-Wl,--no-as-needed
endif

CFLAGS += -I$(ERLANG_PATH) $(shell pkg-config --cflags libnfc)
LDFLAGS += $(shell pkg-config --libs libnfc)

.PHONY: check clean

all: $(DSTDIR)/libnfc_nif.so

$(DSTDIR)/libnfc_nif.so: $(SRCDIR)/libnfc_nif.c
	$(CC) $(CFLAGS) $(LDFLAGS) -shared -o $@ $(SRCDIR)/libnfc_nif.c

check:
	cppcheck --enable=all --library=posix --suppress=missingIncludeSystem src/libnfc_nif.c

clean:
	rm -f priv/libnfc_nif.so*
