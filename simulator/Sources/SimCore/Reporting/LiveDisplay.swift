import Foundation

public struct LiveDisplay: Sendable {
    static let refreshNanoseconds: UInt64 = 500_000_000
    static let statusInterval = 30.0
    static let hideCursor = "\u{1B}[?25l"
    static let showCursor = "\u{1B}[?25h"

    private let task: Task<Int, Never>
    private let interactive: Bool

    public static func start(tracker: ProgressTracker, interactive: Bool = isatty(STDOUT_FILENO) != 0) -> LiveDisplay {
        if interactive { installSignalHandlers() }
        let task = Task.detached(priority: .utility) { await loop(tracker: tracker, interactive: interactive) }
        return LiveDisplay(task: task, interactive: interactive)
    }

    public func stop() async {
        task.cancel()
        let drawn = await task.value
        guard interactive else { return }
        if drawn > 0 { Self.emit("\u{1B}[\(drawn)A\r\u{1B}[J") }
        Self.emit(Self.showCursor)
        Self.restoreSignalHandlers()
    }

    static func loop(tracker: ProgressTracker, interactive: Bool) async -> Int {
        var drawn = 0
        var lastStatus = 0.0
        if interactive { emit(hideCursor) }
        while !Task.isCancelled {
            let snapshot = tracker.snapshot()
            if interactive {
                drawn = draw(LiveDashboard.lines(snapshot, width: terminalWidth()), previous: drawn)
            } else if snapshot.elapsed - lastStatus >= statusInterval {
                lastStatus = snapshot.elapsed
                emit(LiveDashboard.statusLine(snapshot) + "\n")
            }
            try? await Task.sleep(nanoseconds: refreshNanoseconds)
        }
        return drawn
    }

    static func draw(_ lines: [String], previous: Int) -> Int {
        var output = previous > 0 ? "\u{1B}[\(previous)A\r" : ""
        for line in lines { output += line + "\u{1B}[K\n" }
        output += "\u{1B}[J"
        emit(output)
        return lines.count
    }

    static func emit(_ text: String) {
        fflush(nil)
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    static func terminalWidth() -> Int {
        var size = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 && size.ws_col > 0 { return Int(size.ws_col) }
        if let value = ProcessInfo.processInfo.environment["COLUMNS"], let columns = Int(value), columns > 0 { return columns }
        return 80
    }

    static func installSignalHandlers() {
        let handler: @convention(c) (Int32) -> Void = { signalNumber in
            let restore = Array("\u{1B}[?25h\n".utf8)
            _ = restore.withUnsafeBufferPointer { write(STDOUT_FILENO, $0.baseAddress, $0.count) }
            _exit(128 + signalNumber)
        }
        signal(SIGINT, handler)
        signal(SIGTERM, handler)
    }

    static func restoreSignalHandlers() {
        signal(SIGINT, SIG_DFL)
        signal(SIGTERM, SIG_DFL)
    }
}
