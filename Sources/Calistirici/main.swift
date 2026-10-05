#if os(macOS)
import NotDefteriMac

Ana.main()
#elseif os(Linux)
import Glibc
import NotDefteriLinux

exit(LinuxUygulamasi.calistir())
#endif
