#!/usr/bin/make -f

PACKAGES= 

NUM_CPUS ?= $(shell grep -c '^processor' /proc/cpuinfo)

ARCH_NAME := $(shell '$(TRGT)gcc' -dumpmachine)

TRGT?=

CC   = $(TRGT)gcc
CXX  = $(TRGT)g++
AS   = $(TRGT)gcc -x assembler-with-cpp

LD   = $(TRGT)g++
AR   = $(TRGT)ar rvc

RM= rm --force --verbose

PKGCONFIG= pkg-config

ifndef PACKAGES
PKG_CONFIG_CFLAGS=
PKG_CONFIG_LDFLAGS=
PKG_CONFIG_LIBS=
else
PKG_CONFIG_CFLAGS=`pkg-config --cflags $(PACKAGES)`
PKG_CONFIG_LDFLAGS=`pkg-config --libs-only-L $(PACKAGES)`
PKG_CONFIG_LIBS=`pkg-config --libs-only-l $(PACKAGES)`
endif

CFLAGS= \
	-Wall \
	-fwrapv \
	-fstack-protector-strong \
	-Wall \
	-Wno-unused-function \
	-Wno-unused-variable \
	-Wformat \
	-Werror=format-security \
	-Wdate-time \
	-D_FORTIFY_SOURCE=2 \
	-rdynamic \
	-fPIC

LDFLAGS= \
	-Wl,-O1 \
	-Wl,-Bsymbolic-functions \
	-Wl,-z,relro \
	-Wl,--as-needed \
	-Wl,--dynamic-list-cpp-new \
	-Wl,--dynamic-list-cpp-typeinfo

CSTD=-std=gnu17
CPPSTD=-std=gnu++17

OPTS= -O2 -g

DEFS= \
	-DDEBUG \
	-D_LARGEFILE64_SOURCE \
	-D_FILE_OFFSET_BITS=64 \
	-DGL_GLEXT_PROTOTYPES \
	-DAS_USE_NAMESPACE

INCS= -Iinclude/

LIBS= -langelscript -langelscript-addon -lm

BUILD_DIR  = build

all: $(BUILD_DIR)/aatc-test.bin $(BUILD_DIR)/libaatc.a $(BUILD_DIR)/libaatc.so


LIB_SRC_DIRS = source/

LIB_C_SRCS := $(foreach DIR,$(LIB_SRC_DIRS),$(wildcard $(DIR)*.c))
LIB_C_OBJS := ${addprefix $(BUILD_DIR)/, $(LIB_C_SRCS:.c=.o)}

LIB_CPP_SRCS := $(foreach DIR,$(LIB_SRC_DIRS),$(wildcard $(DIR)*.cpp))
LIB_CPP_OBJS := ${addprefix $(BUILD_DIR)/, $(LIB_CPP_SRCS:.cpp=.o)}

LIB_OBJS := $(LIB_C_OBJS) $(LIB_CPP_OBJS)
LIB_DEPS := $(LIB_C_DEPS) $(LIB_CPP_DEPS)

SONAME_MAJOR := 0
SONAME_MINOR := 1

$(BUILD_DIR)/libaatc.a: $(LIB_OBJS)

$(BUILD_DIR)/libaatc.so.$(SONAME_MAJOR).$(SONAME_MINOR): $(LIB_OBJS)


EXE_SRC_DIRS = test/

EXE_C_SRCS := $(foreach DIR,$(EXE_SRC_DIRS),$(wildcard $(DIR)*.c))
EXE_C_OBJS := ${addprefix $(BUILD_DIR)/, $(EXE_C_SRCS:.c=.o)}

EXE_CPP_SRCS := $(foreach DIR,$(EXE_SRC_DIRS),$(wildcard $(DIR)*.cpp))
EXE_CPP_OBJS := ${addprefix $(BUILD_DIR)/, $(EXE_CPP_SRCS:.cpp=.o)}

EXE_OBJS := $(EXE_C_OBJS) $(EXE_CPP_OBJS)
EXE_DEPS := $(EXE_C_DEPS) $(EXE_CPP_DEPS)

$(BUILD_DIR)/aatc-test.bin: $(EXE_OBJS) $(BUILD_DIR)/libaatc.a


$(BUILD_DIR)/%.bin:
	@mkdir -p "$(dir $@)"
	$(LD) $(CPPSTD) $(CSTD) $(LDFLAGS) $(PKG_CONFIG_LDFLAGS) \
		-o $@ $^ $(LIBS) $(PKG_CONFIG_LIBS)

$(BUILD_DIR)/lib%.a:
	@mkdir -p "$(dir $@)"
	$(AR) $@ $^

$(BUILD_DIR)/lib%.so: $(BUILD_DIR)/lib%.so.$(SONAME_MAJOR).$(SONAME_MINOR)
	@mkdir -p "$(dir $@)"
	cd $(dir $@) && rm -f $(notdir $@.$(SONAME_MAJOR))
	cd $(dir $@) && ln -s $(notdir $@.$(SONAME_MAJOR).$(SONAME_MINOR) $@.$(SONAME_MAJOR))
	cd $(dir $@) && rm -f $(notdir $@)
	cd $(dir $@) && ln -s $(notdir $@.$(SONAME_MAJOR) $@)

$(BUILD_DIR)/lib%.so.$(SONAME_MAJOR).$(SONAME_MINOR):
	@mkdir -p "$(dir $@)"
	$(LD) -shared $(CPPSTD) $(CSTD) $(LDFLAGS) $(PKG_CONFIG_LDFLAGS) \
		-Wl,-soname,$(notdir $(basename $@)) \
		-o $@ $^ $(LIBS) $(PKG_CONFIG_LIBS)

$(BUILD_DIR)/%.so:
	@mkdir -p "$(dir $@)"
	$(LD) -shared $(CPPSTD) $(CSTD) $(LDFLAGS) $(PKG_CONFIG_LDFLAGS) \
		-o $@ $^ $(LIBS) $(PKG_CONFIG_LIBS)

$(BUILD_DIR)/%.o: ./%.cpp
	@mkdir -p "$(dir $@)"
	$(CXX) $(CPPSTD) $(OPTS) -o $@ -c $< \
		$(DEFS) $(INCS) $(CFLAGS) $(PKG_CONFIG_CFLAGS)

$(BUILD_DIR)/%.o: ./%.c
	@mkdir -p "$(dir $@)"
	$(CC) $(CSTD) $(OPTS) -o $@ -c $< \
		$(DEFS) $(INCS) $(CFLAGS) $(PKG_CONFIG_CFLAGS)

clean:
	@find . -name '*.bin' -exec $(RM) {} +
	@find . -name '*.o' -exec $(RM) {} +
	@find . -name '*.a' -exec $(RM) {} +
	@find . -name '*.so' -exec $(RM) {} +
	@find . -name '*.so.*' -exec $(RM) {} +
	@find . -name '*.out' -exec $(RM) {} +
	@find . -name '*.pyc' -exec $(RM) {} +
	@find . -name '*.pyo' -exec $(RM) {} +
	@find . -name '*.bak' -exec $(RM) {} +
	@find . -name '*~' -exec $(RM) {} +
	@$(RM) core log

DEPS := $(LIB_C_OBJS:.o=.d) $(LIB_CPP_OBJS:.o=.d) $(EXE_C_OBJS:.o=.d) $(EXE_CPP_OBJS:.o=.d)

info:
	@echo LIB_OBJS: $(LIB_OBJS)
	@echo EXE_OBJS: $(EXE_OBJS)
	@echo DEPS: $(DEPS)
	@echo CFLAGS: $(CFLAGS) $(PKG_CONFIG_CFLAGS)
	@echo LDFLAGS: $(LDFLAGS)
	@echo LIBS: $(LDFLAGS)

.PHONY: all info clean

-include $(DEPS)
