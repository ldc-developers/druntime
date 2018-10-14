/**
 * This code reads ELF files and sections using memory mapped IO.
 *
 * Reference: http://www.dwarfstd.org/
 *
 * Copyright: Copyright Digital Mars 2015 - 2015.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Yazan Dabain
 * Source: $(DRUNTIMESRC rt/backtrace/elf.d)
 */

module rt.backtrace.elf;

version(linux) version = linux_or_bsd;
else version(FreeBSD) version = linux_or_bsd;
else version(DragonFlyBSD) version = linux_or_bsd;

version(linux_or_bsd):

import core.elf;

version(linux) import core.sys.linux.elf;
version(FreeBSD) import core.sys.freebsd.sys.elf;
version(DragonFlyBSD) import core.sys.dragonflybsd.sys.elf;

struct Image
{
    private ElfFile file;

    static Image openSelf()
    {
        const(char)* selfPath;
        foreach (object; SharedObjects)
        {
            // the first object is the main binary
            selfPath = object.name().ptr;
            break;
        }

        Image image;
        if (!ElfFile.open(selfPath, image.file))
            image.file = ElfFile.init;

        return image;
    }

    @property bool isValid()
    {
        return file != ElfFile.init;
    }

    const(ubyte)[] getDebugLineSectionData()
    {
        ElfSectionHeader dbgSectionHeader;
        if (!file.findSectionHeaderByName(".debug_line", dbgSectionHeader))
            return null;

        // we don't support compressed debug sections
        if ((dbgSectionHeader.shdr.sh_flags & SHF_COMPRESSED) != 0)
            return null;

        auto dbgSection = ElfSection(file, dbgSectionHeader);
        const sectionData = cast(const(ubyte)[]) dbgSection.get();
        // do not munmap() the section data to be returned
        import core.stdc.string;
        ElfSection initialSection;
        memcpy(&dbgSection, &initialSection, ElfSection.sizeof);

        return sectionData;
    }

    @property size_t baseAddress()
    {
        // the DWARF addresses for DSOs are relative
        const isDynamicSharedObject = (file.ehdr.e_type == ET_DYN);
        if (!isDynamicSharedObject)
            return 0;

        size_t base = 0;
        foreach (object; SharedObjects)
        {
            // only take the first address as this will be the main binary
            base = cast(size_t) object.baseAddress();
            break;
        }

        return base;
    }
}
