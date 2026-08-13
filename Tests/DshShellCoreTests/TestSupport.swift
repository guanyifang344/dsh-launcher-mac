import Foundation

/// 极简测试框架：不依赖 XCTest，兼容仅安装 Command Line Tools（无 Xcode）的环境。
/// 用法：`expect("名称") { try expectEqual(a, b) }`，最后由 `runTests()` 汇总并退出。

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private struct TestCase {
    let name: String
    let body: () throws -> Void
}

private var cases: [TestCase] = []
private var failureCount = 0

/// 注册一个测试用例。
func expect(_ name: String, _ body: @escaping () throws -> Void) {
    cases.append(TestCase(name: name, body: body))
}

/// 断言相等。
func expectEqual<T: Equatable>(
    _ actual: T, _ expected: T, _ message: String = "",
    file: String = #filePath, line: Int = #line
) throws {
    guard actual == expected else {
        throw TestFailure(description: "\(file):\(line) \(message) — expected \(expected), got \(actual)")
    }
}

/// 断言为真。
func expectTrue(
    _ condition: Bool, _ message: String = "",
    file: String = #filePath, line: Int = #line
) throws {
    guard condition else {
        throw TestFailure(description: "\(file):\(line) \(message) — expected true, got false")
    }
}

/// 运行全部用例，打印结果，并以 0（全通过）/1（有失败）退出。
func runTests() -> Never {
    for c in cases {
        do {
            try c.body()
            print("  ✓ \(c.name)")
        } catch {
            failureCount += 1
            print("  ✗ \(c.name)")
            print("    \(error)")
        }
    }
    let total = cases.count
    if failureCount == 0 {
        print("全部通过：\(total) 个用例")
        exit(0)
    } else {
        print("失败：\(failureCount) / \(total)")
        exit(1)
    }
}
