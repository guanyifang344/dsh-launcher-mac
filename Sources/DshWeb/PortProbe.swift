import Foundation

/// 端口探测：判断 127.0.0.1 上目标端口是否已监听。
enum PortProbe {
    /// 通过 POSIX socket connect 探测端口是否可连接（无副作用，连接后立即关闭）。
    static func isOpen(host: String = "127.0.0.1", port: Int) -> Bool {
        guard port > 0, port <= 65535 else { return false }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var result: Int32 = -1
        withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr in
                result = connect(fd, ptr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }
}
