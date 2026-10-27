package main

import "core:fmt"
import "core:os"
import "core:strings"

Mode :: enum {
	Auto,
	To_Spaces,
	To_Newlines,
	To_Null,
}

print_help :: proc() {
	fmt.println("Usage: delim-swap [flags]")
	fmt.println("Converts between newline and space-delimited input from stdin.")
	fmt.println()
	fmt.println("Flags:")
	fmt.println("  -s, --spaces     Force output to space-separated")
	fmt.println("  -n, --newlines   Force output to newline-separated")
	fmt.println("  -0, --null       Output null-terminated items (for xargs -0)")
	fmt.println("  -h, --help       Show help text")
}

main :: proc() {
	mode := Mode.Auto
	for arg in os.args[1:] {
		switch arg {
		case "-s", "--spaces":
			mode = .To_Spaces
		case "-n", "--newlines":
			mode = .To_Newlines
		case "-0", "--null":
			mode = .To_Null
		case "-h", "--help":
			print_help()
			return
		}
	}
	// Read entire stream from stdin pipe in chunks
	raw_input: [dynamic]u8
	defer delete(raw_input)
	chunk: [4096]u8
	for {
		n, err := os.read(os.stdin, chunk[:])
		if err != nil || n <= 0 {
			break
		}
		append(&raw_input, ..chunk[:n])
	}
	if len(raw_input) == 0 {
		return
	}
	input_str := string(raw_input[:])
	trimmed := strings.trim_right(input_str, "\r\n")
	has_newlines := strings.contains_rune(trimmed, '\n')
	target_mode := mode
	if target_mode == .Auto {
		target_mode = .To_Spaces if has_newlines else .To_Newlines
	}
	tokens: [dynamic]string
	defer delete(tokens)
	if has_newlines && mode != .To_Newlines {
		// Line-oriented input: split strictly on newlines to preserve paths with spaces
		lines := strings.split(trimmed, "\n")
		defer delete(lines)
		for line in lines {
			clean_line := strings.trim_right(line, "\r")
			if len(clean_line) > 0 {
				append(&tokens, clean_line)
			}
		}
	}
	else {
		// Space-oriented input: split on arbitrary whitespace
		fields := strings.fields(trimmed)
		defer delete(fields)
		for field in fields {
			append(&tokens, field)
		}
	}
	if len(tokens) == 0 {
		return
	}
	sep: string
	switch target_mode {
	case .To_Spaces:
		sep = " "
	case .To_Newlines:
		sep = "\n"
	case .To_Null:
		sep = "\x00"
	case .Auto:
		sep = " "
	}

	for token, i in tokens {
		fmt.print(token)
		if i < len(tokens) - 1 {
			fmt.print(sep)
		}
	}

	if target_mode == .To_Null {
		fmt.print("\x00")
	}
	else {
		fmt.println()
	}
}
