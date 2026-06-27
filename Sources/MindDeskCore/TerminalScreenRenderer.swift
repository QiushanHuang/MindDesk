import Foundation

public struct RenderedTerminalScreen: Equatable, Sendable {
    public var lines: [String]

    public var displayText: String {
        var visibleLines = lines
        while visibleLines.count > 1, visibleLines.last?.isEmpty == true {
            visibleLines.removeLast()
        }
        return visibleLines.joined(separator: "\n")
    }

    public init(lines: [String]) {
        self.lines = lines
    }
}

public enum TerminalScreenRenderer {
    public static func render(_ stream: String, rows: Int = 32, columns: Int = 100) -> RenderedTerminalScreen {
        let rowCount = max(1, rows)
        let columnCount = max(1, columns)
        var screen = TerminalScreen(rows: rowCount, columns: columnCount)
        let scalars = Array(stream.unicodeScalars)
        var index = 0

        while index < scalars.count {
            let scalar = scalars[index]
            switch scalar.value {
            case 0x1B:
                index = handleEscapeSequence(scalars, startingAt: index + 1, screen: &screen)
            case 0x08:
                screen.backspace()
                index += 1
            case 0x09:
                screen.tab()
                index += 1
            case 0x0A:
                screen.newline()
                index += 1
            case 0x0D:
                screen.carriageReturn()
                index += 1
            case 0x00...0x1F, 0x7F:
                index += 1
            default:
                screen.write(String(scalar))
                index += 1
            }
        }

        return RenderedTerminalScreen(lines: screen.renderedLines())
    }

    private static func handleEscapeSequence(
        _ scalars: [UnicodeScalar],
        startingAt index: Int,
        screen: inout TerminalScreen
    ) -> Int {
        guard index < scalars.count else { return index }
        let scalar = scalars[index]
        switch scalar {
        case "[":
            return handleCSI(scalars, startingAt: index + 1, screen: &screen)
        case "]":
            return skipOSC(scalars, startingAt: index + 1)
        case "7":
            screen.saveCursor()
            return index + 1
        case "8":
            screen.restoreCursor()
            return index + 1
        case "D":
            screen.newline()
            return index + 1
        case "E":
            screen.newline()
            screen.carriageReturn()
            return index + 1
        case "M":
            screen.reverseIndex()
            return index + 1
        case "(", ")", "*", "+", "-", ".", "/":
            return min(index + 2, scalars.count)
        default:
            return index + 1
        }
    }

    private static func handleCSI(
        _ scalars: [UnicodeScalar],
        startingAt index: Int,
        screen: inout TerminalScreen
    ) -> Int {
        var cursor = index
        var payload = ""
        while cursor < scalars.count {
            let value = scalars[cursor].value
            if (0x40...0x7E).contains(value) {
                let command = Character(scalars[cursor])
                applyCSI(payload: payload, command: command, screen: &screen)
                return cursor + 1
            }
            payload.unicodeScalars.append(scalars[cursor])
            cursor += 1
        }
        return cursor
    }

    private static func applyCSI(payload: String, command: Character, screen: inout TerminalScreen) {
        let parameters = numericParameters(from: payload)
        switch command {
        case "A":
            screen.moveCursor(rowDelta: -parameter(parameters, at: 0, defaultValue: 1), columnDelta: 0)
        case "B":
            screen.moveCursor(rowDelta: parameter(parameters, at: 0, defaultValue: 1), columnDelta: 0)
        case "C":
            screen.moveCursor(rowDelta: 0, columnDelta: parameter(parameters, at: 0, defaultValue: 1))
        case "D":
            screen.moveCursor(rowDelta: 0, columnDelta: -parameter(parameters, at: 0, defaultValue: 1))
        case "E":
            screen.moveCursor(rowDelta: parameter(parameters, at: 0, defaultValue: 1), columnDelta: 0)
            screen.carriageReturn()
        case "F":
            screen.moveCursor(rowDelta: -parameter(parameters, at: 0, defaultValue: 1), columnDelta: 0)
            screen.carriageReturn()
        case "G":
            screen.setCursor(row: nil, column: parameter(parameters, at: 0, defaultValue: 1) - 1)
        case "H", "f":
            screen.setCursor(
                row: parameter(parameters, at: 0, defaultValue: 1) - 1,
                column: parameter(parameters, at: 1, defaultValue: 1) - 1
            )
        case "J":
            screen.clearScreen(mode: parameter(parameters, at: 0, defaultValue: 0))
        case "K":
            screen.clearLine(mode: parameter(parameters, at: 0, defaultValue: 0))
        case "S":
            screen.scrollUp(parameter(parameters, at: 0, defaultValue: 1))
        case "T":
            screen.scrollDown(parameter(parameters, at: 0, defaultValue: 1))
        case "m", "h", "l", "n", "r", "s", "u":
            return
        default:
            return
        }
    }

    private static func numericParameters(from payload: String) -> [Int?] {
        let sanitized = payload
            .unicodeScalars
            .filter { scalar in
                ("0"..."9").contains(scalar) || scalar == ";"
            }
        let parameterText = String(String.UnicodeScalarView(sanitized))
        guard !parameterText.isEmpty else { return [] }
        return parameterText.split(separator: ";", omittingEmptySubsequences: false).map { value in
            guard !value.isEmpty else { return nil }
            return Int(value)
        }
    }

    private static func parameter(_ parameters: [Int?], at index: Int, defaultValue: Int) -> Int {
        guard parameters.indices.contains(index), let value = parameters[index] else {
            return defaultValue
        }
        return value == 0 ? defaultValue : value
    }

    private static func skipOSC(_ scalars: [UnicodeScalar], startingAt index: Int) -> Int {
        var cursor = index
        while cursor < scalars.count {
            if scalars[cursor].value == 0x07 {
                return cursor + 1
            }
            if scalars[cursor].value == 0x1B,
               cursor + 1 < scalars.count,
               scalars[cursor + 1] == "\\" {
                return cursor + 2
            }
            cursor += 1
        }
        return cursor
    }
}

private struct TerminalScreen {
    private let rows: Int
    private let columns: Int
    private var cells: [[String]]
    private var cursorRow = 0
    private var cursorColumn = 0
    private var savedCursor: (row: Int, column: Int)?

    init(rows: Int, columns: Int) {
        self.rows = rows
        self.columns = columns
        self.cells = Array(
            repeating: Array(repeating: " ", count: columns),
            count: rows
        )
    }

    mutating func write(_ scalar: String) {
        cells[cursorRow][cursorColumn] = scalar
        cursorColumn += 1
        if cursorColumn >= columns {
            cursorColumn = 0
            newline()
        }
    }

    mutating func newline() {
        cursorRow += 1
        if cursorRow >= rows {
            scrollUp(1)
            cursorRow = rows - 1
        }
    }

    mutating func reverseIndex() {
        cursorRow -= 1
        if cursorRow < 0 {
            scrollDown(1)
            cursorRow = 0
        }
    }

    mutating func carriageReturn() {
        cursorColumn = 0
    }

    mutating func backspace() {
        cursorColumn = max(0, cursorColumn - 1)
    }

    mutating func tab() {
        let nextTab = ((cursorColumn / 8) + 1) * 8
        cursorColumn = min(columns - 1, nextTab)
    }

    mutating func moveCursor(rowDelta: Int, columnDelta: Int) {
        setCursor(
            row: cursorRow + rowDelta,
            column: cursorColumn + columnDelta
        )
    }

    mutating func setCursor(row: Int?, column: Int?) {
        if let row {
            cursorRow = min(max(0, row), rows - 1)
        }
        if let column {
            cursorColumn = min(max(0, column), columns - 1)
        }
    }

    mutating func saveCursor() {
        savedCursor = (cursorRow, cursorColumn)
    }

    mutating func restoreCursor() {
        guard let savedCursor else { return }
        cursorRow = savedCursor.row
        cursorColumn = savedCursor.column
    }

    mutating func clearScreen(mode: Int) {
        switch mode {
        case 1:
            for row in 0...cursorRow {
                let range = row == cursorRow ? 0...cursorColumn : 0...(columns - 1)
                clear(row: row, columns: range)
            }
        case 2, 3:
            cells = Array(
                repeating: Array(repeating: " ", count: columns),
                count: rows
            )
        default:
            for row in cursorRow..<rows {
                let range = row == cursorRow ? cursorColumn...(columns - 1) : 0...(columns - 1)
                clear(row: row, columns: range)
            }
        }
    }

    mutating func clearLine(mode: Int) {
        switch mode {
        case 1:
            clear(row: cursorRow, columns: 0...cursorColumn)
        case 2:
            clear(row: cursorRow, columns: 0...(columns - 1))
        default:
            clear(row: cursorRow, columns: cursorColumn...(columns - 1))
        }
    }

    mutating func scrollUp(_ count: Int) {
        guard count > 0 else { return }
        for _ in 0..<min(count, rows) {
            cells.removeFirst()
            cells.append(Array(repeating: " ", count: columns))
        }
    }

    mutating func scrollDown(_ count: Int) {
        guard count > 0 else { return }
        for _ in 0..<min(count, rows) {
            cells.removeLast()
            cells.insert(Array(repeating: " ", count: columns), at: 0)
        }
    }

    func renderedLines() -> [String] {
        cells.map { row in
            var text = row.joined()
            while text.last == " " {
                text.removeLast()
            }
            return text
        }
    }

    private mutating func clear(row: Int, columns range: ClosedRange<Int>) {
        guard cells.indices.contains(row) else { return }
        for column in range where cells[row].indices.contains(column) {
            cells[row][column] = " "
        }
    }
}
