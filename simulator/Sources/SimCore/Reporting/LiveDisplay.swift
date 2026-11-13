import Foundation
import os

public final class LiveDisplay: Sendable {
    static let refreshSeconds = 0.5
    static let statusInterval = 30.0
    static let hideCursor = "\u{1B}[?25l"
    static let showCursor = "\u{1B}[?25h"
    public static let descriptor = STDERR_FILENO

    private let interactive: Bool
    private let stopSignal = DispatchSemaphore(value: 0)
    private let finished = DispatchSemaphore(value: 0)
    private let drawnRows = OSAllocatedUnfairLock(initialState: 0)
    private let previousHandlers: SignalHandlers?

    init(interactive: Bool, previousHandlers: SignalHandlers?) {
        self.interactive = interactive
        self.previousHandlers = previousHandlers
    }

    public static func start(tracker: ProgressTracker, interactive: Bool = isatty(descriptor) != 0) -> LiveDisplay {
        let handlers = interactive ? installSignalHandlers() : nil
        let display = LiveDisplay(interactive: interactive, previousHandlers: handlers)
        let thread = Thread { display.loop(tracker: tracker) }
        thread.qualityOfService = .userInteractive
        thread.start()
        return display
    }

    public func stop() {
        stopSignal.signal()
        finished.wait()
        guard interactive else { return }
        let rows = drawnRows.withLock { $0 }
        if rows > 0 { Self.emit("\u{1B}[\(rows)A\r\u{1B}[J") }
        Self.emit(Self.showCursor)
        previousHandlers?.restore()
    }

    func loop(tracker: ProgressTracker) {
        var frame = Frame()
        var lastStatus = 0.0
        if interactive { Self.emit(Self.hideCursor) }
        repeat {
            let snapshot = tracker.snapshot()
            if interactive {
                frame = Self.draw(snapshot, after: frame, width: Self.terminalWidth())
                let rows = frame.rows
                drawnRows.withLock { $0 = rows }
            } else if snapshot.elapsed - lastStatus >= Self.statusInterval {
                lastStatus = snapshot.elapsed
                Self.emit(LiveDashboard.statusLine(snapshot) + "\n")
            }
        } while stopSignal.wait(timeout: .now() + Self.refreshSeconds) == .timedOut
        finished.signal()
    }

    struct Frame: Sendable, Equatable {
        var lengths: [Int] = []

        var rows: Int { lengths.count }

        func rowsOccupied(width: Int) -> Int {
            let columns = max(1, width)
            return lengths.reduce(0) { $0 + max(1, ($1 + columns - 1) / columns) }
        }
    }

    static func fitted(_ lines: [String], width: Int) -> [String] {
        lines.map { LiveDashboard.truncate($0, max(1, width - 1)) }
    }

    static func frameText(_ lines: [String], after previous: Frame, width: Int) -> String {
        let up = previous.rowsOccupied(width: width)
        var output = up > 0 ? "\u{1B}[\(up)A\r" : ""
        for line in lines { output += line + "\u{1B}[K\n" }
        return output + "\u{1B}[J"
    }

    static func draw(_ snapshot: ProgressSnapshot, after previous: Frame, width: Int) -> Frame {
        let lines = fitted(LiveDashboard.lines(snapshot, width: width), width: width)
        emit(frameText(lines, after: previous, width: width))
        return Frame(lengths: lines.map(\.count))
    }

    static func emit(_ text: String) {
        fflush(nil)
        FileHandle.standardError.write(Data(text.utf8))
    }

    static func terminalWidth() -> Int {
        var size = winsize()
        if ioctl(descriptor, TIOCGWINSZ, &size) == 0 && size.ws_col > 0 { return Int(size.ws_col) }
        if let value = ProcessInfo.processInfo.environment["COLUMNS"], let columns = Int(value), columns > 0 { return columns }
        return 80
    }

    static func installSignalHandlers() -> SignalHandlers {
        let handler: @convention(c) (Int32) -> Void = { signalNumber in
            let restore = Array("\u{1B}[?25h\n".utf8)
            _ = restore.withUnsafeBufferPointer { write(STDERR_FILENO, $0.baseAddress, $0.count) }
            _exit(128 + signalNumber)
        }
        return SignalHandlers(interrupt: signal(SIGINT, handler), terminate: signal(SIGTERM, handler))
    }
}

struct SignalHandlers: @unchecked Sendable {
    let interrupt: sig_t?
    let terminate: sig_t?

    func restore() {
        signal(SIGINT, interrupt)
        signal(SIGTERM, terminate)
    }
}
